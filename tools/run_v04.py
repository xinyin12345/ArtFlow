#!/usr/bin/env python3
"""Single regression registry for batch Python and native Questa entry points."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
from v04_config import load_config
ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'work/regression_v04'
SOURCES=['rtl/frame_buffer/DC_FIFO.v','rtl/frame_buffer/rst_n_piple.v',
 'rtl/video/video_axi_scheduler.v','sim/tb_video_axi_scheduler.sv','rtl/video/bayer_bin2x2.v','rtl/video/rgb_frame_store.v','rtl/video/cam_fb_pipe.v',
 'rtl/true_dual_port_ram.v','rtl/gamma_conrrection/gamma_correction.v','rtl/gamma_conrrection/gamma_lut.v',
 'rtl/video/test_pattern.v','sim/tb_gamma_lut.v','sim/tb_test_pattern.v','sim/tb_bayer_bin2x2.v',
 'sim/axi_memory_checked.sv','sim/tb_v04_checked.sv','sim/tb_v04_params.sv']
ERROR=re.compile(r'\*\* (?:Error|Fatal|Warning)\b|\bFAIL\b|(?:Errors|Warnings):\s*[1-9]')

def command(args,name,required=None,timeout=1200,expected_error=None):
 start=time.time()
 r=subprocess.run([str(a) for a in args],cwd=RUN,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
 output=r.stdout.decode('utf-8',errors='replace')
 (RUN/f'{name}.log').write_text(output,encoding='utf-8')
 if expected_error:
  passed=expected_error in output and '** Fatal:' in output and ' PASS ' not in output
 else:
  passed=r.returncode==0 and not ERROR.search(output) and (not required or required in output)
 print(f'{name}: {"PASS" if passed else "FAIL"} ({time.time()-start:.1f}s)',flush=True)
 if not passed:
  print(output[-12000:],flush=True);raise RuntimeError(name)
 return dict(name=name,status='PASS',seconds=round(time.time()-start,2),
             expected_failure=bool(expected_error))

def config_params(c):
 return {**{f'GAIN_{k}':c[f'CFG_{k}_GAIN'] for k in 'RGB'},
  'DUAL_WINDOW':c['CFG_DUAL_WINDOW'],'PHASE':c['CFG_BAYER'],'REV':c['CFG_PIX_REV'],
  **{n:c[n]//2 for n in ('HFP','HSP','HBP')},**{n:c[n] for n in ('VFP','VSP','VBP')}}

def plan(c,smoke=False,full=False):
 gains={f'GAIN_{k}':c[f'CFG_{k}_GAIN'] for k in 'RGB'}
 base=config_params(c)
 gamma={'OLD_FILE':(ROOT/'rtl/gamma_conrrection/2P2.mem').as_posix(),
        'LUT_FILE':(ROOT/'rtl/gamma_conrrection/gamma_2p2_8b.mem').as_posix()}
 cases=[('scheduler','tb_video_axi_scheduler',{},1),('gamma','tb_gamma_lut',gamma,1),('pattern','tb_test_pattern',{},1),('bayer','tb_bayer_bin2x2',gains,1)]
 if smoke:
  cases.append(('small_p0','tb_v04_checked',dict(base,PHASE=0),1))
 else:
  for ph in range(4):
   for rev in range(2):
    for vs in range(2):
     cases.append((f'small_p{ph}_r{rev}_v{vs}','tb_v04_checked',dict(base,PHASE=ph,REV=rev,VS_MODE=vs),1+ph*4+rev*2+vs))
  for seed in (31,73):
   cases.append((f'stress_{seed}','tb_v04_checked',dict(base,W=320,H=96,PREFIX='stress',STRESS=1,MAXFRM=100),seed))
  cases.append(('short_burst','tb_v04_checked',dict(base,W=16,H=8,PREFIX='tiny'),7))
  for fault,name in enumerate(('bresp_error','rresp_error','camera_stop_restart','truncated_frame','reset_during_write','reset_during_read'),1):
   cases.append((name,'tb_v04_checked',dict(base,FAULT=fault),101+fault))
 if not smoke:
  cases.append(('legacy_fullscreen','tb_v04_checked',dict(base,DUAL_WINDOW=0),19))
 if full:
  dims=dict(base,W=c['MAX_HRES'],H=c['MAX_VRES'],PREFIX='full',GAP_PCT=10,MAXFRM=30)
  cases.append(('full_high_load','tb_v04_checked',dict(dims,VBLANK=20000,NGOOD=3),1))
  # Line period ~1481 pixel clocks plus 45 lines vertical blank -> ~30 fps at 50 MHz.
  cases.append(('full_30fps','tb_v04_checked',dict(dims,LINE_BLANK=948,VBLANK=66650,NOMINAL_FPS=30,NGOOD=6),17))
 return cases

def sim(name,top,params,seed=1,expected_error=None):
 return command(['vsim','-c','-onfinish','exit','-sv_seed',seed,
  *[f'-G{k}={v}' for k,v in params.items()],f'work.{top}','-do',
  'run -all; quit -code 0'],name,top+' PASS',expected_error=expected_error)

def generate(cases):
 vectors={'unit':(64,16,0)}
 for _,top,p,_ in cases:
  if top=='tb_v04_checked':vectors[p.get('PREFIX','small')]=(p.get('W',160),p.get('H',40),8)
 for prefix,(w,h,frames) in vectors.items():
  command([sys.executable,'-B',ROOT/'tools/v04_golden.py','gen','--w',w,'--h',h,'--out',prefix,'--frames',frames],f'gen_{prefix}')
  expected={f'{prefix}_raw.hex':(w*h,1023)}
  for ph in range(4):
   expected[f'{prefix}_exp_p{ph}.hex']=(w*h//4,0xffffff)
   for n in range(frames):expected[f'{prefix}_exp_p{ph}_f{n}.hex']=(w*h//4,0xffffff)
  for f,(size,limit) in expected.items():
   words=(RUN/f).read_text().split()
   if len(words)!=size or any(not re.fullmatch('[0-9a-fA-F]+',v) or int(v,16)>limit for v in words):
    raise ValueError('Invalid vector '+f)

def check(name,p):
 prefix=p.get('PREFIX','small')
 seq=int((RUN/f'{prefix}_cap_variant.txt').read_text().strip())
 return command([sys.executable,'-B',ROOT/'tools/v04_golden.py','check','--w',p.get('W',160),'--h',p.get('H',40),
  '--out',prefix,'--phase',p.get('PHASE',0),'--frame',seq,'--dual-window',p.get('DUAL_WINDOW',1)],f'check_{name}','check: PASS')

def negative_tests(c):
 results=[];gp={f'GAIN_{k}':c[f'CFG_{k}_GAIN'] for k in 'RGB'}
 results.append(sim('negative_gamma_missing','tb_gamma_lut',
  {'OLD_FILE':'intentionally_missing_old.mem','LUT_FILE':'intentionally_missing_new.mem'},
  expected_error='Unknown gamma output/reference'))
 target=RUN/'unit_exp_p0.hex';original=target.read_bytes()
 try:
  target.write_text('xxxxxx\n'*256)
  results.append(sim('negative_x_vector','tb_bayer_bin2x2',gp,expected_error='Invalid/missing golden vector'))
  target.rename(target.with_suffix('.hidden'))
  try:results.append(sim('negative_missing_vector','tb_bayer_bin2x2',gp,expected_error='Invalid/missing golden vector'))
  finally:target.with_suffix('.hidden').rename(target)
 finally:target.write_bytes(original)
 for mutation,name,marker in [(1,'startup','Nonblack pixel in startup/black tail'),(2,'stress','Display pixel mismatch'),(3,'frozen','Display pixel mismatch')]:
  p=dict(config_params(c),MUTATION=mutation)
  if mutation==2:p.update(STRESS=1,W=320,H=96,PREFIX='stress')
  results.append(sim('negative_'+name,'tb_v04_checked',p,expected_error=marker))
 for mutation,name,marker in [(4,'right_window','Display pixel mismatch'),(5,'border','Nonblack pixel in startup/black tail')]:
  results.append(sim('negative_'+name,'tb_v04_checked',dict(config_params(c),MUTATION=mutation),expected_error=marker))
 results.append(sim('negative_geometry','tb_v04_params',{},expected_error='Invalid cam_fb_pipe configuration'))
 return results

def emit_tcl(cases,path):
 # Uses the already-running Questa session, no second license checkout.
 lines=['onerror {quit -code 1}',f'cd {{{RUN.as_posix()}}}','catch {quit -sim}','vlib work']
 lines += ['vlog '+' '.join('{'+(ROOT/f).as_posix()+'}' for f in SOURCES)]
 lines += ['proc run_case {name top params seed} {',
  ' transcript file ${name}.log',' transcript on',' vsim -onfinish stop -sv_seed $seed {*}$params work.$top',
  ' run -all',' quit -sim',' transcript off',' set f [open ${name}.log r]; set body [read $f]; close $f',' transcript on',
  ' if {[regexp {\\*\\* (Error|Fatal|Warning)\\M|\\mFAIL\\M|(Errors|Warnings):\\s*[1-9]} $body] || [string first "$top PASS" $body]<0} {error "Failed: $name"}',
  ' puts "$name PASS"','}']
 for name,top,p,seed in cases:
  lines.append(f'run_case {name} {top} '+'{'+' '.join(f'-G{k}={v}' for k,v in p.items())+f'}} {seed}')
  if top=='tb_v04_checked':
   prefix=p.get('PREFIX','small')
   lines += [f'set f [open {prefix}_cap_variant.txt r]; set seq [string trim [read $f]]; close $f',
    f'puts [exec {{{sys.executable}}} -B {{{ROOT.as_posix()}/tools/v04_golden.py}} check --w {p.get("W",160)} --h {p.get("H",40)} --out {prefix} --phase {p.get("PHASE",0)} --frame $seq --dual-window {p.get("DUAL_WINDOW",1)}]']
 lines.append('puts "REGRESSION PASS (native entry)"')
 Path(path).write_text('\n'.join(lines)+'\n',encoding='utf-8')

def main():
 global RUN
 parser=argparse.ArgumentParser()
 parser.add_argument('--full',action='store_true');parser.add_argument('--smoke',action='store_true')
 parser.add_argument('--only');parser.add_argument('--run-dir',type=Path);parser.add_argument('--emit-tcl',type=Path)
 parser.add_argument('--soak-frames',type=int,default=0,
  help='additional small-raster RTL endurance; NOT wall-time/hardware soak')
 args=parser.parse_args()
 if args.run_dir:RUN=args.run_dir.resolve()
 RUN.mkdir(parents=True,exist_ok=True)
 results=[];c={}
 try:
  results.append(command([sys.executable,'-B',ROOT/'tools/test_v04_config.py'],'config','config: PASS'))
  c=load_config();cases=plan(c,args.smoke,args.full)
  if args.soak_frames:
   if args.soak_frames<6:raise ValueError('Use at least 6 endurance frames')
   cases.append(('endurance','tb_v04_checked',dict(config_params(c),W=32,H=16,PREFIX='endurance',
    HFP=12,HSP=6,HBP=10,VFP=2,VSP=2,VBP=4,NGOOD=args.soak_frames,MAXFRM=args.soak_frames+100),211))
  if args.only:
   cases=[v for v in cases if re.fullmatch(args.only,v[0])]
   if not cases:raise ValueError('No matching test case')
  (RUN/'config.json').write_text(json.dumps(c,indent=2)+'\n')
  (RUN/'source_sha256.json').write_text(json.dumps({f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in SOURCES+['rtl/ArtFlow_top.v']},indent=2)+'\n')
  generate(cases)
  if args.emit_tcl:
   emit_tcl(cases,args.emit_tcl);print('Native plan prepared');return 0
  if not (RUN/'work').exists():command(['vlib','work'],'vlib')
  command(['vlog',*[ROOT/f for f in SOURCES]],'compile')
  for name,top,p,seed in cases:
   results.append(dict(sim(name,top,p,seed),seed=seed,parameters=p))
   if top=='tb_v04_checked':results.append(check(name,p))
  if not args.smoke and not args.only:results.extend(negative_tests(c))
  status='PASS'
 except Exception as e:
  results.append(dict(name=str(e),status='FAIL'));status='FAIL'
 (RUN/'summary.json').write_text(json.dumps(dict(status=status,config=c,tests=results),indent=2)+'\n',encoding='utf-8')
 print('REGRESSION '+status,flush=True)
 return status!='PASS'
if __name__=='__main__':sys.exit(main())
