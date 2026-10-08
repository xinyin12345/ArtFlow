`timescale 1ns/1ps
// Reproduce CAMERA off/init while CSI omits FE and holds VS high. The real
// Bayer, triple-buffer controller, scheduler and checked AXI memory must drain
// the aborted capture without publishing a mixture of pre/post-reset pixels.
module tb_camera_gate;
localparam W=16, H=8, OW=W/2, OH=H/2, BANK=4096;
reg clk=0, aclk=0, oclk=0;
always #10 clk=~clk;
always #5 aclk=~aclk;
always #7 oclk=~oclk;
reg rstn=0, camera_ready=0, raw_vs=0, raw_hs=0, raw_valid=0;
reg [39:0] raw_data=0;
wire video_vs, video_hs, video_valid;
wire [39:0] video_data;
artflow_camera_gate gate(.*);
wire bin_vs,bin_hs,bin_valid;
wire [63:0] bin_data;
bayer_bin2x2 #(.MAX_IN_WIDTH(W)) bayer (
    .clk(clk),.rstn(rstn),.i_bayer(2'd0),.i_pix_rev(1'b0),
    .i_gain_r(16'd256),.i_gain_g(16'd256),.i_gain_b(16'd256),
    .i_vs(video_vs),.i_hs(video_hs),.i_valid(video_valid),.i_data(video_data),
    .o_vs(bin_vs),.o_hs(bin_hs),.o_valid(bin_valid),.o_data(bin_data));
wire [31:0] awaddr,araddr;
wire [7:0] awlen,arlen;
wire awvalid,awready,wlast,wvalid,wready,bvalid,bready;
wire arvalid,arready,rlast,rvalid,rready;
wire [127:0] wdata,rdata;
wire [15:0] wstrb;
wire [1:0] bresp,rresp;
wire o_de,o_hs,o_vs;
wire [31:0] o_data;
reg hold_b=0;
rgb_frame_store #(.WIDTH(OW),.HEIGHT(OH),.BANK_BYTES(BANK),
    .FIFO_DEPTH(32),.BURST_BEATS(2)) store (
    .diag_state(), .diag_fifo(), .diag_written(), .diag_completed(), .diag_published(), .diag_rejected(),
    .capture_toggle(),
    .rst_n(rstn),.i_clk(clk),.i_vs(bin_vs),.i_valid(bin_valid),.i_data(bin_data),
    .o_clk(oclk),.H_FRONT_PORCH(13'd40),.H_SYNC(13'd2),.H_VALID(13'd16),
    .H_BACK_PORCH(13'd40),.V_FRONT_PORCH(13'd4),.V_SYNC(13'd1),
    .V_VALID(13'd8),.V_BACK_PORCH(13'd4),
    .o_de(o_de),.o_hs(o_hs),.o_vs(o_vs),.o_data(o_data),
    .axi_clk(aclk),.awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),
    .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
    .bvalid(bvalid),.bresp(bresp),.bready(bready),
    .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
    .rdata(rdata),.rlast(rlast),.rvalid(rvalid),.rresp(rresp),.rready(rready));
axi_memory_checked #(.STALL_PCT(25),.RD_LAT(4)) memory (
    .clk(aclk),.rst_n(rstn),.awaddr(awaddr),.awlen(awlen),.awsize(3'd4),
    .awburst(2'd1),.awlock(1'b0),.awvalid(awvalid),.awready(awready),
    .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
    .bvalid(bvalid),.bresp(bresp),.bready(bready),
    .araddr(araddr),.arlen(arlen),.arsize(3'd4),.arburst(2'd1),.arlock(1'b0),
    .arvalid(arvalid),.arready(arready),.rdata(rdata),.rlast(rlast),
    .rvalid(rvalid),.rready(rready),.rresp(rresp),
    .hold_aw(1'b0),.hold_w(1'b0),.hold_b(hold_b),.hold_ar(1'b0),.hold_r(1'b0),
    .inject_b_error(1'b0),.inject_r_error(1'b0));

integer admitted_beats=0, boundaries=0, expected_seq=-1;
integer published_seen=0, checked_pixels=0, write_outstanding=0;
reg monitor_vs=0, publication_allowed=0;
always @(posedge clk) begin
    #1;
    if(rstn) begin
        if(video_valid) admitted_beats++;
        if(video_vs!=monitor_vs) boundaries++;
        monitor_vs=video_vs;
        if(!camera_ready && (video_hs || video_valid)) $fatal(1,"Disabled camera leaked video");
    end else monitor_vs=0;
end
always @(posedge aclk) if(rstn) begin
    if(awvalid&&awready) write_outstanding++;
    if(bvalid&&bready) write_outstanding--;
    if(write_outstanding<0 || write_outstanding>1) $fatal(1,"AXI outstanding invalid");
end
always @(negedge aclk) if(rstn && store.published_frames!=published_seen) begin
    reg [127:0] word;
    reg [7:0] expected;
    if(!publication_allowed) $fatal(1,"Incomplete/restarted camera frame was published");
    if(write_outstanding!=0) $fatal(1,"Published before outstanding B completed");
    for(integer n=0;n<OW*OH;n++) begin
        word=memory.rd_word((store.latest_bank*BANK)/16+n/4);
        expected=(80+expected_seq*160)/4+n;
        if(word[(n%4)*32+:32] !== {8'd0,expected,expected,expected})
            $fatal(1,"Mixed/corrupt frame: seq=%0d pixel=%0d got=%h expected=%h",
                   expected_seq,n,word[(n%4)*32+:32],expected);
        checked_pixels++;
    end
    published_seen=store.published_frames;
end

task automatic rows(input integer seq,input integer first,input integer number);
    integer value;
    begin
        for(integer y=first;y<first+number;y++) begin
            for(integer x=0;x<W;x+=4) begin
                @(negedge clk); raw_hs=1; raw_valid=1;
                for(integer k=0;k<4;k++) begin
                    value=80+seq*160+((y/2)*OW+(x+k)/2)*4;
                    raw_data[k*10+:10]=value[9:0];
                end
            end
            @(negedge clk); raw_hs=0; raw_valid=0;
            repeat(8) @(negedge clk);
        end
    end
endtask
task automatic boundary;
    begin
        @(negedge clk); raw_vs=~raw_vs; raw_hs=0; raw_valid=0;
        repeat(8) @(negedge clk);
    end
endtask
task automatic settle(input integer cycles);
    begin repeat(cycles) @(negedge clk); end
endtask
task automatic await_publication(input integer count);
    integer tries;
    begin
        tries=0;
        while(published_seen<count && tries<3000) begin @(negedge clk); tries++; end
        if(published_seen!=count) $fatal(1,"Complete restarted frame did not publish");
    end
endtask
integer before_admission, before_boundaries;
reg held_vs;
initial begin
    #2000000; $fatal(1,"tb_camera_gate timeout");
end
initial begin
    settle(8); rstn=1; settle(12);
    // READY alone is not a new frame, even if pixels appear immediately.
    camera_ready=1; rows(0,0,2); settle(12);
    if(admitted_beats!=0 || boundaries!=0) $fatal(1,"READY admitted unframed data");
    boundary();
    hold_b=1;
    rows(0,0,H/2); // half a frame is now in the real DDR pipeline
    settle(20);
    if(!store.capturing || store.input_count==0 || write_outstanding!=1)
        $fatal(1,"Abort test did not establish partial capture and outstanding AXI");
    held_vs=raw_vs; before_boundaries=boundaries;
    @(negedge clk); camera_ready=0; // sensor never emits FE: VS stays high
    settle(10);
    if(boundaries!=before_boundaries+1) $fatal(1,"Exactly one synthetic abort edge required");
    if(store.capturing || raw_vs!=held_vs) $fatal(1,"Synthetic boundary failed to abort capture");
    if(write_outstanding!=1) $fatal(1,"Camera off cancelled an accepted AXI burst");
    hold_b=0;
    settle(200);
    if(write_outstanding!=0 || store.rejected_frames!=1 || store.ws!=0)
        $fatal(1,"Aborted frame AXI did not drain and reject");
    before_admission=admitted_beats;
    // Disabled CSI toggles must be tracked but never forwarded to the video.
    boundary(); boundary();
    if(boundaries!=before_boundaries+1) $fatal(1,"Disabled raw VS leaked boundary");
    @(negedge clk); camera_ready=1;
    rows(1,0,H); // enough data to complete a stale half-frame if gate is wrong
    settle(100);
    if(admitted_beats!=before_admission || published_seen!=0 || store.capturing)
        $fatal(1,"Restart without fresh VS resumed stale frame");

    publication_allowed=1; expected_seq=2;
    boundary(); rows(2,0,H); settle(12); boundary();
    await_publication(1); settle(80);
    expected_seq=3;
    boundary(); rows(3,0,H); settle(12); boundary();
    await_publication(2);
    if(checked_pixels!=2*OW*OH || memory.n_wr_burst==0)
        $fatal(1,"Recovery did not check two complete DDR frames");

    // Gate-level alignment for a real VS and first pixel on the same edge.
    // Spatially varying full-frame same-cycle coverage also lives in
    // tb_bayer_first_pixel, which checks the new even-row first-word handling.
    publication_allowed=0;
    @(negedge clk); camera_ready=0;
    settle(10);
    @(negedge clk); camera_ready=1;
    settle(3);
    @(negedge clk); raw_vs=~raw_vs; raw_hs=1; raw_valid=1; raw_data=40'h0123456789;
    @(posedge clk); #2;
    if(!video_hs || !video_valid || video_data!==40'h0123456789)
        $fatal(1,"Coincident VS/first RAW lost or skewed in admission gate");
    @(negedge clk); camera_ready=0; raw_hs=0; raw_valid=0;
    settle(20);
    $display("tb_camera_gate PASS: half-frame aborted, outstanding AXI drained, stale restart blocked, %0d complete DDR pixels checked",checked_pixels);
    $finish;
end
endmodule
