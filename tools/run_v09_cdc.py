"""Exercise both CNN FIFO directions at changing non-harmonic clocks and reset."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    out=R/'work/v09_perf/cdc';out.mkdir(parents=True,exist_ok=True)
    src=[R/'rtl/accel/artflow_cnn_cdc_fifo.v',R/'sim/tb_cnn_cdc_fifo.sv']
    evidence=src+[Path(__file__)];hashes={p.relative_to(R).as_posix():sha(p) for p in evidence}
    (out/'summary.json').write_text('{"status":"RUNNING"}')
    iv=R/'work/v07/tools/ucrt64/bin';env=os.environ.copy();env['PATH']=str(iv)+os.pathsep+r'C:\msys64\ucrt64\bin'+os.pathsep+r'C:\Windows\System32'
    limits=[];status='FAIL'
    try:
        (out/'test.vvp').unlink(missing_ok=True)
        for stage,cmd in [('compile',[str(iv/'iverilog.exe'),'-v','-g2012','-s','tb_cnn_cdc_fifo','-o',str(out/'test.vvp'),*map(str,src)]),('simulation',[str(iv/'vvp.exe'),str(out/'test.vvp')])]:
            with (out/(stage+'.log')).open('w') as f:
                c=subprocess.run(cmd,cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
            t=(out/(stage+'.log')).read_text(errors='replace')
            if stage=='compile' and c.returncode in (3221225477,-1073741819) and 'DONE.' in t and (out/'test.vvp').exists() and not re.search(r'error:|syntax error',t):limits.append('Icarus exit fault after code emission')
            else:assert c.returncode==0,t[-3000:]
            if stage=='simulation':assert 'tb_cnn_cdc_fifo PASS' in t and not re.search('ERROR:|FATAL:',t);print(t)
        assert hashes=={p.relative_to(R).as_posix():sha(p) for p in evidence}
        status='PASS_WITH_TOOL_LIMITATIONS' if limits else 'PASS'
    except Exception as e:print(e)
    (out/'summary.json').write_text(json.dumps(dict(status=status,tool_limitations=limits,source_sha256=hashes,evidence_sha256={p.name:sha(p) for p in out.glob('*.log')}),indent=2)+'\n')
    print(status);return status=='FAIL'
if __name__=='__main__':sys.exit(main())
