"""The same four-state full arithmetic scoreboard under installed Questa.

Run outside the Windows AppContainer if Questa reports DLL relocation error
623. No installation, license files or encrypted vendor models are modified.
"""
from pathlib import Path
import argparse,json,os,re,subprocess,sys,time
from run_u8 import R,N,vectors,sha
def main():
    p=argparse.ArgumentParser();p.add_argument('--width',type=int,default=960);p.add_argument('--height',type=int,default=540)
    p.add_argument('--frames',type=int,default=2);p.add_argument('--video-load',type=int,default=1)
    p.add_argument('--cnn-half-ns',type=float,default=3.5);p.add_argument('--cnn-rtl',default='rtl/cnn/student_u8/student_u8_flat.v')
    p.add_argument('--bridge-rtl',default='rtl/accel/artflow_cnn_bridge.v');p.add_argument('--resize-rtl',default='rtl/accel/artflow_cnn_resize.v');p.add_argument('--seed',type=int,default=101);p.add_argument('--tag',default='questa')
    p.add_argument('--fault',type=int,default=0);p.add_argument('--stall-pct',type=int,default=25);p.add_argument('--rd-lat',type=int,default=12)
    a=p.parse_args();out=R/f'work/u8_integration/{a.tag}_{a.width}x{a.height}_c{a.cnn_half_ns:g}_v{a.video_load}';out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text('{"status":"RUNNING"}')
    n=vectors(out,a.width,a.height,a.seed)
    sources=[R/a.cnn_rtl,R/a.bridge_rtl,R/a.resize_rtl,*[R/f'rtl/accel/artflow_cnn_{s}.v' for s in ['dma','accel','cdc_fifo']],
             R/'rtl/accel/artflow_axi_mux.v',R/'sim/axi_background_v09.sv',R/'sim/axi_memory_v09.sv',R/'sim/tb_v09_dma.sv']
    inputs=[N/'golden.py',N/'architecture.json',*sorted((N/'reference').rglob('*.py')),*sorted((N/'reference/integer').glob('*'))]+sources+[Path(__file__),R/'tools/run_u8.py',*sorted((R/'rtl/cnn/student_u8').glob('*.mem')),R/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem']
    for source in sources:
        for mem in re.findall(r'\$readmemh\("([^"\n]+)"',source.read_text(encoding='utf-8')):
            inputs.append(R/mem)
    hashes={x.relative_to(R).as_posix():sha(x) for x in inputs}
    q=Path(r'D:\soft\Questa\questa_fse\win64');env=os.environ.copy();env['PATH']=str(q)+os.pathsep+env['PATH']
    status='FAIL';txt='';t=time.monotonic()
    def call(stage,args,cwd=R):
        with (out/(stage+'.log')).open('w') as f:
            argv=[v.as_posix() if isinstance(v,Path) else str(v) for v in args[1:]]
            c=subprocess.run([str(q/(args[0]+'.exe')),*argv],cwd=cwd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=7200)
        body=(out/(stage+'.log')).read_text(errors='replace')
        assert c.returncode==0 and not re.search(r'\*\* (Error|Fatal):',body),body[-5000:]
        return body
    try:
        version=call('version',['vsim','-version']).strip()
        if not (out/'work').exists():call('vlib',['vlib',out/'work'])
        call('vmap_init',['vmap','-c'],cwd=out)
        ini=out/'modelsim.ini';call('vmap',['vmap','-modelsimini',ini,'work',out/'work'],cwd=out)
        call('compile',['vlog','-modelsimini',ini,'-work','work',*sources])
        txt=call('simulation',['vsim','-c','-ini',ini,'-wlf',out/'test.wlf','-l',out/'transcript.log',
            '-onfinish','exit','work.tb_v09_dma',f'-gW={a.width}',f'-gH={a.height}',f'-gN={n}',f'-gFRAMES={a.frames}',
            f'-gFAULT={a.fault}',f'-gSTALL_PCT={a.stall_pct}',f'-gRD_LAT={a.rd_lat}',f'-gCNN_HALF_NS={a.cnn_half_ns}',f'-gVIDEO_LOAD={a.video_load}','+DIR='+out.as_posix(),'-do','run -all; quit -code 0'])
        assert 'tb_v09_dma PASS' in txt and not re.search(r'ERROR:|FATAL:',txt),txt[-5000:]
        assert hashes=={x.relative_to(R).as_posix():sha(x) for x in inputs},'Inputs changed during run'
        status='PASS';print(txt[-6000:],flush=True)
    except Exception as e:print(type(e).__name__,e,flush=True)
    cycles=[int(x) for x in re.findall(r'FRAME PASS .*?cycles=(\d+)',txt)]
    result=dict(status=status,tool_limitations=[],simulator=locals().get('version','unknown'),args=vars(a),feature_words=n,
        frame_cycles_100mhz=cycles,fps_min=100000000/max(cycles) if cycles else None,seconds=time.monotonic()-t,
        source_sha256=hashes,evidence_sha256={x.name:sha(x) for x in out.glob('*.log')})
    (out/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print(status,out,flush=True)
    return status!='PASS'
if __name__=='__main__':sys.exit(main())
