from pathlib import Path
import subprocess,os,json,sys,time,hashlib
R=Path(__file__).resolve().parents[1];Q=Path(os.environ.get('QUESTA_ROOT','D:/soft/Questa/questa_fse/win64'));O=R/'work/osd_tests';O.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env['PATH']=str(Q)+os.pathsep+env.get('PATH','');(O/'tmp').mkdir(exist_ok=True);env.update(TMP=str(O/'tmp'),TEMP=str(O/'tmp'))
def run(label,args):
 with (O/(label+'.log')).open('w') as log:
  p=subprocess.run([str(Q/(args[0]+'.exe')),*[a.as_posix() if isinstance(a,Path) else str(a) for a in args[1:]]],cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT)
 t=(O/(label+'.log')).read_text(errors='replace');assert p.returncode==0 and '** Error:' not in t and '** Fatal:' not in t,t[-5000:]
 return t
if not (O/'work').exists():run('vlib',['vlib',O/'work'])
ini=O/'modelsim.ini';ini.write_text('[Library]\nwork = '+(O/'work').as_posix()+'\n')
files=['rtl/video/artflow_osd.v','rtl/video/artflow_fps.v','rtl/video/artflow_ui.v','rtl/video/artflow_button.v','sim/tb_osd_blackbars.sv','sim/tb_v06_fps.sv','sim/tb_v06_ui.sv','sim/tb_osd_output_telemetry.sv']
run('compile',['vlog','-ini',ini,'-work','work','-sv',*[R/f for f in files]])
results={}
for name in ['v06_fps','v06_ui','osd_output_telemetry','osd_blackbars']:
 t=run(name,['vsim','-c','-ini',ini,'-wlf',O/(name+'.wlf'),'-onfinish','exit','work.tb_'+name,'+DIR='+O.as_posix(),'-do','run -all; quit -code 0']);assert 'PASS' in t,t[-3000:];results[name]=[l for l in t.splitlines() if 'PASS' in l];print(name,results[name],flush=True)
(R/'reports/osd_simulation.json').write_text(json.dumps({'status':'PASS','results':results,'sha256':{f:hashlib.sha256((R/f).read_bytes()).hexdigest() for f in files+['rtl/video/osd_font.mem','rtl/video/osd_text_rows.mem']}},indent=2))
