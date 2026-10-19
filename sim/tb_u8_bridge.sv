`timescale 1ns/1ps
module tb_u8_bridge;
reg clk=0;always #3.5 clk=~clk;
reg rst_n=0,clear=0,flush=0,mv=0,mw=0;
reg [23:0] ma=0;reg [63:0] md=0;wire mr,mrv;wire [63:0] mrd;
wire drained,failed;wire [31:0] araddr,awaddr;wire [7:0] arlen,awlen;
wire arvalid,arready,rvalid,rlast,rready,awvalid,awready,wvalid,wlast,wready,bvalid,bready;
wire [127:0] rdata,wdata;wire [15:0] wstrb;wire [1:0] rresp,bresp;
reg hold_b=0,inject_b=0,inject_r=0;
artflow_cnn_bridge dut(.clk(clk),.rst_n(rst_n),.clear(clear),.flush(flush),.drained(drained),.failed(failed),
 .mem_valid(mv),.mem_write(mw),.mem_addr(ma),.mem_wdata(md),.mem_ready(mr),.mem_rvalid(mrv),.mem_rdata(mrd),
 .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rvalid(rvalid),.rlast(rlast),.rresp(rresp),.rready(rready),
 .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready));
axi_memory_v09 #(.STALL_PCT(55),.RD_LAT(27)) mem(
 .clk(clk),.rst_n(rst_n),.awaddr(awaddr),.awlen(awlen),.awsize(3'd4),.awburst(2'd1),.awlock(1'b0),
 .awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),.araddr(araddr),.arlen(arlen),.arsize(3'd4),.arburst(2'd1),.arlock(1'b0),
 .arvalid(arvalid),.arready(arready),.rdata(rdata),.rlast(rlast),.rvalid(rvalid),.rresp(rresp),.rready(rready),
 .hold_aw(1'b0),.hold_w(1'b0),.hold_b(hold_b),.hold_ar(1'b0),.hold_r(1'b0),.inject_b_error(inject_b),.inject_r_error(inject_r));
reg [63:0] expected[0:1535];reg [127:0] word;
integer seed=1701;
integer commands=0,overlap_cycles=0,early_reads=0,write_overlap=0;
always @(posedge clk)if(rst_n)begin
 if(dut.state!=0&&dut.ws!=0)overlap_cycles++;
 if(mv&&mr&&!mw&&dut.state==6)early_reads++;
 if(mv&&mr&&mw&&dut.ws!=0)write_overlap++;
 if(hold_b&&dut.ws==4&&drained)$fatal(1,"Fence completed before B");
end
function automatic [23:0] address(input integer n);
 address=((n/512)<<21)+((n%512)<<3);
endfunction
task automatic request(input bit wr,input integer n,input [63:0] data);
 begin
 @(negedge clk);mv=1;mw=wr;ma=address(n);md=data;
 do @(posedge clk);while(!mr);
 if(wr)expected[n]=data;
 @(negedge clk);mv=0;
 if(!wr)begin
  if(!mrv||mrd!==expected[n])$fatal(1,"Read mismatch index=%0d got=%h expected=%h valid=%b",n,mrd,expected[n],mrv);
 end
 commands++;
 end
endtask
task automatic fence;
 begin
 @(negedge clk);flush=1;
 do @(negedge clk);while(!drained);
 flush=0;
 end
endtask
task automatic invalidate;
 begin
 fence();@(negedge clk);clear=1;@(negedge clk);clear=0;
 end
endtask
initial begin
 void'($urandom(seed));
 for(int n=0;n<1536;n++)expected[n]={32'h12340000+n,32'hfedc0000+n};
 for(int n=0;n<1536;n+=2)mem.set_word((32'h01800000+address(n))>>4,{expected[n+1],expected[n]});
 repeat(8)@(negedge clk);rst_n=1;
 // A blocked B response must not prevent unrelated read progress.
 hold_b=1;
 for(int n=0;n<40;n++)request(1,n,{32'habcdef01,32'(n)});
 request(0,1024,0);request(0,1025,0);
 if(drained)$fatal(1,"Dirty writes reported drained");
 hold_b=0;fence();
 // Read-after-write forces a flush; untouched byte halves must survive.
 request(1,100,64'h123456789abcdef0);request(0,100,0);request(0,101,0);
 for(int n=0;n<10000;n++)begin
  automatic int index=$urandom_range(1535);
  request($urandom_range(99)<55,index,{$urandom,$urandom});
  if(n%701==0)invalidate();
 end
 fence();
 for(int n=0;n<1536;n+=2)begin
  word=mem.rd_word((32'h01800000+address(n))>>4);
  if(word!=={expected[n+1],expected[n]})$fatal(1,"Final DDR mismatch %0d",n);
 end
 if(failed)$fatal(1,"Unexpected bridge error");
 // Errors survive until a drained clear; both independent engines propagate.
 inject_b=1;request(1,511,64'hbadc0ffe12345678);fence();
 if(!failed)$fatal(1,"Missing B error");
 inject_b=0;invalidate();if(failed)$fatal(1,"Error clear failed");
 inject_r=1;request(0,1024,0);fence();
 if(!failed)$fatal(1,"Missing R error");
 inject_r=0;invalidate();if(failed)$fatal(1,"Error clear failed");
 if(overlap_cycles==0||early_reads==0||write_overlap==0)$fatal(1,"Missing concurrency exercise");
 $display("tb_u8_bridge PASS commands=%0d overlap_cycles=%0d early_reads=%0d write_overlap=%0d",commands,overlap_cycles,early_reads,write_overlap);
 $finish;
end
initial begin #200000000;$fatal(1,"Bridge unit timeout");end
endmodule
