from pathlib import Path
import subprocess,os,json,hashlib
R=Path(__file__).resolve().parents[1];F=R/'fpga';O=R/'logs/reset-equivalence';O.mkdir(exist_ok=True);Q=Path('D:/soft/Questa/questa_fse/win64');env=os.environ.copy();env['PATH']=str(Q)+os.pathsep+env['PATH']
files=[F/'sim/afs_spi_packet_reset_ref.sv',F/'rtl/stream/afs_spi_packet.sv',F/'sim/tb_afs_reset_equivalence.sv']
def run(name,args):
 with (O/(name+'.log')).open('w') as log:p=subprocess.run([str(Q/(args[0]+'.exe')),*[a.as_posix() if isinstance(a,Path) else str(a) for a in args[1:]]],cwd=F,env=env,stdout=log,stderr=subprocess.STDOUT)
 t=(O/(name+'.log')).read_text(errors='replace');assert p.returncode==0 and '** Error:' not in t and '** Fatal:' not in t,t[-3000:];return t
if not (O/'work').exists():run('vlib',['vlib',O/'work'])
ini=O/'modelsim.ini';ini.write_text('[Library]\nwork = '+(O/'work').as_posix()+'\n')
run('compile',['vlog','-ini',ini,'-work','work','-sv','-timescale','1ns/1ps',*files]);t=run('simulation',['vsim','-c','-ini',ini,'-wlf',O/'test.wlf','-onfinish','exit','work.tb_reset_equivalence','+DIR='+(R/'logs/protocol').as_posix(),'-do','run -all; quit -code 0']);assert 'PASS 50 asynchronous resets' in t
(O/'summary.json').write_text(json.dumps({'status':'PASS','source_sha256':{str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},'evidence':[l for l in t.splitlines() if 'PASS' in l],'scope':'Simulation cycle equivalence across 50 asynchronous reset positions including READY wait and CRC tail; not exhaustive formal proof.'},indent=2));print(t[-1000:])
