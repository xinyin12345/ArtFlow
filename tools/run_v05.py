"""Run v05 control/CPU tests and the inherited pixel-accurate video suite.

The real Sapphire boot test is separate from the APB unit test and video tests.
No hardware is programmed by this tool. Use one Questa process at a time.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r'\*\* (?:Error|Fatal|Warning)\b|\bFAIL\b|(?:Errors|Warnings):\s*[1-9]')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--smoke', action='store_true')
    mode.add_argument('--full', action='store_true')
    parser.add_argument('--control-only', action='store_true')
    parser.add_argument('--soc-only', action='store_true')
    parser.add_argument('--skip-soc', action='store_true')
    parser.add_argument('--soc-scenario', choices=('all', 'success', 'nack'), default='all')
    parser.add_argument('--run-dir', type=Path, default=ROOT/'work/regression_v05')
    args = parser.parse_args()
    run = args.run_dir.resolve()
    run.mkdir(parents=True, exist_ok=True)
    results = []
    manifest = {}
    summary_path = run/'summary.json'
    summary_path.write_text('{"status":"RUNNING"}\n')

    def call(name, command, marker=None, timeout=1800):
        start = time.monotonic()
        log_path=run/f'{name}.log'
        with log_path.open('wb') as log:
            proc = subprocess.run([str(v) for v in command], cwd=run,
                                  stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
        output = log_path.read_text(encoding='utf-8', errors='replace')
        ok = proc.returncode == 0 and not ERROR.search(output) and (not marker or marker in output)
        result = dict(name=name, status='PASS' if ok else 'FAIL', seconds=round(time.monotonic()-start, 2))
        results.append(result)
        print(f'{name}: {result["status"]} ({result["seconds"]} s)', flush=True)
        if not ok:
            print(output[-10000:], flush=True)
            raise RuntimeError(name)

    def fingerprint(paths):
        for path in paths:
            p=ROOT/path
            manifest[path]=hashlib.sha256(p.read_bytes()).hexdigest()

    def simulate(top, paths, timeout=1800):
        fingerprint(paths)
        if not (run/'work').exists():
            call('vlib', ['vlib', 'work'])
        call('compile_'+top, ['vlog', '-sv', *[ROOT/p for p in paths]])
        call(top, ['vsim', '-c', '-onfinish', 'exit', 'work.'+top,
                   '-do', 'run -all; quit -code 0'], top+' PASS', timeout)

    try:
        rom_path='rtl/cam_i2c_ctrl/i2c/i2c_master_reg_rom.v'
        rom = re.sub(r'/\*.*?\*/|//[^\n]*', '', (ROOT/rom_path).read_text(encoding='utf-8-sig'), flags=re.S)
        rows = re.findall(r"ROM\[8'h([\da-f]+)\]\s*=\s*\{16'h([\da-f]+),\s*8'h([\da-f]+),\s*1'b0\s*\}",rom,re.I)
        if [int(i,16) for i,_,_ in rows] != list(range(164)):
            raise ValueError('Expected 164 camera ROM entries')
        (run/'camera_golden.memh').write_text(''.join(a+v+'\n' for _,a,v in rows))
        fingerprint([rom_path])
        if not args.soc_only:
            simulate('tb_sapphire_i2c', ['ip/sapphire_soc/sim/sapphire_soc.v',
                     'sim/tb_soc_boot.sv', 'sim/tb_sapphire_i2c.sv'])
            simulate('tb_bayer_first_pixel', ['rtl/video/bayer_bin2x2.v',
                     'sim/tb_bayer_first_pixel.sv'])
            simulate('tb_camera_gate', ['rtl/control/artflow_camera_gate.v',
                     'rtl/video/bayer_bin2x2.v', 'rtl/video/rgb_frame_store.v',
                     'rtl/video/video_axi_scheduler.v', 'rtl/frame_buffer/DC_FIFO.v',
                     'rtl/frame_buffer/rst_n_piple.v', 'sim/axi_memory_checked.sv',
                     'sim/tb_camera_gate.sv'])
            simulate('tb_artflow_control', ['rtl/control/artflow_control.v',
                     'rtl/video/bayer_bin2x2.v', 'sim/tb_artflow_control.sv'])
            for core_half,pixel_half in [(7,11),(11,7)]:
                call(f'control_async_{core_half}_{pixel_half}', ['vsim', '-c', '-onfinish', 'exit',
                    f'-GCORE_HALF={core_half}', f'-GPIXEL_HALF={pixel_half}',
                    'work.tb_artflow_control', '-do', 'run -all; quit -code 0'], 'tb_artflow_control PASS')
        if not args.control_only and not args.skip_soc:
            from check_project_v05 import check_firmware
            check_firmware()
            # The generated SoC uses byte-lane readmemb files relative to simulator cwd.
            import shutil
            memory_dir = run/'ip/sapphire_soc'
            memory_dir.mkdir(parents=True, exist_ok=True)
            for src in (ROOT/'ip/sapphire_soc').glob('*.bin'):
                shutil.copyfile(src, memory_dir/src.name)
                fingerprint([src.relative_to(ROOT).as_posix()])
            paths=['ip/sapphire_soc/sim/sapphire_soc.v', 'rtl/control/artflow_soc.v',
                   'rtl/control/artflow_control.v', 'sim/tb_soc_boot.sv']
            fingerprint([rom_path,*paths])
            if not (run/'work').exists(): call('vlib',['vlib','work'])
            call('compile_tb_soc_boot',['vlog','-sv',*[ROOT/p for p in paths]])
            for scenario in ('success','nack'):
                if args.soc_scenario not in ('all', scenario): continue
                call('soc_'+scenario, ['vsim','-c','-onfinish','exit','work.tb_soc_boot',
                     *(['+SENSOR_NACK'] if scenario=='nack' else []),
                     '-do','run -all; quit -code 0'], 'tb_soc_boot PASS', timeout=3600)
        if not args.control_only and not args.soc_only:
            command = [sys.executable, '-B', ROOT/'tools/run_v04.py', '--run-dir', run/'video']
            command += ['--full', '--soak-frames', '1000'] if args.full else ['--smoke']
            call('video_regression', command, 'REGRESSION PASS', timeout=3600)
            video = json.loads((run/'video/summary.json').read_text())
            if video['status'] != 'PASS': raise RuntimeError('Video summary not PASS')
            manifest.update(json.loads((run/'video/source_sha256.json').read_text()))
        status='PASS'
    except Exception as exc:
        status='FAIL'
        results.append(dict(name=str(exc), status='FAIL'))
        print(str(exc), file=sys.stderr)
    fingerprint(['tools/run_v05.py'])
    (run/'source_sha256.json').write_text(json.dumps(manifest, indent=2)+'\n')
    summary_path.write_text(json.dumps(dict(status=status, tests=results,
        scope=dict(control=not args.soc_only, soc=not args.control_only and not args.skip_soc,
                   video=not args.control_only and not args.soc_only, full_video=args.full)), indent=2)+'\n')
    print('V05 REGRESSION '+status, flush=True)
    return status != 'PASS'


if __name__ == '__main__':
    sys.exit(main())
