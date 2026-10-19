# -*- coding: utf-8 -*-
"""Independent reflection-tap oracle and signed shared-product regression."""
from pathlib import Path
import sys,os,json,tempfile,subprocess,hashlib,time
import numpy as np
from sim_tools import iverilog_bin
R=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'reference'))
from integer_model import tap_sums
rng=np.random.RandomState(213033)
maps=[rng.randint(0,256,(1,16,5,6)),rng.randint(-128,128,(1,16,5,6)),
      np.full((1,16,5,6),255),np.full((1,16,5,6),-128),np.zeros((1,16,5,6),np.int64)]
maps[-1][:,:,0,0]=255;maps[-1][:,:,-1,-1]=127
signed=[0,1,0,1,0];words=[];gold=[]
for x in maps:
    for y in range(5):
        for xx in range(6):
            for group in range(2):words.append(sum((int(x[0,group*8+c,y,xx])&255)<<(8*c) for c in range(8)))
    gold.extend(tap_sums(x).reshape(-1).tolist())
products=[]
for i in range(516):
    v=int(rng.randint(-2080801,2080801));w=int(rng.randint(-128,128))
    if i<4:v=[-2080800,-2080800,2080800,2080800][i];w=[-128,127,-128,127][i]
    products.append((v&((1<<40)-1))|((w&((1<<21)-1))<<40)|((v*w&((1<<48)-1))<<61))
root=R.parent.parent/'xfeat/.fpga_u8_stages';stage=Path(tempfile.mkdtemp(prefix='u8_stats_test_',dir=root))
rep=R/'reports'/('statistics_'+time.strftime('%Y%m%d_%H%M%S'));rep.mkdir()
for name,values,digits in [('inputs.mem',words,16),('expected.mem',gold,6),('products.mem',products,28)]:
    mask=(1<<(digits*4))-1
    (stage/name).write_text(''.join(('%0*x\n'%(digits,int(v)&mask)) for v in values),encoding='ascii')
tb=r'''`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg clear=1,capture=0,sg=0,group_hi=0;reg[9:0]x=0,y=0;reg[63:0]codes=0;
reg[3:0]rc=0,rt=0;wire signed[23:0]value;
source_stats #(.W(6),.H(5)) s(clk,clear,capture,sg,group_hi,x,y,codes,rc,rt,value);
reg rst=1,start=0;reg signed[39:0]pv;reg signed[20:0]pw;wire done;wire signed[47:0]product;
center_div d(clk,rst,start,1'b1,pv,pw,32'sd0,20'd8160,done,product);
reg[63:0]inputs[0:299];reg[23:0]expected[0:719];reg[108:0]products[0:515];
integer m,i,yy,xx,g,c,t;
initial begin
$readmemh("inputs.mem",inputs);$readmemh("expected.mem",expected);$readmemh("products.mem",products);
repeat(5)@(negedge clk);rst=0;
for(m=0;m<5;m=m+1)begin
clear=1;capture=0;@(negedge clk);clear=0;sg=m==1||m==3;
for(yy=0;yy<5;yy=yy+1)for(xx=0;xx<6;xx=xx+1)for(g=0;g<2;g=g+1)begin
x=xx;y=yy;group_hi=g;codes=inputs[m*60+(yy*6+xx)*2+g];capture=1;@(negedge clk);
end
capture=0;
for(c=0;c<16;c=c+1)for(t=0;t<9;t=t+1)begin
rc=c;rt=t;#1;
if(value!==expected[m*144+c*9+t])$fatal(1,"stats m=%0d c=%0d t=%0d got=%0d exp=%0d",m,c,t,$signed(value),$signed(expected[m*144+c*9+t]));
end
@(negedge clk);
end
for(i=0;i<516;i=i+1)begin
pv=products[i][39:0];pw=products[i][60:40];start=1;@(negedge clk);start=0;
wait(done);@(negedge clk);
if(product!==products[i][108:61])$fatal(1,"projection %0d",i);
end
$display("PASS reflection_maps=5 tap_checks=720 shared_signed_products=516");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
'''
(stage/'tb.v').write_text(tb,encoding='ascii')
tools=iverilog_bin(R);env=os.environ.copy();env['TEMP']=env['TMP']=str(stage)
subprocess.check_call([str(tools/'iverilog.exe'),'-g2005-sv','-s','tb','-o','test.vvp','tb.v',str(R/'rtl/source_stats.v'),str(R/'rtl/center_div.v')],cwd=stage,env=env)
run=subprocess.run([str(tools/'vvp.exe'),'test.vvp'],cwd=stage,env=env,capture_output=True,text=True)
(rep/'simulation.log').write_text(run.stdout+run.stderr,encoding='utf8')
(rep/'result.json').write_text(json.dumps(dict(returncode=run.returncode,reflection_maps=5,tap_checks=720,shared_signed_products=516,
    stage=str(stage),rtl_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [R/'rtl/source_stats.v',R/'rtl/center_div.v']}),indent=2),encoding='utf8')
print(run.stdout,flush=True);raise SystemExit(run.returncode)
