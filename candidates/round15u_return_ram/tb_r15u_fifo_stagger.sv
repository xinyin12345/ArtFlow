`timescale 1ns/1ps
module fifo_ram_case #(parameter WIDTH=131,AW=3,ID=0,parameter real WH=5.0,RH=3.5)(output reg done=0);
reg wclk=0,rclk=0,rst_n=0;always #(WH)wclk=~wclk;initial begin #(ID*0.137);forever #(RH)rclk=~rclk;end
reg[2:0] release_pipe=0;
always @(posedge rclk or negedge rst_n)if(!rst_n)release_pipe<=0;else release_pipe<={release_pipe[1:0],1'b1};
wire rrst_n=release_pipe[2];
reg[WIDTH-1:0] wdata=0;reg wvalid=0,rready=0;
wire wr0,wr1,rv0,rv1,ri0,ri1,wi0,wi1;wire[WIDTH-1:0]rd0,rd1;
artflow_cnn_cdc_fifo #(.WIDTH(WIDTH),.AW(AW)) refdut(wclk,rst_n,wdata,wvalid,wr0,rclk,rrst_n,rd0,rv0,rready,ri0,wi0);
artflow_cnn_return_ram_fifo #(.WIDTH(WIDTH),.AW(AW)) dut(wclk,rst_n,wdata,wvalid,wr1,rclk,rrst_n,rd1,rv1,rready,ri1,wi1);
reg[WIDTH-1:0] expected[0:65535];integer wp=0,rp=0,tw=0,tr=0,full_stalls=0,read_stalls=0,reset_count=0,wcycle=0,rcycle=0;
reg[31:0] ws=32'h12345678+ID,rs=32'h9abcdef0+ID,seq=0;realtime read_edge=-1;reg[AW-1:0] read_address=0;reg read_fire=0;
always @(negedge wclk)begin
 wcycle=wcycle+1;ws={ws[30:0],ws[31]^ws[21]^ws[1]^ws[0]};
 if(!rst_n)wvalid=0;
 else if(!wvalid || wr0)begin
  wvalid=$time<300000 && (wcycle%800<96 || ws[3:0]<12);
  if(wvalid)begin seq=seq+1;for(integer j=0;j<WIDTH;j=j+1)wdata[j]=ws[j%32]^seq[j%32]^((j/32)&1);end
 end
end
always @(negedge rclk)begin
 rcycle=rcycle+1;rs={rs[30:0],rs[31]^rs[21]^rs[1]^rs[0]};
 rready=rrst_n && ($time>=300000 || (rcycle%800>=100 && rs[3:0]<11));
end
always @(posedge wclk or negedge rst_n)begin
 if(!rst_n)wp=0;
 else begin
  if(wvalid && wr0)begin expected[wp]=wdata;wp=wp+1;tw=tw+1;if(wp-rp>(1<<AW)+1)$fatal(1,"capacity changed ID%0d",ID);end
  if(wvalid && !wr0)full_stalls=full_stalls+1;
  #0;if(wvalid && wr0 && read_fire && read_edge==$realtime && dut.wbin[AW-1:0]==read_address)$fatal(1,"live RAM collision ID%0d",ID);
  #0.001;if(wr0!==wr1 || wi0!==wi1)$fatal(1,"write control inequivalence ID%0d",ID);
 end
end
always @(posedge rclk or negedge rrst_n)begin
 if(!rrst_n)begin rp=0;read_fire=0;end
 else begin
  read_edge=$realtime;read_fire=(!rv1 || rready) && !dut.empty;read_address=dut.rbin[AW-1:0];
  if(rv0 && rready)begin
   if(rp>=wp || rd0!==expected[rp] || rd1!==expected[rp])$fatal(1,"scoreboard ID%0d rp%0d wp%0d",ID,rp,wp);
   rp=rp+1;tr=tr+1;
  end
  if(rv0 && !rready)read_stalls=read_stalls+1;
  #0.001;if(rv0!==rv1 || ri0!==ri1)$fatal(1,"read control inequivalence ID%0d",ID);
  if(rv0 && rd0!==rd1)$fatal(1,"valid payload cycle mismatch ID%0d",ID);
 end
end
initial begin
 #101;rst_n=1;
 #66003;rst_n=0;reset_count=reset_count+1;#113;rst_n=1;
 #65007;rst_n=0;reset_count=reset_count+1;#117;rst_n=1;
 #69011;rst_n=0;reset_count=reset_count+1;#119;rst_n=1;
 #120000;
 if(wp!=rp || !ri0 || !wi0 || !ri1 || !wi1 || tw<1000 || tr<1000 || full_stalls<10 || read_stalls<10)$fatal(1,"coverage/drain ID%0d wp%0d rp%0d tw%0d tr%0d",ID,wp,rp,tw,tr);
 $display("FIFO_RAM_CASE_PASS ID=%0d WIDTH=%0d AW=%0d writes=%0d reads=%0d full_stalls=%0d read_stalls=%0d resets=%0d",ID,WIDTH,AW,tw,tr,full_stalls,read_stalls,reset_count);done=1;
end
endmodule
module tb_r15u_fifo_stagger;
wire[5:0] done;
fifo_ram_case #(.ID(0),.WIDTH(131),.WH(5.0),.RH(3.5)) a(done[0]);
fifo_ram_case #(.ID(1),.WIDTH(131),.WH(3.5),.RH(5.0)) b(done[1]);
fifo_ram_case #(.ID(2),.WIDTH(131),.WH(5.0),.RH(5.0)) c(done[2]);
fifo_ram_case #(.ID(3),.WIDTH(1),.AW(2),.WH(3.0),.RH(5.0)) d(done[3]);
fifo_ram_case #(.ID(4),.WIDTH(20),.AW(2),.WH(5.0),.RH(3.0)) e(done[4]);
fifo_ram_case #(.ID(5),.WIDTH(21),.AW(4),.WH(4.0),.RH(7.0)) f(done[5]);
initial begin wait(&done);$display("TEST PASS r15u_fifo_stagger nativeRAM six parameter/clock cases exact valid/control cycles and scoreboard, resets/full/backpressure/wrap/collision/drain");$finish;end
initial begin #400000;$fatal(1,"FIFO functional watchdog");end
endmodule
