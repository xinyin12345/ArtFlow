`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0;wire busy,done,mv,mw;wire [23:0] ma;wire [63:0] wd;wire [7:0] ws;
reg ready=0,rv=0;reg [63:0] rd=0;wire ld;wire [4:0] layer;wire [31:0] fc;
s8_shared #(.EXT_W(480),.EXT_H(270)) dut(clk,rst,start,busy,done,mv,mw,ma,wd,ws,ready,rv,rd,ld,layer,fc);
reg [63:0] memory[0:786431];reg [63:0] golden[0:572280-1];
reg [23:0] expected_address[0:572280-1];
reg held=0;reg [23:0] held_addr;reg [63:0] held_data;reg held_write;
integer waitread=0;reg [23:0] pending;integer writes=0,reads=0,cycles=0,frames=0;
reg [31:0] rng=32'h12345678;
initial begin
$readmemh("input.mem",memory,0,129600-1);
$readmemh("addresses.mem",expected_address);

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
if(held && (!mv || ma!==held_addr || mw!==held_write || (mw&&wd!==held_data)))
 $fatal(1,"command changed under backpressure");
held=mv&&!ready;held_addr=ma;held_data=wd;held_write=mw;
if(mv&&ready)begin
 if(ma[2:0]!=0)$fatal(1,"unaligned address %h",ma);
 if(mw)begin
 if(writes>=572280 || ma!==expected_address[writes])$fatal(1,"write address mismatch at %0d: %h",writes,ma);
 
 memory[ma>>3]=wd;writes=writes+1;
 end else begin pending=ma;waitread=3;reads=reads+1;end
end
if(ld)begin $display("LAYER index_next=%0d cycles=%0d writes=%0d reads=%0d",layer,fc,writes,reads);$fflush();end
if(done)begin
 if(writes!=572280)$fatal(1,"wrong writes %0d expected %0d",writes,572280);
 $display("PASS frame=%0d cycles=%0d reads=%0d writes=%0d",frames,fc,reads,writes);
 frames=frames+1;
 if(frames==1)$finish;
 writes=0;reads=0;
 $readmemh("input.mem",memory,0,129600-1);
 start<=1;
end else if(start)start<=0;
if(cycles>100000000)$fatal(1,"timeout state=%0d layer=%0d",dut.state,layer);
end
endmodule
