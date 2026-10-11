"""Check the board color profile and simulate BLC/WB/gamma plus frame-boundary regressions.

Usage: python -B tools/test_reference_color.py --tool-bin PATH_TO_IVERILOG_BIN
An Icarus process error fails by default, even if it created a model. The explicit
--allow-compiler-exit-crash flag accepts only the known Windows exit-time crash
after DONE and fresh model generation; this is recorded, never hidden as exit 0.
"""
from pathlib import Path
from datetime import datetime
import argparse
import hashlib
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tool-bin', type=Path, required=True)
    parser.add_argument('--allow-compiler-exit-crash', action='store_true')
    args = parser.parse_args()
    run = ROOT / 'work/reference_color' / datetime.now().strftime('test_%Y%m%d_%H%M%S_%f')
    run.mkdir(parents=True)
    env = os.environ.copy()
    env['PATH'] = str(args.tool_bin) + os.pathsep + env['PATH']
    top = (ROOT/'rtl/ArtFlow_top.v').read_text(encoding='utf-8')
    header = (ROOT/'firmware/include/platform.h').read_text(encoding='utf-8')
    gains = [int(re.search(r"CFG_"+c+r"_GAIN\s*=\s*16'd(\d+)", top)[1]) for c in 'RGB']
    fw = [int(re.search(r'#define DEFAULT_'+c+r'\s+(\d+)u', header)[1]) for c in 'RGB']
    assert gains == fw == [102,102,102], (gains, fw)
    assert re.search(r"CFG_BLACK_LEVEL\s*=\s*10'd68", top)
    assert re.search(r'\.BLACK_LEVEL\s*\(CFG_BLACK_LEVEL\)', top)
    pipe = (ROOT/'rtl/video/cam_fb_pipe.v').read_text(encoding='utf-8')
    assert re.search(r'bayer_bin2x2\s*#\(\s*\.BLACK_LEVEL\s*\(BLACK_LEVEL\)', pipe)
    assert re.search(r'\.LUT_FILE\s*\("\./rtl/gamma_conrrection/gamma_inv2p2_8b.mem"\)', top)
    lut = [int(n,16) for n in (ROOT/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem').read_text().split()]
    assert lut == [round(255*(n/255)**(1/2.2)) for n in range(256)]
    assert lut[0]==0 and lut[64]==136 and lut[128]==186 and lut[255]==255
    print('PROFILE PASS: BLC=68 RAW10; hardware/firmware=102/102/102; 256 display gamma entries', flush=True)
    bayer = 'rtl/video/bayer_bin2x2.v'
    cases = [
        ('tb_reference_color', [bayer, 'rtl/gamma_conrrection/gamma_lut.v','sim/tb_reference_color.sv']),
        ('tb_bayer_first_pixel', [bayer, 'sim/tb_bayer_first_pixel.sv']),
        ('tb_artflow_control', [bayer, 'rtl/control/artflow_control.v','sim/tb_artflow_control.sv']),
    ]
    inputs = {ROOT/p for _, files in cases for p in files}
    inputs.update(ROOT/p for p in ['rtl/ArtFlow_top.v','rtl/video/cam_fb_pipe.v',
        'firmware/include/platform.h','rtl/gamma_conrrection/gamma_inv2p2_8b.mem',
        'tools/test_reference_color.py'])
    def hashes():
        return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(inputs)}
    before = hashes()
    results = []
    for name, files in cases:
        model = run/(name+'.vvp')
        cmd = [str(args.tool_bin/'iverilog.exe'), '-v','-g2012','-gstrict-expr-width',
               '-s',name,'-o',str(model),*files]
        built = subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,text=True,errors='replace',timeout=120)
        log = built.stdout + built.stderr
        (run/(name+'_compile.log')).write_text(log,encoding='utf-8')
        exception = built.returncode in (-1073741819,3221225477) and args.allow_compiler_exit_crash
        exception = exception and 'DONE.' in log and model.is_file() and model.stat().st_size>0
        if built.returncode and not exception:
            raise RuntimeError(f'{name} compiler exit {built.returncode}:\n{log[-5000:]}')
        if exception:
            print(f'WARNING: {name} compiler exit {built.returncode} after DONE; executing fresh model',flush=True)
        executed = subprocess.run([str(args.tool_bin/'vvp.exe'),'-i',str(model)],cwd=ROOT,env=env,
                                  capture_output=True,text=True,errors='replace',timeout=120)
        output = executed.stdout + executed.stderr
        (run/(name+'.log')).write_text(output,encoding='utf-8')
        print(output.strip(),flush=True)
        if executed.returncode or name+' PASS' not in output or re.search(r'ERROR:|FATAL:',output):
            raise RuntimeError(f'{name} runtime failed: {executed.returncode}')
        results.append(dict(name=name,compiler_exit=built.returncode,compiler_exit_exception=bool(exception),
                            runtime_exit=executed.returncode,status='PASS'))
    assert before == hashes(), 'Inputs changed during simulation'
    result = dict(status='PASS',scope='BLC/WB/gamma and Bayer/APB regressions; not a board test',
                  source_sha256=before,tests=results,run_directory=str(run))
    (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    (ROOT/'work/reference_color/latest_test.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('REFERENCE COLOR PASS',run,flush=True)


if __name__=='__main__':
    main()
