# -*- coding: utf-8 -*-
"""Regression for signed means (non-power-of-two N) and all R24 output modes."""
from pathlib import Path
import random,subprocess,json,time,tempfile,hashlib,os
from sim_tools import iverilog_bin
R=Path(__file__).resolve().parent
root=R.parent.parent/'xfeat/.fpga_u8_stages';root.mkdir(parents=True,exist_ok=True)
stage=Path(tempfile.mkdtemp(prefix='u8_units_',dir=root))
rep=R/'reports'/('units_'+time.strftime('%Y%m%d_%H%M%S'));rep.mkdir()
r=random.Random(20261013);dv=[];qv=[]
def mask(x,n):return int(x)&((1<<n)-1)
for n in (16,24,30,8160):
    for s in (-n*630000,-n//2,-1,0,1,n//2,n*630000):
        for m in (1,638400):
            b=123456789;v=s*m;rounded=v//n+(2*(v%n)>=n)
            dv.append(mask(s,40)|(m<<40)|(mask(b,32)<<61)|(n<<93)|(mask(b-rounded,48)<<113))
for i in range(1000):
    n=r.choice([16,24,30,8160]);s=r.randrange(-630000*n,630000*n);m=r.randrange(1,638401);b=r.randrange(-2**30,2**30)
    v=s*m;rounded=v//n+(2*(v%n)>=n)
    dv.append(mask(s,40)|(m<<40)|(mask(b,32)<<61)|(n<<93)|(mask(b-rounded,48)<<113))
for mode in range(4):
    for i in range(600):
        # First cases exercise both signs of ties and clipping endpoints.
        if i<20:
            a=0;m=1;sk=0;sm=0;db=(i-10)*2**24+2**23
        else:
            a=r.randrange(-2540962,2540963);m=r.randrange(1,638401)
            sk=r.randrange(-128,256);sm=r.randrange(0,11944936);db=r.randrange(-2**36,2**36)
        z=a*m+sk*sm+db;v=z//2**24;rem=z%2**24
        v+=int(rem>2**23 or (rem==2**23 and (mode!=2 or v%2!=0)))
        lo,hi=((-2048,2047) if mode==3 else (-128,127) if mode==1 else (0,255))
        q=max(lo,min(hi,v));q=mask(q,16) if mode==3 else mask(q,8)
        qv.append(mask(a,24)|(m<<24)|(mask(sk,9)<<45)|(sm<<54)|(mask(db,48)<<79)|(mode<<127)|(q<<129))
(stage/'divider.mem').write_text(''.join('%041x\n'%v for v in dv),encoding='ascii')
(stage/'quant.mem').write_text(''.join('%037x\n'%v for v in qv),encoding='ascii')
tb=r'''`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0,qvalid=0;wire dd,qd;wire signed[47:0]db;wire[63:0]qc;
reg [160:0] ds[0:DN-1];reg [144:0] qs[0:QN-1];integer i;
reg signed [39:0] sm;reg [20:0] mul;reg signed [31:0] beta;reg [19:0] area;
reg [23:0] acc;reg [20:0] qm;reg [8:0] skip;reg [24:0] skipm;reg[47:0] dyn;reg[1:0] mode;
center_div d(clk,rst,start,1'b0,sm,mul,beta,area,dd,db);
shared_quant q(clk,rst,qvalid,mode,{4{acc}},skipm,{4{skip}},{4{qm}},{4{dyn}},qd,qc);
initial begin
$readmemh("divider.mem",ds);$readmemh("quant.mem",qs);
repeat(5)@(negedge clk);rst=0;
for(i=0;i<DN;i=i+1)begin
sm=ds[i][39:0];mul=ds[i][60:40];beta=ds[i][92:61];area=ds[i][112:93];start=1;
@(negedge clk);start=0;wait(dd);@(negedge clk);
if(db!==ds[i][160:113])$fatal(1,"divider %0d got=%0d expected=%0d",i,$signed(db),$signed(ds[i][160:113]));
end
for(i=0;i<QN;i=i+1)begin
acc=qs[i][23:0];qm=qs[i][44:24];skip=qs[i][53:45];skipm=qs[i][78:54];dyn=qs[i][126:79];mode=qs[i][128:127];qvalid=1;
@(negedge clk);qvalid=0;wait(qd);@(negedge clk);
if(qc!=={4{qs[i][144:129]}})$fatal(1,"quant %0d got=%h expected=%h",i,qc,{4{qs[i][144:129]}});
end
$display("PASS divider=DN quant_vectors=QN quant_lanes=4");$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
'''.replace('DN',str(len(dv))).replace('QN',str(len(qv)))
(stage/'tb.v').write_text(tb,encoding='ascii')
tools=iverilog_bin(R);env=os.environ.copy();env['TEMP']=str(stage);env['TMP']=str(stage)
cmd=[str(tools/'iverilog.exe'),'-g2005-sv','-s','tb','-o','test.vvp','tb.v',str(R/'rtl/center_div.v'),str(R/'rtl/shared_quant.v')]
subprocess.check_call(cmd,cwd=stage,env=env)
run=subprocess.run([str(tools/'vvp.exe'),'test.vvp'],cwd=stage,env=env,capture_output=True,text=True)
(rep/'simulation.log').write_text(run.stdout+run.stderr,encoding='utf8')
(rep/'result.json').write_text(json.dumps(dict(returncode=run.returncode,divider_vectors=len(dv),quant_vectors=len(qv),quant_lane_checks=len(qv)*4,
    stage=str(stage),rtl_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [R/'rtl/center_div.v',R/'rtl/shared_quant.v']}),indent=2),encoding='utf8')
print(run.stdout,flush=True);raise SystemExit(run.returncode)
