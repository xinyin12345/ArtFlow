from pathlib import Path
import os,subprocess,sys,time,json,hashlib
R=Path(__file__).resolve().parents[1];W=R/'work/osd_impl';W.mkdir(parents=True,exist_ok=True);E=Path(os.environ.get('EFINITY_ROOT','D:/soft/Efinity/2026.1'));phase=sys.argv[1];pnr_opt=sys.argv[2] if len(sys.argv)>2 else 'TIMING_3';assert pnr_opt in ['TIMING_3','CONGESTION_3']
assert phase in ['map','interface','pnr','pgm','sta_tclsh']
env=os.environ.copy()
for key,sub in [('EFINITY_HOME',''),('EFXPT_HOME','pt'),('EFXIPM_HOME','ipm'),('EFXPGM_HOME','pgm'),('EFXDBG_HOME','debugger'),('PYTHONHOME','python311'),('QT_PLUGIN_PATH','python311')]:env[key]=(E/sub).as_posix()
for n in ['tmp','user','out','build']:(W/n).mkdir(exist_ok=True)
env.update(TMP=str(W/'tmp'),TEMP=str(W/'tmp'),EFINITY_USER_DIR_INI=str(W/'user.ini'),EFINITY_USER_DIR=str(W/'user'))
env['PATH']=str(E/'bin')+os.pathsep+str(E/'python311/bin')+os.pathsep+env['PATH']
(W/'user.ini').write_text('[General]\nEFINITY_USER_DIR='+(W/'user').as_posix()+'\n')
cmd=[str(E/'python311/bin/python.exe'),str(E/'scripts/efx_run.py'),'ArtFlow.xml','--flow',phase,'--output_dir',(W/'out').as_posix(),'--work_dir',(W/'build').as_posix()]
if phase=='pnr':cmd+=['--pnr_opts','optimization_level='+pnr_opt,'max_threads=2']
if phase=='pnr' and len(sys.argv)>3:
 assert sys.argv[3]=='route_only'
 assert (W/'out/ArtFlow.place').exists()
 cmd+=['route']
if phase=='map':
 map_threads=int(os.environ.get('OSD_MAP_THREADS','2')); assert 1<=map_threads<=16
 map_mode=os.environ.get('OSD_MAP_MODE','speed'); assert map_mode in ['speed','speed2','area','area2','power','cong']
 cmd+=['--map_opts','max_threads='+str(map_threads),'mode='+map_mode]
if phase=='sta_tclsh':cmd+=['-t',(W/'audit.tcl').as_posix(),'--pnr_opts','sdc_file='+(W/'video_cdc_audit.sdc').as_posix()]
if phase=='pgm':assert json.loads((R/'reports/physical_gate.json').read_text())['status']=='PASS'
start=time.time();log=W/(phase+'.log');assert not log.exists(),'Preserve existing logs before retry'
with log.open('w') as f:
 p=subprocess.Popen(cmd,cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.BELOW_NORMAL_PRIORITY_CLASS)
 (W/(phase+'_process.json')).write_text(json.dumps({'pid':p.pid,'command':cmd,'start':start},indent=2));rc=p.wait()
res=dict(status='PASS' if rc==0 else 'FAIL',returncode=rc,seconds=time.time()-start,command=cmd)
(W/(phase+'_summary.json')).write_text(json.dumps(res,indent=2));print(json.dumps(res));sys.exit(rc)
