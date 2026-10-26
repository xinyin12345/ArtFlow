from pathlib import Path
import subprocess,sys,json,hashlib
R=Path(__file__).resolve().parents[1];O=R/'logs/protocol';O.mkdir(exist_ok=True)
gcc='C:/msys64/ucrt64/bin/gcc.exe';report={}
for name in ['mailbox','generation']:
    exe=O/(name+'_test.exe')
    subprocess.run([gcc,'-std=c11','-O2','-Wall','-Wextra','-Werror','-I'+str(R/'protocol'),str(R/'tests'/(name+'_test.c')),'-o',str(exe)],check=True)
    report[name]=subprocess.run([str(exe)],capture_output=True,text=True,check=True).stdout.strip()
exe=O/'receiver.exe'
subprocess.run([gcc,'-std=c11','-O2','-Wall','-Wextra','-Werror','-I'+str(R/'protocol'),str(R/'protocol/afs.c'),str(R/'tests/protocol_runner.c'),'-o',str(exe)],check=True)
report['RTL_to_C']=subprocess.run([str(exe),str(O/'rtl.spi'),str(O/'rtl.ws'),'2'],capture_output=True,text=True,check=True).stdout.strip()
subprocess.run([sys.executable,str(R/'tests/check_rtl_vectors.py')],check=True)
evidence={'status':'PASS','results':report,'source_sha256':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (R/'protocol').glob('*')}}
(R/'logs/host-tests.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
