// Frozen pair -> display RGB composition in an unused DDR bank.
// One write beat at a time, held through B. No new pixel-domain FIFO.
module artflow_pair_render #(parameter WIDTH=960,HEIGHT=540,CONFIG_HELD=0,FIXED_BURST=0,PACKED_RGB25=0)(
 input logic clk,rst_n,start,cancel,input logic [31:0] original_base,style_base,result_base,
 input logic [2:0] mode,level,input logic [10:0] x0,y0,x1,y1,split_x,
 output wire busy,output logic done,failed,
 output wire [31:0] araddr,output wire [7:0] arlen,output wire arvalid,input wire arready,
 input wire [127:0] rdata,input wire rvalid,rlast,input wire [1:0] rresp,output wire rready,
 output wire [31:0] awaddr,output wire [7:0] awlen,output wire awvalid,input wire awready,
 output wire [127:0] wdata,output wire [15:0] wstrb,output wire wvalid,wlast,input wire wready,
 input wire bvalid,input wire [1:0] bresp,output wire bready);
localparam IDLE=0,INPUT=1,PIXEL=2,AW=3,W=4,B=5,DRAIN=6,FIN=7;
logic [2:0] state;logic reader_start,aborted,read_finished;
wire rb,rd,rf,pv;wire [31:0] ip,sp;wire [10:0] px,py;
wire cancel_read=cancel || aborted || failed;
wire take=pv && state==INPUT && !cancel_read;
logic [2:0] m,l;logic [10:0] a,b,c,d,s;
// Integrated parent rejects configuration writes throughout active/drain.
// Default keeps the standalone start-edge snapshot contract.
generate if(CONFIG_HELD)begin:held_config
 always_comb begin m=mode;l=level;a=x0;b=y0;c=x1;d=y1;s=split_x;end
end else begin:snapshot_config
 always_ff @(posedge clk or negedge rst_n)
  if(!rst_n)begin m<=0;l<=0;a<=0;b<=0;c<=0;d<=0;s<=0;end
  else if(state==IDLE && start)begin m<=mode;l<=level;a<=x0;b<=y0;c<=x1;d<=y1;s<=split_x;end
end endgenerate

logic [31:0] base,offset;logic [127:0] pixel_word;logic [1:0] lane;
wire nd,bd;wire [10:0] nx,ny;wire [23:0] ni,ns,rgb;
artflow_pair_reader #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.FIXED_BURST(FIXED_BURST),.PACKED_RGB25(PACKED_RGB25)) reader(.clk(clk),.rst_n(rst_n),.start(reader_start),.cancel(cancel_read),.original_base(original_base),.style_base(style_base),.busy(rb),.done(rd),.failed(rf),.araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rvalid(rvalid),.rlast(rlast),.rresp(rresp),.rready(rready),.valid(pv),.ready(state==INPUT && !cancel_read),.original_pixel(ip),.style_pixel(sp),.x(px),.y(py));
artflow_pair_normalize norm(.clk(clk),.rst_n(rst_n),.de(take),.hs(1'b0),.vs(1'b0),.x(px),.y(py),.original_pixel(ip),.style_pixel(sp),.ode(nd),.ohs(),.ovs(),.ox(nx),.oy(ny),.original_rgb(ni),.style_rgb(ns));
artflow_interact_blend blend(.clk(clk),.rst_n(rst_n),.de(nd),.hs(1'b0),.vs(1'b0),.x(nx),.y(ny),.original_rgb(ni),.style_rgb(ns),.mode(m),.level(l),.mask(1'b0),.x0(a),.y0(b),.x1(c),.y1(d),.split_x(s),.ode(bd),.ohs(),.ovs(),.ox(),.oy(),.rgb(rgb));
assign busy=state!=IDLE;
assign awaddr=base+offset;assign awlen=0;assign awvalid=state==AW;
assign wdata=pixel_word;assign wstrb=16'hffff;assign wlast=1;assign wvalid=state==W;assign bready=state==B;
always_ff @(posedge clk or negedge rst_n)
 if(!rst_n)begin state<=IDLE;done<=0;failed<=0;reader_start<=0;aborted<=0;read_finished<=0;base<=0;offset<=0;pixel_word<=0;lane<=0;end
 else begin
 done<=0;reader_start<=0;
 if(rd)begin read_finished<=1;if(rf)failed<=1;end
 if(cancel && busy)aborted<=1;
 case(state)
 IDLE:if(start)begin
  failed<=0;aborted<=0;read_finished<=0;base<=result_base;offset<=0;lane<=0;
  if(result_base[3:0]!=0 || result_base==original_base || result_base==style_base)begin failed<=1;state<=FIN;end
  else begin reader_start<=1;state<=INPUT;end
 end
 INPUT:if(cancel_read || (rd && rf))state<=DRAIN;
 else if(take)state<=PIXEL;
 else if(read_finished && !rb)state<=FIN;
 PIXEL:if(cancel_read)state<=DRAIN;
 else if(bd)begin
  pixel_word[lane*32+:32]<={8'h01,rgb};lane<=lane+1'b1;
  if(lane==3)state<=AW;else state<=INPUT;
 end
 // Never withdraw AWVALID or abandon accepted write transactions on cancellation.
 AW:if(awready)state<=W;
 W:if(wready)state<=B;
 B:if(bvalid)begin
  if(bresp!=0)failed<=1;
  offset<=offset+16;
  if(cancel_read || bresp!=0)state<=DRAIN;else state<=INPUT;
 end
 DRAIN:if(!rb && !reader_start)state<=FIN;
 FIN:begin done<=1;state<=IDLE;end
 endcase
 end
endmodule
