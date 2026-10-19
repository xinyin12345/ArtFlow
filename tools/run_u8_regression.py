from pathlib import Path
import subprocess,sys,json,time
R=Path(__file__).resolve().parents[1]
out=R/'work/u8_integration';out.mkdir(parents=True,exist_ok=True)
cases=[('smoke',['tools/run_u8_questa.py','--width','32','--height','28','--frames','2','--video-load','1','--tag','smoke']),('stress',['tools/run_u8_questa.py','--width','48','--height','36','--frames','3','--video-load','1','--stall-pct','60','--rd-lat','48','--cnn-half-ns','3.7','--tag','stress'])]
for fault in range(1,5):
    cases.append((f'fault{fault}',['tools/run_u8_questa.py','--width','32','--height','28','--frames','2','--video-load','0','--fault',str(fault),'--tag',f'fault{fault}']))
cases += [('system',['tools/run_u8_system.py']),('full',['tools/run_u8_questa.py','--frames','2','--video-load','1','--tag','full'])]
results=[]
for name,args in cases:
    print('START',name,flush=True);start=time.time()
    with (out/(name+'_runner.log')).open('w') as log:
        c=subprocess.run([sys.executable,'-X','utf8','-B',*args],cwd=R,stdout=log,stderr=subprocess.STDOUT)
    results.append(dict(case=name,returncode=c.returncode,seconds=time.time()-start))
    (out/'regression.json').write_text(json.dumps(results,indent=2))
    print('END',name,c.returncode,flush=True)
    if c.returncode:sys.exit(c.returncode)
