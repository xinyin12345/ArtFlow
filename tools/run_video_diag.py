"""Read-only telemetry regression; no hardware programming."""
import json,subprocess,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'work/video_diag_tests'
RUN.mkdir(parents=True,exist_ok=True)
results=[]
def run(name,args,marker=None):
    r=subprocess.run([str(x) for x in args],cwd=RUN,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    (RUN/(name+'.log')).write_text(r.stdout,encoding='utf-8')
    ok=r.returncode==0 and not re.search(r'\*\* (?:Error|Fatal|Warning)\b',r.stdout) and (not marker or marker in r.stdout)
    results.append({'name':name,'status':'PASS' if ok else 'FAIL'})
    print(name,results[-1]['status'],flush=True)
    if not ok: raise RuntimeError(r.stdout[-8000:])
try:
    if not (RUN/'work').exists():run('vlib',['vlib','work'])
    run('compile',['vlog','-sv',ROOT/'rtl/control/artflow_control.v',ROOT/'sim/tb_video_diag.sv'])
    for core,pixel in [(5,10),(7,11),(11,7)]:
        run(f'cdc_{core}_{pixel}',['vsim','-c','-onfinish','exit',f'-GCORE_HALF={core}',f'-GPIXEL_HALF={pixel}',
            'work.tb_video_diag','-do','run -all; quit -code 0'],'tb_video_diag PASS')
finally:
    (RUN/'summary.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
