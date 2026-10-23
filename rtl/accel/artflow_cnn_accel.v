// CNN/resize execute on cnn_clk; the video/DDR/CPU clock remains 100 MHz.
// Every AXI channel, job and completion event crosses an independent FIFO.
// A job completes only after its final DDR B response has crossed back.
module artflow_cnn_accel #(parameter WIDTH=960,HEIGHT=540,BURST=64,STYLE_ENABLE=0,STYLE_COUNT=19,STYLE_DEBOUNCE=2857143)(
 input clk,cnn_clk,rst_n,start,input [31:0] src_addr,dst_addr,
 input key_style_n,flash_miso,output flash_cs_n,flash_sck,flash_mosi,
 output reg [31:0] style_status,output reg [4:0] completed_style,
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
wire [6:0] event_data;reg [4:0] c_frame_style;
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
artflow_cnn_cdc_fifo #(.WIDTH(7),.AW(2)) events(
 .wclk(cnn_clk),.wrst_n(crst_n),.wdata({c_frame_style,c_done,c_failed}),
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
wire param_bank,cfg_valid,cfg_bank;wire [1:0] cfg_kind;wire [9:0] cfg_addr;wire [575:0] cfg_data;
wire [4:0] c_job_style;
wire [31:0] c_style_status;
generate if(STYLE_ENABLE)begin:styles
 wire press,loading,bank_ready;wire [4:0] active,requested;wire [15:0] load_errors;
 artflow_button #(.DEBOUNCE_CYCLES(STYLE_DEBOUNCE)) key_filter(.clk(cnn_clk),.rst_n(crst_n),.key_n(key_style_n),.press(press));
 style_bank_controller #(.STYLE_COUNT(STYLE_COUNT)) banks(
  .clk(cnn_clk),.rst_n(crst_n),.key_press(press),.job_start(job_valid && !c_busy),
  .active_bank(param_bank),.active_style(active),.requested_style(requested),.job_style(c_job_style),
  .cfg_valid(cfg_valid),.cfg_bank(cfg_bank),.cfg_kind(cfg_kind),.cfg_addr(cfg_addr),.cfg_data(cfg_data),
  .loading(loading),.ready(bank_ready),.errors(load_errors),
  .flash_cs_n(flash_cs_n),.flash_sck(flash_sck),.flash_mosi(flash_mosi),.flash_miso(flash_miso));
 assign c_style_status={4'd0,load_errors,bank_ready,loading,requested,active};
end else begin
 assign param_bank=0;assign cfg_valid=0;assign cfg_bank=0;assign cfg_kind=0;assign cfg_addr=0;assign cfg_data=0;
 assign c_job_style=0;assign c_style_status=0;assign flash_cs_n=1;assign flash_sck=0;assign flash_mosi=0;
end endgenerate
always @(posedge cnn_clk or negedge crst_n)
 if(!crst_n)c_frame_style<=0;else if(job_valid && !c_busy)c_frame_style<=c_job_style;
reg [31:0] sent_status;wire status_ready,status_valid;wire [31:0] status_data;
always @(posedge cnn_clk or negedge crst_n)
 if(!crst_n)sent_status<=0;else if(status_ready && c_style_status!=sent_status)sent_status<=c_style_status;
artflow_cnn_cdc_fifo #(.WIDTH(32),.AW(2)) style_status_fifo(
 .wclk(cnn_clk),.wrst_n(crst_n),.wdata(c_style_status),.wvalid(c_style_status!=sent_status),.wready(status_ready),
 .rclk(clk),.rrst_n(rst_n),.rdata(status_data),.rvalid(status_valid),.rready(1'b1));
artflow_cnn_dma #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BURST(BURST)) engine(
 .param_bank(param_bank),.cfg_valid(cfg_valid),.cfg_bank(cfg_bank),.cfg_kind(cfg_kind),.cfg_addr(cfg_addr),.cfg_data(cfg_data),
 .clk(cnn_clk),.rst_n(crst_n),.start(job_valid && !c_busy),.src_addr(job[31:0]),.dst_addr(job[63:32]),
 .busy(c_busy),.done(c_done),.failed(c_failed),.cycles(),.source_consumed(c_consumed),
 .araddr(c_araddr),.arlen(c_arlen),.arvalid(c_arvalid),.arready(c_arready),
 .rdata(c_rdata),.rvalid(c_rvalid),.rlast(c_rlast),.rresp(c_rresp),.rready(c_rready),
 .awaddr(c_awaddr),.awlen(c_awlen),.awvalid(c_awvalid),.awready(c_awready),
 .wdata(c_wdata),.wstrb(c_wstrb),.wvalid(c_wvalid),.wlast(c_wlast),.wready(c_wready),
 .bvalid(c_bvalid),.bresp(c_bresp),.bready(c_bready));
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin busy<=0;done<=0;failed<=0;source_consumed<=0;cycles<=0;style_status<=0;completed_style<=0;end
 else begin
  done<=0;source_consumed<=0;if(status_valid)style_status<=status_data;
  if(busy) cycles<=cycles+1'b1; // APB statistics still use 100 MHz wall time.
  if(start) begin busy<=1;failed<=0;cycles<=0;end
  if(event_valid) begin
   if(event_data[1]) begin busy<=0;done<=1;failed<=event_data[0];completed_style<=event_data[6:2];end
   else source_consumed<=1;
  end
 end
end
// synthesis translate_off
always @(posedge clk) if(rst_n && start && (busy || !job_ready)) $fatal(1,"CNN job overflow");
always @(posedge cnn_clk) if(crst_n && (c_done || c_consumed) && !event_ready) $fatal(1,"CNN event overflow");
// synthesis translate_on
endmodule
