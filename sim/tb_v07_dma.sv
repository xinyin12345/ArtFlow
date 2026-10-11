`timescale 1ns/1ps
module tb_v07_dma;
parameter W=32,H=12,FAULT=0;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start=0;wire busy,done,failed;wire [31:0] cycles;
wire [31:0] awaddr,araddr;wire [7:0] awlen,arlen;
wire awvalid,awready,wvalid,wready,wlast,bvalid,bready,arvalid,arready,rvalid,rready,rlast;
wire [127:0] wdata,rdata;wire [15:0] wstrb;wire [1:0] bresp,rresp;
artflow_accel_dma #(.WIDTH(W),.HEIGHT(H),.BURST(64)) dut(
 .clk(clk),.rst_n(rst_n),.start(start),.src_addr(32'hff0),.dst_addr(32'h400ff0),
 .busy(busy),.done(done),.failed(failed),.cycles(cycles),
 .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),
 .wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),
 .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
 .rdata(rdata),.rvalid(rvalid),.rlast(rlast),.rresp(rresp),.rready(rready));
axi_memory_v07 #(.WORDS_PER_BANK(W*H/4+512),.STALL_PCT(35),.RD_LAT(7)) mem(
 .clk(clk),.rst_n(rst_n),.awaddr(awaddr),.awlen(awlen),.awsize(3'd4),.awburst(2'd1),.awlock(1'b0),
 .awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),.araddr(araddr),.arlen(arlen),.arsize(3'd4),.arburst(2'd1),.arlock(1'b0),
 .arvalid(arvalid),.arready(arready),.rdata(rdata),.rvalid(rvalid),.rresp(rresp),.rlast(rlast),.rready(rready),
 .hold_aw(1'b0),.hold_w(1'b0),.hold_b(1'b0),.hold_ar(1'b0),.hold_r(1'b0),
 .inject_b_error(FAULT==1),.inject_r_error(FAULT==2));
reg [31:0] pixels[0:W*H-1],golden[0:W*H-1];
integer fd;reg [127:0] word;
initial begin
 $readmemh("input.hex",pixels);$readmemh("golden.hex",golden);
 for(int i=0;i<W*H/4;i++) mem.set_word((32'hff0>>4)+i,{pixels[i*4+3],pixels[i*4+2],pixels[i*4+1],pixels[i*4]});
 repeat(10) @(negedge clk);rst_n=1;repeat(5) @(negedge clk);start=1;@(negedge clk);start=0;
 wait(done);@(negedge clk);
 if(failed !== (FAULT!=0)) $fatal(1,"Error propagation failed");
 for(int i=0;i<W*H/4;i++) begin
  word=mem.rd_word((32'h400ff0>>4)+i);
  for(int j=0;j<4;j++) if(word[j*32+:32]!==golden[i*4+j])
    $fatal(1,"Pixel %0d got %08x expected %08x",i*4+j,word[j*32+:32],golden[i*4+j]);
 end
 $display("tb_v07_dma PASS pixels=%0d cycles=%0d fault=%0d",W*H,cycles,FAULT);$finish;
end
initial begin #200000000; $fatal(1,"timeout");end
endmodule
