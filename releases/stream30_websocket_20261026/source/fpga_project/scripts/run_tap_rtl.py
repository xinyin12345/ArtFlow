from pathlib import Path
import subprocess,os,json,hashlib
R=Path(__file__).resolve().parents[1];F=R/'fpga';O=R/'logs/tap';O.mkdir(exist_ok=True);Q=Path('D:/soft/Questa/questa_fse/win64');env=os.environ.copy();env['PATH']=str(Q)+os.pathsep+env['PATH']
files=[F/n for n in ['rtl/video/rgb_frame_store_v07.v','rtl/video/rgb_frame_store.v','rtl/video/video_axi_scheduler.v','rtl/frame_buffer/DC_FIFO.v','rtl/frame_buffer/rst_n_piple.v','sim/tb_afs_tap.sv']]+[Path('D:/soft/Efinity/2026.1/sim_models/verilog')/n for n in ['efx_ram10.v','efx_dpram10.v']]
def run(name,args,timeout=180):
 with (O/(name+'.log')).open('w') as log:p=subprocess.run([str(Q/(args[0]+'.exe')),*[a.as_posix() if isinstance(a,Path) else str(a) for a in args[1:]]],cwd=F,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
 t=(O/(name+'.log')).read_text(errors='replace');assert p.returncode==0 and '** Error:' not in t and '** Fatal:' not in t,t[-5000:];return t
if not (O/'work').exists():run('vlib',['vlib',O/'work'])
ini=O/'modelsim.ini';ini.write_text('[Library]\nwork = '+(O/'work').as_posix()+'\n')
run('compile',['vlog','-ini',ini,'-work','work','-sv','-timescale','1ns/1ps',*files]);t=run('simulation',['vsim','-c','-ini',ini,'-wlf',O/'test.wlf','-onfinish','exit','work.tb_afs_tap','+DIR='+(R/'logs/protocol').as_posix(),'-do','run -all; quit -code 0']);assert 'PASS AFS' in t
(O/'summary.json').write_text(json.dumps({'status':'PASS','source_sha256':{(str(p.relative_to(R)) if p.is_relative_to(R) else str(p)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},'evidence':[l for l in t.splitlines() if 'PASS' in l]},indent=2));print(t[-2000:])
