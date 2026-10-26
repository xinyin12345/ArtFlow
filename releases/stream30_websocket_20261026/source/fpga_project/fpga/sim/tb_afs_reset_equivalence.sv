`timescale 1ns/1ps
module tb_reset_equivalence;
reg clk=0;always #5 clk=~clk;
reg rst=0,start=0,ready=1,miso=0;reg[7:0]status[0:1055];
wire [1:0] cs,sclk,mosi,busy,done,failed,take,sv,se;
wire[7:0] fps[2];wire[31:0]session[2];integer bits=0,good=0,k,delay_cycles;string vector_dir;
afs_spi_packet_ref refdut(.clk(clk),.rst_n(rst),.start(start),.fast(1'b1),.ready_async(ready),.miso(miso),.kind(8'd2),.session(32'h12345678),.sequence_id(32'd7),.offset(32'd0),.frame_crc(32'd0),.length(16'd1024),.payload_byte(8'h5a),.payload_take(take[0]),.busy(busy[0]),.done(done[0]),.failed(failed[0]),.cs_n(cs[0]),.sclk(sclk[0]),.mosi(mosi[0]),.status_valid(sv[0]),.status_enable(se[0]),.status_fps(fps[0]),.status_session(session[0]));
afs_spi_packet newdut(.clk(clk),.rst_n(rst),.start(start),.fast(1'b1),.ready_async(ready),.miso(miso),.kind(8'd2),.session(32'h12345678),.sequence_id(32'd7),.offset(32'd0),.frame_crc(32'd0),.length(16'd1024),.payload_byte(8'h5a),.payload_take(take[1]),.busy(busy[1]),.done(done[1]),.failed(failed[1]),.cs_n(cs[1]),.sclk(sclk[1]),.mosi(mosi[1]),.status_valid(sv[1]),.status_enable(se[1]),.status_fps(fps[1]),.status_session(session[1]));
always @(negedge cs[0])begin bits=0;miso=status[0][7];end
always @(posedge sclk[0])if(!cs[0])bits++;
always @(negedge sclk[0])if(!cs[0]&&bits<8448)miso<=#25 status[bits/8][7-bits%8];
always @(negedge clk)begin
 if({cs[0],sclk[0],mosi[0],busy[0],done[0],failed[0],take[0],sv[0]}!=={cs[1],sclk[1],mosi[1],busy[1],done[1],failed[1],take[1],sv[1]})$fatal(1,"Observable control mismatch at %0t",$time);
 if(sv[0])begin good++;if({se[0],fps[0],session[0]}!=={se[1],fps[1],session[1]})$fatal(1,"Valid status differs");end
end
task pulse_reset;begin rst=0;start=0;ready=1;repeat(5)@(negedge clk);#2;rst=1;repeat(5)@(negedge clk);end endtask
task launch;begin @(negedge clk);start=1;@(negedge clk);start=0;end endtask
initial begin
 if(!$value$plusargs("DIR=%s",vector_dir))vector_dir="../logs/protocol";
 $readmemh({vector_dir,"/status.hex"},status);
 repeat(5)@(negedge clk);rst=1;repeat(5)@(negedge clk);
 for(k=0;k<50;k++)begin
  if(k==0)ready=0;
  launch();
  if(k==49)wait(refdut.index==1053&&refdut.bitno==3&&sclk[0]);
  else begin delay_cycles=1+((k*7919)%45000);repeat(delay_cycles)@(negedge clk);end
  #2;pulse_reset();
  if(k%5==0)begin launch();wait(done[0]);repeat(2)@(negedge clk);pulse_reset();end
 end
 launch();wait(done[0]);repeat(3)@(negedge clk);if(good!=11)$fatal(1,"Expected eleven CRC-valid status packets, saw %0d",good);
 $display("PASS 50 asynchronous resets including READY wait and CRC tail, 11 valid full packets: control/wire/status cycle equivalence");$finish;
end
initial begin #50000000;$fatal(1,"reset miter watchdog");end
endmodule
