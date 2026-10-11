`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0;wire busy,done,mv,mw;wire [23:0] ma;wire [63:0] wd;wire [7:0] ws;
reg ready=0,rv=0;reg [63:0] rd=0;wire ld;wire [4:0] layer;wire [31:0] fc;
s8_shared #(.EXT_W(16),.EXT_H(14)) dut(clk,rst,start,busy,done,mv,mw,ma,wd,ws,ready,rv,rd,ld,layer,fc);
reg [63:0] memory[0:786431];reg [63:0] golden[0:1092-1];
integer waitread=0;reg [23:0] pending;integer writes=0,reads=0,cycles=0,frames=0;
reg [31:0] rng=32'h12345678;
initial begin
$readmemh("input.mem",memory,0,224-1);
$readmemh("expected.mem",golden);
repeat(5)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;
end
always @(negedge clk)begin
rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
ready= !rst && waitread==0 && (1==0 || rng[2:0]!=0);
rv=0;
if(waitread>0)begin
 waitread=waitread-1;
 if(waitread==0)begin rv=1;rd=memory[pending>>3];end
end
end
always @(posedge clk)if(!rst)begin
cycles=cycles+1;
if(mv&&ready)begin
 if(ma[2:0]!=0)$fatal(1,"unaligned address %h",ma);
 if(mw)begin
 if(writes>=1092 || wd!==golden[writes])begin $display("FAIL layer=%0d x=%0d y=%0d og=%0d write=%0d got=%h expected=%h",layer,dut.ox,dut.oy,dut.og,writes,wd,golden[writes]);$fatal(1,"integer mismatch");end
 memory[ma>>3]=wd;writes=writes+1;
 end else begin pending=ma;waitread=3;reads=reads+1;end
end
if(ld)$display("LAYER index_next=%0d cycles=%0d writes=%0d reads=%0d",layer,fc,writes,reads);
if(done)begin
 if(writes!=1092)$fatal(1,"wrong writes %0d expected %0d",writes,1092);
 $display("PASS frame=%0d cycles=%0d reads=%0d writes=%0d",frames,fc,reads,writes);
 frames=frames+1;
 if(frames==2)$finish;
 writes=0;reads=0;
 $readmemh("input.mem",memory,0,224-1);
 start<=1;
end else if(start)start<=0;
if(cycles>100000000)$fatal(1,"timeout state=%0d layer=%0d",dut.state,layer);
end
endmodule
