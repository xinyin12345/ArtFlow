"""Black-box random memory scoreboard for the overlapped DDR bridge."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,time
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 out=R/'work/u8_optimization/bridge_unit';out.mkdir(parents=True,exist_ok=True)
 src=[R/'rtl/accel/artflow_cnn_bridge.v',R/'sim/axi_memory_v09.sv',R/'sim/tb_u8_bridge.sv']
 inputs=src+[Path(__file__)];hashes={p.relative_to(R).as_posix():sha(p) for p in inputs}
 q=Path(r'D:/soft/Questa/questa_fse/win64');env=os.environ.copy();env['PATH']=str(q)+os.pathsep+env['PATH']
 status='FAIL';txt='';start=time.monotonic()
 def call(stage,args,cwd=R):
  with (out/(stage+'.log')).open('w') as f:
   c=subprocess.run([str(q/(args[0]+'.exe')),*[p.as_posix() if isinstance(p,Path) else str(p) for p in args[1:]]],cwd=cwd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=600)
  body=(out/(stage+'.log')).read_text(errors='replace')
  assert c.returncode==0 and not re.search(r'\*\* (Error|Fatal):',body),body[-3000:]
  return body
 try:
  version=call('version',['vsim','-version']).strip()
  if not (out/'work').exists():call('vlib',['vlib',out/'work'])
  call('vmap_init',['vmap','-c'],out);ini=out/'modelsim.ini'
  call('vmap',['vmap','-modelsimini',ini,'work',out/'work'],out)
  call('compile',['vlog','-modelsimini',ini,'-work','work','-sv',*src])
  txt=call('simulation',['vsim','-c','-ini',ini,'-wlf',out/'test.wlf','-l',out/'transcript.log','-onfinish','exit','work.tb_u8_bridge','-do','run -all; quit -code 0'])
  assert 'tb_u8_bridge PASS' in txt
  assert hashes=={p.relative_to(R).as_posix():sha(p) for p in inputs}
  status='PASS'
 except Exception as e:print(type(e).__name__,e,flush=True)
 summary=dict(status=status,simulator=locals().get('version','unknown'),seconds=time.monotonic()-start,source_sha256=hashes,evidence_sha256={p.name:sha(p) for p in out.glob('*.log')})
 (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
 print(txt[-1500:]);print(status,flush=True);return status!='PASS'
if __name__=='__main__':sys.exit(main())
