"""Rebuild and validate the accepted eight-style P1/P2 design; never program hardware.

Use --phase tests, map, physical or all. Existing outcomes are preserved; use
--archive-run before a new all run to move only this workflow's generated data.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,os,shutil,subprocess,sys,time
from check_round23t_project import verify,W,SNAP
R=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def run(script,*args):
 print('START',script,*args,flush=True)
 subprocess.run([sys.executable,'-B',str(R/script),*args],cwd=R,check=True)
def flow(name):
 dest=W/(name+'_summary.json');assert not dest.exists(),'Existing flow outcome: '+str(dest)
 e=Path(os.environ.get('EFINITY_ROOT','D:/soft/Efinity/2026.1'))
 env=os.environ.copy()
 for key,sub in [('EFINITY_HOME',''),('EFXPT_HOME','pt'),('EFXIPM_HOME','ipm'),('EFXPGM_HOME','pgm'),('EFXDBG_HOME','debugger'),('PYTHONHOME','python311'),('QT_PLUGIN_PATH','python311')]:env[key]=(e/sub).as_posix()
 for d in ['tmp','user']:(W/d).mkdir(exist_ok=True)
 env.update(TMP=str(W/'tmp'),TEMP=str(W/'tmp'),EFINITY_USER_DIR_INI=str(W/'user.ini'),EFINITY_USER_DIR=str(W/'user'))
 env['PATH']=str(e/'bin')+os.pathsep+str(e/'python311/bin')+os.pathsep+env['PATH']
 (W/'user.ini').write_text('[General]\nEFINITY_USER_DIR='+(W/'user').as_posix()+'\n')
 cmd=[str(e/'python311/bin/python.exe'),str(e/'scripts/efx_run.py'),'ArtFlow.xml','--flow',name,'--output_dir',(W/'out').as_posix(),'--work_dir',(W/'build').as_posix()]
 if name=='pnr':cmd+=['--pnr_opts','optimization_level=TIMING_3']
 if name=='sta_tclsh':cmd+=['-t',(W/'audit.tcl').as_posix(),'--pnr_opts','sdc_file='+(W/'video_cdc_audit.sdc').as_posix()]
 before=(R/'ArtFlow.xml').read_bytes();start=time.monotonic();print('START FLOW',name,flush=True)
 with (W/(name+'.log')).open('x') as log:p=subprocess.run(cmd,cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT)
 from map_evidence import restore_only_eol
 restore_only_eol(R/'ArtFlow.xml',before,W,name)
 d=dict(status='PASS' if p.returncode==0 else 'FAIL',returncode=p.returncode,seconds=time.monotonic()-start,command=cmd)
 dest.write_text(json.dumps(d,indent=2));print(json.dumps(d),flush=True)
 assert p.returncode==0,'See '+str(W/(name+'.log'));verify()
def tests():
 run('tools/build_firmware.py');verify()
 run('tools/test_firmware.py')
 run('tools/verify_package.py','--record');run('tools/regenerate_package.py')
 commands=json.loads((R/'tools/styles8_tests.json').read_text());rows=[];files=[]
 for name,cmd in commands.items():
  output='styles8_v2_'+name
  run('tools/run_rtl_case.py',cmd[0],output,*cmd[1:])
  p=R/'work'/output/'summary.json';d=json.loads(p.read_text());assert d['status']=='PASS'
  rows.append(dict(name=name,status=d['status'],evidence=d['evidence']))
  files.extend([p,(p.parent/'simulation.log')]);files.extend(R/n for n in d['source_sha256'])
 run('tools/receipt_styles8_formal.py')

def mapped():
 run('stream/scripts/verify_regression_evidence.py')
 receipt=json.loads((R/'reports/styles8/round23t_functional_receipt.json').read_text())
 assert receipt['status']=='PASS' and receipt['implementation']==verify()
 for n,h in receipt['sha256'].items():assert sha(R/n)==h,('Stale functional evidence',n)
 assert not SNAP.exists(),'Existing map: archive previous run first'
 SNAP.write_text(json.dumps(verify(),indent=2));flow('map');flow('interface');run('tools/analyze_styles8_map.py')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--phase',choices=['all','tests','map','physical'],default='all');p.add_argument('--archive-run',action='store_true');a=p.parse_args()
 # Preserve prior generated runs; never touch other historical work/releases.
 assert not (W/'build.lock').exists(),'Another run is active; inspect its PID before recovery'
 if a.archive_run:
  archive=R/'work'/('styles8_archive_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'));archive.mkdir(parents=True)
  items=[(W,'implementation'),(R/'reports/styles8','reports')]+[(p,p.name) for p in sorted((R/'work').glob('styles8_v2_*'))]
  for old,label in items:
   if old.exists():
    assert old.resolve().is_relative_to(R.resolve())
    dest=archive/label;assert not dest.exists()
    shutil.move(str(old),str(dest))
 W.mkdir(parents=True,exist_ok=True);(R/'reports/styles8').mkdir(parents=True,exist_ok=True);(R/'stream/logs/protocol').mkdir(parents=True,exist_ok=True)
 lock=W/'build.lock'
 with lock.open('x') as f:f.write(str(os.getpid()))
 try:
  verify()
  if a.phase in ['all','tests']:
   tests()
   run('stream/tests/protocol_test.py')
   for script in ['run_stream_rtl.py','run_shared_tests.py','run_reset_equivalence.py','run_tap_rtl.py']:
    run('stream/scripts/'+script)
   run('tools/test_stream_esp.py')
  if a.phase in ['all','map']:mapped()
  if a.phase in ['all','physical']:run('stream/scripts/fpga_physical.py')
 finally:lock.unlink()
