`timescale 1ns/1ps
module fifo_exerciser(input wclk,rclk,rst_n,enable,output [31:0] written,read_count,blocked,checked);
reg wvalid=0,rready=0;wire wready,rvalid;
reg [31:0] ws=0,rs=0,full_cycles=0,total=0;
wire [63:0] wdata={ws^32'h5a1234bc,ws};wire [63:0] rdata;
artflow_cnn_cdc_fifo #(.WIDTH(64),.AW(3)) dut(wclk,rst_n,wdata,wvalid,wready,rclk,rst_n,rdata,rvalid,rready);
assign written=ws;assign read_count=rs;assign blocked=full_cycles;assign checked=total;
always @(negedge wclk) wvalid<=rst_n && enable && $urandom_range(9)<8;
always @(negedge rclk) rready<=rst_n && (!enable || $urandom_range(9)<5);
always @(posedge wclk or negedge rst_n) begin
 if(!rst_n) ws<=0;
 else begin
  if(wvalid && wready) ws<=ws+1;
  if(wvalid && !wready) full_cycles<=full_cycles+1;
 end
end
reg stalled=0;reg [63:0] previous;
always @(posedge rclk or negedge rst_n) begin
 if(!rst_n) begin rs<=0;stalled<=0;end
 else begin
  if(stalled && (!rvalid || rdata!==previous)) $fatal(1,"FIFO changed while stalled");
  stalled<=rvalid&&!rready;previous<=rdata;
  if(rvalid && rready) begin
   if(rdata!=={rs^32'h5a1234bc,rs}) $fatal(1,"FIFO order/data mismatch expected=%0d got=%h",rs,rdata);
   rs<=rs+1;total<=total+1;
  end
 end
end
endmodule
module tb_cnn_cdc_fifo;
reg a=0,b=0,rst_n=0,enable=0;
real half_a=2.5,half_b=5.0;
always #(half_a) a=~a;
initial begin #1.137;forever #(half_b) b=~b;end
wire [31:0] wa,ra,ba,ca,wb,rb,bb,cb;
fifo_exerciser forward(a,b,rst_n,enable,wa,ra,ba,ca);
fifo_exerciser reverse(b,a,rst_n,enable,wb,rb,bb,cb);
initial begin
 #101;rst_n=1;enable=1;
 repeat(6000) @(negedge a);
 // Cancel queued data with a common asynchronous reset; clocks keep running.
 #0.731;rst_n=0;enable=0;#83;half_a=3.7;half_b=4.3;rst_n=1;enable=1;
 repeat(30000) @(negedge a);
 enable=0;
 repeat(200) @(negedge a);
 if(wa!=ra || wb!=rb || ca<10000 || cb<10000 || ba<100 || bb<100) $fatal(1,"FIFO insufficient stress or lost data");
 $display("tb_cnn_cdc_fifo PASS checked=%0d/%0d backpressure=%0d/%0d",ca,cb,ba,bb);$finish;
end
initial begin #2000000;$fatal(1,"FIFO timeout");end
endmodule
