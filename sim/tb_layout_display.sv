`timescale 1ns/1ps
module tb_layout_display #(parameter W=64,H=32);
localparam BANK=32'h00400000;
reg iclk=0,aclk=0,hclk=0,rst=0,ivs=0,ivalid=0,key=1;
always #10 iclk=~iclk;
always #5 aclk=~aclk;
always #3.367 hclk=~hclk;
reg [63:0] idata=0;
wire [1:0] requested,layout;
wire de,hs,vs;wire [31:0] data;
reg osd_key=1;
wire osd_enable;
artflow_ui #(.DEBOUNCE_CYCLES(4)) u_ui(.clk(hclk),.rst_n(rst),.key_mode_n(key),.key_osd_n(osd_key),
 .capture_toggle(1'b0),.i_vs(vs),.mode(requested),.osd_enable(osd_enable),.capture_bcd(),.display_bcd(),.fps_valid());
wire [31:0] awaddr,araddr;wire [7:0] awlen,arlen;
wire awvalid,awready,wlast,wvalid,wready,bvalid,bready,arvalid,arready,rlast,rvalid,rready;
wire [127:0] wdata,rdata;wire [15:0] wstrb;wire [1:0] bresp,rresp;
wire original_valid,display_active;wire [1:0] original_bank,display_bank;
rgb_frame_store_v07 #(.WIDTH(W),.HEIGHT(H)) dut(
 .rst_n(rst),.i_clk(iclk),.i_vs(ivs),.i_valid(ivalid),.i_data(idata),
 .o_clk(hclk),.requested_layout(requested),.active_layout(layout),
 .H_FRONT_PORCH(13'd88),.H_SYNC(13'd44),.H_VALID(13'(W*2)),.H_BACK_PORCH(13'd148),
 .V_FRONT_PORCH(13'd4),.V_SYNC(13'd5),.V_VALID(13'(H*2)),.V_BACK_PORCH(13'd36),
 .o_de(de),.o_hs(hs),.o_vs(vs),.o_data(data),.capture_toggle(),
 .diag_state(),.diag_fifo(),.diag_written(),.diag_completed(),.diag_published(),.diag_rejected(),
 .source_locked(1'b0),.source_bank(2'd0),.original_valid(original_valid),.original_bank(original_bank),
 .styled_valid(1'b1),.styled_bank(2'd0),.display_active(display_active),.display_bank(display_bank),
 .axi_clk(aclk),.awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),
 .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),.araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
 .rdata(rdata),.rlast(rlast),.rvalid(rvalid),.rresp(rresp),.rready(rready));
axi_memory_v07 #(.STALL_PCT(25),.RD_LAT(12)) mem(
 .clk(aclk),.rst_n(rst),.awaddr(awaddr),.awlen(awlen),.awsize(3'd4),.awburst(2'd1),.awlock(1'b0),
 .awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),.araddr(araddr),.arlen(arlen),.arsize(3'd4),.arburst(2'd1),.arlock(1'b0),
 .arvalid(arvalid),.arready(arready),.rdata(rdata),.rlast(rlast),.rvalid(rvalid),.rresp(rresp),.rready(rready),
 .hold_aw(1'b0),.hold_w(1'b0),.hold_b(1'b0),.hold_ar(1'b0),.hold_r(1'b0),.inject_b_error(1'b0),.inject_r_error(1'b0));
function automatic [31:0] pix(input int x,y,styled);
 return (styled<<24) | (((x*3+y*7+styled*97)%256)<<16) | (((x*11+y+styled*31)%256)<<8) | ((x+y*13+styled*17)%256);
endfunction
reg [127:0] word;
integer checked[0:2];int frames[0:2];int x=0,y=0;bit lastde=0,lastvs=0;
int frame_pixels=0;reg [1:0] frame_layout;reg [31:0] expected;
always @(negedge hclk) if(rst) begin
 if(vs && !lastvs) begin
  if(frame_pixels>0) begin
   if(frame_pixels!=2*W*2*H) $fatal(1,"Incomplete raster %d",frame_pixels);
   frames[frame_layout]++;$display("LAYOUT FRAME PASS mode=%0d pixels=%0d epoch=%0d",frame_layout,frame_pixels,dut.display_epoch-1);
  end
  x=0;y=0;lastde=0;frame_pixels=0;frame_layout=layout;
 end
 lastvs=vs;
 if(!vs) begin
  if(de) begin
   if(original_valid && dut.display_epoch>2) begin
    if(layout!==frame_layout) $fatal(1,"Mid-frame layout change");
    if(dut.frame_bad) $fatal(1,"Steady state underflow mode=%0d x=%0d y=%0d",layout,x,y);
    if(layout==0) expected=(y<H/2 || y>=H/2+H)?0:pix(x%W,y-H/2,x>=W);
    else expected=pix(x/2,y/2,layout==1);
    if(data!==expected) $fatal(1,"Pixel mode=%0d x=%0d y=%0d got=%08x expected=%08x",layout,x,y,data,expected);
    checked[layout]++;frame_pixels++;
   end
   x++;
  end else begin if(lastde)y++;x=0;end
  lastde=de;
 end
end
always @(posedge aclk) if(rst && arvalid && arready) begin
 if((araddr%BANK)+(int'(arlen)+1)*16>W*H*4) $fatal(1,"Read outside frame");
 if(araddr/BANK!=0 && araddr/BANK!=3) $fatal(1,"Wrong pinned bank");
 if(dut.read_layout==1 && araddr/BANK!=3) $fatal(1,"Styled fullscreen wrong source");
 if(dut.read_layout==2 && araddr/BANK!=0) $fatal(1,"Original fullscreen wrong source");
end
task press;
 // Press during active video, with initial bounce, then long hold and release.
 wait(de);repeat(13) @(negedge hclk);
 key=0;repeat(2) @(negedge hclk);key=1;repeat(8) @(negedge hclk);
 key=0;repeat(100) @(negedge hclk);key=1;repeat(12) @(negedge hclk);
endtask
initial begin
 for(int n=0;n<3;n++)begin checked[n]=0;frames[n]=0;end
 for(int yy=0;yy<H;yy++)for(int xx=0;xx<W;xx+=4)begin
  for(int q=0;q<4;q++)word[q*32+:32]=pix(xx+q,yy,1);
  mem.set_word((3*BANK+yy*W*4+xx*4)>>4,word);
 end
 repeat(30)@(negedge iclk);rst=1;repeat(30)@(negedge iclk);
 ivs=1;repeat(10)@(negedge iclk);
 for(int yy=0;yy<H;yy++)for(int xx=0;xx<W;xx+=2)begin
  idata={pix(xx+1,yy,0),pix(xx,yy,0)};ivalid=1;@(negedge iclk);
 end
 ivalid=0;
 wait(frames[0]>=2);press();wait(frames[1]>=2);
 if(requested!=1)$fatal(1,"Long hold repeats");
 press();wait(frames[2]>=2);press();wait(frames[0]>=4);
 if(requested!=0)$fatal(1,"Three-state wrap");
 $display("tb_layout_display PASS W=%0d H=%0d checked=%0d/%0d/%0d frames=%0d/%0d/%0d",W,H,checked[0],checked[1],checked[2],frames[0],frames[1],frames[2]);$finish;
end
initial begin #300000000;$fatal(1,"Layout timeout");end
endmodule
