`timescale 1ns/1ps
module tb_glass_core;
parameter W=32,H=30,N=1,FRAMES=2,STALL_PCT=25;
reg clk=0;always #3.5 clk=~clk;
reg rst=1,start=0;wire busy,done,mv,mw;wire [23:0] ma;wire [63:0] wd;
reg ready=0,rv=0;reg [63:0] rd;wire ld;wire [4:0] li;wire [31:0] cycles;
glass_int8 #(.EXT_W(W),.EXT_H(H)) dut(clk,rst,start,busy,done,mv,mw,ma,wd,,ready,rv,rd,ld,li,cycles);
reg [63:0] mem[0:786431],input_words[0:W*H-1],expected[0:N-1];
reg [23:0] addresses[0:N-1];string folder;integer writes=0,delay_count=0,frame,fd;
reg pending=0;reg [23:0] pending_addr;reg [31:0] rng=32'h12671;
always @(posedge clk) begin
 rng<={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
 ready<=!pending && (rng%100>=STALL_PCT);rv<=0;
 if(pending)begin
 if(delay_count==0)begin rv<=1;rd<=mem[pending_addr>>3];pending<=0;end else delay_count<=delay_count-1;
 end
 if(!rst&&mv&&ready)begin
 if(mw)begin
 if(writes>=N || ma!==addresses[writes] || wd!==expected[writes])
 $fatal(1,"feature mismatch layer=%0d word=%0d address=%h expected_addr=%h got=%h want=%h",li,writes,ma,addresses[writes],wd,expected[writes]);
 mem[ma>>3]<=wd;writes=writes+1;
 end else begin
 if(pending)$fatal(1,"multiple reads");
 pending<=1;pending_addr<=ma;delay_count<=rng%7;
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


