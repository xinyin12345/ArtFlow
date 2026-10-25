`timescale 1ns/1ps
module tb_r15u_lease;
localparam WIDTH=64,HEIGHT=16,BANK=32'h400000;
reg clk=0,cnn_clk=0,rst_n=0,start=0,cancel=0;always #5 clk=~clk;always #3.5 cnn_clk=~cnn_clk;
reg freeze_req=0,cnn_start=0;wire local_grant,cnn_port_ready,cnn_busy,cnn_done,cnn_failed;integer cnn_jobs=0;
reg [31:0] original_base=0,style_base=3*BANK,result_base=4*BANK;
reg [2:0] mode=4,level=4;reg [10:0] x0=10,y0=3,x1=50,y1=13,split_x=23;
wire busy,done,failed;wire [31:0] awaddr,araddr;wire [7:0] awlen,arlen;wire awvalid,awready,wvalid,wlast,wready,bvalid,bready,arvalid,arready,rvalid,rlast,rready;wire [127:0] wdata,rdata;wire [15:0] wstrb;wire [1:0] bresp,rresp;
reg hold_aw=0,hold_w=0,hold_b=0,hold_ar=0,hold_r=0,inject_b_error=0,inject_r_error=0;
wire [31:0] l_araddr;
wire [7:0] l_arlen;
wire l_arvalid;
wire l_arready;
wire [127:0] l_rdata;
wire l_rvalid;
wire [1:0] l_rresp;
wire l_rlast;
wire l_rready;
wire [31:0] l_awaddr;
wire [7:0] l_awlen;
wire l_awvalid;
wire l_awready;
wire [127:0] l_wdata;
wire [15:0] l_wstrb;
wire l_wvalid;
wire l_wlast;
wire l_wready;
wire l_bvalid;
wire [1:0] l_bresp;
wire l_bready;
artflow_pair_render #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) dut(.clk(clk),.rst_n(rst_n),.start(start),.cancel(cancel),.original_base(original_base),.style_base(style_base),.result_base(result_base),.mode(mode),.level(level),.x0(x0),.y0(y0),.x1(x1),.y1(y1),.split_x(split_x),.busy(busy),.done(done),.failed(failed),.araddr(l_araddr),.arlen(l_arlen),.arvalid(l_arvalid),.arready(l_arready),.rdata(l_rdata),.rvalid(l_rvalid),.rresp(l_rresp),.rlast(l_rlast),.rready(l_rready),.awaddr(l_awaddr),.awlen(l_awlen),.awvalid(l_awvalid),.awready(l_awready),.wdata(l_wdata),.wstrb(l_wstrb),.wvalid(l_wvalid),.wlast(l_wlast),.wready(l_wready),.bvalid(l_bvalid),.bresp(l_bresp),.bready(l_bready));
artflow_cnn_accel #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.LOCAL_ENABLE(1)) accel(.clk(clk),.cnn_clk(cnn_clk),.rst_n(rst_n),.start(cnn_start),.src_addr(32'd0),.dst_addr(5*BANK),.busy(cnn_busy),.done(cnn_done),.failed(cnn_failed),.cycles(),.source_consumed(),.key_style_n(1'b1),.flash_miso(1'b0),.flash_cs_n(),.flash_sck(),.flash_mosi(),.style_status(),.completed_style(),.freeze_req(freeze_req),.local_active(busy),.local_grant(local_grant),.cnn_port_ready(cnn_port_ready),.araddr(araddr),.local_araddr(l_araddr),.arlen(arlen),.local_arlen(l_arlen),.arvalid(arvalid),.local_arvalid(l_arvalid),.arready(arready),.local_arready(l_arready),.rdata(rdata),.local_rdata(l_rdata),.rvalid(rvalid),.local_rvalid(l_rvalid),.rresp(rresp),.local_rresp(l_rresp),.rlast(rlast),.local_rlast(l_rlast),.rready(rready),.local_rready(l_rready),.awaddr(awaddr),.local_awaddr(l_awaddr),.awlen(awlen),.local_awlen(l_awlen),.awvalid(awvalid),.local_awvalid(l_awvalid),.awready(awready),.local_awready(l_awready),.wdata(wdata),.local_wdata(l_wdata),.wstrb(wstrb),.local_wstrb(l_wstrb),.wvalid(wvalid),.local_wvalid(l_wvalid),.wlast(wlast),.local_wlast(l_wlast),.wready(wready),.local_wready(l_wready),.bvalid(bvalid),.local_bvalid(l_bvalid),.bresp(bresp),.local_bresp(l_bresp),.bready(bready),.local_bready(l_bready));
always @(posedge cnn_done)if(rst_n)begin if(cnn_failed)$fatal(1,"fixture CNN failed");cnn_jobs++;end
task job;wait(cnn_port_ready);@(negedge clk);cnn_start=1;@(negedge clk);cnn_start=0;endtask

axi_memory_v07 #(.WORDS_PER_BANK(WIDTH*HEIGHT/4+512),.STALL_PCT(30),.RD_LAT(9)) mem(.*,.awsize(3'd4),.awlock(1'b0),.awburst(2'd1),.arsize(3'd4),.arlock(1'b0),.arburst(2'd1));
reg [7:0] lut[0:255];reg [31:0] pixels_i[0:WIDTH*HEIGHT-1],pixels_s[0:WIDTH*HEIGHT-1];
function automatic [23:0] norm(input [31:0] p);norm=p[24]?p[23:0]:{lut[p[23:16]],lut[p[15:8]],lut[p[7:0]]};endfunction
integer checks=0,cycles=0,cases=0;always @(posedge clk)if(busy)cycles++;
task launch;wait(local_grant);@(negedge clk);start=1;@(negedge clk);start=0;endtask
task verify;
 reg selected;reg [23:0] a,b;reg [31:0] expected;reg [127:0] got;integer v;
 begin
 for(integer y=0;y<HEIGHT;y++)for(integer x=0;x<WIDTH;x++)begin
  a=norm(pixels_i[y*WIDTH+x]);b=norm(pixels_s[y*WIDTH+x]);
  selected=mode==4 || (mode==1 && x>=x0 && x<x1 && y>=y0 && y<y1) || (mode==2 && x<split_x);
  expected=32'h01000000;
  for(integer k=0;k<3;k++)begin v=selected ? ((4-level)*a[k*8+:8]+level*b[k*8+:8]+2)/4 : a[k*8+:8];expected[k*8+:8]=v;end
  got=mem.rd_word((result_base+(y*WIDTH+x)*4)>>4);
  if(got[(x%4)*32+:32]!==expected)$fatal(1,"pixel mode=%0d level=%0d x=%0d y=%0d got=%h expected=%h",mode,level,x,y,got[(x%4)*32+:32],expected);
  checks++;
 end
 cases++;
 end
endtask
initial begin
 $readmemh("rtl/gamma_conrrection/gamma_inv2p2_8b.mem",lut);
 for(integer j=0;j<WIDTH*HEIGHT;j++)begin
  pixels_i[j]={7'd0,1'(j%2),8'(j*7),8'(j*3),8'(j*11)};
  pixels_s[j]={7'd0,1'(j%3!=0),8'(255-j*5),8'(j*17),8'(j*13)};
 end
 for(integer j=0;j<WIDTH*HEIGHT/4;j++)begin
  mem.set_word(j,{pixels_i[j*4+3],pixels_i[j*4+2],pixels_i[j*4+1],pixels_i[j*4]});
  mem.set_word((3*BANK>>4)+j,{pixels_s[j*4+3],pixels_s[j*4+2],pixels_s[j*4+1],pixels_s[j*4]});
 end
 repeat(6)@(negedge clk);rst_n=1;
 repeat(10)@(negedge clk);job();wait(cnn_busy);freeze_req=1;
 wait(cnn_done);if(local_grant)$fatal(1,"grant before CNN completion drained");wait(local_grant);

 for(integer m=0;m<3;m++)begin mode=m==0?4:m;for(integer l=0;l<5;l++)begin level=l;launch();wait(done);@(negedge clk);if(failed)$fatal(1,"render failed");verify();end end
 // B response is the publication barrier; cancel must drain it.
 hold_b=1;launch();wait(bready);@(negedge clk);cancel=1;repeat(15)@(negedge clk);if(!busy || done)$fatal(1,"cancel ignored B barrier");hold_b=0;wait(done);@(negedge clk);cancel=0;cases++;
 inject_b_error=1;launch();wait(done);@(negedge clk);if(!failed)$fatal(1,"B error lost");inject_b_error=0;cases++;
 inject_r_error=1;launch();wait(done);@(negedge clk);if(!failed)$fatal(1,"R error lost");inject_r_error=0;cases++;
 // AR offer cannot disappear on exit while backpressured.
 hold_ar=1;launch();wait(arvalid);@(negedge clk);cancel=1;repeat(10)@(negedge clk);if(!arvalid || !busy)$fatal(1,"withdrawn AR");hold_ar=0;wait(done);@(negedge clk);cancel=0;cases++;
 // Cancel during AW offer, during W backpressure and while B is delayed.
 for(integer stage=0;stage<3;stage++)begin
  freeze_req=1;wait(local_grant);
  hold_aw=stage==0;hold_w=stage==1;hold_b=stage==2;
  repeat(5)@(negedge clk);launch();
  if(stage==0)wait(awvalid);else if(stage==1)wait(wvalid);else wait(bready);
  @(negedge clk);freeze_req=0;cancel=1;
  repeat(20)@(negedge clk);if(cnn_port_ready || !accel.local_owner)$fatal(1,"premature owner release");
  hold_aw=0;hold_w=0;hold_b=0;wait(done);wait(cnn_port_ready);@(negedge clk);cancel=0;job();wait(cnn_done);cases++;
 end
 // Cancel acquisition before acknowledgement; then retry and recover.
 @(negedge clk);freeze_req=1;wait(accel.lease_state==1);@(negedge clk);freeze_req=0;
 wait(cnn_port_ready);freeze_req=1;wait(local_grant);freeze_req=0;wait(cnn_port_ready);
 // Reset while parked, then prove a fresh CNN transaction succeeds.
 freeze_req=1;wait(local_grant);@(negedge clk);rst_n=0;freeze_req=0;
 repeat(8)@(negedge clk);rst_n=1;repeat(10)@(negedge clk);job();wait(cnn_done);
 @(negedge clk);if(cnn_jobs!=5)$fatal(1,"lost/duplicate CNN completions %0d",cnn_jobs);
 $display("TEST PASS r15u_lease real wrapper/CDC, transaction engine fixture; cases=%0d pixels=%0d cycles=%0d writes=%0d reads=%0d",cases,checks,cycles,mem.n_wr_burst,mem.n_rd_burst);$finish;
end
initial begin #100000000;$fatal(1,"render watchdog");end
endmodule
