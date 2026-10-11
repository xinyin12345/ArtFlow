"""Run real Efinity tools in an ASCII staging directory; preserve every run."""
from pathlib import Path
import shutil,tempfile,subprocess,json,time,hashlib,argparse,re,sys
R=Path(__file__).resolve().parent
a=argparse.ArgumentParser();a.add_argument('--flow',choices=['map','pnr'],default='map');a.add_argument('--period',type=float,default=10);a.add_argument('--source');args=a.parse_args()
stage=Path(tempfile.mkdtemp(prefix='s8_480_shared_'))
for folder in ['rtl','mem']:shutil.copytree(str(R/folder),str(stage/folder))
top=(R/'rtl/s8_shared.v').read_text().replace('`include "layer_config.vh"',(R/'rtl/layer_config.vh').read_text())
for name in ['shared_mac','shared_quant','shared_line']:top+='\n'+(R/'rtl'/ (name+'.v')).read_text()
(stage/'s8_shared_flat.v').write_text(top,encoding='ascii')
xml=(R/'s8_shared.xml').read_text()
xml=re.sub(r'  <efx:design_file[^\n]+\n','',xml)
xml=xml.replace('  <efx:top_vhdl_arch','  <efx:design_file name="s8_shared_flat.v" version="default" library="default"/>\n  <efx:top_vhdl_arch')
(stage/'s8_shared.xml').write_text(xml,encoding='ascii')
(stage/'clock.sdc').write_text('create_clock -name clk -period %.3f [get_ports {clk}]\n'%args.period,encoding='ascii')
if args.flow=='pnr':
    assert args.source,'Pass --source synthesis stage'
    source=Path(args.source)
    assert (source/'s8_shared_flat.v').read_bytes()==(stage/'s8_shared_flat.v').read_bytes(),'RTL changed; resynthesize'
    assert all((source/'mem'/p.name).read_bytes()==p.read_bytes() for p in (stage/'mem').iterdir()),'ROM changed; resynthesize'
    shutil.copytree(str(source/'outflow'),str(stage/'outflow'))
cmd='call "C:\\Efinity\\2026.1\\bin\\efx_run.bat" s8_shared.xml --flow '+args.flow
cmd+= ' --map_opts max_mult=150 max-bit-blast-mem-size=16384' if args.flow=='map' else ' --pnr_opts print_critical_path=10 max_threads=4 seed=1'
(stage/'run.cmd').write_text('@echo off\nsetlocal\ncd /d "%~dp0"\nset "PYTHONPATH="\ncall "C:\\Efinity\\2026.1\\bin\\setup.bat"\n'+cmd+'\nexit /b %errorlevel%\n',encoding='ascii')
rep=R/'reports'/(args.flow+'_'+time.strftime('%Y%m%d_%H%M%S'));rep.mkdir(parents=True)
(rep/'deployment.json').write_text(json.dumps(dict(stage=str(stage),command=cmd,clock_ns=args.period,
    rtl_sha256=hashlib.sha256((stage/'s8_shared_flat.v').read_bytes()).hexdigest(),
    rtl_sha256_lf_text=hashlib.sha256(top.encode('ascii')).hexdigest()),indent=2),encoding='utf-8')
print('STAGE',stage,'REPORT',rep,flush=True)
start=time.time()
with (rep/'console.log').open('w') as f:p=subprocess.run(['cmd.exe','/c',str(stage/'run.cmd')],cwd=str(stage),stdout=f,stderr=subprocess.STDOUT)
if (stage/'outflow').exists():shutil.copytree(str(stage/'outflow'),str(rep/'outflow'))
(rep/'result.json').write_text(json.dumps(dict(returncode=p.returncode,seconds=time.time()-start,stage=str(stage)),indent=2),encoding='utf-8')
print('RETURN',p.returncode,'SECONDS',time.time()-start,flush=True)
sys.exit(p.returncode)
