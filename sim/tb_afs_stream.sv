`timescale 1ns/1ps
module tb_afs_stream;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,tick=0,bad=0,valid=0,ready=1,miso=0;
 reg [9:0] x=0,y=0;reg [23:0] rgb=0;reg [31:0] epoch=7;
 wire cs,sck,mosi;wire [31:0] completed,dropped;
 afs_stream_tx dut(.clk(clk),.rst_n(rst),.frame_tick(tick),.frame_bad(bad),.pixel_valid(valid),.source_x(x),.source_y(y),.rgb(rgb),.epoch(epoch),.ready(ready),.miso(miso),.cs_n(cs),.sclk(sck),.mosi(mosi),.completed(completed),.dropped(dropped));
reg timeout_start=0;wire timeout_done,timeout_failed,timeout_cs;
 afs_spi_packet #(.WAIT_CYCLES(100)) timeout_dut(.clk(clk),.rst_n(rst),.start(timeout_start),.fast(1'b0),.ready_async(1'b0),.miso(1'b0),.kind(8'd0),.session(32'd0),.sequence_id(32'd0),.offset(32'd0),.frame_crc(32'd0),.length(16'd0),.payload_byte(8'd0),.payload_take(),.busy(),.done(timeout_done),.failed(timeout_failed),.cs_n(timeout_cs),.sclk(),.mosi(),.status_valid(),.status_enable(),.status_fps(),.status_session());
 initial begin wait(rst);@(negedge clk);timeout_start=1;@(negedge clk);timeout_start=0;wait(timeout_done);if(!timeout_failed||!timeout_cs)$fatal(1,"READY timeout unsafe");$display("PASS READY timeout leaves CS inactive");end
 reg [7:0] status[0:1055],received[0:1055];integer bitidx=0,fd,npack=0,cancels=0,ends=0,peak=0,gap_cycles=2000;
 always @(posedge clk)if(rst&&dut.used>peak)peak=dut.used;
 reg [31:0] c;integer i,j;string dir;
 function automatic [31:0] crcbyte(input [31:0] c0,input [7:0] b0);reg [31:0] v;integer k;begin v=c0^b0;for(k=0;k<8;k++)v=(v>>1)^(v[0]?32'hedb88320:0);return v;end endfunction
 always @(negedge cs)begin bitidx=0;miso=status[0][7];end
 always @(posedge sck)if(!cs)begin received[bitidx/8][7-bitidx%8]=mosi;bitidx=bitidx+1;end
 always @(negedge sck)if(!cs&&bitidx<8448)miso<=#25 status[bitidx/8][7-bitidx%8];
 always @(posedge cs)if(rst&&bitidx>0)begin
  if(bitidx!=8448)$fatal(1,"short packet %0d",bitidx);
  c=32'hffffffff;for(i=0;i<1056;i++)begin c=crcbyte(c,received[i]);$fwrite(fd,"%c",received[i]);end
  if(c!=32'hdebb20e3)$fatal(1,"wire CRC packet %0d type %0d",npack,received[5]);
  if(received[5]==4)cancels++;if(received[5]==3)ends++;
  npack++;ready=0;repeat(gap_cycles)@(negedge clk);ready=1;
 end
 task reset_dut;begin @(negedge clk);rst=0;valid=0;tick=0;bad=0;repeat(10)@(negedge clk);rst=1;wait(dut.enabled);wait(!dut.pending);end endtask
 task source_frame(input integer spacing,input integer fail_at);integer a,b;begin
  for(b=0;b<90;b++)begin
   for(a=0;a<160;a++)begin
   @(negedge clk);valid=1;x=a*6;y=b*6;rgb={8'(a),8'(b),8'(a^b)};
   if(b*160+a==fail_at)bad=1;
   @(negedge clk);valid=0;repeat(spacing-2)@(negedge clk);
   end
   if(spacing==6)repeat(12240)@(negedge clk);
  end
  repeat(1000)@(negedge clk);tick=1;@(negedge clk);tick=0;bad=0;
 end endtask
 initial begin
  if(!$value$plusargs("DIR=%s",dir))dir="../logs/protocol";
  $readmemh({dir,"/status.hex"},status);fd=$fopen({dir,"/rtl.spi"},"wb");if(!fd)$fatal(1,"open vector output");
  status[1052]=status[1052]^1;repeat(10)@(negedge clk);rst=1;wait(npack==1);repeat(20)@(negedge clk);if(dut.enabled)$fatal(1,"bad status CRC enabled video");status[1052]=status[1052]^1;$display("PASS bad MISO CRC cannot enable video");
  reset_dut();source_frame(6,-1);wait(completed==1);if(ends!=1||cancels!=0)$fatal(1,"normal frame did not commit");$display("NORMAL FIFO peak=%0d words; READY gap=2000 cycles; MISO model delay=25ns",peak);
  reset_dut();epoch=8;source_frame(2,-1);wait(dropped==1);if(cancels!=1)$fatal(1,"overflow did not cancel");
  reset_dut();epoch=9;source_frame(6,100);wait(dropped==1);if(cancels!=2)$fatal(1,"bad source did not cancel");
  reset_dut();epoch=10;source_frame(6,-1);wait(completed==1);if(ends!=2)$fatal(1,"recovery did not commit");
  gap_cycles=4000;reset_dut();epoch=11;source_frame(6,-1);wait(dropped==1);if(cancels!=3)$fatal(1,"slow slave did not cancel");$display("PASS 4000-cycle slow slave cancels complete frame");
  $fclose(fd);$display("PASS AFS SPI wire CRC, full frame, overflow cancel, source error cancel, reset recovery; packets=%0d",npack);$finish;
 end
 initial begin #200000000;$fatal(1,"simulation watchdog");end
endmodule
