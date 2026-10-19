// CNN/resize execute on cnn_clk; the video/DDR/CPU clock remains 100 MHz.
// Every AXI channel, job and completion event crosses an independent FIFO.
// A job completes only after its final DDR B response has crossed back.
module artflow_cnn_accel #(parameter WIDTH=960,HEIGHT=540,BURST=64)(
 input clk,cnn_clk,rst_n,start,input [31:0] src_addr,dst_addr,
 output reg busy,done,failed,output reg [31:0] cycles,
 output reg source_consumed,
 output [31:0] araddr,output [7:0] arlen,output arvalid,input arready,
 input [127:0] rdata,input rvalid,rlast,input [1:0] rresp,output rready,
 output [31:0] awaddr,output [7:0] awlen,output awvalid,input awready,
 output [127:0] wdata,output [15:0] wstrb,output wvalid,wlast,input wready,
 input bvalid,input [1:0] bresp,output bready
);
(* async_reg="true" *) reg [2:0] reset_cnn;
always @(posedge cnn_clk or negedge rst_n)
 if(!rst_n) reset_cnn<=0;else reset_cnn<={reset_cnn[1:0],1'b1};
wire crst_n=reset_cnn[2];
wire c_busy,c_done,c_failed,c_consumed,job_valid,job_ready,event_valid,event_ready;
wire [63:0] job;
wire [1:0] event_data;
wire [31:0] c_araddr,c_awaddr;
wire [7:0] c_arlen,c_awlen;
wire c_arvalid,c_arready,c_awvalid,c_awready;
wire [127:0] c_rdata,c_wdata;
wire [15:0] c_wstrb;
wire c_rvalid,c_rlast,c_rready,c_wvalid,c_wlast,c_wready,c_bvalid,c_bready;
wire [1:0] c_rresp,c_bresp;
artflow_cnn_cdc_fifo #(.WIDTH(64),.AW(2)) jobs(
 .wclk(clk),.wrst_n(rst_n),.wdata({dst_addr,src_addr}),.wvalid(start),.wready(job_ready),
 .rclk(cnn_clk),.rrst_n(crst_n),.rdata(job),.rvalid(job_valid),.rready(!c_busy));
artflow_cnn_cdc_fifo #(.WIDTH(2),.AW(2)) events(
 .wclk(cnn_clk),.wrst_n(crst_n),.wdata({c_done,c_failed}),
 .wvalid(c_done || c_consumed),.wready(event_ready),
 .rclk(clk),.rrst_n(rst_n),.rdata(event_data),.rvalid(event_valid),.rready(1'b1));
artflow_cnn_cdc_fifo #(.WIDTH(40),.AW(2)) ar(
 .wclk(cnn_clk),.wrst_n(crst_n),.wdata({c_arlen,c_araddr}),.wvalid(c_arvalid),.wready(c_arready),
 .rclk(clk),.rrst_n(rst_n),.rdata({arlen,araddr}),.rvalid(arvalid),.rready(arready));
artflow_cnn_cdc_fifo #(.WIDTH(40),.AW(2)) aw(
 .wclk(cnn_clk),.wrst_n(crst_n),.wdata({c_awlen,c_awaddr}),.wvalid(c_awvalid),.wready(c_awready),
 .rclk(clk),.rrst_n(rst_n),.rdata({awlen,awaddr}),.rvalid(awvalid),.rready(awready));
artflow_cnn_cdc_fifo #(.WIDTH(145),.AW(3)) w(
 .wclk(cnn_clk),.wrst_n(crst_n),.wdata({c_wlast,c_wstrb,c_wdata}),.wvalid(c_wvalid),.wready(c_wready),
 .rclk(clk),.rrst_n(rst_n),.rdata({wlast,wstrb,wdata}),.rvalid(wvalid),.rready(wready));
artflow_cnn_cdc_fifo #(.WIDTH(131),.AW(3)) r(
 .wclk(clk),.wrst_n(rst_n),.wdata({rlast,rresp,rdata}),.wvalid(rvalid),.wready(rready),
 .rclk(cnn_clk),.rrst_n(crst_n),.rdata({c_rlast,c_rresp,c_rdata}),.rvalid(c_rvalid),.rready(c_rready));
artflow_cnn_cdc_fifo #(.WIDTH(2),.AW(2)) b(
 .wclk(clk),.wrst_n(rst_n),.wdata(bresp),.wvalid(bvalid),.wready(bready),
 .rclk(cnn_clk),.rrst_n(crst_n),.rdata(c_bresp),.rvalid(c_bvalid),.rready(c_bready));
artflow_cnn_dma #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BURST(BURST)) engine(
 .clk(cnn_clk),.rst_n(crst_n),.start(job_valid && !c_busy),.src_addr(job[31:0]),.dst_addr(job[63:32]),
 .busy(c_busy),.done(c_done),.failed(c_failed),.cycles(),.source_consumed(c_consumed),
 .araddr(c_araddr),.arlen(c_arlen),.arvalid(c_arvalid),.arready(c_arready),
 .rdata(c_rdata),.rvalid(c_rvalid),.rlast(c_rlast),.rresp(c_rresp),.rready(c_rready),
 .awaddr(c_awaddr),.awlen(c_awlen),.awvalid(c_awvalid),.awready(c_awready),
 .wdata(c_wdata),.wstrb(c_wstrb),.wvalid(c_wvalid),.wlast(c_wlast),.wready(c_wready),
 .bvalid(c_bvalid),.bresp(c_bresp),.bready(c_bready));
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin busy<=0;done<=0;failed<=0;source_consumed<=0;cycles<=0;end
 else begin
  done<=0;source_consumed<=0;
  if(busy) cycles<=cycles+1'b1; // APB statistics still use 100 MHz wall time.
  if(start) begin busy<=1;failed<=0;cycles<=0;end
  if(event_valid) begin
   if(event_data[1]) begin busy<=0;done<=1;failed<=event_data[0];end
   else source_consumed<=1;
  end
 end
end
// synthesis translate_off
always @(posedge clk) if(rst_n && start && (busy || !job_ready)) $fatal(1,"CNN job overflow");
always @(posedge cnn_clk) if(crst_n && (c_done || c_consumed) && !event_ready) $fatal(1,"CNN event overflow");
// synthesis translate_on
endmodule
