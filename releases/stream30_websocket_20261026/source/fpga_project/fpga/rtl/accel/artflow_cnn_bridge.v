// Two tagged read-cache banks and two write-combining banks.
// Read fills and write bursts run independently. Each request remains ordered
// against dirty writes to its own cache line; B is the publication fence.
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
reg [2:0] state,ws;
reg [15:0] fill_tag,cache_tag[0:1],write_tag[0:1];
reg [15:0] cache_valid[0:1];
reg [31:0] mask[0:1];
reg [3:0] rb,wb;
reg active_bank,write_bank;
reg [127:0] cache[0:31],cache_q;
reg [63:0] low[0:31],high[0:31],lo_q,hi_q;
reg half;
wire bank=mem_addr[22];
wire hit=cache_valid[bank][mem_addr[7:4]] && cache_tag[bank]==mem_addr[23:8];
wire dirty0=|mask[0],dirty1=|mask[1];
wire dirty=|mask[active_bank];
wire write_match=write_tag[active_bank]==mem_addr[23:8];
wire hazard=(dirty0 && write_tag[0]==mem_addr[23:8]) ||
            (dirty1 && write_tag[1]==mem_addr[23:8]);
wire filling_same=state!=IDLE && fill_tag==mem_addr[23:8];
assign drained=state==IDLE && ws==IDLE && !dirty0 && !dirty1;
assign mem_ready=rst_n && !clear && !flush &&
 (mem_write ? ((!dirty || write_match) && !filling_same) : (hit && !hazard));
wire accept=mem_valid && mem_ready;
wire need_flush=dirty && (flush || (mem_valid &&
                  (mem_write ? !write_match : write_match)));
assign mem_rdata=half ? cache_q[127:64] : cache_q[63:0];
assign araddr=BASE+{8'd0,fill_tag,8'd0}; assign arlen=15;
assign awaddr=BASE+{8'd0,write_tag[write_bank],8'd0}; assign awlen=15;
assign arvalid=state==AR; assign rready=state==RD;
assign awvalid=ws==AW; assign wvalid=ws==WD;
assign wdata={mask[write_bank][{wb,1'b1}]?hi_q:64'd0,mask[write_bank][{wb,1'b0}]?lo_q:64'd0};
assign wstrb={{8{mask[write_bank][{wb,1'b1}]}},{8{mask[write_bank][{wb,1'b0}]}}};
assign wlast=wb==15; assign bready=ws==BR;
wire [3:0] next_wb=(ws==WD && wready && !wlast)?wb+4'd1:wb;
always @(posedge clk) begin
 cache_q<=cache[{bank,mem_addr[7:4]}];
 lo_q<=low[{write_bank,next_wb}]; hi_q<=high[{write_bank,next_wb}];
 if(accept && mem_write) begin
  if(mem_addr[3]) high[{active_bank,mem_addr[7:4]}]<=mem_wdata;
  else low[{active_bank,mem_addr[7:4]}]<=mem_wdata;
 end
 if(state==RD && rvalid) cache[{fill_tag[14],rb}]<=rdata;
end
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  state<=IDLE;ws<=IDLE;fill_tag<=0;cache_tag[0]<=0;cache_tag[1]<=0;
  write_tag[0]<=0;write_tag[1]<=0;cache_valid[0]<=0;cache_valid[1]<=0;
  mask[0]<=0;mask[1]<=0;rb<=0;wb<=0;active_bank<=0;write_bank<=1;
  half<=0;mem_rvalid<=0;failed<=0;
 end else begin
  mem_rvalid<=accept && !mem_write;
  if(accept && !mem_write) half<=mem_addr[3];
  if(clear && drained) begin cache_valid[0]<=0;cache_valid[1]<=0;failed<=0;end
  if(accept && mem_write) begin
   write_tag[active_bank]<=mem_addr[23:8];mask[active_bank][mem_addr[7:3]]<=1;
   if(cache_tag[bank]==mem_addr[23:8]) cache_valid[bank]<=0;
  end
  case(ws)
   IDLE:if(!clear && need_flush) begin
    write_bank<=active_bank;active_bank<=!active_bank;wb<=0;ws<=AW;
   end
   AW:if(awready) ws<=PREF;
   PREF:ws<=WD;
   WD:if(wready) begin
    if(wlast) ws<=BR;else wb<=wb+1'b1;
   end
   BR:if(bvalid) begin
    if(bresp!=0) failed<=1;
    mask[write_bank]<=0;ws<=IDLE;
   end
   default:ws<=IDLE;
  endcase
  case(state)
   IDLE:if(!clear && !flush && mem_valid && !mem_write && !hit && !hazard) begin
    fill_tag<=mem_addr[23:8];cache_tag[bank]<=mem_addr[23:8];
    cache_valid[bank]<=0;rb<=0;state<=AR;
   end
   AR:if(arready) state<=RD;
   RD:if(rvalid) begin
    if(rresp!=0 || rlast!=(rb==15)) failed<=1;
    cache_valid[fill_tag[14]][rb]<=1;
    if(rlast) state<=IDLE;else rb<=rb+1'b1;
   end
   default:state<=IDLE;
  endcase
 end
end
// synthesis translate_off
always @(posedge clk) if(rst_n) begin
 if(accept && (mem_addr[2:0]!=0 || mem_addr>=24'h600000)) $fatal(1,"CNN scratch bounds/alignment");
 if(ws!=IDLE && active_bank==write_bank) $fatal(1,"Write bank ownership collision");
 if(ws==IDLE && need_flush && |mask[!active_bank]) $fatal(1,"Reusing dirty write bank");
end
// synthesis translate_on
endmodule
