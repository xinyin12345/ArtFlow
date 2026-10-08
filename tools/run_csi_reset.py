"""FIX1 reset ordering and camera re-init/AXI drain checks in native Questa.

The receiver output clamp in the integration test is a behavioral boundary,
not an analog D-PHY or encrypted CSI packet decoder model.
"""
from pathlib import Path
import json,re,subprocess,hashlib,sys
ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'work/csi_reset_tests'
RUN.mkdir(parents=True,exist_ok=True)
results=[]
sources=['rtl/reset.v','sim/tb_csi_reset.sv','sim/tb_csi_reset_gate.sv',
 'rtl/control/artflow_camera_gate.v','rtl/video/bayer_bin2x2.v',
 'rtl/video/rgb_frame_store.v','rtl/video/video_axi_scheduler.v',
 'rtl/frame_buffer/DC_FIFO.v','rtl/frame_buffer/rst_n_piple.v','sim/axi_memory_checked.sv']
def run(name,args,marker=None):
    r=subprocess.run([str(x) for x in args],cwd=RUN,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
    (RUN/(name+'.log')).write_text(r.stdout,encoding='utf-8')
    ok=r.returncode==0 and not re.search(r'\*\* (?:Error|Fatal|Warning)\b',r.stdout) and (not marker or marker in r.stdout)
    results.append({'name':name,'status':'PASS' if ok else 'FAIL'})
    print(name,results[-1]['status'],flush=True)
    if not ok: raise RuntimeError(r.stdout[-6000:])
try:
    if not (RUN/'work').exists():run('vlib',['vlib','work'])
    run('compile',['vlog','-sv',*[ROOT/p for p in sources]])
    for core,byte,pixel in [(5,7,10),(11,3,7),(3,13,5)]:
        run(f'reset_{core}_{byte}_{pixel}',['vsim','-c','-onfinish','exit',
            f'-GCORE_HALF={core}',f'-GBYTE_HALF={byte}',f'-GPIXEL_HALF={pixel}',
            'work.tb_csi_reset','-do','run -all; quit -code 0'],'tb_csi_reset PASS')
    run('camera_init_axi_drain',['vsim','-c','-onfinish','exit',
        'work.tb_csi_reset_gate','-do','run -all; quit -code 0'],'tb_csi_reset_gate PASS')
finally:
    (RUN/'summary.json').write_text(json.dumps({'status':'PASS' if len(results)>=5 and all(x['status']=='PASS' for x in results) else 'FAIL',
        'tests':results,'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}},indent=2)+'\n')

