"""Independent NumPy integer-only student. No torch, floats or dequantization.

Dynamic means use the preceding stored integer feature statistics, projected
through integer weights with exact reflection-edge corrections. All data-path
operations are integer; coefficient generation is exclusively offline.
"""
import json
from pathlib import Path
import numpy as np
from integer_ops import conv2d_int,round_shift_half_up,round_shift_even

def round_divide(x,n):
    q=x//n;r=x-q*n
    return q+(r*2>=n).astype(np.int64)

def tap_sums(x):
    h,w=x.shape[-2:]
    dy=[[(1,1),(h-1,-1)],[],[(h-2,1),(0,-1)]]
    dx=[[(1,1),(w-1,-1)],[],[(w-2,1),(0,-1)]]
    total=x.sum((-2,-1),dtype=np.int64)
    out=np.empty((*x.shape[:2],3,3),np.int64)
    rows={i:x[:,:,i,:].sum(-1,dtype=np.int64) for i in (0,1,h-2,h-1)}
    cols={i:x[:,:,:,i].sum(-1,dtype=np.int64) for i in (0,1,w-2,w-1)}
    for a,ry in enumerate(dy):
        for b,cx in enumerate(dx):
            v=total.copy()
            for i,s in ry:v+=s*rows[i]
            for j,s in cx:v+=s*cols[j]
            for i,s in ry:
                for j,t in cx:v+=s*t*x[:,:,i,j]
            out[:,:,a,b]=v
    return out

class IntegerStudent:
    def __init__(self,directory):
        d=Path(directory)
        self.graph=json.loads((d/'graph.json').read_text('utf8'))
        if self.graph['format']!='student_b8r3_integer_v1':raise ValueError('Unsupported graph')
        with np.load(d/'model_int.npz',allow_pickle=False) as p:self.params={n:p[n].copy() for n in p.files}
        if any(v.dtype.kind not in 'iu' for v in self.params.values()):raise TypeError('Noninteger parameter')
        # The export proves every product for the entire code range, not only
        # observed images. Reject tampered/incompatible parameter packages.
        import hashlib
        pins=json.loads((d/'SHA256.json').read_text('utf8'))
        for n in ('graph.json','model_int.npz','range_proof.json'):
            if hashlib.sha256((d/n).read_bytes()).hexdigest()!=pins[n]:raise ValueError('Hash mismatch '+n)
        proof=json.loads((d/'range_proof.json').read_text('utf8'))
        if max(proof['max_requant_bound'],proof['max_statistics_product_bound'])>=2**63:raise OverflowError('Unsafe INT64')
    def forward(self,rgb8,trace=None,verify_statistics=False):
        x=np.asarray(rgb8)
        if x.dtype!=np.uint8 or x.ndim!=4 or x.shape[1:]!=(3,270,480):raise ValueError('Expected NCHW U8 480x270')
        cache={'input':np.pad(x.astype(np.int64),((0,0),(0,0),(0,2),(0,0)),mode='reflect')}
        for node in self.graph['nodes']:
            name=node['name'];src=cache[node['source']]
            if node['up2_before']:src=src.repeat(2,axis=2).repeat(2,axis=3)
            weight=self.params[name+'.weight'].astype(np.int64)
            a=conv2d_int(src,weight,self.params[name+'.bias'],stride=node['stride'],
                         padding=node['kernel']//2,groups=node['groups'])
            m=self.params[name+'.multiplier']
            wide=a*m[None,:,None,None]
            if node['center']:
                if node['kernel']==1:
                    sums=src.sum((-2,-1),dtype=np.int64).dot(weight[:,:,0,0].T)
                else:
                    sums=tap_sums(src).reshape(len(src),-1).dot(weight.reshape(len(weight),-1).T)
                if verify_statistics and not np.array_equal(sums,a.sum((-2,-1),dtype=np.int64)):
                    raise AssertionError('Reflection projection mismatch '+name)
                n=node['center_n']
                if n!=a.shape[-2]*a.shape[-1]:raise ValueError('Wrong mean area')
                dynamic=self.params[name+'.beta_fixed'][None,:]-round_divide(sums*m[None,:],n)
                wide+=dynamic[:,:,None,None]
            if node['skip'] is not None:wide+=cache[node['skip']]*self.params[name+'.skip_multiplier'][0]
            q=round_shift_even(wide,node['shift']) if node['kind']=='rgb' else round_shift_half_up(wide,node['shift'])
            if node['kind']=='rgb':
                if trace is not None:trace['rgb_raw']=q.copy()
                q=np.clip(q,0,255).astype(np.uint8)
            else:
                q=np.clip(q,node['qmin'],node['qmax']).astype(np.int16 if 'enc' in name and name.endswith('_dw') else
                       np.int8 if node['qmin']<0 else np.uint8)
            cache[name]=q.astype(np.int64)
            if trace is not None:trace[name]=q.copy()
        return cache['rgb'][:,:,:270].astype(np.uint8)
