"""Standalone scriptable integer Model 4, with INT8 weights and feature codes.

This module needs only PyTorch; it does not import the FP32 network or VGG.
Convolution and statistics use actual integer operations on the CPU reference.
"""
from typing import List
import torch
from torch import nn


@torch.jit.script
def reflect_integer(value: torch.Tensor, left: int, right: int, top: int, bottom: int) -> torch.Tensor:
    height,width=value.size(2),value.size(3)
    rows=torch.arange(-top,height+bottom,device=value.device)
    rows=torch.where(rows<0,-rows,rows)
    rows=torch.where(rows>=height,2*height-rows-2,rows)
    cols=torch.arange(-left,width+right,device=value.device)
    cols=torch.where(cols<0,-cols,cols)
    cols=torch.where(cols>=width,2*width-cols-2,cols)
    return value.index_select(2,rows).index_select(3,cols)


@torch.jit.script
def integer_convolution(value: torch.Tensor, weight: torch.Tensor, bias: torch.Tensor,
                        stride: int, groups: int) -> torch.Tensor:
    value=value.to(torch.int64)
    weight=weight.to(torch.int64)
    bias=bias.to(torch.int64)
    kernel=weight.size(3)
    height=(value.size(2)-kernel)//stride+1
    width=(value.size(3)-kernel)//stride+1
    batch=value.size(0)
    if groups==value.size(1) and groups==weight.size(0) and weight.size(1)==1:
        result=bias.view(1,-1,1,1).expand(batch,-1,height,width).clone()
        for row in range(kernel):
            for col in range(kernel):
                result=result+value[:,:,row:row+height*stride:stride,col:col+width*stride:stride]*weight[:,0,row,col].view(1,-1,1,1)
        return result
    if groups!=1:
        raise RuntimeError('Expected standard or depthwise convolution')
    windows=value.unfold(2,kernel,stride).unfold(3,kernel,stride)
    output=torch.empty((batch,weight.size(0),height,width),dtype=torch.int64,device=value.device)
    matrix=weight.flatten(1).t().contiguous()
    for start in range(0,height,8):
        stop=min(height,start+8)
        patch=windows[:,:,start:stop].permute(0,2,3,1,4,5).reshape(-1,matrix.size(0))
        result=torch.matmul(patch,matrix)+bias
        output[:,:,start:stop]=result.reshape(batch,stop-start,width,-1).permute(0,3,1,2)
    return output


@torch.jit.script
def shift_round(value: torch.Tensor, shift: int) -> torch.Tensor:
    if shift==0:
        return value
    return torch.div(value+(1<<(shift-1)),1<<shift,rounding_mode='floor')


class IntegerNode(nn.Module):
    __constants__=['source_index','skip_index','kernel','stride','groups','up2',
                   'center','shift','qmin','qmax']

    def __init__(self,spec,params,source_index,skip_index):
        super().__init__()
        self.source_index=source_index
        self.skip_index=skip_index
        self.kernel=spec['kernel']
        self.stride=spec['stride']
        self.groups=spec['groups']
        self.up2=spec['up2_before']
        self.center=spec['center']
        self.shift=spec['shift']
        self.qmin=spec['qmin']
        self.qmax=spec['qmax']
        prefix=spec['name']+'.'
        for name in ['weight','bias','multiplier','beta_fixed','skip_multiplier']:
            self.register_buffer(name,params[prefix+name].detach().cpu().clone())

    def forward(self,value: torch.Tensor,skip: torch.Tensor) -> torch.Tensor:
        if self.up2:
            value=value.repeat_interleave(2,2).repeat_interleave(2,3)
        padding=self.kernel//2
        if padding>0:
            value=reflect_integer(value,padding,padding,padding,padding)
        acc=integer_convolution(value,self.weight,self.bias,self.stride,self.groups)
        if self.center:
            total=acc.sum(dim=[2,3],keepdim=True)
            acc=acc-shift_round(total,13)
        wide=acc*self.multiplier.to(torch.int64).view(1,-1,1,1)+self.beta_fixed.view(1,-1,1,1)
        if self.skip_index>=0:
            wide=wide+skip.to(torch.int64)*self.skip_multiplier.to(torch.int64).view(1,1,1,1)
        return shift_round(wide,self.shift).clamp(self.qmin,self.qmax).to(torch.int8)


class IntegerScriptModel(nn.Module):
    __constants__=['rgb_shift']

    def __init__(self,graph,params):
        super().__init__()
        indices={'input':0}
        nodes=[]
        for index,spec in enumerate(graph['nodes'],1):
            nodes.append(IntegerNode(spec,params,indices[spec['source']],
                                     indices[spec['skip']] if spec['skip'] is not None else -1))
            indices[spec['name']]=index
        self.nodes=nn.ModuleList(nodes)
        self.rgb_shift=graph['rgb_shift']
        self.register_buffer('rgb_multiplier',params['rgb.multiplier'].detach().cpu().clone())
        self.register_buffer('rgb_bias',params['rgb.bias'].detach().cpu().clone())

    def forward(self,rgb: torch.Tensor) -> torch.Tensor:
        if rgb.dim()!=4 or rgb.size(1)!=3 or rgb.size(2)!=270 or rgb.size(3)!=480:
            raise RuntimeError('Expected NCHW [N,3,270,480]')
        if rgb.dtype!=torch.uint8:
            raise RuntimeError('Expected RGB uint8 input codes')
        if rgb.device.type!='cpu':
            raise RuntimeError('This integer reference runs on CPU')
        values=torch.jit.annotate(List[torch.Tensor],[])
        values.append(reflect_integer(rgb.to(torch.int64),0,0,0,2))
        for node in self.nodes:
            value=values[node.source_index]
            skip=values[node.skip_index] if node.skip_index>=0 else values[0]
            values.append(node(value,skip))
        value=values[-1].to(torch.int64)
        wide=value*self.rgb_multiplier.view(1,-1,1,1)+self.rgb_bias.view(1,-1,1,1)
        return shift_round(wide,self.rgb_shift).clamp(0,255).to(torch.uint8)[:,:,:270,:480]
