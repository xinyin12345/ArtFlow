from pathlib import Path
import sys,json,shutil,hashlib
R=Path(__file__).resolve().parents[1];F=R.parent;sys.path.insert(0,str(F/'tools'));import build_styles15 as b
from check_round23t_project import verify,W
assert json.loads((F/'reports/round23t_map_analysis.json').read_text())['status']=='PASS'
assert json.loads((R/'logs/rtl/summary.json').read_text())['status']=='PASS'
if '--resume-audit' not in sys.argv: b.flow('pnr')
else: assert json.loads((W/'pnr_summary.json').read_text())['status']=='PASS'
b.run('tools/check_round23t_timing.py')
for n in ['video_cdc','cnn_cdc','style_io']:b.run('tools/check_round23t_'+n+'.py','prepare')
(W/'audit.tcl').write_text('\n'.join((F/'tools'/n).read_text() for n in ['check_video_cdc.tcl','check_ui_cdc.tcl','check_cnn_cdc.tcl','check_al_lease_cdc.tcl','check_style_io.tcl','check_round23t_return_ram_v2.tcl']))
import stream_io_audit as stream;stream.prepare();b.flow('sta_tclsh')
for n in ['cnn','ui']:shutil.copy2(W/'sta_tclsh.log',W/(n+'_cdc.log'))
for n in ['video_cdc','cnn_cdc','style_io']:b.run('tools/check_round23t_'+n+'.py','check')
b.run('tools/check_round23t_ui_cdc.py');b.run('tools/check_round23t_return_ram_cdc_v2.py');stream.check()
# pgm only generates files. No programmer is invoked and no device is opened.
import subprocess
subprocess.run([sys.executable,str(R/'scripts/verify_regression_evidence.py')],check=True)
subprocess.run([sys.executable,str(R/'tests/cdc_audit_test.py')],check=True)
b.flow('pgm');verify()
artifacts={n:hashlib.sha256((W/'out'/n).read_bytes()).hexdigest() for n in ['ArtFlow.bit','ArtFlow.hex']}
(R/'logs/fpga-final.json').write_text(json.dumps({'status':'PASS_OFFLINE_CONDITIONAL_IO_BUDGET','hardware_programmed':False,'artifacts':artifacts},indent=2));print('FPGA OFFLINE GATES PASS',artifacts)
