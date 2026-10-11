"""Post-map functional check: real 480x270 netlist, first encoder output row.
Original Efinix simulation models, Verilog-2005; no SDF timing simulation.
"""
from pathlib import Path
import json,tempfile,shutil,subprocess,time,re
R=Path(__file__).resolve().parent
rep=R/'reports/pnr_20261010_202809'
stage=Path(tempfile.mkdtemp(prefix='s8_480_gate_'))
src=R/'reports/sim_480x270_L3_S1_random'
shutil.copy2(str(src/'input.mem'),str(stage/'input.mem'))
(stage/'expected.mem').write_text('\n'.join((src/'expected.mem').read_text().splitlines()[:240])+'\n',encoding='ascii')
shutil.copy2(str(rep/'outflow/s8_shared.map.core.v'),str(stage/'core.v'))
modeldir=Path('C:/Efinity/2026.1/sim_models/verilog')
models=['efx_add','efx_ff','efx_lut4','efx_gbufce','efx_ram10','efx_dsp48','efx_dsp24','efx_dsp12']
for m in models:shutil.copy2(str(modeldir/(m+'.v')),str(stage/(m+'.v')))
tb=r'''`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;reg rst=1,start=0;
wire busy,done,mv,mw;wire [23:0] ma;wire [63:0] wd;wire [7:0] ws;
reg ready=0,rv=0;reg [63:0] rd=0;wire ld;wire [4:0] layer;wire [31:0] fc;
\s8_shared~core  dut(clk,rst,start,busy,done,mv,mw,ma,wd,ws,ready,rv,rd,ld,layer,fc);
reg [63:0] memory[0:786431];reg [63:0] expected[0:239];
integer writes=0,waitread=0,cycles=0;reg [23:0] pending;
initial begin $readmemh("input.mem",memory,0,129599);$readmemh("expected.mem",expected);
repeat(5)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;end
always @(negedge clk)begin ready=!rst&&waitread==0;rv=0;
if(waitread>0)begin waitread=waitread-1;if(waitread==0)begin rv=1;rd=memory[pending>>3];end end end
always @(posedge clk)if(!rst)begin cycles=cycles+1;
if(mv&&ready)begin
if(mw)begin
if(wd!==expected[writes])begin $display("FAIL first row pixel=%0d got=%h expected=%h",writes,wd,expected[writes]);$finish_and_return(1);end
writes=writes+1;
if(writes==240)begin $display("PASS post-map first encoder row pixels=240 cycles=%0d",fc);$finish;end
end else begin pending=ma;waitread=3;end end
if(cycles>20000)begin $display("FAIL timeout writes=%0d",writes);$finish_and_return(1);end
end
endmodule
'''
(stage/'tb.v').write_text(tb,encoding='ascii')
from sim_tools import iverilog_bin
tools=iverilog_bin(R)
subprocess.check_call([str(tools/'iverilog.exe'),'-g2005','-s','tb','-o','gate.vvp','tb.v','core.v']+[m+'.v' for m in models],cwd=str(stage))
O=R/'reports/gate_prefix';O.mkdir(exist_ok=True)
print('GATE_STAGE',stage,flush=True);t=time.time()
with (O/'simulation.log').open('w') as f:
    try:p=subprocess.run([str(tools/'vvp.exe'),'gate.vvp'],cwd=str(stage),stdout=f,stderr=subprocess.STDOUT,timeout=600);rc=p.returncode
    except subprocess.TimeoutExpired:rc=124
result=dict(returncode=rc,seconds=time.time()-t,stage=str(stage),scope='Post-map functional, 480x270 netlist, first encoder row 240 pixels only; unmodified vendor models, no SDF')
(O/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print((O/'simulation.log').read_text(),flush=True);assert rc==0
