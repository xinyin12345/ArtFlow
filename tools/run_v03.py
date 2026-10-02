#!/usr/bin/env python3
"""Reproducible Questa regression. All generated files go under work/regression.
Nonzero process status, assertion/error/fatal, FAIL, or missing PASS fails the run.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / 'work' / 'regression'
SOURCES = ['rtl/frame_buffer/DC_FIFO.v', 'rtl/frame_buffer/rst_n_piple.v',
           'rtl/video/bayer_bin2x2.v', 'rtl/video/rgb_frame_store.v',
           'rtl/video/cam_fb_pipe.v', 'rtl/true_dual_port_ram.v',
           'rtl/gamma_conrrection/gamma_correction.v', 'rtl/gamma_conrrection/gamma_lut.v',
           'rtl/video/test_pattern.v', 'sim/tb_gamma_lut.v', 'sim/tb_test_pattern.v',
           'sim/tb_bayer_bin2x2.v', 'sim/axi_memory_checked.sv', 'sim/tb_v03_checked.sv']

def command(args, name, required=None, timeout=900):
    start = time.time()
    r = subprocess.run([str(a) for a in args], cwd=RUN, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    output = r.stdout.decode('utf-8', errors='replace')
    (RUN / f'{name}.log').write_text(output, encoding='utf-8')
    failed = r.returncode != 0 or re.search(r'\*\* (?:Error|Fatal)\b|\bFAIL\b|Errors:\s*[1-9]', output)
    if required and required not in output:
        failed = True
    print(f'{name}: {"FAIL" if failed else "PASS"} ({time.time()-start:.1f}s)', flush=True)
    if failed:
        print(output[-10000:], flush=True)
        raise RuntimeError(name)
    return dict(name=name, status='PASS', seconds=round(time.time()-start, 2))

def gen(w, h, prefix, frames=8):
    command([sys.executable, '-B', ROOT/'tools/v03_golden.py', 'gen', '--w', w,
             '--h', h, '--out', prefix, '--frames', frames], f'gen_{prefix}')

def sim(name, top, params=(), seed=1):
    return command(['vsim', '-c', '-onfinish', 'exit', '-sv_seed', seed,
                    *params, f'work.{top}', '-do',
                    'onbreak {quit -code 1}; run -all; quit -code 0'], name, f'{top} PASS')

def check(prefix, w, h, phase):
    variant = int((RUN/f'{prefix}_cap_variant.txt').read_text().strip())
    return command([sys.executable, '-B', ROOT/'tools/v03_golden.py', 'check',
                    '--w', w, '--h', h, '--out', prefix, '--phase', phase,
                    '--frame', variant], f'check_{prefix}_{phase}', 'check: PASS')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--full', action='store_true')
    parser.add_argument('--smoke', action='store_true')
    args = parser.parse_args()
    RUN.mkdir(parents=True, exist_ok=True)
    results = []
    try:
        if not (RUN/'work').exists():
            command(['vlib', 'work'], 'vlib')
        command(['vlog', *[ROOT/f for f in SOURCES]], 'compile')
        gen(64, 16, 'unit', 0)
        gen(160, 40, 'small')
        results.append(sim('gamma', 'tb_gamma_lut'))
        results.append(sim('pattern', 'tb_test_pattern'))
        results.append(sim('bayer', 'tb_bayer_bin2x2'))
        for phase in ([0] if args.smoke else range(4)):
            results.append(sim(f'small_p{phase}', 'tb_v03_checked', [f'-GPHASE={phase}']))
            results.append(check('small',160,40,phase))
        if not args.smoke:
            results.append(sim('reverse_pulse', 'tb_v03_checked', ['-GREV=1','-GVS_MODE=1'], 17))
            results.append(check('small',160,40,0))
            gen(320,96,'stress')
            results.append(sim('stress', 'tb_v03_checked',
                               ['-GW=320','-GH=96','-GPREFIX=stress','-GSTRESS=1','-GMAXFRM=80'], 31))
            results.append(check('stress',320,96,0))
            gen(16,8,'tiny')
            results.append(sim('short_burst', 'tb_v03_checked',
                               ['-GW=16','-GH=8','-GPREFIX=tiny'], 7))
            results.append(check('tiny',16,8,0))
        if args.full:
            gen(1920,1080,'full')
            results.append(sim('full', 'tb_v03_checked',
                               ['-GW=1920','-GH=1080','-GPREFIX=full','-GGAP_PCT=10',
                                '-GVBLANK=20000','-GNGOOD=3','-GMAXFRM=15']))
            results.append(check('full',1920,1080,0))
        status = 'PASS'
    except Exception as e:
        results.append(dict(name=str(e), status='FAIL'))
        status = 'FAIL'
    (RUN/'summary.json').write_text(json.dumps(dict(status=status, tests=results), indent=2), encoding='utf-8')
    print(f'REGRESSION {status}', flush=True)
    return status != 'PASS'

if __name__ == '__main__':
    sys.exit(main())
