`timescale 1ns/1ps
module tb_r15u_system;
localparam W=64,H=24,OW=W/2,OH=H/2,DUAL_WINDOW=1,PHASE=3,REV=0;
localparam HFP=16,HSP=4,HBP=12,VFP=4,VSP=2,VBP=12;
localparam [31:0] BANK=32'h00400000;
localparam [15:0] GAIN_R=256,GAIN_G=256,GAIN_B=256;
reg pclk=0,aclk=0,hclk=0,vclk=0,cclk=0;always #3.5 cclk=~cclk;
always #10 pclk=~pclk;always #5 aclk=~aclk;always #3.367 hclk=~hclk;
always @(posedge hclk) vclk<=~vclk;
reg rst_n=0,prst_n=0,s_vs=0,s_hs=0,s_valid=0;reg [39:0] s_raw=0;
wire o_de,o_hs,o_vs;wire [7:0] o_r,o_g,o_b;
wire [5:0] awid,arid;wire [31:0] awaddr,araddr;wire [7:0] awlen,arlen;
wire [2:0] awsize,arsize,awprot,arprot;wire [1:0] awburst,arburst,bresp,rresp;
wire [3:0] awcache,arcache;
wire awlock,arlock,awvalid,awready,arvalid,arready;
wire [127:0] wdata,rdata;wire [15:0] wstrb;
wire wlast,wvalid,wready,rlast,rvalid,rready,bvalid,bready;
reg key_style_n=1;
reg hold_aw=0,hold_w=0,hold_b=0,hold_ar=0,hold_r=0,inject_b=0,inject_r=0;
reg [15:0] paddr=0;reg psel=0,penable=0,pwrite=0;reg [31:0] pwdata=0;
wire [31:0] prdata;wire pready,pslverror,irq;
cam_fb_pipe_v09 #(.DUAL_WINDOW(DUAL_WINDOW),.AXI_DATA_WIDTH(128),.AXI_ADDR_WIDTH(32),.START_ADDR(0),.BANK_BYTES(BANK),
 .MAX_IN_HEIGHT(H),.MAX_IN_WIDTH(W),.MAX_OUT_WIDTH(OW)) dut (
 .cnn_clk(cclk),.key_style_n(key_style_n),.flash_miso(1'b0),.flash_cs_n(),.flash_sck(),.flash_mosi(),.requested_layout(2'd0),.active_layout(),.o_display_rgb(),
 .accel_paddr(paddr),.accel_psel(psel),.accel_penable(penable),.accel_pwrite(pwrite),
 .accel_pwdata(pwdata),.accel_prdata(prdata),.accel_pready(pready),.accel_pslverror(pslverror),
 .accel_irq(irq),.process_toggle(),
       .diag_state(), .diag_fifo(), .diag_written(), .diag_completed(), .diag_published(), .diag_rejected(),
    .diag_bin_toggle(),
 .capture_toggle(),
 .cfg_bayer(PHASE[1:0]),.cfg_pix_rev(REV[0]),.cfg_gain_r(GAIN_R),.cfg_gain_g(GAIN_G),.cfg_gain_b(GAIN_B),
 .i_pclk(pclk),.i_pclk_rstn(prst_n),.i_vs(s_vs),.i_hs(s_hs),.i_valid(s_valid),.i_raw(s_raw),
 .H_FRONT_PORCH(HFP[12:0]),.H_SYNC(HSP[12:0]),.H_VALID(OW[12:0]),.H_BACK_PORCH(HBP[12:0]),
 .V_FRONT_PORCH(VFP[12:0]),.V_SYNC(VSP[12:0]),.V_VALID(H[12:0]),.V_BACK_PORCH(VBP[12:0]),
 .rst_n(rst_n),.o_clk(vclk),.o_hdmi_clk(hclk),.o_de(o_de),.o_hs(o_hs),.o_vs(o_vs),.o_r(o_r),.o_g(o_g),.o_b(o_b),
 .axi_clk(aclk),.awid(awid),.awaddr(awaddr),.awlen(awlen),.awsize(awsize),.awburst(awburst),
 .awcache(awcache),.awprot(awprot),.awlock(awlock),.awvalid(awvalid),.awready(awready),
 .arid(arid),.araddr(araddr),.arlen(arlen),.arsize(arsize),.arburst(arburst),
 .arcache(arcache),.arprot(arprot),.arlock(arlock),.arvalid(arvalid),.arready(arready),
 .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
 .rid(6'd0),.rdata(rdata),.rlast(rlast),.rvalid(rvalid),.rready(rready),.rresp(rresp),
 .bid(6'd0),.bvalid(bvalid),.bresp(bresp),.bready(bready));
axi_memory_v07 #(.WORDS_PER_BANK(OW*OH/4+512),.DW(128),.AW(32),.STALL_PCT(20),.RD_LAT(12)) u_mem (
 .clk(aclk),.rst_n(rst_n),.awaddr(awaddr),.awlen(awlen),.awsize(awsize),.awlock(awlock),.awburst(awburst),
 .awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),.araddr(araddr),.arlen(arlen),.arsize(arsize),.arlock(arlock),
 .arburst(arburst),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rlast(rlast),.rvalid(rvalid),.rready(rready),.rresp(rresp),
 .hold_aw(hold_aw),.hold_w(hold_w),.hold_b(hold_b),.hold_ar(hold_ar),.hold_r(hold_r),
 .inject_b_error(inject_b),.inject_r_error(inject_r));

task apb_write(input [15:0] addr,input [31:0] value);
 @(negedge aclk);paddr=addr;pwdata=value;psel=1;pwrite=1;
 @(negedge aclk);penable=1;
 // Complete only on a rising edge with PREADY already high. In particular,
 // reset release may raise PREADY just after an edge, before acceptance.
 @(posedge aclk);while(!pready) @(posedge aclk);if(pslverror) $fatal(1,"APB write failed");
 @(negedge aclk);psel=0;penable=0;pwrite=0;
endtask
int irqs=0,jobs=0,published=0;integer srcfile,dstfile;reg [127:0] tmp;
integer good_pixels=0;
integer frozen_capture,frozen_done,render_count;
initial begin
 srcfile=$fopen("work/r15u_system/system_input.hex","w");dstfile=$fopen("work/r15u_system/system_output.hex","w");
 repeat(20) @(negedge aclk);rst_n=1;prst_n=1;
 apb_write('h84,3);wait(irq);apb_write('h8c,1);
 for(integer round=0;round<3;round++)begin
  apb_write('hc0,1);apb_write('h84,3);wait(dut.freeze_valid);apb_write('h8c,1);apb_write('h84,3);
  frozen_capture=dut.diag_published;frozen_done=dut.u_accel_ctrl.completed;
  // Render all levels while original capture continues and CNN remains stopped.
  for(integer l=0;l<5;l++)begin
   render_count=dut.u_render_ctrl.count;
   apb_write('hd4,4+(l<<3));apb_write('hd0,1);
   wait(dut.u_render_ctrl.count==render_count+1);repeat(12000)@(negedge aclk);
   if(dut.u_accel_ctrl.completed!=frozen_done || !dut.source_locked)$fatal(1,"frozen inference restarted or original released");
  end
  if(dut.diag_published<=frozen_capture+2)$fatal(1,"capture stopped during freeze");
  if(round==1)begin force dut.u_accel_dma.style_status=32'h20;repeat(4)@(negedge aclk);release dut.u_accel_dma.style_status;end
  else apb_write('hc0,2);
  wait(!dut.freeze_busy);wait(irq);apb_write('h8c,1);
 end
 // Cancellation while an accepted output transaction is awaiting B.
 apb_write('hc0,1);apb_write('h84,3);wait(dut.freeze_valid);apb_write('h8c,1);apb_write('h84,3);
 render_count=dut.u_render_ctrl.count;apb_write('hd4,20);apb_write('hd0,1);
 wait(dut.u_render_ctrl.render.awvalid);@(negedge aclk);hold_b=1;
 apb_write('hc0,2);repeat(200)@(negedge aclk);
 if(!dut.source_locked || !dut.freeze_busy || !dut.render_active)$fatal(1,"exit abandoned renderer transaction");
 hold_b=0;wait(!dut.freeze_busy);
 if(dut.u_render_ctrl.count!=render_count)$fatal(1,"cancel published partial composition");
 apb_write('hd0,1);if(!dut.u_render_ctrl.rejected)$fatal(1,"live render command did not report rejected");
 if(good_pixels<OW*OH*10)$fatal(1,"display coverage short");
 if(dut.u_store.underflow_frames>1)$fatal(1,"steady display underflow");
 $display("TEST PASS r15u_system actual pipe/mux/FIFOs/scheduler, real CNN wrapper/CDC, engine transaction fixture; style request injected; jobs=%0d rendered=%0d captures=%0d pixels=%0d underflows=%0d",jobs,dut.u_render_ctrl.count,dut.diag_published,good_pixels,dut.u_store.underflow_frames);$finish;
end
always @(negedge aclk) if(rst_n) begin
 if(dut.start) begin
  jobs++;
  for(int n=0;n<OW*OH/4;n++) begin
   tmp=u_mem.rd_word((dut.src_addr>>4)+n);
   for(int q=0;q<4;q++) $fdisplay(srcfile,"%08x",tmp[q*32+:32]);
  end
 end
 if(dut.done) begin
  if(dut.failed) $fatal(1,"Unexpected shell failure");
  published++;
  for(int n=0;n<OW*OH/4;n++) begin
   tmp=u_mem.rd_word((dut.dst_addr>>4)+n);
   for(int q=0;q<4;q++) $fdisplay(dstfile,"%08x",tmp[q*32+:32]);
  end
 end
 if(awvalid && awready) begin
  if(awaddr<3*BANK) begin
   if(dut.source_locked && awaddr/BANK==dut.source_bank) $fatal(1,"Overwrite accel source");
   if(dut.u_store.read_active && awaddr/BANK==dut.u_store.read_bank) $fatal(1,"Overwrite display source");
  end else if(dut.display_active && (awaddr-3*BANK)/BANK==dut.display_bank)
    $fatal(1,"Overwrite displayed result");
 end
end
// Snapshot both display banks at the epoch selection, before any later reuse.
reg [31:0] expected[0:OW*OH*2-1];int snapshot_epoch=0;
always @(posedge aclk) if(rst_n && dut.u_store.rs==0 &&
 dut.u_store.requested_epoch!=dut.u_store.handled_epoch && dut.original_valid) begin
 snapshot_epoch=dut.u_store.requested_epoch;
 for(int y=0;y<OH;y++) for(int x=0;x<OW;x++) begin
  tmp=u_mem.rd_word((dut.u_store.selected_original*BANK+y*OW*4+x*4)>>4);
  expected[y*OW*2+x]=tmp[(x%4)*32+:32];
  tmp=u_mem.rd_word(((dut.styled_valid ? (3+(dut.render_valid?dut.render_bank:dut.styled_bank))*BANK : dut.u_store.selected_original*BANK)+y*OW*4+x*4)>>4);
  expected[y*OW*2+OW+x]=tmp[(x%4)*32+:32];
 end
end
int px=0,py=0,underflow_seen=0;reg de_prev=0;
always @(negedge hclk) if(dut.u_store.underflow_frames!=underflow_seen) begin
 underflow_seen=dut.u_store.underflow_frames;
 $display("UNDERFLOW time=%t epoch=%0d x=%0d y=%0d latest=%b words=%0d rs=%0d used=%0d q=%0d qepoch=%0d",
 $time,dut.u_store.display_epoch,px,py,dut.original_valid,dut.u_store.words_read,dut.u_store.rs,dut.u_store.rf_used,dut.u_store.qcount,dut.u_store.q0[159:128]);
end
always @(negedge hclk) begin
 if(dut.fb_vs) begin px=0;py=0;de_prev=0;end
 else begin
  if(dut.fb_de) begin
   if(py>=OH/2 && py<OH/2+OH && snapshot_epoch==dut.u_store.display_epoch && !dut.u_store.frame_bad) begin
    if(dut.fb_data!==expected[(py-OH/2)*OW*2+px])
      $fatal(1,"Display mismatch x=%0d y=%0d got=%08x expected=%08x",px,py,dut.fb_data,expected[(py-OH/2)*OW*2+px]);
    good_pixels++;
   end
   px++;
  end else begin if(de_prev) py++;px=0;end
  de_prev=dut.fb_de;
 end
end
initial begin
 wait(prst_n);repeat(20) @(negedge pclk);
 for(int f=1;f<=160;f++) begin
  s_vs=~s_vs;repeat(10) @(negedge pclk);
  for(int y=0;y<H;y++) begin
   for(int x=0;x<W;x+=4) begin
    @(negedge pclk);s_hs=1;s_valid=1;
    for(int q=0;q<4;q++) s_raw[q*10+:10]=((f*31+x+q+y*7)%220+10)*4;
   end
   @(negedge pclk);s_hs=0;s_valid=0;repeat(4) @(negedge pclk);
  end
  #50000;
 end
end
initial begin #20000000;$fatal(1,"system timeout");end
endmodule

