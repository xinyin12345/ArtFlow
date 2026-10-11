"""Build exact frozen parameter ROMs and 22 shared-engine descriptors."""
import json, hashlib, sys
from pathlib import Path
import numpy as np

R=Path(__file__).resolve().parent
E=R/'reference/exports' if (R/'reference/exports').exists() else R.parent/'style_s8_integer/exports'
graph=json.loads((E/'graph.json').read_text(encoding='utf-8'))
P=np.load(str(E/'model_int.npz'),allow_pickle=False)
assert hashlib.sha256((E/'model_int.npz').read_bytes()).hexdigest()==graph['params_sha256']
nodes=graph['nodes']; byname={n['name']:n for n in nodes}
layers=[]; wb=[]; bb=[]; mm=[]; tensors={'input.rgb8':dict(slot=0,scale=1,ci=3,signed=0)}
uses={}
# Fused nearest2 -> DW, conv -> Q4/add/RGB. Allocate three DDR buffers by liveness.
for n in nodes:
    if n['kind']!='conv': continue
    q=next(x for x in nodes if x.get('input')==n['name'])
    source=n['input']; up=byname.get(source,{}).get('kind')=='nearest2'
    if up: source=byname[source]['input']
    skip=q.get('skip')
    uses[source]=uses.get(source,0)+1
    if skip: uses[skip]=uses.get(skip,0)+1
    layers.append(dict(n=n,q=q,source=source,skip=skip,up=up))
conf=[]
for li,l in enumerate(layers):
    n,q=l['n'],l['q']; src=tensors[l['source']]; w=P[n['weight']]; co,ci0,kh,kw=w.shape
    ci=src['ci']; dw=n['groups']!=1; cgroups=(co+7)//8; igroups=(ci+11)//12
    mode=1 if q['kind']=='add' else (2 if q.get('rounding')=='nearest_even' else 0)
    inputs=[l['source']]+([l['skip']] if l['skip'] else [])
    for s in inputs: uses[s]-=1
    occupied={v['slot'] for k,v in tensors.items() if uses.get(k,0)>0 or k in inputs}
    free=[x for x in range(3) if x not in occupied]
    assert free, (li,occupied)
    dst=free[0]
    scale=src['scale']*n['stride']//(2 if l['up'] else 1)
    c=dict(index=li,name=n['name'],output=q['name'],ci=ci,co=co,istride=((ci+7)//8)*8,
           ostride=cgroups*8,scale_in=src['scale'],scale_out=scale,
           dw=int(dw),kernel=kh,stride=n['stride'],up=int(l['up']),signed=src['signed'],mode=mode,
           src=src['slot'],dst=dst,skip=tensors[l['skip']]['slot'] if l['skip'] else 0,
           skip_signed=tensors[l['skip']]['signed'] if l['skip'] else 0,
           wbase=len(wb),cbase=len(bb),igroups=igroups,cgroups=cgroups)
    for og in range(cgroups):
        if dw:
            word=0
            for o in range(8):
                for t in range(9):
                    val=int(w[og*8+o,0,t//3,t%3]) if og*8+o<co else 0
                    word|=(val&255)<<((o*12+t)*8)
            wb.append(word)
        else:
            for t in range(kh*kw):
                for ig in range(igroups):
                    word=0
                    for o in range(8):
                        for i in range(12):
                            oc,ic=og*8+o,ig*12+i
                            val=int(w[oc,ic,t//kw,t%kw]) if oc<co and ic<ci else 0
                            word|=(val&255)<<((o*12+i)*8)
                    wb.append(word)
    bias=P[n['bias']]
    m=P[q['main_multiplier'] if mode==1 else q['multiplier']].reshape(-1)
    if len(m)==1:m=np.repeat(m,co)
    assert np.all(m>0) and int(m.max())<2**35
    assert max(n['accumulator_abs_bound'])<2**19
    for quad in range(cgroups*2):
        bword=mword=0
        for j in range(4):
            oc=quad*4+j
            b=int(bias[oc]) if oc<co else 0
            mul=int(m[oc]) if oc<co else 0
            bword|=(b&0xfffff)<<(j*20);mword|=mul<<(j*36)
        bb.append(bword);mm.append(mword)
    ms=P[q['skip_multiplier']].reshape(-1) if mode==1 else np.array([0])
    assert len(set(map(int,ms)))==1
    c['ms']=int(ms[0]);conf.append(c)
    tensors[q['name']]=dict(slot=dst,scale=scale,ci=co,signed=int(mode==1))
assert len(conf)==22 and len(wb)<=512 and len(bb)<=256
(R/'mem').mkdir(exist_ok=True)
for name,data,bits,depth in [('weights',wb,768,512),('bias',bb,80,256),('main',mm,144,256)]:
    (R/'mem'/('shared_'+name+'.mem')).write_text(''.join(('%0*x\n'%((bits+3)//4,v)) for v in data+[0]*(depth-len(data))),encoding='ascii')
decl=['// Generated from frozen integer graph; register descriptors once per layer.','always @(posedge clk) begin if(state==NEW_LAYER) begin',
      'ci=3; co=8; isp=8; osp=8; iw=W; ih=H; ow=W/2; oh=H/2;',
      'dw=0; k3=1; stride2=1; sign_in=0; mode=0; src_slot=0; dst_slot=1; skip_slot=0; skip_sign=0;',
      'wbase=0; cbase=0; ng=1; ogs=1; skip_mul=0;', 'case (layer_index)']
for c in conf:
    decl+=['%d: begin // %s'%(c['index'],c['name']),
      'ci=%d;co=%d;isp=%d;osp=%d;iw=W/%d;ih=H/%d;ow=W/%d;oh=H/%d;'%(c['ci'],c['co'],c['istride'],c['ostride'],c['scale_in'],c['scale_in'],c['scale_out'],c['scale_out']),
      'dw=%d;k3=%d;stride2=%d;sign_in=%d;mode=%d;src_slot=%d;dst_slot=%d;skip_slot=%d;skip_sign=%d;'%(c['dw'],c['kernel']==3,c['stride']==2,c['signed'],c['mode'],c['src'],c['dst'],c['skip'],c['skip_signed']),
      "wbase=%d;cbase=%d;ng=%d;ogs=%d;skip_mul=36'd%d;end"%(c['wbase'],c['cbase'],c['igroups'],c['cgroups'],c['ms'])]
decl+=['default: begin end','endcase','end end']
(R/'rtl/layer_config.vh').write_text('\n'.join(decl)+'\n',encoding='ascii')
report=dict(model_sha256=graph['params_sha256'],weight_words=len(wb),coefficient_quad_words=len(bb),layers=conf,
            layout='NHWC byte codes, channels padded to 8, three 2MiB DDR regions',
            external_hw=[270,480],internal_hw=[272,480],input_pad='bottom reflection excluding edge',output_crop='first 270 rows')
(R/'architecture.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
top=(R/'rtl/s8_shared.v').read_text().replace('`include "layer_config.vh"',(R/'rtl/layer_config.vh').read_text())
for name in ['shared_mac','shared_quant','shared_line']:top+='\n'+(R/'rtl'/(name+'.v')).read_text()
(R/'s8_shared_flat.v').write_text(top,encoding='ascii')
print('Generated',len(conf),'layers,',len(wb),'weight words,',len(bb),'coefficient quads')
