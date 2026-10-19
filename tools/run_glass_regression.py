"""Sequential glass regression: never run multiple Questa sessions together."""
from pathlib import Path
import subprocess,sys,json
R=Path(__file__).resolve().parents[1]
cases=[
 ['--pattern','black','--frames','1','--stall-pct','60','--tag','final_black'],
 ['--pattern','white','--frames','1','--stall-pct','60','--tag','final_white'],
 ['--pattern','checker','--frames','1','--stall-pct','60','--tag','final_checker'],
 ['--system','--width','32','--height','28','--frames','3','--stall-pct','60','--cnn-half-ns','3.1','--video-load','1','--tag','final_stress'],
 *[['--system','--width','32','--height','28','--frames','2','--fault',str(i),'--tag',f'final_fault{i}'] for i in range(1,5)]]
def main():
    out=R/'work/glass_int8/regression.json';out.write_text('{"status":"RUNNING"}')
    results=[]
    for args in cases:
        p=subprocess.run([sys.executable,'-B',str(R/'tools/run_glass_int8.py'),*args],cwd=R,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        print(p.stdout[-1600:],flush=True);results.append(dict(args=args,returncode=p.returncode))
        if p.returncode:out.write_text(json.dumps(dict(status='FAIL',cases=results),indent=2));return 1
    out.write_text(json.dumps(dict(status='PASS',cases=results),indent=2));return 0
if __name__=='__main__':sys.exit(main())

