"""Serialize all Questa runs under the installed single-session license."""
from pathlib import Path
import json,subprocess,sys,time
R=Path(__file__).resolve().parents[1]
p=R/'work/u8_integration/opt_full_960x540_c3.5_v1/summary.json'
print('Waiting for full-size simulation to release the single Questa license',flush=True)
deadline=time.monotonic()+7200
while time.monotonic()<deadline:
 try: status=json.loads(p.read_text())['status']
 except (OSError,ValueError,KeyError):status='RUNNING'
 if status!='RUNNING':break
 time.sleep(5)
else:raise RuntimeError('Full-size run timeout')
if status!='PASS':raise RuntimeError('Full-size run did not pass: '+status)
for script in ['tools/run_u8_bridge.py','tools/run_u8_optimization_regression.py']:
 print('START',script,flush=True)
 subprocess.check_call([sys.executable,'-X','utf8','-B',script],cwd=R)
 print('END',script,flush=True)
