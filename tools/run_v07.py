"""Pixel-accurate v07 RTL regression (Icarus or Questa), without programming hardware."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys,time
from v07_reference import write_vectors,resize
ROOT=Path(__file__).resolve().parents[1]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--full',action='store_true')
    ap.add_argument('--system-only',action='store_true')
    ap.add_argument('--simulator',choices=['questa','iverilog'],default='iverilog')
    a=ap.parse_args()
    run=ROOT/'work/v07/regression';run.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env['PYTHONUTF8']='1'
    iv=ROOT/'work/v07/tools/ucrt64/bin'
    env['PATH']=(str(iv)+os.pathsep+r'C:\msys64\ucrt64\bin'+os.pathsep+r'C:\Windows\System32'+os.pathsep+r'C:\Windows'
                 if a.simulator=='iverilog' else r'D:\soft\Questa\questa_fse\win64'+os.pathsep+env['PATH'])
    common=[*sorted((ROOT/'rtl/accel').glob('*.v')),ROOT/'sim/axi_memory_v07.sv']
    dma=[*common,ROOT/'sim/tb_v07_dma.sv']
    control=[ROOT/'rtl/accel/artflow_accel_ctrl.v',ROOT/'sim/tb_v07_ctrl.sv']
    system=[*common,*[ROOT/p for p in [
        'rtl/video/bayer_bin2x2.v','rtl/video/rgb_frame_store.v','rtl/video/rgb_frame_store_v07.v',
        'rtl/video/cam_fb_pipe_v07.v','rtl/video/video_axi_scheduler.v',
        'rtl/frame_buffer/DC_FIFO.v','rtl/frame_buffer/rst_n_piple.v','sim/tb_v07_system.sv']]]
    paths=sorted(set([*dma,*control,*system,Path(__file__),ROOT/'tools/v07_reference.py']))
    fingerprint=lambda:{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    hashes=fingerprint();results=[];limitations=[]
    (run/'summary.json').write_text('{"status":"RUNNING"}\n')
    def call(name,cmd,marker=None,compile_step=False):
        start=time.monotonic();log=run/(name+'.log')
        if compile_step and a.simulator=='iverilog':(run/'design.vvp').unlink(missing_ok=True)
        with log.open('w') as f:
            p=subprocess.run(list(map(str,cmd)),env=env,cwd=run,stdout=f,stderr=subprocess.STDOUT,timeout=1800)
        text=log.read_text(errors='replace')
        bad=re.search(r'\*\* (?:Error|Fatal|Warning)|(?:Errors|Warnings):\s*[1-9]|ERROR:|FATAL:|Fatal:|syntax error|error:',text)
        if (compile_step and a.simulator=='iverilog' and p.returncode in (3221225477,-1073741819)
            and not bad and 'DONE.' in text and (run/'design.vvp').is_file()):
            # Do not label the compiler PASS: independently execute its fresh output
            # and require the scoreboard PASS and clean simulator process exit.
            limitations.append(dict(step=name,exit_code=p.returncode,issue='ivl exit fault after completed code emission'))
            state='EMITTED_WITH_EXIT_FAULT'
        else:state='PASS' if p.returncode==0 and not bad and (not marker or marker in text) else 'FAIL'
        results.append(dict(name=name,status=state,exit_code=p.returncode,seconds=round(time.monotonic()-start,2)))
        print(name,state,flush=True)
        if state=='FAIL':raise RuntimeError(text[-6000:])
    def simulate(top,files,label,params=None):
        params=params or {}
        if a.simulator=='iverilog':
            call('compile_'+label,[iv/'iverilog.exe','-v','-g2012','-s',top,
                 *[f'-P{top}.{k}={v}' for k,v in params.items()],'-o','design.vvp',*files],compile_step=True)
            call(label,[iv/'vvp.exe','design.vvp'],top+' PASS')
        else:
            call('compile_'+label,['vlog','-sv',*files],compile_step=True)
            call(label,['vsim','-c','-onfinish','exit',*[f'-G{k}={v}' for k,v in params.items()],
                 'work.'+top,'-do','run -all; quit -code 0'],top+' PASS')
    status='FAIL'
    try:
        if a.simulator=='questa' and not (run/'work').exists():call('vlib',['vlib','work'])
        cases=[] if a.system_only else [(32,12,0,7),(68,14,0,19),(32,12,1,7),(32,12,2,7)]
        if a.full and not a.system_only:cases.append((960,540,0,23))
        for w,h,f,seed in cases:
            write_vectors(run,w,h,seed)
            simulate('tb_v07_dma',dma,f'dma_{w}x{h}_fault{f}',dict(W=w,H=h,FAULT=f))
        simulate('tb_v07_ctrl',control,'control')
        simulate('tb_v07_system',system,'system')
        src=[int(s,16) for s in (run/'system_input.hex').read_text().split()]
        dst=[int(s,16) for s in (run/'system_output.hex').read_text().split()]
        assert len(src)==len(dst) and len(src)>=6*384 and len(src)%384==0
        for i in range(0,len(src),384):
            rgb=[tuple((p>>(c*8))&255 for c in range(3)) for p in src[i:i+384]]
            golden=[p[0]|p[1]<<8|p[2]<<16 for p in resize(rgb,32,12)]
            assert dst[i:i+384]==golden,'System pixel mismatch frame '+str(i//384)
        results.append(dict(name='system_python_pixels',status='PASS',pixels=len(dst)))
        print('system_python_pixels PASS',len(dst),flush=True)
        assert fingerprint()==hashes,'Sources changed during regression'
        status='PASS_WITH_TOOL_LIMITATIONS' if limitations else 'PASS'
    except Exception as e:results.append(dict(name='failure',status='FAIL',reason=str(e)));print(e,flush=True)
    (run/'summary.json').write_text(json.dumps(dict(status=status,full=a.full,system_only=a.system_only,
        simulator=a.simulator,tests=results,source_sha256=hashes,tool_limitations=limitations,
        evidence_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in run.glob('*.log')}),indent=2)+'\n')
    return status=='FAIL'
if __name__=='__main__':sys.exit(main())
