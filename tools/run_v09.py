"""Real arithmetic, complete DDR/scaler/CNN pixel scoreboard. No hardware download."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys,time
import numpy as np
R=Path(__file__).resolve().parents[1]
N=R/'network/S8_480x270_Pipeline_v2_20261010/S8_480x270_Pipeline_v2'
sys.path.insert(0,str(N/'reference'))
from integer_model import IntegerS8

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def vectors(out,w,h,seed):
    # RGB in model order; framebuffer uses 0x00RRGGBB.
    rng=np.random.RandomState(seed)
    rgb=rng.randint(0,256,(h,w,3)).astype(np.int64)
    low=(rgb[::2,::2]+rgb[1::2,::2]+rgb[::2,1::2]+rgb[1::2,1::2]+2)//4
    lut=np.array([int(x,16) for x in (R/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem').read_text().split()])
    low=lut[low].astype(np.uint8)
    hp=(h//2+7)//8*8
    model=IntegerS8(N/'reference/exports')
    styled,trace=model.forward(np.pad(low.transpose(2,0,1)[None],((0,0),(0,0),(0,hp-h//2),(0,0)),mode='reflect'),trace=True)
    styled=styled[0,:,:h//2,:].transpose(1,2,0).astype(np.int64)
    # Independent closed-form half-pixel interpolation, round only at end.
    y=np.arange(h);x=np.arange(w);y0=(2*y-1)//4;x0=(2*x-1)//4
    fy=(2*y-1)%4;fx=(2*x-1)%4
    up=np.zeros((h,w,3),np.int64)
    for dy in range(2):
        for dx in range(2):
            a=styled[np.clip(y0+dy,0,h//2-1)[:,None],np.clip(x0+dx,0,w//2-1)[None,:]]
            up+=a*((fy if dy else 4-fy)[:,None]*(fx if dx else 4-fx)[None,:])[:,:,None]
    up=(up+8)//16
    def pixels(name,a,tag=0):
        words=(a[:,:,0]<<16)|(a[:,:,1]<<8)|a[:,:,2]|tag
        (out/name).write_text(''.join(f'{int(v):08x}\n' for v in words.flat))
    pixels('input.hex',rgb);pixels('golden.hex',up,1<<24)
    words=(low[:,:,2].astype(np.int64)<<16)|(low[:,:,1].astype(np.int64)<<8)|low[:,:,0]
    (out/'prepared.hex').write_text(''.join(f'{int(v):016x}\n' for v in words.flat))
    # Every feature write, not only final RGB, checked against frozen graph.
    expected=[];addresses=[]
    for c in json.loads((N/'architecture.json').read_text())['layers']:
        a=trace[c['output']][0].transpose(1,2,0)
        if c['mode']==2:a=a[:h//2]
        pad=np.zeros((*a.shape[:2],(a.shape[2]+7)//8*8),np.uint8)
        pad[:,:,:a.shape[2]]=a.astype(np.uint8)
        z=[sum(int(v)<<(8*j) for j,v in enumerate(row)) for row in pad.reshape(-1,8)]
        expected+=z;addresses += [(c['dst']<<21)+8*i for i in range(len(z))]
    (out/'features.hex').write_text(''.join(f'{v:016x}\n' for v in expected))
    (out/'addresses.hex').write_text(''.join(f'{v:06x}\n' for v in addresses))
    return len(expected)

def main():
    p=argparse.ArgumentParser();p.add_argument('--width',type=int,default=32);p.add_argument('--height',type=int,default=28)
    p.add_argument('--frames',type=int,default=2);p.add_argument('--fault',type=int,default=0);p.add_argument('--seed',type=int,default=101)
    p.add_argument('--video-load',type=int,choices=[0,1],default=0);p.add_argument('--tag',default='final');p.add_argument('--stall-pct',type=int,default=25);p.add_argument('--rd-lat',type=int,default=12);p.add_argument('--cnn-half-ns',type=float,default=2.25)
    a=p.parse_args();assert a.width%16==0 and a.width>=32 and a.height>=28 and a.height%2==0
    out=R/f'work/v09_perf/{a.tag}/sim_{a.width}x{a.height}_f{a.fault}_s{a.stall_pct}_r{a.rd_lat}_c{a.cnn_half_ns:g}_v{a.video_load}';out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text('{"status":"RUNNING"}')
    n=vectors(out,a.width,a.height,a.seed)
    sources=[R/'rtl/cnn/s8_shared_flat.v',*[R/f'rtl/accel/artflow_cnn_{s}.v' for s in ['resize','bridge','dma','accel','cdc_fifo']],R/'rtl/accel/artflow_axi_mux.v',R/'sim/axi_background_v09.sv',R/'sim/axi_memory_v09.sv',R/'sim/tb_v09_dma.sv']
    inputs=sources+[Path(__file__),*sorted((R/'rtl/cnn').glob('*.mem')),R/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem']
    hashes={str(x.relative_to(R)):sha(x) for x in inputs}
    iv=R/'work/v07/tools/ucrt64/bin';env=os.environ.copy()
    env['PATH']=str(iv)+os.pathsep+r'C:\msys64\ucrt64\bin'+os.pathsep+r'C:\Windows\System32'
    # Run from the project root so actual synthesizable ROM paths are exercised.
    cmd=[str(iv/'iverilog.exe'),'-v','-g2012','-s','tb_v09_dma',f'-Ptb_v09_dma.W={a.width}',f'-Ptb_v09_dma.H={a.height}',f'-Ptb_v09_dma.N={n}',f'-Ptb_v09_dma.FRAMES={a.frames}',f'-Ptb_v09_dma.FAULT={a.fault}',f'-Ptb_v09_dma.STALL_PCT={a.stall_pct}',f'-Ptb_v09_dma.RD_LAT={a.rd_lat}',f'-Ptb_v09_dma.CNN_HALF_NS={a.cnn_half_ns}',f'-Ptb_v09_dma.VIDEO_LOAD={a.video_load}','-o',str(out/'test.vvp'),*map(str,sources)]
    limits=[];t=time.monotonic()
    def call(name,cmd,timeout):
        with (out/(name+'.log')).open('w') as f:r=subprocess.run(cmd,cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
        txt=(out/(name+'.log')).read_text(errors='replace')
        return r.returncode,txt
    status='FAIL'
    try:
        (out/'test.vvp').unlink(missing_ok=True)
        code,txt=call('compile',cmd,120)
        if code and code in (3221225477,-1073741819) and 'DONE.' in txt and (out/'test.vvp').exists() and not re.search(r'error:|syntax error',txt):limits.append('Icarus code emission followed by exit fault')
        else:assert code==0,txt[-3000:]
        code,txt=call('simulation',[str(iv/'vvp.exe'),str(out/'test.vvp'),'+DIR='+out.as_posix()],7200)
        assert code==0 and 'tb_v09_dma PASS' in txt and not re.search(r'ERROR:|FATAL:',txt),txt[-4000:]
        assert hashes=={str(x.relative_to(R)):sha(x) for x in inputs},'Inputs changed during run'
        assert not (a.video_load and a.fault),'Fault tests must isolate the CNN'
        status='PASS_WITH_TOOL_LIMITATIONS' if limits else 'PASS'
        print(txt,flush=True)
    except Exception as e:print(e,flush=True)
    frame_cycles=[int(x) for x in re.findall(r'FRAME PASS .*?cycles=(\d+)',txt)]
    result=dict(frame_cycles_100mhz=frame_cycles,fps_min=100000000/max(frame_cycles) if frame_cycles else None,status=status,args=vars(a),feature_words=n,seconds=time.monotonic()-t,tool_limitations=limits,source_sha256=hashes,evidence_sha256={p.name:sha(p) for p in out.glob('*.log')})
    (out/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(status,out,flush=True);return status=='FAIL'
if __name__=='__main__':sys.exit(main())
