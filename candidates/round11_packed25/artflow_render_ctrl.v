// AXI-clock register bank and DDR ownership for frozen composition.
module artflow_render_ctrl #(parameter REQUIRE_GRANT=0,WIDTH=960,HEIGHT=540,BANK_BYTES=32'h400000,START_ADDR=0,TIMEOUT=200000000)(
 input wire local_grant,
 input wire clk,rst_n,input wire freeze_valid,input wire [1:0] original_bank,style_bank,
 input wire display_active,input wire [1:0] display_bank,
 input wire [15:0] paddr,input wire psel,penable,pwrite,input wire [31:0] pwdata,
 output reg [31:0] prdata,output wire pready,pslverror,
 output reg result_valid,output reg [1:0] result_bank,output wire active,
 output wire [31:0] araddr,output wire [7:0] arlen,output wire arvalid,input wire arready,
 input wire [127:0] rdata,input wire rvalid,rlast,input wire [1:0] rresp,output wire rready,
 output wire [31:0] awaddr,output wire [7:0] awlen,output wire awvalid,input wire awready,
 output wire [127:0] wdata,output wire [15:0] wstrb,output wire wvalid,wlast,input wire wready,
 input wire bvalid,input wire [1:0] bresp,output wire bready);
// Preserve the generic algorithm for every other legal parameter set.
localparam FIXED_READER=(BANK_BYTES%256==0) && (START_ADDR%256==0) && ((WIDTH*HEIGHT)%64==0);
reg [2:0] mode,level;reg [10:0] x0,y0,x1,y1,split_x;
reg pending,running,start,timeout_error,rejected;reg [1:0] target;reg [31:0] timer,count;
wire busy,done,failed;reg valid_addr,valid_write;reg free_valid;reg [1:0] free_bank;integer n;
assign active=pending || running || busy || start;
assign pready=rst_n;
assign pslverror=psel && penable && (!valid_addr || (pwrite && !valid_write));
always @* begin
 free_valid=0;free_bank=0;
 for(n=0;n<3;n=n+1)if(n!=style_bank && (!result_valid || n!=result_bank) && (!display_active || n!=display_bank))begin free_valid=1;free_bank=n;end
 prdata=0;valid_addr=1;valid_write=0;
 case(paddr)
 16'hd0:valid_write=pwdata==1;
 16'hd4:begin prdata={26'd0,level,mode};valid_write=!active && pwdata[31:6]==0 && pwdata[5:3]<=4 && (pwdata[2:0]<=2 || pwdata[2:0]==4);end
 16'hd8:begin prdata={5'd0,y0,5'd0,x0};valid_write=!active && pwdata[15:0]<=WIDTH && pwdata[31:16]<=HEIGHT;end
 16'hdc:begin prdata={5'd0,y1,5'd0,x1};valid_write=!active && pwdata[15:0]<=WIDTH && pwdata[31:16]<=HEIGHT;end
 16'he0:begin prdata={21'd0,split_x};valid_write=!active && pwdata<=WIDTH;end
 16'he4:prdata={24'd0,rejected,timeout_error,failed,result_bank,result_valid,running,pending};
 16'he8:prdata=count;
 default:valid_addr=0;
 endcase
end
always @(posedge clk or negedge rst_n)
 if(!rst_n)begin mode<=4;level<=4;x0<=240;y0<=135;x1<=720;y1<=405;split_x<=WIDTH/2;pending<=0;running<=0;start<=0;target<=0;timer<=0;count<=0;timeout_error<=0;rejected<=0;result_valid<=0;result_bank<=0;end
 else begin
 start<=0;
 if(!active)timer<=0;else if(timer<TIMEOUT)timer<=timer+1'b1;
 if(timer==TIMEOUT-1)timeout_error<=1;
 // A newly accepted idle retry takes priority over the old timeout latch.
 if(timeout_error)pending<=0;
 if(psel && penable && pwrite && !pslverror)case(paddr)
 16'hd0:begin
  rejected<=!freeze_valid || active;
  if(freeze_valid && !active)begin pending<=1;timeout_error<=0;end
 end
 16'hd4:begin mode<=pwdata[2:0];level<=pwdata[5:3];end
 16'hd8:begin x0<=pwdata[10:0];y0<=pwdata[26:16];end
 16'hdc:begin x1<=pwdata[10:0];y1<=pwdata[26:16];end
 16'he0:split_x<=pwdata[10:0];
 endcase
 if(pending && free_valid && freeze_valid && !timeout_error && (!REQUIRE_GRANT || local_grant))begin pending<=0;target<=free_bank;running<=1;start<=1;end
 if(done)begin
  running<=0;
  if(freeze_valid && !failed && !timeout_error)begin result_valid<=1;result_bank<=target;count<=count+1'b1;end
 end
 if(!freeze_valid)begin pending<=0;result_valid<=0;end
 end
artflow_pair_render #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.CONFIG_HELD(1),.FIXED_BURST(FIXED_READER),.PACKED_RGB25(1)) render(
 .clk(clk),.rst_n(rst_n),.start(start),.cancel(!freeze_valid || timeout_error),
 .original_base(START_ADDR+original_bank*BANK_BYTES),.style_base(START_ADDR+(3+style_bank)*BANK_BYTES),.result_base(START_ADDR+(3+target)*BANK_BYTES),
 .mode(mode),.level(level),.x0(x0),.y0(y0),.x1(x1),.y1(y1),.split_x(split_x),.busy(busy),.done(done),.failed(failed),
 .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rvalid(rvalid),.rlast(rlast),.rresp(rresp),.rready(rready),
 .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),.bvalid(bvalid),.bresp(bresp),.bready(bready));
// synthesis translate_off
reg cfg_active_q;reg [60:0] cfg_previous;
wire [60:0] cfg_bundle={mode,level,x0,y0,x1,y1,split_x};
always @(posedge clk or negedge rst_n)
 if(!rst_n)begin cfg_active_q<=0;cfg_previous<=0;end
 else begin
  if(cfg_active_q && cfg_bundle!==cfg_previous)$fatal(1,"protected render configuration changed while active/draining");
  cfg_active_q<=active;cfg_previous<=cfg_bundle;
 end
// synthesis translate_on
endmodule
