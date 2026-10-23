`timescale 1ns/1ps
module tb_glass_core;
parameter W=32,H=30,N=1,FRAMES=2,STALL_PCT=25;
reg clk=0;always #3.5 clk=~clk;
reg rst=1,start=0;wire busy,done,mv,mw;wire [23:0] ma;wire [63:0] wd;
reg ready=0,rv=0;reg [63:0] rd;wire ld;wire [4:0] li;wire [31:0] cycles;
glass_int8 #(.EXT_W(W),.EXT_H(H)) dut(clk,rst,start,busy,done,1'b0,1'b0,1'b0,2'b0,10'b0,576'b0,mv,mw,ma,wd,,ready,rv,rd,ld,li,cycles);
reg [63:0] mem[0:786431],input_words[0:W*H-1],expected[0:N-1];
reg [23:0] addresses[0:N-1];string folder;integer writes=0,delay_count=0,frame,fd;
// Ordered variable-latency memory supporting the four allowed outstanding reads.
reg [23:0] queue_addr[0:15];integer queue_due[0:15];
integer sent_reads=0,returned_reads=0,clock_count=0;
reg [31:0] rng=32'h12671;
always @(posedge clk) begin
 clock_count<=clock_count+1;
 rng<={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
 ready<=sent_reads-returned_reads<3 && (rng%100>=STALL_PCT);rv<=0;
 if(sent_reads!=returned_reads && clock_count>=queue_due[returned_reads%16])begin
  rv<=1;rd<=mem[queue_addr[returned_reads%16]>>3];returned_reads<=returned_reads+1;
 end
 if(!rst&&mv&&ready)begin
 if(mw)begin
 if(writes>=N || ma!==addresses[writes] || wd!==expected[writes])
 $fatal(1,"feature mismatch layer=%0d word=%0d address=%h expected_addr=%h got=%h want=%h",li,writes,ma,addresses[writes],wd,expected[writes]);
 mem[ma>>3]<=wd;writes=writes+1;
 end else begin
 if(sent_reads-returned_reads>=4)$fatal(1,"too many reads");
 queue_addr[sent_reads%16]<=ma;queue_due[sent_reads%16]<=clock_count+1+rng%7;sent_reads<=sent_reads+1;
 end end
 if(ld)begin $display("LAYER next=%0d cycles=%0d writes=%0d",li,cycles,writes);$fflush();end
end
initial begin
 if(!$value$plusargs("DIR=%s",folder))$fatal(1,"missing DIR");
 $readmemh({folder,"/input.hex"},input_words);$readmemh({folder,"/features.hex"},expected);$readmemh({folder,"/addresses.hex"},addresses);
 repeat(8)@(negedge clk);rst=0;
 for(frame=0;frame<FRAMES;frame=frame+1)begin
 for(integer i=0;i<W*H;i=i+1)mem[i]=input_words[i];
 writes=0;@(negedge clk);start=1;@(negedge clk);start=0;wait(done);@(negedge clk);
 if(writes!=N)$fatal(1,"wrong write count");
 $display("FRAME PASS frame=%0d pixels=%0d features=%0d cycles=%0d",frame,W*H,writes,cycles);
 end
 fd=$fopen({folder,"/rtl_output.hex"},"w");
 for(integer i=0;i<W*H;i=i+1)$fdisplay(fd,"%016h",mem[i]);
 $fclose(fd);$display("tb_glass_core PASS");$finish;
end
initial begin #2000000000;$fatal(1,"timeout state=%0d layer=%0d",dut.state,li);end
endmodule


