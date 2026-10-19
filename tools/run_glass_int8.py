"""Independent integer reference plus four-state per-layer hardware scoreboard."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys,time
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[1];N=R/'network/glass_5_20epochs_sum8192_480x270_input3x3_res32_r4_int8'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def forward(rgb):
    import torch
    torch.set_num_threads(4);sys.path.insert(0,str(N))
    from model import IntegerScriptModel,reflect_integer,shift_round
    g=json.loads((N/'parameters/graph.json').read_text());p=np.load(N/'parameters/model_int8.npz')
    m=IntegerScriptModel(g,{k:torch.from_numpy(p[k].copy()) for k in p.files}).eval()
    h,w=rgb.shape[:2];v=torch.from_numpy(rgb.copy()).permute(2,0,1)[None].long()
    v=reflect_integer(v,0,0,0,(-h)%4);values=[v];trace=[]
    with torch.inference_mode():
        for node in m.nodes:
            v=node(values[node.source_index],values[node.skip_index] if node.skip_index>=0 else values[0])
            values.append(v);trace.append(v[0].permute(1,2,0).numpy())
        wide=v.long()*m.rgb_multiplier.view(1,-1,1,1)+m.rgb_bias.view(1,-1,1,1)
        rgb_out=shift_round(wide,24).clamp(0,255).byte()[:,:,:h,:w]
        if (h,w)==(270,480):
            scripted=torch.jit.load(str(N/'model_int8.pt')).eval()
            canonical=scripted(torch.from_numpy(rgb.copy()).permute(2,0,1)[None])
            assert torch.equal(canonical,rgb_out),'Reference differs from delivered TorchScript'
    result=rgb_out[0].permute(1,2,0).numpy()
    trace[-1]=result
    return result,trace
def pack(a):
    h,w,c=a.shape;z=np.zeros((h,w,(c+7)//8*8),np.uint8);z[:,:,:c]=a.astype(np.uint8)
    return z.copy().view('<u8').reshape(-1)
def features(out,trace):
    arch=json.loads((R/'rtl/cnn/glass_int8/architecture.json').read_text())
    fs=[];ads=[]
    for c,t in zip(arch['layers'],trace):
        z=pack(t);fs.extend(z);ads.extend((c['dst']<<21)+np.arange(len(z))*8)
    (out/'features.hex').write_text(''.join(f'{int(z):016x}\n' for z in fs))
    (out/'addresses.hex').write_text(''.join(f'{int(z):06x}\n' for z in ads))
    return len(fs)
def run_questa(out,sources,top,params,timeout=7200):
    q=Path(r'D:\soft\Questa\questa_fse\win64');env=os.environ.copy();env['PATH']=str(q)+os.pathsep+env['PATH']
    def call(stage,args,cwd=R):
        with (out/(stage+'.log')).open('w') as f:
            a=[str(q/(args[0]+'.exe'))]+[v.as_posix() if isinstance(v,Path) else str(v) for v in args[1:]]
            c=subprocess.run(a,cwd=cwd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
        text=(out/(stage+'.log')).read_text(errors='replace')
        assert c.returncode==0 and not re.search(r'\*\* (Error|Fatal):',text),text[-5000:]
        return text
    version=call('version',['vsim','-version']).strip()
    if not (out/'work').exists():call('vlib',['vlib',out/'work'])
    call('vmap_init',['vmap','-c'],out);ini=out/'modelsim.ini'
    call('vmap',['vmap','-modelsimini',ini,'work',out/'work'],out)
    call('compile',['vlog','-modelsimini',ini,'-work','work','-sv',*sources])
    txt=call('simulation',['vsim','-c','-ini',ini,'-wlf',out/'test.wlf','-l',out/'transcript.log',
        '-onfinish','exit','work.'+top,*[f'-g{k}={v}' for k,v in params.items()],'+DIR='+out.as_posix(),
        '-do','run -all; quit -code 0'])
    assert ' PASS' in txt and not re.search(r'ERROR:|FATAL:',txt),txt[-3000:]
    return txt,version
def main():
    a=argparse.ArgumentParser();a.add_argument('--width',type=int,default=32);a.add_argument('--height',type=int,default=30)
    a.add_argument('--pattern',default='random',choices=['random','black','white','checker','example']);a.add_argument('--frames',type=int,default=2)
    a.add_argument('--tag',default='core');a.add_argument('--system',action='store_true');a.add_argument('--fault',type=int,default=0)
    a.add_argument('--stall-pct',type=int,default=25);a.add_argument('--video-load',type=int,default=0)
    a.add_argument('--cnn-half-ns',type=float,default=3.5);a=a.parse_args()
    out=R/f'work/glass_int8/{a.tag}_{a.width}x{a.height}_{a.pattern}';out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text('{"status":"RUNNING"}');t=time.monotonic()
    rgb=np.random.default_rng(101).integers(0,256,(a.height,a.width,3),dtype=np.uint8)
    if a.pattern in ('black','white'):rgb.fill(255 if a.pattern=='white' else 0)
    if a.pattern=='checker':rgb[:]=((np.indices((a.height,a.width)).sum(0)%2)*255)[:,:,None]
    if a.pattern=='example':rgb=np.array(Image.open(N/'example_input.png').convert('RGB').resize((a.width,a.height)))
    if a.system:
        src=rgb.astype(np.int64)
        low=(src[::2,::2]+src[1::2,::2]+src[::2,1::2]+src[1::2,1::2]+2)//4
        lut=np.array([int(s,16) for s in (R/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem').read_text().split()])
        rgb=lut[low].astype(np.uint8)
        pixels=(src[:,:,0]<<16)|(src[:,:,1]<<8)|src[:,:,2]
        (out/'input.hex').write_text(''.join(f'{int(x):08x}\n' for x in pixels.flat))
    else:
        (out/'input.hex').write_text(''.join(f'{int(x):016x}\n' for x in pack(rgb)))
    result,trace=forward(rgb);n=features(out,trace)
    Image.fromarray(rgb).save(out/'input.png');Image.fromarray(result).save(out/'integer_output.png')
    if a.pattern=='example' and not a.system and (a.width,a.height)==(480,270):
        assert np.array_equal(result,np.array(Image.open(N/'example_output_int8.png'))),'Delivered example mismatch'
    sources=[R/'rtl/cnn/glass_int8/glass_int8.v']
    if a.system:
        (out/'prepared.hex').write_text(''.join(f'{int(x):016x}\n' for x in pack(rgb)))
        h,w=a.height,a.width;y=np.arange(h);x=np.arange(w);y0=(2*y-1)//4;x0=(2*x-1)//4
        fy=(2*y-1)%4;fx=(2*x-1)%4;up=np.zeros((h,w,3),np.int64)
        for dy in range(2):
            for dx in range(2):
                z=result[np.clip(y0+dy,0,h//2-1)[:,None],np.clip(x0+dx,0,w//2-1)[None,:]]
                up+=z.astype(np.int64)*((fy if dy else 4-fy)[:,None]*(fx if dx else 4-fx)[None,:])[:,:,None]
        up=(up+8)//16;pixels=(1<<24)|(up[:,:,0]<<16)|(up[:,:,1]<<8)|up[:,:,2]
        (out/'golden.hex').write_text(''.join(f'{int(x):08x}\n' for x in pixels.flat))
        sources += [*[R/('rtl/accel/artflow_glass_dma.v' if s=='dma' else f'rtl/accel/artflow_cnn_{s}.v') for s in ['resize','bridge','dma','accel','cdc_fifo']],
            R/'rtl/accel/artflow_axi_mux.v',R/'sim/axi_background_v09.sv',R/'sim/axi_memory_v09.sv',R/'sim/tb_glass_dma.sv']
        top='tb_v09_dma';params=dict(W=a.width,H=a.height,N=n,FRAMES=a.frames,FAULT=a.fault,STALL_PCT=a.stall_pct,RD_LAT=12,VIDEO_LOAD=a.video_load,CNN_HALF_NS=a.cnn_half_ns)
    else:
        sources+=[R/'sim/tb_glass_core.sv'];top='tb_glass_core'
        params=dict(W=a.width,H=a.height,N=n,FRAMES=a.frames,STALL_PCT=a.stall_pct)
    inputs=sources+list((R/'rtl/cnn/glass_int8').glob('*'))+[N/'model_int8.pt',N/'model.py',N/'parameters/model_int8.npz',Path(__file__)]
    hashes={p.relative_to(R).as_posix():sha(p) for p in inputs if p.is_file()}
    status='FAIL';txt='';version='';error=''
    try:
        txt,version=run_questa(out,sources,top,params)
        assert hashes=={p.relative_to(R).as_posix():sha(p) for p in inputs if p.is_file()},'Sources changed during run'
        if not a.fault:
            got=np.array([int(s,16) for s in (out/('rtl_model.hex' if a.system else 'rtl_output.hex')).read_text().split()],np.uint64)
            rgbgot=np.stack([((got>>(i*8))&255).astype(np.uint8) for i in range(3)],-1).reshape(rgb.shape)
            assert np.array_equal(rgbgot,result)
            Image.fromarray(rgbgot).save(out/'rtl_output.png')
        status='PASS'
    except Exception as e:error=str(e);print(error,flush=True)
    cycles=[int(v) for v in re.findall(r'FRAME PASS .*?cycles=(\d+)',txt)]
    summary=dict(status=status,args=vars(a),feature_words=n,frame_cycles=cycles,simulator=version,
        seconds=time.monotonic()-t,source_sha256=hashes,error=error,
        evidence_sha256={p.name:sha(p) for p in out.glob('*.log')})
    if a.system and cycles:summary['fps_min']=1e8/max(cycles)
    (out/'summary.json').write_text(json.dumps(summary,indent=2))
    print(txt[-2500:]);print(status,out,flush=True);return status!='PASS'
if __name__=='__main__':sys.exit(main())


