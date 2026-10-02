// =============================================================================
// tb_v03_pipe.sv  --  ArtFlow v03 端到端逐像素比对
// -----------------------------------------------------------------------------
//   摄像头模型 (RAW10, 4 像素/拍, 50 MHz, 行内随机空拍)
//     -> cam_fb_pipe（与顶层完全相同的 RTL：2x2 合并 + frame_buffer + 2 倍放大）
//     -> axi_mem_model（代替 DDR，随机反压）
//     -> HDMI 口 (148.5 MHz) 抓帧
//   检查：
//     1) 每个 HDMI 像素 (x,y) == 期望[y/2][x/2]（Python 黄金模型）
//     2) DDR 里的帧缓存内容 == 期望（小端 XRGB8888，像素 n 在字节 4n）
//     3) AXI 协议（4KB 边界、wlast），由 axi_mem_model 报告
//   通过条件：最后 NGOOD 帧全部逐像素一致，且无 AXI 错误
//
// 参数（vsim -G 覆盖）：
//   W, H       摄像头 RAW 分辨率（= HDMI 输出分辨率）
//   PREFIX     黄金模型文件前缀（small / full）
//   PHASE      Bayer 相位
//   GAP_PCT    行内空拍概率 %
//   NGOOD      需要连续正确的帧数
// =============================================================================
`timescale 1ns/1ps
module tb_v03_checked;
parameter int STRESS=0, REV=0, VS_MODE=0;
localparam int VARIANTS=8;

parameter int    W       = 160;
parameter int    H       = 40;
parameter string PREFIX  = "small";
parameter int    PHASE   = 0;
parameter int    GAP_PCT = 25;
parameter int    NGOOD   = 3;
parameter int    MAXFRM  = 60;       // 最多观察的输出帧数
parameter int    VBLANK  = 20;     // 帧消隐（pclk 拍数）。真实传感器 >= 几十行；
                                     // 太短会触发旧 ddr_wr_buffer 在帧头中途放弃突发的问题（见 doc/v03_notes.md）

localparam int OW = W / 2, OH = H / 2;
localparam [31:0] BANK = 32'h0040_0000;

// ---------------------------------------------------------------- 时钟
reg pclk = 0;   always #10.000 pclk = ~pclk;          // 50 MHz   i_mipi_rx_pclk
reg aclk = 0;   always #5.000  aclk = ~aclk;          // 100 MHz  core_clk
reg hclk = 0;   always #3.367  hclk = ~hclk;          // 148.5 MHz hdmi_tx_slow_clk
reg vclk = 0;   always @(posedge hclk) vclk <= ~vclk; // 74.25 MHz vid_clk_dvi2（同源，上升沿对齐）

reg rst_n = 0, prst_n = 0;

// ---------------------------------------------------------------- DUT
reg         s_vs = 0, s_hs = 0, s_valid = 0;
reg  [39:0] s_raw = 0;
wire        o_de, o_hs, o_vs;
wire [7:0]  o_r, o_g, o_b;

wire [5:0]   awid, arid;
wire [31:0]  awaddr, araddr;
wire [7:0]   awlen, arlen;
wire [2:0]   awsize, arsize, awprot, arprot;
wire [1:0]   awburst, arburst;
wire [3:0]   awcache, arcache;
wire         awlock, arlock, awvalid, awready, arvalid, arready;
wire [127:0] wdata, rdata;
wire [1:0] bresp,rresp;
reg hold_aw=0,hold_w=0,hold_b=0,hold_ar=0,hold_r=0;
wire [15:0]  wstrb;
wire         wlast, wvalid, wready, rlast, rvalid, rready, bvalid, bready;

cam_fb_pipe #(
    .AXI_DATA_WIDTH(128), .AXI_ADDR_WIDTH(32),
    .START_ADDR(32'h0), .BANK_BYTES(BANK),
    .MAX_IN_HEIGHT(H), .MAX_IN_WIDTH(W), .MAX_OUT_WIDTH(OW)
) dut (
    .cfg_bayer(PHASE[1:0]), .cfg_pix_rev(REV[0]),
    .cfg_gain_r(16'h0118), .cfg_gain_g(16'h00FF), .cfg_gain_b(16'h015E),
    .i_pclk(pclk), .i_pclk_rstn(prst_n),
    .i_vs(s_vs), .i_hs(s_hs), .i_valid(s_valid), .i_raw(s_raw),
    .H_FRONT_PORCH(13'd44), .H_SYNC(13'd22), .H_VALID(OW[12:0]), .H_BACK_PORCH(13'd74),
    .V_FRONT_PORCH(13'd4), .V_SYNC(13'd5), .V_VALID(H[12:0]),  .V_BACK_PORCH(13'd36),
    .rst_n(rst_n), .o_clk(vclk), .o_hdmi_clk(hclk),
    .o_de(o_de), .o_hs(o_hs), .o_vs(o_vs), .o_r(o_r), .o_g(o_g), .o_b(o_b),
    .axi_clk(aclk),
    .awid(awid), .awaddr(awaddr), .awlen(awlen), .awsize(awsize), .awburst(awburst),
    .awcache(awcache), .awprot(awprot), .awlock(awlock), .awvalid(awvalid), .awready(awready),
    .arid(arid), .araddr(araddr), .arlen(arlen), .arsize(arsize), .arburst(arburst),
    .arcache(arcache), .arprot(arprot), .arlock(arlock), .arvalid(arvalid), .arready(arready),
    .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
    .rid(6'd0), .rdata(rdata), .rlast(rlast), .rvalid(rvalid), .rready(rready), .rresp(rresp),
    .bid(6'd0), .bvalid(bvalid), .bresp(bresp), .bready(bready));

axi_memory_checked #(.DW(128), .AW(32), .STALL_PCT(20), .RD_LAT(12)) u_mem (
    .clk(aclk), .rst_n(rst_n),
    .awaddr(awaddr), .awlen(awlen), .awsize(awsize), .awlock(awlock), .awburst(awburst), .awvalid(awvalid), .awready(awready),
    .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
    .bvalid(bvalid), .bresp(bresp), .bready(bready),
    .araddr(araddr), .arlen(arlen), .arsize(arsize), .arlock(arlock), .arburst(arburst), .arvalid(arvalid), .arready(arready),
    .rdata(rdata), .rlast(rlast), .rvalid(rvalid), .rready(rready), .rresp(rresp),
    .hold_aw(hold_aw), .hold_w(hold_w), .hold_b(hold_b), .hold_ar(hold_ar), .hold_r(hold_r));

// ---------------------------------------------------------------- 黄金数据
reg [9:0]  raw [0:W*H-1];
reg [23:0] exp_px [0:VARIANTS*OW*OH-1];
initial begin
    $readmemh({PREFIX, "_raw.hex"}, raw);
    for(int v=0;v<VARIANTS;v++)
        $readmemh($sformatf("%s_exp_p%0d_f%0d.hex", PREFIX, PHASE,v), exp_px, v*OW*OH,(v+1)*OW*OH-1);
end

// ---------------------------------------------------------------- 摄像头模型（输入 RAW 统一按 RGGB 马赛克）
int in_frames = 0;
initial begin : sensor
    int y, x, k;
    wait (prst_n);
    repeat (20) @(posedge pclk);
    forever begin
        s_vs <= 1;                                   // vs：整帧高电平
        repeat (10) @(posedge pclk);
        if(VS_MODE) begin s_vs<=0; repeat(3) @(posedge pclk); end
        for (y = 0; y < H; y++) begin
            s_hs <= 1;
            x = 0;
            while (x < W) begin
                @(posedge pclk);
                if ($urandom_range(99) >= GAP_PCT) begin
                    s_valid <= 1;
                    for (k = 0; k < 4; k++) s_raw[(REV?3-k:k)*10 +: 10] <= raw[y*W + x + k] ^ ((in_frames%VARIANTS)*128);
                    x += 4;
                end else begin
                    s_valid <= 0;
                    s_raw   <= {$urandom, $urandom};
                end
            end
            @(posedge pclk);
            s_valid <= 0; s_hs <= 0;
            repeat (8) @(posedge pclk);
        end
        repeat (4) @(posedge pclk);
        s_vs <= 0;
        in_frames++;
        repeat (VBLANK) @(posedge pclk);
    end
end


// Every frame has a different image. The first pixel identifies its variant;
// every subsequent pixel must belong to that SAME frame, including both repeats.
int frm=0,x=0,y=-1,bad=0,npx=0,good_run=0,first_good=-1,tag=-1;
bit de_d=0,vs_d=0;
bit [7:0] displayed=0;
bit [2:0] banks_checked=0;
int published_seen=0,capture_tag=0;
int write_outstanding=0,read_outstanding=0;
bit read_active_d=0;
bit capture_d=0;
bit stress_done=(STRESS==0);
int recovery_at=1000000;
int fd=0;
bit dumped=0,cap_this=0;
realtime last_vs=0;
always @(posedge pclk) begin
    capture_d<=dut.u_store.capture_begin;
    if(capture_d!=dut.u_store.capture_begin) capture_tag=in_frames%VARIANTS;
end
always @(posedge aclk) if(rst_n) begin
    if(awvalid&&awready) write_outstanding++;
    if(bvalid&&bready) write_outstanding--;
    if(arvalid&&arready) read_outstanding++;
    if(rvalid&&rready&&rlast) read_outstanding--;
    if(read_active_d&&!dut.u_store.read_active && read_outstanding!=0)
        $fatal(1,"Read bank released before RLAST");
    read_active_d=dut.u_store.read_active;
    if((dut.u_store.ws==2 || dut.u_store.ws==3 || dut.u_store.ws==4) &&
        dut.u_store.read_active && dut.u_store.write_bank==dut.u_store.read_bank)
        $fatal(1,"Reader and writer own same bank");
    if(dut.u_store.published_frames!=published_seen) begin
        int b;
        logic [127:0] word;
        if(write_outstanding!=0) $fatal(1,"Bank published before B response");
        b=dut.u_store.latest_bank;
        for(int n=0;n<OW*OH;n++) begin
            word=u_mem.rd_word((b*BANK+n*4)>>4);
            if(word[(n%4)*32+:32] !== {8'h00,exp_px[capture_tag*OW*OH+n]})
                $fatal(1,"Published bank %0d frame variant %0d pixel %0d is incomplete/wrong",b,capture_tag,n);
        end
        banks_checked[b]=1;
        published_seen=dut.u_store.published_frames;
    end
end
always @(posedge hclk) begin
    vs_d<=o_vs; de_d<=o_de;
    if(o_vs&&!vs_d) begin
        if(npx>0) begin
            if(npx!=W*H) $fatal(1,"Frame size %0d expected %0d",npx,W*H);
            if(bad==0 && tag>=0) begin
                good_run++; displayed[tag]=1;
                if(first_good<0) first_good=frm;
            end else begin
                good_run=0;
                if(first_good>=0 && (STRESS==0 || frm>recovery_at+2))
                    $fatal(1,"Unexpected bad frame %0d tag=%0d mismatches=%0d",frm,tag,bad);
            end
            $display("FRAME %0d tag=%0d pixels=%0d mismatch=%0d good_run=%0d",frm,tag,npx,bad,good_run);
            if(cap_this) begin $fclose(fd); dumped=1; cap_this=0; end
            if(last_vs>0 && ((($realtime-last_vs)-((W/2+140)*(H+45)*13.468)>0.01) ||
                            (($realtime-last_vs)-((W/2+140)*(H+45)*13.468)<-0.01)))
                $fatal(1,"Output video timing mismatch");
        end
        last_vs=$realtime;
        frm++; bad=0; npx=0; y=-1; tag=-1;
        if(stress_done && recovery_at==1000000) recovery_at=frm;
    end
    if(o_de&&!de_d) begin y++; x=0; end
    if(!o_de&&de_d && x!=W) $fatal(1,"Line width=%0d expected=%0d",x,W);
    if(o_de) begin
        if(npx==0) begin
            for(int v=0;v<VARIANTS;v++)
                if({o_r,o_g,o_b}===exp_px[v*OW*OH]) tag=v;
            if(tag>=0 && !dumped && stress_done) begin
                fd=$fopen({PREFIX,"_cap.hex"},"w"); cap_this=1;
                begin int mf; mf=$fopen({PREFIX,"_cap_variant.txt"},"w"); $fdisplay(mf,"%0d",tag); $fclose(mf); end
            end
        end
        if($isunknown({o_r,o_g,o_b})) $fatal(1,"Unknown display pixel");
        if(tag>=0 && y<H && x<W) begin
            if({o_r,o_g,o_b}!==exp_px[tag*OW*OH+(y/2)*OW+x/2]) bad++;
        end else if({o_r,o_g,o_b}!==24'd0 || y>=H || x>=W) bad++;
        if(cap_this) $fdisplay(fd,"%h",{o_r,o_g,o_b});
        npx++; x++;
    end
end
// Sequential directed stalls: address wait, accepted write across camera frames,
// delayed write response, and an accepted read lasting across display frames.
initial begin : faults
    if(STRESS) begin
        wait(first_good>=0);
        @(negedge aclk); hold_aw=1;
        repeat(20000) @(negedge aclk);
        hold_aw=0;
        wait(wvalid);
        @(negedge aclk); hold_w=1;
        repeat(150000) @(negedge aclk);
        hold_w=0;
        wait(dut.u_store.published_frames>published_seen-1);
        @(negedge aclk); hold_b=1;
        repeat(100000) @(negedge aclk);
        hold_b=0;
        wait(arvalid&&arready);
        @(negedge aclk); hold_r=1;
        repeat(200000) @(negedge aclk);
        hold_r=0;
        stress_done=1;
    end
end
initial begin
    repeat(20) @(negedge aclk);
    prst_n=1; rst_n=1;
    wait(frm>MAXFRM || (stress_done && frm>recovery_at+2 && good_run>=NGOOD &&
         banks_checked==3'b111 && $countones(displayed)>=2));
    @(negedge hclk);
    if(frm>MAXFRM) $fatal(1,"Timeout: no dynamic-frame convergence");
    if(STRESS && (dut.u_store.dropped_frames==0 || dut.u_store.overflow_frames==0 ||
       dut.u_store.rejected_frames==0)) $fatal(1,"Stress did not exercise drop/overflow/reject");
    $display("COUNTERS published=%0d rejected=%0d dropped=%0d overflow=%0d underflow=%0d banks=%b variants=%b",
        dut.u_store.published_frames,dut.u_store.rejected_frames,dut.u_store.dropped_frames,
        dut.u_store.overflow_frames,dut.u_store.underflow_frames,banks_checked,displayed);
    $display("=== tb_v03_checked PASS %0dx%0d phase=%0d rev=%0d vs=%0d stress=%0d ===",W,H,PHASE,REV,VS_MODE,STRESS);
    $finish;
end
initial begin
    #((W/2+140)*(H+45)*13.468*(MAXFRM+3));
    $fatal(1,"Global watchdog: simulation did not finish");
end
endmodule
