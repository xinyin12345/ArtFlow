"""Read back every ROM coefficient using the RTL address layout."""
from pathlib import Path
import json,hashlib
import numpy as np
R=Path(__file__).resolve().parent
E=R/'reference/exports' if (R/'reference/exports').exists() else R.parent/'style_s8_integer/exports'
G=json.loads((E/'graph.json').read_text());P=np.load(str(E/'model_int.npz'),allow_pickle=False)
C=json.loads((R/'architecture.json').read_text())['layers']
N={x['name']:x for x in G['nodes']}
W=[int(x,16) for x in (R/'mem/shared_weights.mem').read_text().splitlines()]
B=[int(x,16) for x in (R/'mem/shared_bias.mem').read_text().splitlines()]
M=[int(x,16) for x in (R/'mem/shared_main.mem').read_text().splitlines()]
def signed(v,bits):return v-(1<<bits) if v>>(bits-1) else v
counts=dict(weights=0,biases=0,main_multipliers=0,skip_multipliers=0)
bound=0
for c in C:
    n=N[c['name']];q=N[c['output']];w=P[n['weight']];bias=P[n['bias']]
    m=P[q['main_multiplier'] if c['mode']==1 else q['multiplier']].reshape(-1)
    if m.size==1:m=np.repeat(m,c['co'])
    bound=max(bound,max(n['accumulator_abs_bound']))
    for oc in range(c['co']):
        group,lane=divmod(oc,8);qa=c['cbase']+oc//4;ql=oc%4
        assert signed((B[qa]>>(ql*20))&0xfffff,20)==int(bias[oc])
        assert (M[qa]>>(ql*36))&((1<<36)-1)==int(m[oc])
        counts['biases']+=1;counts['main_multipliers']+=1
        for ic in range(w.shape[1]):
            for ky in range(w.shape[2]):
                for kx in range(w.shape[3]):
                    tap=ky*w.shape[3]+kx
                    if c['dw']:addr=c['wbase']+group;offset=(lane*12+tap)*8
                    else:
                        addr=c['wbase']+group*(w.shape[2]*w.shape[3]*c['igroups'])+tap*c['igroups']+ic//12
                        offset=(lane*12+ic%12)*8
                    assert signed((W[addr]>>offset)&255,8)==int(w[oc,ic,ky,kx]),(c['name'],oc,ic,ky,kx)
                    counts['weights']+=1
    if c['mode']==1:
        ms=P[q['skip_multiplier']].reshape(-1)
        assert np.all(ms==c['ms']);counts['skip_multipliers']+=ms.size
assert bound<2**19
out=dict(pass_all=True,counts=counts,max_accumulator_abs_bound=bound,s20_safe=True,
         model_sha256=hashlib.sha256((E/'model_int.npz').read_bytes()).hexdigest(),
         rom_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (R/'mem').glob('*.mem')})
(R/'parameter_readback_audit.json').write_text(json.dumps(out,indent=2),encoding='utf-8');print(json.dumps(out,indent=2))
