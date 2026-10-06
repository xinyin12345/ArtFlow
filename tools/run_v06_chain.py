"""Full-HD integration test, separate from the unit/inherited regression."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1]
FILES=['rtl/video/artflow_button.v','rtl/video/artflow_fps.v','rtl/video/artflow_ui.v',
 'rtl/video/artflow_osd.v','rtl/video/osd_font.mem','rtl/gamma_conrrection/gamma_lut.v',
 'rtl/gamma_conrrection/gamma_2p2_8b.mem','sim/tb_v06_chain.sv','tools/run_v06_chain.py']
def hashes():return {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in FILES}
def main():
 run=ROOT/'work/chain_v06';run.mkdir(parents=True,exist_ok=True);summary=run/'summary.json'
 summary.write_text('{"status":"RUNNING"}');before=hashes();results=[]
 env=os.environ.copy();env['PATH']=r'D:\soft\Questa\questa_fse\win64'+os.pathsep+env['PATH']
 def call(name,cmd,marker=None):
  log=run/(name+'.log');start=time.monotonic()
  with log.open('w') as f:p=subprocess.run(cmd,cwd=run,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
  t=log.read_text();ok=p.returncode==0 and not re.search(r'\*\* (?:Error|Fatal|Warning)|(?:Errors|Warnings):\s*[1-9]',t) and (not marker or marker in t)
  results.append(dict(name=name,status='PASS' if ok else 'FAIL',seconds=round(time.monotonic()-start,2)))
  print(name,results[-1]['status'],flush=True)
  if not ok:raise ValueError(t[-5000:])
 try:
  for name in FILES:
   if name.endswith('.mem'):
    p=run/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((ROOT/name).read_bytes())
  if not (run/'work').exists():call('vlib',['vlib','work'])
  call('compile',['vlog','-sv',*[str(ROOT/p) for p in FILES if p.endswith(('.v','.sv'))]])
  call('chain',['vsim','-c','-onfinish','exit','work.tb_v06_chain','-do','run -all; quit -code 0'],'tb_v06_chain PASS')
  if before!=hashes():raise ValueError('Source changed during integration run')
  status='PASS'
 except Exception as e:status='FAIL';results.append(dict(name=str(e),status='FAIL'));print(e)
 summary.write_text(json.dumps(dict(status=status,tests=results,source_sha256=before,
  evidence_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in run.glob('*.log')}),indent=2)+'\n')
 return status!='PASS'
if __name__=='__main__':sys.exit(main())
