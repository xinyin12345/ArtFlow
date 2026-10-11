"""Independent integer rounding/saturation stress test for all four lanes."""
from pathlib import Path
import tempfile,subprocess,json,time,shutil
import numpy as np
R=Path(__file__).resolve().parent;stage=Path(tempfile.mkdtemp(prefix='s8_quant_unit_'))
rng=np.random.RandomState(123);rows=[];gold=[]
def rounded(z,mode):
    floor=z//2**32;frac=z%2**32
    inc=(frac>2**31 or (frac==2**31 and floor%2)) if mode==2 else frac>=2**31
    lo,hi=(-128,127) if mode==1 else (0,255 if mode==2 else 15)
    return max(lo,min(hi,floor+int(inc)))&255
for i in range(12000):
    mode=i%3;ms=int(rng.randint(1,2**35,dtype=np.int64)) if mode==1 else 0
    word=mode;expected=0
    for j in range(4):
        ac=int(rng.randint(-2**19,2**19));m=int(rng.randint(1,2**35,dtype=np.int64));sk=int(rng.randint(-128,128))
        # Deliberately include negative/positive exact halves and near-zero outputs.
        if i%4==0:ac=(i//4)%1024-512;m=2**31;sk=0;ms=0
        word|=(ac&0xfffff)<<(2+j*20)
        word|=m<<(82+j*36)
        word|=(sk&511)<<(226+j*9)
        expected|=rounded(ac*m+sk*ms,mode)<<(j*8)
    word|=ms<<262;rows.append(word);gold.append(expected)
(stage/'vectors.mem').write_text(''.join('%075x\n'%v for v in rows),encoding='ascii')
(stage/'gold.mem').write_text(''.join('%08x\n'%v for v in gold),encoding='ascii')
tb='''`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;reg rst=1,vin=0;reg [297:0] x=0;wire valid;wire [31:0] y;
shared_quant dut(clk,rst,vin,x[1:0],x[81:2],x[297:262],x[261:226],x[225:82],valid,y);
reg [297:0] vectors[0:11999];reg [31:0] gold[0:11999];integer i,got=0;
initial begin $readmemh("vectors.mem",vectors);$readmemh("gold.mem",gold);
repeat(4)@(negedge clk);rst=0;
for(i=0;i<12000;i=i+1)begin @(negedge clk);vin=1;x=vectors[i];
if(i%7==0)begin @(negedge clk);vin=0;end end
@(negedge clk);vin=0;repeat(8)@(negedge clk);
if(got!=12000)$fatal(1,"wrong count");$display("PASS quant vectors=12000 lane_results=48000");$finish;end
always @(posedge clk)if(!rst && valid)begin
if(y!==gold[got])begin $display("FAIL idx=%0d got=%h expected=%h",got,y,gold[got]);$fatal(1,"quant mismatch");end
got=got+1;end
endmodule
'''
(stage/'tb.v').write_text(tb,encoding='ascii');shutil.copy2(str(R/'rtl/shared_quant.v'),str(stage/'shared_quant.v'))
from sim_tools import iverilog_bin
tools=iverilog_bin(R)
subprocess.check_call([str(tools/'iverilog.exe'),'-g2005-sv','-s','tb','-o','test.vvp','tb.v','shared_quant.v'],cwd=str(stage))
O=R/'reports/quant_unit';O.mkdir(exist_ok=True)
t=time.time()
with (O/'simulation.log').open('w') as f:p=subprocess.run([str(tools/'vvp.exe'),'test.vvp'],cwd=str(stage),stdout=f,stderr=subprocess.STDOUT)
(O/'result.json').write_text(json.dumps(dict(returncode=p.returncode,seconds=time.time()-t,stage=str(stage),vectors=12000,lane_results=48000),indent=2))
print((O/'simulation.log').read_text());assert p.returncode==0
