`timescale 1ns/1ps
module tb_v09_dma;
parameter W=32,H=28,N=1,FRAMES=2,FAULT=0,STALL_PCT=25,RD_LAT=12,VIDEO_LOAD=0;
parameter real CNN_HALF_NS=2.25;
reg cnn_clk=0;always #(CNN_HALF_NS) cnn_clk=~cnn_clk;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start=0;wire busy,done,failed;wire [31:0] cycles;
wire [31:0] awaddr,araddr;wire [7:0] awlen,arlen;
wire awvalid,awready,wvalid,wready,wlast,bvalid,bready,arvalid,arready,rvalid,rready,rlast;
wire [127:0] wdata,rdata;wire [15:0] wstrb;wire [1:0] bresp,rresp;
artflow_cnn_accel #(.WIDTH(W),.HEIGHT(H)) dut(
 .clk(clk),.cnn_clk(cnn_clk),.rst_n(rst_n),.start(start),.source_consumed(),.src_addr(32'hff0),.dst_addr(32'hc00ff0),
 .busy(busy),.done(done),.failed(failed),.cycles(cycles),
 .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),
 .wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),
 .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
 .rdata(rdata),.rvalid(rvalid),.rlast(rlast),.rresp(rresp),.rready(rready));
wire [31:0] v_awaddr;
wire [7:0] v_awlen;
wire v_awvalid;
wire v_awready;
wire [127:0] v_wdata;
wire [15:0] v_wstrb;
wire v_wvalid;
wire v_wlast;
wire v_wready;
wire v_bvalid;
wire [1:0] v_bresp;
wire v_bready;
wire [31:0] v_araddr;
wire [7:0] v_arlen;
wire v_arvalid;
wire v_arready;
wire [127:0] v_rdata;
wire v_rvalid;
wire [1:0] v_rresp;
wire v_rlast;
wire v_rready;
wire [31:0] m_awaddr;
wire [7:0] m_awlen;
wire m_awvalid;
wire m_awready;
wire [127:0] m_wdata;
wire [15:0] m_wstrb;
wire m_wvalid;
wire m_wlast;
wire m_wready;
wire m_bvalid;
wire [1:0] m_bresp;
wire m_bready;
wire [31:0] m_araddr;
wire [7:0] m_arlen;
wire m_arvalid;
wire m_arready;
wire [127:0] m_rdata;
wire m_rvalid;
wire [1:0] m_rresp;
wire m_rlast;
wire m_rready;
axi_background_v09 #(.ENABLE(VIDEO_LOAD)) background(.clk(clk),.rst_n(rst_n),
 .awaddr(v_awaddr),
 .awlen(v_awlen),
 .awvalid(v_awvalid),
 .awready(v_awready),
 .wdata(v_wdata),
 .wstrb(v_wstrb),
 .wvalid(v_wvalid),
 .wlast(v_wlast),
 .wready(v_wready),
 .bvalid(v_bvalid),
 .bresp(v_bresp),
 .bready(v_bready),
 .araddr(v_araddr),
 .arlen(v_arlen),
 .arvalid(v_arvalid),
 .arready(v_arready),
 .rdata(v_rdata),
 .rvalid(v_rvalid),
 .rresp(v_rresp),
 .rlast(v_rlast),
 .rready(v_rready));
artflow_axi_mux mux(.clk(clk),.rst_n(rst_n),
 .v_awaddr(v_awaddr),
 .v_awlen(v_awlen),
 .v_awvalid(v_awvalid),
 .v_awready(v_awready),
 .v_wdata(v_wdata),
 .v_wstrb(v_wstrb),
 .v_wvalid(v_wvalid),
 .v_wlast(v_wlast),
 .v_wready(v_wready),
 .v_bvalid(v_bvalid),
 .v_bresp(v_bresp),
 .v_bready(v_bready),
 .v_araddr(v_araddr),
 .v_arlen(v_arlen),
 .v_arvalid(v_arvalid),
 .v_arready(v_arready),
 .v_rdata(v_rdata),
 .v_rvalid(v_rvalid),
 .v_rresp(v_rresp),
 .v_rlast(v_rlast),
 .v_rready(v_rready),
 .a_awaddr(awaddr),
 .a_awlen(awlen),
 .a_awvalid(awvalid),
 .a_awready(awready),
 .a_wdata(wdata),
 .a_wstrb(wstrb),
 .a_wvalid(wvalid),
 .a_wlast(wlast),
 .a_wready(wready),
 .a_bvalid(bvalid),
 .a_bresp(bresp),
 .a_bready(bready),
 .a_araddr(araddr),
 .a_arlen(arlen),
 .a_arvalid(arvalid),
 .a_arready(arready),
 .a_rdata(rdata),
 .a_rvalid(rvalid),
 .a_rresp(rresp),
 .a_rlast(rlast),
 .a_rready(rready),
 .awaddr(m_awaddr),
 .awlen(m_awlen),
 .awvalid(m_awvalid),
 .awready(m_awready),
 .wdata(m_wdata),
 .wstrb(m_wstrb),
 .wvalid(m_wvalid),
 .wlast(m_wlast),
 .wready(m_wready),
 .bvalid(m_bvalid),
 .bresp(m_bresp),
 .bready(m_bready),
 .araddr(m_araddr),
 .arlen(m_arlen),
 .arvalid(m_arvalid),
 .arready(m_arready),
 .rdata(m_rdata),
 .rvalid(m_rvalid),
 .rresp(m_rresp),
 .rlast(m_rlast),
 .rready(m_rready));
axi_memory_v09 #(.STALL_PCT(STALL_PCT),.RD_LAT(RD_LAT)) mem(
 .clk(clk),.rst_n(rst_n),.awaddr(m_awaddr),.awlen(m_awlen),.awsize(3'd4),.awburst(2'd1),.awlock(1'b0),
 .awvalid(m_awvalid),.awready(m_awready),.wdata(m_wdata),.wstrb(m_wstrb),.wvalid(m_wvalid),.wlast(m_wlast),.wready(m_wready),
 .bvalid(m_bvalid),.bresp(m_bresp),.bready(m_bready),.araddr(m_araddr),.arlen(m_arlen),.arsize(3'd4),.arburst(2'd1),.arlock(1'b0),
 .arvalid(m_arvalid),.arready(m_arready),.rdata(m_rdata),.rvalid(m_rvalid),.rresp(m_rresp),.rlast(m_rlast),.rready(m_rready),
 .hold_aw(1'b0),.hold_w(1'b0),.hold_b(1'b0),.hold_ar(1'b0),.hold_r(1'b0),
 .inject_b_error(FAULT==1 || (FAULT==3 && dut.engine.select_cnn)),
 .inject_r_error(FAULT==2 || (FAULT==4 && dut.engine.select_cnn)));
reg [31:0] pixels[0:W*H-1],golden[0:W*H-1];
reg [63:0] prepared[0:W*H/4-1],features[0:N-1];
reg [23:0] addresses[0:N-1];
reg [127:0] word;integer writes=0,frame=0,glass_fd;string folder;
integer perf_reads=0,perf_writes=0,perf_ar=0,perf_aw=0,perf_stall=0,perf_skipwait=0,perf_run=0;
reg [3:0] perf_phase=0;
longint unsigned wall_cycles=0,last_complete=0;
integer completions=0;
always @(posedge clk)wall_cycles<=wall_cycles+1;
// Observe the actual completion edge, including the final frame before finish.
always @(posedge done)if(rst_n)begin
 if(completions>0)$display("FRAME_INTERVAL index=%0d axi_cycles=%0d",completions,wall_cycles-last_complete);
 last_complete=wall_cycles;completions=completions+1;
end
always @(posedge cnn_clk) if(dut.crst_n) begin
 if(dut.engine.state!=perf_phase) begin
  $display("PHASE state=%0d cycles=%0d",dut.engine.state,cycles);
  perf_phase<=dut.engine.state;
 end
 if(dut.engine.select_cnn) begin
  if(dut.engine.mv && dut.engine.mready) begin
   if(dut.engine.mw) perf_writes=perf_writes+1; else perf_reads=perf_reads+1;
  end
  if(dut.engine.c_arvalid && dut.engine.arready) perf_ar=perf_ar+1;
  if(dut.engine.c_awvalid && dut.engine.awready) perf_aw=perf_aw+1;
  if(dut.engine.mv && !dut.engine.mready) perf_stall=perf_stall+1;
  if(dut.engine.core.state==dut.engine.core.RUN && dut.engine.core.fs==dut.engine.core.F_LOAD) perf_skipwait=perf_skipwait+1;
  if(dut.engine.state==4) perf_run=perf_run+1;
 end
 if(dut.engine.core.layer_done) begin
  $display("PERF reads=%0d writes=%0d ar=%0d aw=%0d stalled=%0d row_wait=%0d cnn_cycles=%0d",perf_reads,perf_writes,perf_ar,perf_aw,perf_stall,perf_skipwait,perf_run);
  perf_reads=0;perf_writes=0;perf_ar=0;perf_aw=0;perf_stall=0;perf_skipwait=0;perf_run=0;
 end
 if(dut.engine.state==3) begin
  perf_reads=0;perf_writes=0;perf_ar=0;perf_aw=0;perf_stall=0;perf_skipwait=0;perf_run=0;
 end
end
always @(posedge cnn_clk) if(dut.crst_n) begin
 if(dut.engine.state==3 && FAULT==0) begin
  for(integer i=0;i<W*H/8;i=i+1) begin
   word=mem.rd_word((32'h1800000>>4)+i);
   if(word!=={prepared[2*i+1],prepared[2*i]}) $fatal(1,"prepare pixel mismatch %0d %h",i,word);
  end
 end
 if(dut.engine.mv && dut.engine.mready && dut.engine.mw && (FAULT==0 || FAULT==3 || FAULT==4)) begin
  if(writes>=N || dut.engine.ma!==addresses[writes] || dut.engine.mwd!==features[writes])
   $fatal(1,"feature mismatch layer=%0d write=%0d addr=%h got=%h want=%h",dut.engine.core.layer_index,writes,dut.engine.ma,dut.engine.mwd,features[writes]);
  if(dut.engine.core.layer_index==21 && frame==0)$fdisplay(glass_fd,"%016h",dut.engine.mwd);
  writes=writes+1;
 end
 if(dut.engine.core.layer_done) begin $display("LAYER next=%0d cycles=%0d",dut.engine.core.layer_index,cycles);$fflush();end
end
initial begin
 if(!$value$plusargs("DIR=%s",folder)) $fatal(1,"missing vectors DIR");
 glass_fd=$fopen({folder,"/rtl_model.hex"},"w");
 $readmemh({folder,"/input.hex"},pixels);$readmemh({folder,"/golden.hex"},golden);
 $readmemh({folder,"/prepared.hex"},prepared);$readmemh({folder,"/features.hex"},features);$readmemh({folder,"/addresses.hex"},addresses);
 for(int i=0;i<W*H/4;i++) mem.set_word((32'hff0>>4)+i,{pixels[i*4+3],pixels[i*4+2],pixels[i*4+1],pixels[i*4]});
 for(int i=0;i<64;i++)mem.set_word((32'h800000>>4)+i,128'd0);
 repeat(10) @(negedge clk);rst_n=1;
 for(frame=0;frame<FRAMES;frame=frame+1) begin
  writes=0;repeat(5) @(negedge clk);start=1;@(negedge clk);start=0;
  wait(done);@(negedge clk);
  if(failed !== (FAULT!=0)) $fatal(1,"Error propagation failed");
  if(FAULT==0) begin
   if(writes!=N || !dut.engine.drained) $fatal(1,"early completion or wrong feature count");
   for(int i=0;i<W*H/4;i++) begin
    word=mem.rd_word((32'hc00ff0>>4)+i);
    for(int j=0;j<4;j++) if(word[j*32+:32]!==golden[i*4+j])
     $fatal(1,"Pixel %0d got %08x expected %08x",i*4+j,word[j*32+:32],golden[i*4+j]);
   end
  end
  $display("FRAME PASS frame=%0d pixels=%0d features=%0d cycles=%0d fault=%0d",frame,W*H,writes,cycles,FAULT);$fflush();
 end
 $display("TRAFFIC read_beats=%0d write_beats=%0d",background.read_beats,background.write_beats);
 $fclose(glass_fd);$display("tb_v09_dma PASS");$finish;
end
initial begin #2000000000; $fatal(1,"timeout state=%0d bridge=%0d",dut.engine.state,dut.engine.bridge.state);end
endmodule

