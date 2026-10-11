"""Early source release must preserve IRQ/error/publication and job ownership."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys
R=Path(__file__).resolve().parents[1];out=R/'work/v09/control';out.mkdir(parents=True,exist_ok=True)
s=(R/'sim/tb_v07_ctrl.sv').read_text().replace('tb_v07_ctrl','tb_v09_ctrl')
s=s.replace('artflow_accel_ctrl dut',"artflow_accel_ctrl #(.VERSION_ID(32'h41524609),.EARLY_RELEASE(1)) dut")
s=s.replace(".source_consumed(1'b0)",'.source_consumed(source_consumed)')
s=s.replace('reg busy=0,done=0,failed=0;','reg source_consumed=0;reg busy=0,done=0,failed=0;')
s=s.replace('failed=bad;busy=0;done=1;', '''source_consumed=1; @(negedge clk); source_consumed=0;
 if(source_locked || !dut.job_active) $fatal(1,"Early release lost job tracking");
 repeat(12) @(negedge clk);
 failed=bad;busy=0;done=1;''')
(out/'tb_v09_ctrl.sv').write_text(s)
iv=R/'work/v07/tools/ucrt64/bin';env=os.environ.copy();env['PATH']=str(iv)+os.pathsep+r'C:\msys64\ucrt64\bin'+os.pathsep+r'C:\Windows\System32'
limits=[];status='FAIL'
try:
    (out/'test.vvp').unlink(missing_ok=True)
    with (out/'compile.log').open('w') as f:
        c=subprocess.run([str(iv/'iverilog.exe'),'-v','-g2012','-s','tb_v09_ctrl','-o',str(out/'test.vvp'),str(R/'rtl/accel/artflow_accel_ctrl.v'),str(out/'tb_v09_ctrl.sv')],cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60)
    txt=(out/'compile.log').read_text(errors='replace')
    if c.returncode in (3221225477,-1073741819) and 'DONE.' in txt and (out/'test.vvp').exists() and not re.search(r'error:|syntax error',txt):limits.append('Icarus exit fault after code emission')
    else:assert c.returncode==0,txt[-2500:]
    with (out/'simulation.log').open('w') as f:
        c=subprocess.run([str(iv/'vvp.exe'),str(out/'test.vvp')],cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60)
    txt=(out/'simulation.log').read_text();print(txt)
    assert c.returncode==0 and 'tb_v09_ctrl PASS' in txt and not re.search(r'ERROR:|FATAL:',txt)
    status='PASS_WITH_TOOL_LIMITATIONS' if limits else 'PASS'
except Exception as e:print(e)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=[Path(__file__),R/'sim/tb_v07_ctrl.sv',R/'rtl/accel/artflow_accel_ctrl.v']
(out/'summary.json').write_text(json.dumps(dict(status=status,tool_limitations=limits,source_sha256={p.relative_to(R).as_posix():sha(p) for p in inputs},evidence_sha256={p.name:sha(p) for p in out.glob('*.log')}),indent=2)+'\n')
sys.exit(status=='FAIL')
