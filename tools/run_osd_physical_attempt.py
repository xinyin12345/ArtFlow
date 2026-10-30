"""One explicit OSD PNR attempt; never programs hardware or auto-retries."""
from pathlib import Path
import os, subprocess, sys, json, time, hashlib
R=Path(__file__).resolve().parents[1]; W=R/'work/osd_impl'; E=Path(os.environ.get('EFINITY_ROOT','D:/soft/Efinity/2026.1'))
sys.path.insert(0,str(R/'tools'))
from check_osd_sources import verify
verify()
profile=sys.argv[1]; seed=int(sys.argv[2]); effort=int(sys.argv[3]); threads=int(sys.argv[4]) if len(sys.argv)>4 else 2
assert profile in ['TIMING_1','TIMING_2','TIMING_3','CONGESTION_1','CONGESTION_2','CONGESTION_3']
assert 1<=effort<=5 and 1<=threads<=16
assert not (W/'pnr.log').exists(), 'Archive previous attempt first'
assert not (W/'pnr_summary.json').exists(), 'Archive previous summary first'
env=os.environ.copy(); env['PYTHONUTF8']='1'
for key,sub in [('EFINITY_HOME',''),('EFXPT_HOME','pt'),('EFXIPM_HOME','ipm'),('EFXPGM_HOME','pgm'),('EFXDBG_HOME','debugger'),('PYTHONHOME','python311'),('QT_PLUGIN_PATH','python311')]: env[key]=(E/sub).as_posix()
for n in ['tmp','user','out','build']: (W/n).mkdir(exist_ok=True)
env.update(TMP=str(W/'tmp'),TEMP=str(W/'tmp'),EFINITY_USER_DIR_INI=str(W/'user.ini'),EFINITY_USER_DIR=str(W/'user'))
env['PATH']=str(E/'bin')+os.pathsep+str(E/'python311/bin')+os.pathsep+env['PATH']
(W/'user.ini').write_text('[General]\nEFINITY_USER_DIR='+(W/'user').as_posix()+'\n')
cmd=[str(E/'python311/bin/python.exe'),str(E/'scripts/efx_run.py'),'ArtFlow.xml','--flow','pnr','--output_dir',(W/'out').as_posix(),'--work_dir',(W/'build').as_posix(),'--pnr_opts','optimization_level='+profile,'max_threads='+str(threads),'seed='+str(seed),'placer_effort_level='+str(effort)]
route_only=len(sys.argv)>5 and sys.argv[5]=='route_only'
if route_only:
 assert (W/'out/ArtFlow.place').is_file()
 cmd+=['route']
start=time.time()
inputs={n:hashlib.sha256((R/n).read_bytes()).hexdigest() for n in ['ArtFlow.xml','ArtFlow.sdc','ArtFlow.peri.xml','work/osd_impl/implementation_source_sha256.json','work/osd_impl/out/ArtFlow.map.v','work/osd_impl/out/ArtFlow.vdb','work/osd_impl/out/ArtFlow.interface.csv']}
if route_only: inputs['work/osd_impl/out/ArtFlow.place']=hashlib.sha256((W/'out/ArtFlow.place').read_bytes()).hexdigest()
with (W/'pnr.log').open('w') as f:
 p=subprocess.Popen(cmd,cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.BELOW_NORMAL_PRIORITY_CLASS)
 (W/'pnr_process.json').write_text(json.dumps(dict(pid=p.pid,command=cmd,start=start,source_inputs_sha256=inputs,owner_thread='01a18de2-e123-7803-802f-e86da73e2521'),indent=2))
 rc=p.wait()
result=dict(status='PASS' if rc==0 else 'FAIL',returncode=rc,seconds=time.time()-start,command=cmd,source_inputs_sha256=inputs)
(W/'pnr_summary.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result),flush=True)
sys.exit(rc)
