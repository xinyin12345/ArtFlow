`timescale 1ns/1ps
module tb_r15u_timeout;
localparam WIDTH=16,HEIGHT=4,BANK=32'h400000;
reg clk=0,cnn_clk=0,rst_n=0,start=0,cancel=0;always #5 clk=~clk;always #3.5 cnn_clk=~cnn_clk;
reg freeze_req=0,cnn_start=0;wire local_grant,cnn_port_ready,cnn_busy,cnn_done,cnn_failed;integer cnn_jobs=0;
reg [31:0] original_base=0,style_base=3*BANK,result_base=4*BANK;
reg [2:0] mode=4,level=4;reg [10:0] x0=10,y0=3,x1=50,y1=13,split_x=23;
wire busy,done,failed;reg [15:0] paddr=0;reg psel=0,penable=0,pwrite=0;reg [31:0] pwdata=0;wire [31:0] prdata;wire pready,pslverror,result_valid;wire [1:0] result_bank;wire [31:0] awaddr,araddr;wire [7:0] awlen,arlen;wire awvalid,awready,wvalid,wlast,wready,bvalid,bready,arvalid,arready,rvalid,rlast,rready;wire [127:0] wdata,rdata;wire [15:0] wstrb;wire [1:0] bresp,rresp;
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
artflow_render_ctrl #(.REQUIRE_GRANT(1),.WIDTH(WIDTH),.HEIGHT(HEIGHT),.TIMEOUT(5000)) ctrl(.clk(clk),.rst_n(rst_n),.freeze_valid(freeze_req),.local_grant(local_grant),.original_bank(2'd0),.style_bank(2'd0),.display_active(1'b0),.display_bank(2'd0),.paddr(paddr),.psel(psel),.penable(penable),.pwrite(pwrite),.pwdata(pwdata),.prdata(prdata),.pready(pready),.pslverror(pslverror),.result_valid(result_valid),.result_bank(result_bank),.active(busy),.araddr(l_araddr),.arlen(l_arlen),.arvalid(l_arvalid),.arready(l_arready),.rdata(l_rdata),.rvalid(l_rvalid),.rresp(l_rresp),.rlast(l_rlast),.rready(l_rready),.awaddr(l_awaddr),.awlen(l_awlen),.awvalid(l_awvalid),.awready(l_awready),.wdata(l_wdata),.wstrb(l_wstrb),.wvalid(l_wvalid),.wlast(l_wlast),.wready(l_wready),.bvalid(l_bvalid),.bresp(l_bresp),.bready(l_bready));
artflow_cnn_accel #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.LOCAL_ENABLE(1)) accel(.clk(clk),.cnn_clk(cnn_clk),.rst_n(rst_n),.start(cnn_start),.src_addr(32'd0),.dst_addr(5*BANK),.busy(cnn_busy),.done(cnn_done),.failed(cnn_failed),.cycles(),.source_consumed(),.key_style_n(1'b1),.flash_miso(1'b0),.flash_cs_n(),.flash_sck(),.flash_mosi(),.style_status(),.completed_style(),.freeze_req(freeze_req),.local_active(busy),.local_grant(local_grant),.cnn_port_ready(cnn_port_ready),.araddr(araddr),.local_araddr(l_araddr),.arlen(arlen),.local_arlen(l_arlen),.arvalid(arvalid),.local_arvalid(l_arvalid),.arready(arready),.local_arready(l_arready),.rdata(rdata),.local_rdata(l_rdata),.rvalid(rvalid),.local_rvalid(l_rvalid),.rresp(rresp),.local_rresp(l_rresp),.rlast(rlast),.local_rlast(l_rlast),.rready(rready),.local_rready(l_rready),.awaddr(awaddr),.local_awaddr(l_awaddr),.awlen(awlen),.local_awlen(l_awlen),.awvalid(awvalid),.local_awvalid(l_awvalid),.awready(awready),.local_awready(l_awready),.wdata(wdata),.local_wdata(l_wdata),.wstrb(wstrb),.local_wstrb(l_wstrb),.wvalid(wvalid),.local_wvalid(l_wvalid),.wlast(wlast),.local_wlast(l_wlast),.wready(wready),.local_wready(l_wready),.bvalid(bvalid),.local_bvalid(l_bvalid),.bresp(bresp),.local_bresp(l_bresp),.bready(bready),.local_bready(l_bready));
always @(posedge cnn_done)if(rst_n)begin if(cnn_failed)$fatal(1,"fixture CNN failed");cnn_jobs++;end
task job;wait(cnn_port_ready);@(negedge clk);cnn_start=1;@(negedge clk);cnn_start=0;endtask

axi_memory_v07 #(.WORDS_PER_BANK(WIDTH*HEIGHT/4+512),.STALL_PCT(30),.RD_LAT(9)) mem(.*,.awsize(3'd4),.awlock(1'b0),.awburst(2'd1),.arsize(3'd4),.arlock(1'b0),.arburst(2'd1));

task cmd(input [15:0] a,input [31:0] v);
 @(negedge clk);paddr=a;pwdata=v;psel=1;pwrite=1;
 @(negedge clk);penable=1;@(posedge clk);if(!pready || pslverror)$fatal(1,"APB command");
 @(negedge clk);psel=0;penable=0;pwrite=0;
endtask
integer stage=0;
initial begin
 for(integer k=0;k<WIDTH*HEIGHT/4;k++)begin mem.set_word(k,128'h00112233004455660077889900aabbcc);mem.set_word((3*BANK>>4)+k,128'h01aabbcc017788990144556601112233);end
 repeat(8)@(negedge clk);rst_n=1;freeze_req=1;wait(local_grant);
 stage=1;hold_b=1;cmd('hd4,36);cmd('hd0,1);wait(bready);stage=2;wait(ctrl.timeout_error);
 repeat(20)@(negedge clk);if(!busy || result_valid || !accel.local_owner)$fatal(1,"timeout discarded B or published partial frame");
 freeze_req=0;repeat(20)@(negedge clk);if(cnn_port_ready || !busy)$fatal(1,"timeout falsely resumed live");
 stage=3;hold_b=0;wait(!busy);wait(cnn_port_ready);if(ctrl.count!=0)$fatal(1,"timed-out frame counted");
 stage=4;freeze_req=1;wait(local_grant);cmd('hd0,1);wait(result_valid);if(ctrl.timeout_error || ctrl.count!=1)$fatal(1,"retry after timeout failed");
 // Reset while a local read is accepted but stalled; the DDR model shares reset.
 stage=5;freeze_req=0;wait(cnn_port_ready);freeze_req=1;wait(local_grant);hold_r=1;cmd('hd0,1);wait(accel.read_inflight);
 @(negedge clk);rst_n=0;freeze_req=0;hold_r=0;repeat(8)@(negedge clk);rst_n=1;
 repeat(12)@(negedge clk);job();wait(cnn_done);@(negedge clk);if(cnn_failed || busy || result_valid)$fatal(1,"reset recovery");
 $display("TEST PASS r15u_timeout actual5000cycle timeout, withheldB, no partial publish, retry, outstanding-reset recovery");$finish;
end
initial begin #2000000;$fatal(1,"timeout watchdog stage=%0d pending=%b running=%b timeout=%b timer=%0d lease=%0d freeze=%b renderer=%0d",stage,ctrl.pending,ctrl.running,ctrl.timeout_error,ctrl.timer,accel.lease_state,freeze_req,ctrl.render.state);end
endmodule
