# -*- coding: utf-8 -*-
"""Independent spatial oracle: sums actual accumulators, unlike projected CPU sums."""
from pathlib import Path
import sys
import numpy as np
R=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'reference'))
from integer_model import IntegerStudent,round_divide
from integer_ops import conv2d_int,round_shift_half_up,round_shift_even
MODEL=IntegerStudent(R/'reference/integer')

def forward(rgb):
    h,w=rgb.shape[-2:];hp=(h+3)//4*4
    cache={'input':np.pad(rgb.astype(np.int64),((0,0),(0,0),(0,hp-h),(0,0)),mode='reflect')};trace={}
    for node in MODEL.graph['nodes']:
        name=node['name'];src=cache[node['source']];p=MODEL.params
        if node['up2_before']:src=src.repeat(2,axis=2).repeat(2,axis=3)
        a=conv2d_int(src,p[name+'.weight'],p[name+'.bias'],stride=node['stride'],padding=node['kernel']//2,groups=node['groups'])
        m=p[name+'.multiplier'];wide=a*m[None,:,None,None]
        if node['center']:
            sums=a.sum((-2,-1),dtype=np.int64)
            dynamic=p[name+'.beta_fixed'][None,:]-round_divide(sums*m[None,:],a.shape[-1]*a.shape[-2])
            wide+=dynamic[:,:,None,None]
        if node['skip']:wide+=cache[node['skip']]*p[name+'.skip_multiplier'][0]
        q=(round_shift_even if node['kind']=='rgb' else round_shift_half_up)(wide,24)
        cache[name]=np.clip(q,node['qmin'],node['qmax']);trace[name]=cache[name]
    out=cache['rgb'][:,:,:h].astype(np.uint8)
    if (h,w)==(270,480):
        original_trace={};original=MODEL.forward(rgb,trace=original_trace,verify_statistics=True)
        assert np.array_equal(original,out)
        for node in MODEL.graph['nodes']:assert np.array_equal(trace[node['name']],original_trace[node['name']]),node['name']
    return out,trace

def pack(x,wide=False):
    x=x[0].transpose(1,2,0);h,w,c=x.shape
    arr=np.zeros((h,w,(c+7)//8*8),dtype='<i2' if wide else np.uint8)
    arr[:,:,:c]=x.astype(arr.dtype)
    return [sum(int(v)<<(8*j) for j,v in enumerate(b)) for b in arr.view(np.uint8).reshape(-1,8)]
