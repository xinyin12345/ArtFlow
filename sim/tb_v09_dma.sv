`timescale 1ns/1ps
module tb_v09_dma;
parameter W=32,H=28,N=1,FRAMES=2,FAULT=0;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start=0;wire busy,done,failed;wire [31:0] cycles;
wire [31:0] awaddr,araddr;wire [7:0] awlen,arlen;
wire awvalid,awready,wvalid,wready,wlast,bvalid,bready,arvalid,arready,rvalid,rready,rlast;
wire [127:0] wdata,rdata;wire [15:0] wstrb;wire [1:0] bresp,rresp;
artflow_cnn_dma #(.WIDTH(W),.HEIGHT(H)) dut(
 .clk(clk),.rst_n(rst_n),.start(start),.src_addr(32'hff0),.dst_addr(32'hc00ff0),
 .busy(busy),.done(done),.failed(failed),.cycles(cycles),
 .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),
 .wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),
 .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
 .rdata(rdata),.rvalid(rvalid),.rlast(rlast),.rresp(rresp),.rready(rready));
axi_memory_v09 #(.STALL_PCT(25),.RD_LAT(12)) mem(
 .clk(clk),.rst_n(rst_n),.awaddr(awaddr),.awlen(awlen),.awsize(3'd4),.awburst(2'd1),.awlock(1'b0),
 .awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),.araddr(araddr),.arlen(arlen),.arsize(3'd4),.arburst(2'd1),.arlock(1'b0),
 .arvalid(arvalid),.arready(arready),.rdata(rdata),.rvalid(rvalid),.rresp(rresp),.rlast(rlast),.rready(rready),
 .hold_aw(1'b0),.hold_w(1'b0),.hold_b(1'b0),.hold_ar(1'b0),.hold_r(1'b0),
 .inject_b_error(FAULT==1 || (FAULT==3 && dut.select_cnn)),
 .inject_r_error(FAULT==2 || (FAULT==4 && dut.select_cnn)));
reg [31:0] pixels[0:W*H-1],golden[0:W*H-1];
reg [63:0] prepared[0:W*H/4-1],features[0:N-1];
reg [23:0] addresses[0:N-1];
reg [127:0] word;integer writes=0,frame=0;string folder;
always @(posedge clk) if(rst_n) begin
 if(dut.state==3 && FAULT==0) begin
  for(integer i=0;i<W*H/8;i=i+1) begin
   word=mem.rd_word((32'h1800000>>4)+i);
   if(word!=={prepared[2*i+1],prepared[2*i]}) $fatal(1,"prepare pixel mismatch %0d %h",i,word);
  end
 end
 if(dut.mv && dut.mready && dut.mw && (FAULT==0 || FAULT==3 || FAULT==4)) begin
  if(writes>=N || dut.ma!==addresses[writes] || dut.mwd!==features[writes])
   $fatal(1,"feature mismatch layer=%0d write=%0d addr=%h got=%h want=%h",dut.core.layer_index,writes,dut.ma,dut.mwd,features[writes]);
  writes=writes+1;
 end
 if(dut.core.layer_done) begin $display("LAYER next=%0d cycles=%0d",dut.core.layer_index,cycles);$fflush();end
end
initial begin
 if(!$value$plusargs("DIR=%s",folder)) $fatal(1,"missing vectors DIR");
 $readmemh({folder,"/input.hex"},pixels);$readmemh({folder,"/golden.hex"},golden);
 $readmemh({folder,"/prepared.hex"},prepared);$readmemh({folder,"/features.hex"},features);$readmemh({folder,"/addresses.hex"},addresses);
 for(int i=0;i<W*H/4;i++) mem.set_word((32'hff0>>4)+i,{pixels[i*4+3],pixels[i*4+2],pixels[i*4+1],pixels[i*4]});
 repeat(10) @(negedge clk);rst_n=1;
 for(frame=0;frame<FRAMES;frame=frame+1) begin
  writes=0;repeat(5) @(negedge clk);start=1;@(negedge clk);start=0;
  wait(done);@(negedge clk);
  if(failed !== (FAULT!=0)) $fatal(1,"Error propagation failed");
  if(FAULT==0) begin
   if(writes!=N || !dut.drained) $fatal(1,"early completion or wrong feature count");
   for(int i=0;i<W*H/4;i++) begin
    word=mem.rd_word((32'hc00ff0>>4)+i);
    for(int j=0;j<4;j++) if(word[j*32+:32]!==golden[i*4+j])
     $fatal(1,"Pixel %0d got %08x expected %08x",i*4+j,word[j*32+:32],golden[i*4+j]);
   end
  end
  $display("FRAME PASS frame=%0d pixels=%0d features=%0d cycles=%0d fault=%0d",frame,W*H,writes,cycles,FAULT);$fflush();
 end
 $display("tb_v09_dma PASS");$finish;
end
initial begin #2000000000; $fatal(1,"timeout state=%0d bridge=%0d",dut.state,dut.bridge.state);end
endmodule
