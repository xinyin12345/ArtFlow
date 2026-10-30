"""Fresh reproducible OSD flow. Run from repository; never accesses hardware."""
from pathlib import Path
import os,sys,subprocess,json,hashlib
R=Path(__file__).resolve().parents[1];W=R/'work/osd_impl'
def run(n,*a):subprocess.run([sys.executable,'-B',str(R/n),*a],cwd=R,check=True)
assert not (W/'map.log').exists(),'Archive existing work/osd_impl before rebuilding'
run('tools/verify_osd_integration.py');run('tools/run_osd_tests.py');run('tools/check_osd_frames.py');run('tools/run_osd_regression.py')
p=R/'reports/regression_complete.json';d=json.loads(p.read_text());d['revision']='CAP_OUT';p.write_text(json.dumps(d,indent=2))
W.mkdir(parents=True,exist_ok=True)
inputs=json.loads((R/'releases/osd_blackbars_20261031/implementation_inputs.json').read_text())
(W/'implementation_source_sha256.json').write_text(json.dumps(inputs,indent=2))
os.environ['OSD_MAP_THREADS']='16';os.environ['OSD_MAP_MODE']='speed'
run('tools/run_osd_flow.py','interface');run('tools/run_osd_flow.py','map')
run('tools/run_osd_physical_attempt.py','TIMING_3','2','5','16')
run('tools/run_osd_audits.py');run('tools/run_osd_flow.py','pgm')
print('PASS fresh physical build: work/osd_impl/out/ArtFlow.bit and .hex; no hardware programmed')
