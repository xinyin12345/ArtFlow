from pathlib import Path
import subprocess,sys,hashlib,json
r=Path(__file__).resolve().parents[1];e=r/'releases/stream30_websocket_20261026/source/esp_project'
(e/'logs/protocol').mkdir(parents=True,exist_ok=True)
for n in ['run_diagnostics.py','run_websocket.py']:
 subprocess.run([sys.executable,str(e/'tests'/n)],cwd=e,check=True)
subprocess.run(['D:/soft/Node_js/node.exe',str(e/'tests/browser_test.js')],cwd=e,check=True)
files=[e/'esp32/main/main.c',e/'esp32/main/index.html',e/'protocol/afs.c',e/'protocol/afs.h',e/'protocol/afs.js']+list((e/'tests').glob('*'))
out=r/'stream/logs/browser-tests.json';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps({'status':'PASS','scope':'Final ESP diagnostics, browser and TCP loopback tests; no hardware','source_sha256':{str(p.resolve()):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file()}},indent=2))
