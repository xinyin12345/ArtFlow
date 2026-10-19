# -*- coding: utf-8 -*-
"""Self-check every external feature write against the frozen NumPy integer graph."""
from pathlib import Path
import sys,json,subprocess,time,argparse,tempfile,shutil
import numpy as np
R=Path(__file__).resolve().parent
reference=R/'reference' if (R/'reference').exists() else R.parent/'style_s8_integer'
sys.path.insert(0,str(reference))
from golden import forward,pack
a=argparse.ArgumentParser();a.add_argument('--width',type=int,default=16);a.add_argument('--height',type=int,default=14)
a.add_argument('--latency',type=int,default=1);a.add_argument('--stall',type=int,default=0);a.add_argument('--frames',type=int,default=1)
a.add_argument('--mode',choices=['random','black','white','checker','gradient','impulse'],default='random');a.add_argument('--image');a.add_argument('--prepare-only',action='store_true');args=a.parse_args()
args.count_only=False
assert args.width%8==0 and args.width>=16 and args.height>=14
O=R/'reports'/('sim_%dx%d_L%d_S%d_%s%s'%(args.width,args.height,args.latency,args.stall,args.mode,'_count' if args.count_only else ''))
if args.image:O=O.with_name(O.name+'_'+Path(args.image).stem)
O.mkdir(parents=True,exist_ok=True)
rgbs=[]
for frame in range(args.frames):
    rgb=np.random.RandomState(101+frame).randint(0,256,(1,3,args.height,args.width)).astype(np.uint8)
    if args.mode in ('black','white'):rgb.fill(255 if args.mode=='white' else 0)
    elif args.mode=='checker':rgb[:]=((np.indices((args.height,args.width)).sum(0)%2)*255)[None,None]
    elif args.mode=='gradient':rgb[:]=np.arange(args.width,dtype=np.int64)[None,None,None,:]*255//(args.width-1)
    elif args.mode=='impulse':rgb.fill(0);rgb[:,:,args.height//2,args.width//2]=255
    if args.image:
        from PIL import Image
        rgb=np.asarray(Image.open(args.image).convert('RGB').resize((args.width,args.height)))[None].transpose(0,3,1,2)
    rgbs.append(rgb)
rgb=rgbs[0];hp=(args.height+3)//4*4
def savehex(name,words):
    (O/name).write_text(''.join('%016x\n'%v for v in words),encoding='ascii')
savehex('input.mem',[v for rgb in rgbs for v in pack(rgb)])
conf=json.loads((R/'architecture.json').read_text())['layers']
expected=[];counts=[]
for frame,rgb in enumerate(rgbs):
    output,trace=forward(rgb)
    frame_counts=[]
    for c in conf:
        x=trace[c['name']]
        if c['mode']==2:x=x[:,:,:args.height,:]
        words=pack(x,c['mode']==3);expected+=words;frame_counts.append(len(words))
    if frame==0:counts=frame_counts
    else:assert counts==frame_counts
savehex('expected.mem',expected)
if args.image:
    from PIL import Image
    Image.fromarray(output[0].transpose(1,2,0)).save(O/'integer_output.png')
gold=max(1,sum(counts));inputlen=len(pack(rgb))
addresses=[]
for c,n in zip(conf,counts):
    addresses += [(int(c['dst'])<<21)+8*i for i in range(n)]
(O/'addresses.mem').write_text(''.join('%06x\n'%v for v in addresses),encoding='ascii')
stage_root=R.parent.parent/'xfeat/.fpga_u8_stages';stage_root.mkdir(parents=True,exist_ok=True)
stage=Path(tempfile.mkdtemp(prefix='u8_sim_',dir=str(stage_root)))
for folder in ['rtl','mem']:shutil.copytree(str(R/folder),str(stage/folder))

for name in ['input.mem','expected.mem','addresses.mem']:
    if (O/name).exists():shutil.copy2(str(O/name),str(stage/name))
tb='''`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0;wire busy,done,mv,mw;wire [23:0] ma;wire [63:0] wd;wire [7:0] ws;
reg ready=0,rv=0;reg [63:0] rd=0;wire ld;wire [4:0] layer;wire [31:0] fc;
student_u8 #(.EXT_W(WIDTH),.EXT_H(HEIGHT)) dut(clk,rst,start,busy,done,mv,mw,ma,wd,ws,ready,rv,rd,ld,layer,fc);
reg [63:0] memory[0:786431];reg [63:0] golden[0:GOLD*FRAMES-1];reg [63:0] inputs[0:INPUTLEN*FRAMES-1];integer ii;
reg [23:0] expected_address[0:GOLD-1];
reg held=0;reg [23:0] held_addr;reg [63:0] held_data;reg held_write;
integer waitread=0;reg [23:0] pending;integer writes=0,reads=0,cycles=0,frames=0;
reg [31:0] rng=32'h12345678;
initial begin
$readmemh("INPUT",inputs);
for(ii=0;ii<INPUTLEN;ii=ii+1)memory[ii]=inputs[ii];
$readmemh("addresses.mem",expected_address);
GOLDLOAD
repeat(5)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;
end
always @(negedge clk)begin
rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
ready= !rst && waitread==0 && (STALL==0 || rng[2:0]!=0);
rv=0;
if(waitread>0)begin
 waitread=waitread-1;
 if(waitread==0)begin rv=1;rd=memory[pending>>3];end
end
end
always @(posedge clk)if(!rst)begin
cycles=cycles+1;
if(held && (!mv || ma!==held_addr || mw!==held_write || (mw&&wd!==held_data)))
 $fatal(1,"command changed under backpressure");
held=mv&&!ready;held_addr=ma;held_data=wd;held_write=mw;
if(mv&&ready)begin
 if(ws!==8'hff)$fatal(1,"byte enable");
 if(ma[2:0]!=0)$fatal(1,"unaligned address %h",ma);
 if(mw)begin
 if(writes>=GOLD || ma!==expected_address[writes])$fatal(1,"write address mismatch at %0d: %h",writes,ma);
 CHECK
 memory[ma>>3]=wd;writes=writes+1;
 end else begin pending=ma;waitread=LATENCY;reads=reads+1;end
end
if(ld)begin $display("LAYER index_next=%0d cycles=%0d writes=%0d reads=%0d",layer,fc,writes,reads);$fflush();end
if(done)begin
 if(writes!=GOLD)$fatal(1,"wrong writes %0d expected %0d",writes,GOLD);
 $display("PASS frame=%0d cycles=%0d reads=%0d writes=%0d",frames,fc,reads,writes);
 frames=frames+1;
 if(frames==FRAMES)$finish;
 writes=0;reads=0;
 for(ii=0;ii<INPUTLEN;ii=ii+1)memory[ii]=inputs[frames*INPUTLEN+ii];
 start<=1;
end else if(start)start<=0;
if(cycles>100000000)$fatal(1,"timeout state=%0d layer=%0d",dut.state,layer);
end
endmodule
'''
replace=dict(WIDTH=args.width,HEIGHT=args.height,GOLD=gold,INPUTLEN=inputlen,LATENCY=args.latency,STALL=args.stall,FRAMES=args.frames,
INPUT='input.mem',
GOLDLOAD='' if args.count_only else '$readmemh("expected.mem",golden);',
CHECK='' if args.count_only else 'if(writes>=GOLD || wd!==golden[frames*GOLD+writes])begin $display("FAIL layer=%0d x=%0d y=%0d og=%0d write=%0d got=%h expected=%h",layer,dut.ox,dut.oy,dut.og,writes,wd,golden[frames*GOLD+writes]);$fatal(1,"integer mismatch");end')
import re
tb=re.sub(r'\b('+'|'.join(replace)+r')\b',lambda m:str(replace[m.group(0)]),tb)
tb=tb.replace('GOLD',str(gold))
(O/'tb.v').write_text(tb,encoding='ascii');(stage/'tb.v').write_text(tb,encoding='ascii')
if args.prepare_only:
    (O/'prepared.json').write_text(json.dumps(dict(stage=str(stage),gold=gold,inputlen=inputlen,counts=counts,args=vars(args)),indent=2),encoding='utf8')
    print('PREPARED',stage,flush=True);sys.exit(0)
from sim_tools import iverilog_bin
tools=iverilog_bin(R)
sources=[str(p.relative_to(stage)) for p in (stage/'rtl').glob('*.v')]
cmd=[str(tools/'iverilog.exe'),'-g2005-sv','-I','rtl','-s','tb','-o','test.vvp','tb.v']+sources
subprocess.check_call(cmd,cwd=str(stage))
t=time.time()
with (O/'simulation.log').open('w') as f:run=subprocess.run([str(tools/'vvp.exe'),'test.vvp'],cwd=str(stage),stdout=f,stderr=subprocess.STDOUT)
import hashlib
manifest={str(p.relative_to(stage)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (stage/'rtl').glob('*') if p.is_file()}
result=dict(returncode=run.returncode,seconds=time.time()-t,args=vars(args),counts=counts,checked_integer=not args.count_only,stage=str(stage),rtl_sha256=manifest)
(O/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print((O/'simulation.log').read_text(),flush=True)
print(json.dumps(result),flush=True)
sys.exit(run.returncode)
