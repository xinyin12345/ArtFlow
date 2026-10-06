"""Run actual Questa RTL and pixel checker. --full adds inherited video/control suite."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time
from gen_osd_font import GLYPHS,generate
ROOT=Path(__file__).resolve().parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def pixel_check(path):
    bars=[0xffffff,0xffff00,0x00ffff,0x00ff00,0xff00ff,0xff0000,0x0000ff,0]
    count=0
    with path.open() as f:
        for frame in range(9):
            mode=frame%4
            lines=[('ARTFLOW V06 MODE: '+['DUAL','LEFT','RIGHT','BARS'][mode]).ljust(28),
                   ('CAP FPS:---  OUT FPS:---' if frame==8 else 'CAP FPS:030  OUT FPS:060').ljust(28)]
            # Hardware uses a space after the colon at column 16; title mode begins at 18.
            for y in range(100):
                for x in range(1920):
                    expected=((x+frame)&255)<<16 | ((y*3)&255)<<8 | ((x^y)&255)
                    if mode==1 and x>=960 or mode==2 and x<960: expected=0
                    if mode==3:expected=bars[x//240]
                    if (frame<4 or frame==8) and 32<=x<928 and 32<=y<96:
                        col=(x-32)//32; row=(y-32)//32
                        glyph=GLYPHS.get(lines[row][col],['00000']*7)
                        gx=(x-32)%32//4;gy=(y-32)%32//4
                        bit=gy<7 and 1<=gx<6 and glyph[gy][gx-1]=='1'
                        expected=(0x40e0ff if row==0 else 0xffffff) if bit else 0x081828
                    got=f.readline().strip();count+=1
                    if got!=f'{expected:06x}':
                        raise ValueError(f'Pixel mismatch frame={frame} ({x},{y}): {got} != {expected:06x}')
        if f.read().strip():raise ValueError('Extra pixels')
    return count
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--full',action='store_true')
    ap.add_argument('--soc',action='store_true',help='Also rerun unchanged production CPU boot/NACK tests')
    args=ap.parse_args();run=ROOT/'work/regression_v06';run.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env['PATH']=str(Path(r'D:\soft\Questa\questa_fse\win64'))+os.pathsep+env['PATH']
    sources=[p for d in ('rtl','sim','tools','firmware','ip') for p in (ROOT/d).rglob('*')
             if p.is_file() and p.suffix in ('.v','.sv','.vh','.mem','.py','.c','.h','.S','.bin')]
    before={p.relative_to(ROOT).as_posix():sha(p) for p in sources}
    results=[];summary=run/'summary.json';summary.write_text('{"status":"RUNNING"}')
    def call(name,cmd,marker=None,cwd=run,timeout=3600):
        start=time.monotonic();log=run/(name+'.log')
        with log.open('w') as out:p=subprocess.run(list(map(str,cmd)),cwd=cwd,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=timeout)
        text=log.read_text(errors='replace')
        good=p.returncode==0 and (marker is None or marker in text)
        if name.startswith(('compile','tb_')):good=good and not re.search(r'\*\* (?:Error|Fatal|Warning)|(?:Errors|Warnings):\s*[1-9]',text)
        results.append(dict(name=name,status='PASS' if good else 'FAIL',seconds=round(time.monotonic()-start,2)))
        print(name,results[-1]['status'],flush=True)
        if not good:raise RuntimeError(name+'\n'+text[-5000:])
    try:
        if (ROOT/'rtl/video/osd_font.mem').read_text()!=generate():raise ValueError('Stale font')
        if not (run/'work').exists():call('vlib',['vlib','work'])
        # Keep $readmemh paths identical to hardware.
        (run/'rtl/video').mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/'rtl/video/osd_font.mem',run/'rtl/video/osd_font.mem')
        files=[*sorted((ROOT/'rtl/video').glob('artflow_*.v')),*sorted((ROOT/'sim').glob('tb_v06_*.sv'))]
        call('compile_v06',['vlog','-sv',*files])
        for top in ('tb_v06_ui','tb_v06_fps','tb_v06_osd'):
            call(top,['vsim','-c','-onfinish','exit','work.'+top,'-do','run -all; quit -code 0'],top+' PASS')
        count=pixel_check(run/'osd_pixels.hex');results.append(dict(name='osd_pixel_reference',status='PASS',pixels=count))
        print('pixel_reference PASS',count,flush=True)
        if args.full:
            call('inherited', [sys.executable,'-B',ROOT/'tools/run_v05.py','--full',
                *([] if args.soc else ['--skip-soc']),'--run-dir',run/'inherited'], 'V05 REGRESSION PASS')
        if before!={p.relative_to(ROOT).as_posix():sha(p) for p in sources}:raise ValueError('Source changed during regression')
        status='PASS'
    except Exception as e:status='FAIL';results.append(dict(name=str(e),status='FAIL'));print(str(e),flush=True)
    summary.write_text(json.dumps(dict(status=status,full=args.full,soc=args.soc,tests=results,
        source_sha256=before,evidence_sha256={p.name:sha(p) for p in run.glob('*.log')}),indent=2)+'\n')
    print('V06 REGRESSION '+status,flush=True);return status!='PASS'
if __name__=='__main__':sys.exit(main())
