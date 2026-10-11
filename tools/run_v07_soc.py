"""Production Sapphire/PLIC/C5 boot test. Requires vendor-supported Questa.

The encrypted CPU remains intact. The accelerator completion input is driven
by a timed peripheral fixture; the real frame/DMA path is tested by run_v07.py.
"""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1]
def main():
    run=ROOT/'work/v07/soc_questa';run.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env['PATH']=r'D:\soft\Questa\questa_fse\win64'+os.pathsep+env['PATH']
    files=['ip/sapphire_soc/sim/sapphire_soc.v','rtl/control/artflow_soc.v',
           'rtl/control/artflow_control.v','rtl/accel/artflow_accel_ctrl.v','sim/tb_v07_soc_boot.sv']
    results=[];status='FAIL'
    def call(name,cmd,marker=None):
        with (run/(name+'.log')).open('w') as f:p=subprocess.run(list(map(str,cmd)),cwd=run,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=3600)
        text=(run/(name+'.log')).read_text(errors='replace')
        ok=p.returncode==0 and not re.search(r'\*\* (Error|Fatal|Warning)|(?:Errors|Warnings):\s*[1-9]',text) and (not marker or marker in text)
        results.append(dict(name=name,status='PASS' if ok else 'FAIL',exit_code=p.returncode))
        if not ok:raise RuntimeError(text[-5000:])
    try:
        from check_project_v05 import check_firmware
        check_firmware()
        (run/'ip/sapphire_soc').mkdir(parents=True,exist_ok=True)
        for p in (ROOT/'ip/sapphire_soc').glob('*.bin'):shutil.copyfile(p,run/'ip/sapphire_soc'/p.name)
        source=(ROOT/'rtl/cam_i2c_ctrl/i2c/i2c_master_reg_rom.v').read_text(encoding='utf-8-sig')
        source=re.sub(r'/\*.*?\*/|//[^\n]*','',source,flags=re.S)
        rows=re.findall(r"ROM\[8'h([\da-f]+)\]\s*=\s*\{16'h([\da-f]+),\s*8'h([\da-f]+),\s*1'b0\s*\}",source,re.I)
        assert len(rows)==164
        (run/'camera_golden.memh').write_text(''.join(a+v+'\n' for _,a,v in rows))
        if not (run/'work').exists():call('vlib',['vlib','work'])
        call('compile',['vlog','-sv',*[ROOT/p for p in files]])
        for name,extra in [('success',[]),('nack',['+SENSOR_NACK'])]:
            call(name,['vsim','-c','-onfinish','exit','work.tb_v07_soc_boot','+P1_BOOT',*extra,
                 '-do','run -all; quit -code 0'],'tb_v07_soc_boot PASS')
        status='PASS'
    except OSError as e:
        status='TOOL_BLOCKED'
        results.append(dict(name='simulator_start',status=status,reason=str(e)));print(e)
    except Exception as e:results.append(dict(name='tool_or_test_failure',status='FAIL',reason=str(e)));print(e)
    evidence_files=files+[p.relative_to(ROOT).as_posix() for p in (ROOT/'ip/sapphire_soc').glob('*.bin')]
    (run/'summary.json').write_text(json.dumps(dict(status=status,tests=results,
        source_sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in evidence_files}),indent=2)+'\n')
    print('V07 SOC',status);return status!='PASS'
if __name__=='__main__':sys.exit(main())
