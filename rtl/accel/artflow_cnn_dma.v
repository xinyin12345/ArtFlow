// v09 candidate: prepare sRGB -> frozen 22-layer S8 -> upscale/tag display RGB.
module artflow_cnn_dma #(
    parameter WIDTH=960, HEIGHT=540, BURST=64
)(
    input clk, rst_n, start, input [31:0] src_addr, dst_addr,
    output busy, output reg done, failed, output reg [31:0] cycles,
    output source_consumed,
    output [31:0] araddr, output [7:0] arlen,
    output arvalid, input arready, input [127:0] rdata,
    input rvalid, rlast, input [1:0] rresp, output rready,
    output [31:0] awaddr, output [7:0] awlen,
    output awvalid, input awready, output [127:0] wdata,
    output [15:0] wstrb, output wvalid, wlast, input wready,
    input bvalid, input [1:0] bresp, output bready
);
localparam SCRATCH=32'h01800000;
localparam IDLE=0,PRE_START=1,PRE=2,CNN_START=3,CNN=4,DRAIN=5,POST_START=6,POST=7,FIN=8;
reg [3:0] state;
reg [31:0] src,dst;
wire select_cnn=state==CNN_START || state==CNN || state==DRAIN;
wire scale_done,scale_failed;
wire core_done,bridge_failed,drained;
wire mv,mw,mready,mrv;wire [23:0] ma;wire [63:0] mwd,mrd;
assign busy=state!=IDLE;
// All original pixels are now committed to private scratch DDR. The camera
// can reuse the source while the network runs and while the result is scaled.
assign source_consumed=state==CNN_START;
wire [31:0] s_araddr;
wire [7:0] s_arlen;
wire s_arvalid;
wire s_rready;
wire [31:0] s_awaddr;
wire [7:0] s_awlen;
wire s_awvalid;
wire [127:0] s_wdata;
wire [15:0] s_wstrb;
wire s_wvalid;
wire s_wlast;
wire s_bready;
wire [31:0] c_araddr;
wire [7:0] c_arlen;
wire c_arvalid;
wire c_rready;
wire [31:0] c_awaddr;
wire [7:0] c_awlen;
wire c_awvalid;
wire [127:0] c_wdata;
wire [15:0] c_wstrb;
wire c_wvalid;
wire c_wlast;
wire c_bready;
assign araddr=select_cnn ? c_araddr : s_araddr;
assign arlen=select_cnn ? c_arlen : s_arlen;
assign arvalid=select_cnn ? c_arvalid : s_arvalid;
assign rready=select_cnn ? c_rready : s_rready;
assign awaddr=select_cnn ? c_awaddr : s_awaddr;
assign awlen=select_cnn ? c_awlen : s_awlen;
assign awvalid=select_cnn ? c_awvalid : s_awvalid;
assign wdata=select_cnn ? c_wdata : s_wdata;
assign wstrb=select_cnn ? c_wstrb : s_wstrb;
assign wvalid=select_cnn ? c_wvalid : s_wvalid;
assign wlast=select_cnn ? c_wlast : s_wlast;
assign bready=select_cnn ? c_bready : s_bready;
artflow_cnn_resize #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BURST(BURST)) scaler(
 .clk(clk),.rst_n(rst_n),.start(state==PRE_START || state==POST_START),
 .upscale(state==POST_START || state==POST),
 .src_addr(state==PRE_START || state==PRE ? src : SCRATCH),
 .dst_addr(state==PRE_START || state==PRE ? SCRATCH : dst),
 .busy(),.done(scale_done),.failed(scale_failed),.cycles(),
 .araddr(s_araddr),
 .arlen(s_arlen),
 .arvalid(s_arvalid),
 .rready(s_rready),
 .awaddr(s_awaddr),
 .awlen(s_awlen),
 .awvalid(s_awvalid),
 .wdata(s_wdata),
 .wstrb(s_wstrb),
 .wvalid(s_wvalid),
 .wlast(s_wlast),
 .bready(s_bready),
 .arready(!select_cnn && arready),
 .rdata(rdata),
 .rvalid(!select_cnn && rvalid),
 .rlast(rlast),
 .rresp(rresp),
 .awready(!select_cnn && awready),
 .wready(!select_cnn && wready),
 .bvalid(!select_cnn && bvalid),
 .bresp(bresp));
s8_shared #(.EXT_W(WIDTH/2),.EXT_H(HEIGHT/2)) core(
 .clk(clk),.rst(!rst_n || state==IDLE || state==PRE_START || state==PRE),
 .start(state==CNN_START),.busy(),.done(core_done),
 .mem_valid(mv),.mem_write(mw),.mem_addr(ma),.mem_wdata(mwd),.mem_wstrb(),
 .mem_ready(mready),.mem_rvalid(mrv),.mem_rdata(mrd),
 .layer_done(),.layer_index(),.frame_cycles());
artflow_cnn_bridge #(.BASE(SCRATCH)) bridge(
 .clk(clk),.rst_n(rst_n),.clear(state==IDLE || state==PRE_START || state==PRE),
 .flush(state==DRAIN),.drained(drained),.failed(bridge_failed),
 .mem_valid(mv && select_cnn),.mem_write(mw),.mem_addr(ma),.mem_wdata(mwd),
 .mem_ready(mready),.mem_rvalid(mrv),.mem_rdata(mrd),
 .araddr(c_araddr),
 .arlen(c_arlen),
 .arvalid(c_arvalid),
 .rready(c_rready),
 .awaddr(c_awaddr),
 .awlen(c_awlen),
 .awvalid(c_awvalid),
 .wdata(c_wdata),
 .wstrb(c_wstrb),
 .wvalid(c_wvalid),
 .wlast(c_wlast),
 .bready(c_bready),
 .arready(select_cnn && arready),
 .rdata(rdata),
 .rvalid(select_cnn && rvalid),
 .rlast(rlast),
 .rresp(rresp),
 .awready(select_cnn && awready),
 .wready(select_cnn && wready),
 .bvalid(select_cnn && bvalid),
 .bresp(bresp));
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin state<=IDLE;src<=0;dst<=0;done<=0;failed<=0;cycles<=0;end
 else begin
  done<=0;if(busy) cycles<=cycles+1'b1;
  case(state)
   IDLE: if(start) begin src<=src_addr;dst<=dst_addr;failed<=0;cycles<=0;state<=PRE_START;end
   PRE_START: state<=PRE;
   PRE: if(scale_done) begin
    if(scale_failed) begin failed<=1;state<=FIN;end
    else state<=CNN_START;
   end
   CNN_START: state<=CNN;
   CNN: if(core_done) state<=DRAIN;
   DRAIN: if(drained) begin
    if(bridge_failed) begin failed<=1;state<=FIN;end
    else state<=POST_START;
   end
   POST_START: state<=POST;
   POST: if(scale_done) begin failed<=scale_failed;state<=FIN;end
   FIN: begin done<=1;state<=IDLE;end
   default: state<=IDLE;
  endcase
 end
end
// synthesis translate_off
initial if(WIDTH%16 || WIDTH<32 || HEIGHT<28) $fatal(1,"CNN geometry requires width / 16, min 32x28");
// synthesis translate_on
endmodule
