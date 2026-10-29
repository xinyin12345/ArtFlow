from pathlib import Path
import os,subprocess,json,sys,hashlib,time
r=Path(__file__).resolve().parents[1];name=sys.argv[1];output_name=sys.argv[2];assert output_name.replace('_','').isalnum();o=r/'work'/output_name;o.mkdir(parents=True,exist_ok=True);assert not (o/'summary.json').exists(),'Preserve old test outcome';q=Path(os.environ.get('QUESTA_ROOT','D:/soft/Questa/questa_fse/win64'));env=os.environ.copy();env['PATH']=str(q)+os.pathsep+env.get('PATH','')
(o/'tmp').mkdir(exist_ok=True);env.update(TEMP=str(o/'tmp'),TMP=str(o/'tmp'))
files=[r/x for x in sys.argv[3:]]
files.append(Path(os.environ.get('EFINITY_ROOT','D:/soft/Efinity/2026.1'))/'sim_models/verilog/efx_ram10.v')
files.append(Path(os.environ.get('EFINITY_ROOT','D:/soft/Efinity/2026.1'))/'sim_models/verilog/efx_dpram10.v')
vector_hashes={}
if any(p.name=='spi_model_archive.sv' for p in files):
 p=r/'network/styles8/models8_parameters.hex';vector_hashes[p.relative_to(r).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
result={'status':'RUNNING','vector_sha256':vector_hashes,'source_sha256':{(p.relative_to(r).as_posix() if p.is_relative_to(r) else p.as_posix()):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
def call(label,args):
 cmd=[str(q/(args[0]+'.exe')),*[a.as_posix() if isinstance(a,Path) else a for a in args[1:]]]
 budget=None
 with (o/(label+'.log')).open('w') as log:
  p=subprocess.Popen(cmd,cwd=r,env=env,stdout=log,stderr=subprocess.STDOUT)
  (o/(label+'_process.json')).write_text(json.dumps(dict(pid=p.pid,command=cmd,wall_budget_seconds=budget,start=time.time()),indent=2))
  last_notice=time.monotonic()
  while p.poll() is None:
   time.sleep(2)
   d={'phase':label,'revision':'round23_row_rgb','pid':p.pid,'utc':__import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat(),'wall_budget_seconds':None,'last_lines':(o/(label+'.log')).read_text(errors='replace').splitlines()[-4:]}
   (o/'active.json').write_text(json.dumps(d,indent=2));(r/'reports/styles8/round23_live.json').write_text(json.dumps(d,indent=2))
   if time.monotonic()-last_notice>=60:print(json.dumps(d),flush=True);last_notice=time.monotonic()
 t=(o/(label+'.log')).read_text(errors='replace');assert p.returncode==0 and '** Error:' not in t and '** Fatal:' not in t,t[-4000:];return t

try:
 if not (o/'work').exists():call('vlib',['vlib',o/'work'])
 ini=o/'modelsim.ini';ini.write_text('[Library]\nwork = '+(o/'work').as_posix()+'\n')
 call('compile',['vlog','-ini',ini,'-work','work','-sv','-timescale','1ns/1ps',*files]);t=call('simulation',['vsim','-c','-ini',ini,'-wlf',o/'test.wlf','-onfinish','exit','work.tb_'+name,*(['+DIR='+o.as_posix()] if name.startswith('r23_numeric') or name=='r15u_system' else []),'-do','run -all; quit -code 0']);assert 'PASS' in t,t[-3000:];result.update(status='PASS',evidence=[l for l in t.splitlines() if 'PASS' in l])
except Exception as e:result.update(status='FAIL',error=str(e))
(o/'active.json').unlink(missing_ok=True)
for n,h in (result['source_sha256']|result['vector_sha256']).items():assert hashlib.sha256((r/n).read_bytes()).hexdigest()==h,n
(o/'summary.json').write_text(json.dumps(result,indent=2));(r/'reports/styles8/round23_live.json').write_text(json.dumps(dict(result,revision='round23_row_rgb',test=name,phase='complete',utc=__import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat()),indent=2));print(json.dumps(result,indent=2));raise SystemExit(result['status']!='PASS')
