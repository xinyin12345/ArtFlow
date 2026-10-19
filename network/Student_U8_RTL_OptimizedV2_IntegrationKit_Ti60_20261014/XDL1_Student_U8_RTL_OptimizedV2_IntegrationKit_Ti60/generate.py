# -*- coding: utf-8 -*-
"""Freeze the accepted U8 integer graph into exact ROMs and DDR descriptors."""
from pathlib import Path
import json, hashlib
import numpy as np
R=Path(__file__).resolve().parent
E=R/'reference/integer'
pins=json.loads((E/'SHA256.json').read_text('utf8'))
for name in ('graph.json','model_int.npz','range_proof.json'):
    assert hashlib.sha256((E/name).read_bytes()).hexdigest()==pins[name],name
graph=json.loads((E/'graph.json').read_text('utf8'))
proof=json.loads((E/'range_proof.json').read_text('utf8'))
assert proof['max_conv_bound']<2**23
assert proof['max_requant_bound']<2**47
assert proof['max_statistics_product_bound']<2**60
P=np.load(E/'model_int.npz',allow_pickle=False)
nodes=graph['nodes'];uses={};tensors={'input':dict(slot=0,scale=1,ci=3,signed=0,wide=0)}
for n in nodes:
    for name in [n['source']]+([n['skip']] if n['skip'] else []):uses[name]=uses.get(name,0)+1
