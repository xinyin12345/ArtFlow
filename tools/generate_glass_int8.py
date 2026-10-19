"""Generate exact glass INT8 ROMs and descriptors; no quantization or retraining."""
from pathlib import Path
import json,hashlib,math
import numpy as np
R=Path(__file__).resolve().parents[1]
N=R/'network/glass_5_20epochs_sum8192_480x270_input3x3_res32_r4_int8'
O=R/'rtl/cnn/glass_int8'
def main():
    O.mkdir(parents=True,exist_ok=True)
    g=json.loads((N/'parameters/graph.json').read_text());p=np.load(N/'parameters/model_int8.npz')
    assert len(g['nodes'])==22 and g['rgb_shift']==24
    slots={'input':0};divs={'input':1};weights=[];coeffs=[];layers=[];cases=[]
    def packed(a,b):return sum((int(v)&((1<<b)-1))<<(i*b) for i,v in enumerate(a))
    for idx,n in enumerate(g['nodes']):
        name=n['name'];w=p[name+'.weight'];co,ic,k,_=w.shape;dw=n['groups']!=1
        ci=co if dw else ic;ng=(ci+7)//8;ogs=(co+7)//8
        assert ci in (3,8,16,32) and co in (3,8,16,32) and k in (1,3,5)
        assert n['stride'] in (1,2) and (not n['up2_before'] or dw)
        src=slots[n['source']];skip=slots[n['skip']] if n['skip'] else 0
        dst=next(x for x in range(3) if x!=src and (not n['skip'] or x!=skip))
        # Retain residual input while its reduce/spatial children execute.
        if name.endswith('_spatial'):dst=2
        slots[name]=dst;d=divs[n['source']];od=d*n['stride']//(2 if n['up2_before'] else 1);divs[name]=od
        assert ng/d<=2 and (480//od)*(272//od)*ogs*8<=2**21,'DDR/cache capacity exceeded'
        wb=len(weights);cb=len(coeffs)
        for og in range(ogs):
            for ky in range(k):
                for kx in range(k):
                    for ig in range(1 if dw else ng):
                        block=np.zeros((8,8),np.int64)
                        for o in range(8):
                            if og*8+o>=co:continue
                            for i in range(8):
                                if dw:
                                    if i==o:block[o,i]=w[og*8+o,0,ky,kx]
                                elif ig*8+i<ci:block[o,i]=w[og*8+o,ig*8+i,ky,kx]
                        weights.append(packed(block.flat,8))
            a=[]
            for o in range(8):
                c=og*8+o
                a.append(0 if c>=co else packed([p[name+'.bias'][c]],24) |
                         (packed([p[name+'.multiplier'][c]],21)<<24) |
                         (packed([p[name+'.beta_fixed'][c]],32)<<45))
            coeffs.append(packed(a,77))
        c=dict(n,index=idx,ci=ci,co=co,ng=ng,ogs=ogs,src=src,dst=dst,skip_slot=skip,div=d,out_div=od,wbase=wb,cbase=cb)
        layers.append(c)
        cases.append(f"""  {idx}:begin // {name}
   ci<={ci};co<={co};ng<={ng};ogs<={ogs};iw<=W/{d};ih<=H/{d};ow<=W/{od};oh<=H/{od};
   row_words<=W/{d}*{ng};out_row_words<=W/{od}*{ogs};
   kernel<={k};radius<={k//2};dw<={int(dw)};up2<={int(n['up2_before'])};stride2<={int(n['stride']==2)};
   center<={int(n['center'])};signed_input<={int(idx!=0)};has_skip<={int(n['skip'] is not None)};relu<={int(n['qmin']==0)};rgb<={int(idx==21)};
   src_slot<={src};dst_slot<={dst};skip_slot<={skip};wbase<={wb};cbase<={cb};steps<={k*k*(1 if dw else ng)};
   skip_mul<=25'd{int(p[name+'.skip_multiplier'][0])};
  end""")
    for name,values,bits,depth in [('weights',weights,512,256),('coeff',coeffs,616,64)]:
        assert len(values)<=depth,(name,len(values))
        (O/(name+'.mem')).write_text(''.join(f'{v:0{bits//4}x}\n' for v in values+[0]*(depth-len(values))))
    for lane in range(8):
        vals=[(v>>(lane*77))&((1<<77)-1) for v in coeffs]+[0]*(64-len(coeffs))
        (O/f'coeff{lane}.mem').write_text(''.join(f'{v:020x}\n' for v in vals))
    (O/'layers.vh').write_text('case(layer_index)\n'+'\n'.join(cases)+'\n default:begin end\nendcase\n')
    rgb=[]
    for i in range(3):rgb.append(f"  {i}:begin rgb_mul=28'd{int(p['rgb.multiplier'][i])};rgb_bias=32'sd{int(p['rgb.bias'][i])};end")
    (O/'rgb.vh').write_text('case(qchannel)\n'+'\n'.join(rgb)+"\n default:begin rgb_mul=0;rgb_bias=0;end\nendcase\n")
    proof=json.loads((N/'parameters/range_proof.json').read_text())
    assert max(x['convolution_bits'] for x in proof['layers'])<=24
    assert max(x['spatial_sum_bits'] for x in proof['layers'])<=40
    assert max(x['requant_bits'] for x in proof['layers'])<=48
    for n in g['nodes']:
        assert n['shift']==24 and n['mean_divisor']==8192
        for suffix,bits in [('bias',24),('multiplier',21),('beta_fixed',32),('skip_multiplier',25)]:
            a=p[n['name']+'.'+suffix];assert int(a.min())>=-(1<<(bits-1)) and int(a.max())<(1<<(bits-1))
    (O/'architecture.json').write_text(json.dumps(dict(layers=layers,weight_words=len(weights),coefficient_words=len(coeffs),final_slot=layers[-1]['dst']),indent=2))
    print('ROM PASS',len(weights),'weight words;',len(coeffs),'coefficient words; final slot',layers[-1]['dst'])
if __name__=='__main__':main()


