"""Optimized U8 short regressions; full-size run is recorded separately."""
from pathlib import Path
import subprocess,sys,json,time
R=Path(__file__).resolve().parents[1]
out=R/'work/u8_optimization';out.mkdir(parents=True,exist_ok=True)
cases=[('smoke',['tools/run_u8_questa.py','--width','32','--height','28','--frames','2','--tag','opt_smoke']),
 ('stress',['tools/run_u8_questa.py','--width','48','--height','36','--frames','3','--stall-pct','60','--rd-lat','48','--cnn-half-ns','3.7','--tag','opt_stress']),
 ('random',['tools/run_u8_questa.py','--width','192','--height','108','--frames','2','--seed','402','--tag','opt_random'])]
for fault in range(1,5):
 cases.append((f'fault{fault}',['tools/run_u8_questa.py','--width','32','--height','28','--frames','2','--video-load','0','--fault',str(fault),'--tag',f'opt_fault{fault}']))
cases.append(('system',['tools/run_u8_system.py']))
results=[]
for name,args in cases:
 print('START',name,flush=True);t=time.monotonic()
 with (out/(name+'_runner.log')).open('w') as log:
  c=subprocess.run([sys.executable,'-X','utf8','-B',*args],cwd=R,stdout=log,stderr=subprocess.STDOUT)
 results.append(dict(case=name,returncode=c.returncode,seconds=time.monotonic()-t))
 (out/'regression.json').write_text(json.dumps(results,indent=2))
 print('END',name,c.returncode,flush=True)
 if c.returncode:sys.exit(c.returncode)