conf=[];wb=[];bb=[];mm=[];bet=[]
for li,n in enumerate(nodes):
    name=n['name'];src=tensors[n['source']];w=P[name+'.weight'];co,_,kh,kw=w.shape
    ci=src['ci'];dw=n['groups']!=1;ogs=(co+7)//8;ng=(ci+11)//12
    assert ci<=16 and co<=16 and ogs<=2 and ng<=2, 'Optimized address logic is for the frozen B8R3 graph'
    mode=2 if n['kind']=='rgb' else 1 if n['skip'] else 3 if n['qmin']==-2048 else 0
    inputs=[n['source']]+([n['skip']] if n['skip'] else [])
    for s in inputs:uses[s]-=1
    occupied={v['slot'] for k,v in tensors.items() if uses.get(k,0)>0 or k in inputs}
    free=[s for s in range(3) if s not in occupied];assert free,(li,occupied)
    scale=src['scale']*n['stride']//(2 if n['up2_before'] else 1)
    c=dict(index=li,name=name,ci=ci,co=co,istride=((ci+7)//8)*8*(2 if src['wide'] else 1),
           ostride=ogs*8*(2 if mode==3 else 1),scale_in=src['scale'],scale_out=scale,
           dw=int(dw),up=int(n['up2_before']),kernel=kh,stride=n['stride'],
           signed=src['signed'],wide=src['wide'],mode=mode,center=int(n['center']),
           src=src['slot'],dst=free[0],skip=tensors[n['skip']]['slot'] if n['skip'] else 0,
           skip_signed=tensors[n['skip']]['signed'] if n['skip'] else 0,
           wbase=len(wb),cbase=len(bb),igroups=ng,cgroups=ogs)
    for og in range(ogs):
        if dw:
            word=0
            for o in range(8):
                for t in range(9):
                    val=int(w[og*8+o,0,t//3,t%3]) if og*8+o<co else 0
                    word|=(val&255)<<((o*12+t)*8)
            wb.append(word)
        else:
            for t in range(kh*kw):
                for ig in range(ng):
                    word=0
                    for o in range(8):
                        for i in range(12):
                            oc,ic=og*8+o,ig*12+i
                            val=int(w[oc,ic,t//kw,t%kw]) if oc<co and ic<ci else 0
                            word|=(val&255)<<((o*12+i)*8)
                    wb.append(word)
    bias=P[name+'.bias'];m=P[name+'.multiplier'];beta=P[name+'.beta_fixed']
    assert np.all(m>0) and m.max()<2**20
    assert np.max(np.abs(bias.astype(np.int64)))<2**23
    assert np.max(np.abs(beta))<2**31
    if n['center']:assert np.all(bias==0)
    for quad in range(ogs*2):
        bword=mword=tword=0
        for j in range(4):
            oc=quad*4+j
            b=int(bias[oc]) if oc<co else 0
            mul=int(m[oc]) if oc<co else 0
            bt=int(beta[oc]) if oc<co else 0
            bword|=(b&0xffffff)<<(j*24);mword|=mul<<(j*21);tword|=(bt&0xffffffff)<<(j*32)
        bb.append(bword);mm.append(mword);bet.append(tword)
    c['ms']=int(P[name+'.skip_multiplier'][0]) if n['skip'] else 0
    assert c['ms']<2**24
    conf.append(c)
    tensors[name]=dict(slot=c['dst'],scale=scale,ci=co,signed=int(mode in (1,3)),wide=int(mode==3))
assert len(conf)==19 and len(wb)<=128 and len(bb)<=64
for name,data,bits,depth in [('weights',wb,768,128),('bias',bb,96,64),('main',mm,84,64),('beta',bet,128,64)]:
    (R/'mem'/('shared_'+name+'.mem')).write_text(''.join('%0*x\n'%((bits+3)//4,v) for v in data+[0]*(depth-len(data))),encoding='ascii')
decl=['// Generated from SHA256-pinned U8 integer graph.','always @(posedge clk) if(state==NEW_LAYER) begin','case(layer_index)']
for c in conf:
    decl+=['%d: begin // %s'%(c['index'],c['name']),
      'ci=%d;co=%d;isp=%d;osp=%d;iw=W/%d;ih=H/%d;ow=W/%d;oh=H/%d;'%(c['ci'],c['co'],c['istride'],c['ostride'],c['scale_in'],c['scale_in'],c['scale_out'],c['scale_out']),
      'dw=%d;up2=%d;k3=%d;stride2=%d;sign_in=%d;wide_in=%d;mode=%d;center=%d;src_slot=%d;dst_slot=%d;skip_slot=%d;skip_sign=%d;'%(c['dw'],c['up'],c['kernel']==3,c['stride']==2,c['signed'],c['wide'],c['mode'],c['center'],c['src'],c['dst'],c['skip'],c['skip_signed']),
      "wbase=%d;cbase=%d;ng=%d;ogs=%d;skip_mul=25'd%d;end"%(c['wbase'],c['cbase'],c['igroups'],c['cgroups'],c['ms'])]
decl+=['default: begin end','endcase','end']
(R/'rtl/layer_config.vh').write_text('\n'.join(decl)+'\n',encoding='ascii')
report=dict(model_sha256=pins['model_int.npz'],source='accepted QAT selected epoch 4, no retraining',
    weight_words=len(wb),coefficient_quad_words=len(bb),layers=conf,
    layout='NHWC; channels padded to 8; U8/S8 byte, S12 sign-extended little-endian 16 bit; three 2 MiB slots',
    external_hw=[270,480],internal_hw=[272,480],center='exact same-frame source-tap statistics projection; one convolution pass',
    widths=dict(mac_input=13,weight=8,accumulator=24,main_multiplier=21,skip_multiplier=25,center_sum=40,requant=48,mean_product=61),
    optimizations=['exact source-tap statistics projection', 'cached layer bias and multipliers',
                   'eight accumulators initialized together', 'all 16 DW channels captured together',
                   'pointwise next-row prefetch into existing line RAM', 'DSP-free fixed-graph addresses'])
(R/'architecture.json').write_text(json.dumps(report,indent=2),encoding='utf8')
top=(R/'rtl/student_u8.v').read_text().replace('`include "layer_config.vh"',(R/'rtl/layer_config.vh').read_text())
for name in ['shared_mac','shared_quant','shared_line','center_div','source_stats']:
    top+='\n'+(R/'rtl'/(name+'.v')).read_text()
(R/'student_u8_flat.v').write_text(top,encoding='ascii')
print('Generated',len(conf),'layers,',len(wb),'weight words,',len(bb),'coefficient quads')
