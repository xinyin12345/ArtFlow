# -*- coding: utf-8 -*-
"""Compile the actual RTL to C++, without substituting any arithmetic module."""
from pathlib import Path
import sys,subprocess,shutil,json,os,time,hashlib,argparse
R=Path(__file__).resolve().parent
a=argparse.ArgumentParser()
a.add_argument('--width',type=int,default=480);a.add_argument('--height',type=int,default=270)
a.add_argument('--latency',type=int,default=3);a.add_argument('--stall',type=int,default=1)
a.add_argument('--frames',type=int,default=1);a.add_argument('--mode',default='random');a.add_argument('--image')
args=a.parse_args()
cmd=[sys.executable,str(R/'verify.py'),'--prepare-only']
for key in ('width','height','latency','stall','frames','mode'):cmd+=['--'+key,str(getattr(args,key))]
if args.image:cmd+=['--image',args.image]
subprocess.check_call(cmd)
datarep=R/'reports'/('sim_%dx%d_L%d_S%d_%s'%(args.width,args.height,args.latency,args.stall,args.mode))
if args.image:datarep=datarep.with_name(datarep.name+'_'+Path(args.image).stem)
info=json.loads((datarep/'prepared.json').read_text('utf8'));stage=Path(info['stage'])
tag=args.mode+('_'+Path(args.image).stem if args.image else '')
rep=R/'reports'/('verilator_%dx%d_%s_%s'%(args.width,args.height,tag,time.strftime('%Y%m%d_%H%M%S')));rep.mkdir()
package=R.parent/'.venv_u8_rtl/Lib/site-packages/verilator'
tool=R.parent.parent/'xfeat/.fpga_tools/verilator_5_48'
if not tool.exists():shutil.copytree(package,tool)
env=os.environ.copy();env['VERILATOR_ROOT']=str(tool);env['TEMP']=str(stage);env['TMP']=str(stage)
command=[str(tool/'bin/verilator_bin.exe'),'--cc','--top-module','student_u8','--Mdir','obj_dir',
         '-Wno-fatal','-Irtl','-GEXT_W='+str(args.width),'-GEXT_H='+str(args.height),'--compiler','msvc']
command += [str(p.relative_to(stage)) for p in (stage/'rtl').glob('*.v')]
with (rep/'compile.log').open('w') as log:
    subprocess.check_call(command,cwd=stage,env=env,stdout=log,stderr=subprocess.STDOUT)
    shutil.copy2(R/'sim_main.cpp',stage/'sim_main.cpp')
    cpp=sorted((stage/'obj_dir').glob('*.cpp'))
    cpp += [tool/'include/verilated.cpp',tool/'include/verilated_threads.cpp',stage/'sim_main.cpp']
    vcvars=Path(r'C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat')
    line='cl /nologo /O2 /EHsc /std:c++20 /MD /DVL_TIME_CONTEXT /I"'+str(tool/'include')+'" /I"'+str(tool/'include/vltstd')+'" /Iobj_dir '
    line+=' '.join('"'+str(p)+'"' for p in cpp)+' /Fe:simulation.exe'
    (stage/'build.cmd').write_text('@echo off\ncall "'+str(vcvars)+'"\n'+line+'\nexit /b %errorlevel%\n',encoding='ascii')
    subprocess.check_call(['cmd.exe','/c',str(stage/'build.cmd')],cwd=stage,env=env,stdout=log,stderr=subprocess.STDOUT)
t=time.time()
with (rep/'simulation.log').open('w') as f:
    run=subprocess.run([str(stage/'simulation.exe'),str(args.latency),str(args.stall),str(args.frames)],cwd=stage,env=env,stdout=f,stderr=subprocess.STDOUT)
result=dict(returncode=run.returncode,seconds=time.time()-t,args=vars(args),stage=str(stage),checked_integer=True,
    checked_words_per_frame=info['gold'],counts=info['counts'],arithmetic_substitution=False,
    rtl_sha256={str(p.relative_to(stage)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (stage/'rtl').iterdir() if p.is_file()})
if run.returncode==0:
    import numpy as np
    from PIL import Image
    for frame in range(args.frames):
        raw=stage/('rtl_rgb_frame%d.bin'%frame)
        if raw.exists():
            image=np.frombuffer(raw.read_bytes(),np.uint8).reshape(args.height,args.width,3)
            Image.fromarray(image).save(rep/('rtl_output_frame%d.png'%frame))
            if args.image:
                oracle=np.asarray(Image.open(datarep/'integer_output.png'))
                result['rgb_max_abs_error']=int(np.abs(image.astype(np.int16)-oracle.astype(np.int16)).max())
                assert result['rgb_max_abs_error']==0
                Image.open(args.image).convert('RGB').resize((args.width,args.height)).save(rep/'input.png')
                shutil.copy2(datarep/'integer_output.png',rep/'integer_output.png')
(rep/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print((rep/'simulation.log').read_text(),flush=True);print(json.dumps(result),flush=True)
sys.exit(run.returncode)
