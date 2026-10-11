// S8 byte-addressed 64-bit logical port to 128-bit AXI INCR.
// 256-byte read cache and write-combining line. Writes retire only after B;
// flush/drained is the frame-publication fence. Single clock, no new CDC.
module artflow_cnn_bridge #(parameter BASE=32'h01800000)(
 input clk,rst_n,clear,flush, output drained,output reg failed,
 input mem_valid,mem_write,input [23:0] mem_addr,input [63:0] mem_wdata,
 output mem_ready,output reg mem_rvalid,output [63:0] mem_rdata,
 output [31:0] araddr,output [7:0] arlen,output arvalid,input arready,
 input [127:0] rdata,input rvalid,rlast,input [1:0] rresp,output rready,
 output [31:0] awaddr,output [7:0] awlen,output awvalid,input awready,
 output [127:0] wdata,output [15:0] wstrb,output wvalid,wlast,input wready,
 input bvalid,input [1:0] bresp,output bready
);
localparam IDLE=0,AW=1,PREF=2,WD=3,BR=4,AR=5,RD=6;
reg [2:0] state;
reg [15:0] read_tag,write_tag;
reg cache_valid;
reg [31:0] mask;
reg [3:0] beat;
reg [127:0] cache[0:15],cache_q;
reg [63:0] low[0:15],high[0:15],lo_q,hi_q;
reg half;
wire dirty=|mask;
wire hit=cache_valid && read_tag==mem_addr[23:8];
wire write_match=write_tag==mem_addr[23:8];
assign drained=state==IDLE && !dirty;
assign mem_ready=rst_n && !clear && !flush && state==IDLE &&
 (mem_write ? (!dirty || write_match) : (hit && !(dirty && write_match)));
wire accept=mem_valid && mem_ready;
assign mem_rdata=half ? cache_q[127:64] : cache_q[63:0];
assign araddr=BASE+{8'd0,read_tag,8'd0}; assign arlen=15;
assign awaddr=BASE+{8'd0,write_tag,8'd0}; assign awlen=15;
assign arvalid=state==AR; assign rready=state==RD;
assign awvalid=state==AW; assign wvalid=state==WD;
assign wdata={mask[{beat,1'b1}]?hi_q:64'd0,mask[{beat,1'b0}]?lo_q:64'd0};
assign wstrb={{8{mask[{beat,1'b1}]}},{8{mask[{beat,1'b0}]}}};
assign wlast=beat==15; assign bready=state==BR;
always @(posedge clk) begin
 cache_q<=cache[mem_addr[7:4]];
 lo_q<=low[beat]; hi_q<=high[beat];
 if(accept && mem_write) begin
  if(mem_addr[3]) high[mem_addr[7:4]]<=mem_wdata;
  else low[mem_addr[7:4]]<=mem_wdata;
 end
 if(state==RD && rvalid) cache[beat]<=rdata;
end
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  state<=IDLE;read_tag<=0;write_tag<=0;cache_valid<=0;mask<=0;
  beat<=0;half<=0;mem_rvalid<=0;failed<=0;
 end else begin
  mem_rvalid<=accept && !mem_write;
  if(accept && !mem_write) half<=mem_addr[3];
  if(clear && drained) begin cache_valid<=0;failed<=0;end
  case(state)
   IDLE: if(!clear) begin
    if(accept && mem_write) begin
     write_tag<=mem_addr[23:8];mask[mem_addr[7:3]]<=1;
     if(hit) cache_valid<=0;
    end else if(dirty && (flush || (mem_valid &&
                (mem_write ? !write_match : (!hit || write_match))))) begin
     beat<=0;state<=AW;
    end else if(mem_valid && !mem_write && !hit && !flush) begin
     read_tag<=mem_addr[23:8];cache_valid<=0;beat<=0;state<=AR;
    end
   end
   AW: if(awready) state<=PREF;
   PREF: state<=WD;
   WD: if(wready) begin
    if(wlast) state<=BR;
    else begin beat<=beat+1'b1;state<=PREF;end
   end
   BR: if(bvalid) begin
    if(bresp!=0) failed<=1;
    mask<=0;state<=IDLE;
   end
   AR: if(arready) state<=RD;
   RD: if(rvalid) begin
    if(rresp!=0 || rlast!=(beat==15)) failed<=1;
    if(rlast) begin cache_valid<=1;state<=IDLE;end
    else beat<=beat+1'b1;
   end
   default: state<=IDLE;
  endcase
 end
end
// synthesis translate_off
always @(posedge clk) if(rst_n && accept)
 if(mem_addr[2:0]!=0 || mem_addr>=24'h600000) $fatal(1,"CNN scratch bounds/alignment");
// synthesis translate_on
endmodule
