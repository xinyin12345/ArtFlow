from pathlib import Path
import subprocess,json,hashlib
R=Path(__file__).resolve().parents[1];S=R.parent/'fpga_project';O=R/'logs/protocol';gcc='C:/msys64/ucrt64/bin/gcc.exe'
subprocess.run(['C:/Python314/python.exe',str(R/'tests/protocol_test.py')],check=True)
exe=O/'diagnostics.exe'
subprocess.run([gcc,'-std=c11','-O2','-Wall','-Wextra','-Werror','-I'+str(R/'protocol'),str(R/'protocol/afs.c'),str(R/'tests/diagnostics_test.c'),'-o',str(exe)],check=True)
unit=subprocess.run([str(exe)],check=True,capture_output=True,text=True).stdout
old=O/'legacy.exe'
subprocess.run([gcc,'-std=c11','-O2','-Wall','-Wextra','-Werror','-I'+str(S/'protocol'),str(S/'protocol/afs.c'),str(S/'tests/protocol_runner.c'),'-o',str(old)],check=True)
cases=json.loads((O/'summary.json').read_text())['cases'];comparison={}
for name,expected in cases.items():
 want=1 if name in ['valid','recovery_after_error'] else 0
 out=O/(name+'.legacy.ws');result=subprocess.run([str(old),str(O/(name+'.spi')),str(out),str(want)],check=True,capture_output=True,text=True)
 assert result.stdout.strip()==expected,(name,result.stdout,expected)
 assert out.read_bytes()==(O/(name+'.ws')).read_bytes(),name
 comparison[name]='identical counters, return outcome and output bytes'
(R/'logs/diagnostics-tests.json').write_text(json.dumps({'status':'PASS','unit':unit,'legacy_differential':comparison},indent=2))
print(unit);print('PASS: 12 original scenarios byte-identical to original receiver')
