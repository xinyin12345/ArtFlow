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
module tb_v03_pipe;

parameter int    W       = 160;
parameter int    H       = 40;
parameter string PREFIX  = "small";
parameter int    PHASE   = 0;
parameter int    GAP_PCT = 25;
parameter int    NGOOD   = 3;
parameter int    MAXFRM  = 12;       // 最多观察的输出帧数
parameter int    VBLANK  = 2000;     // 帧消隐（pclk 拍数）。真实传感器 >= 几十行；
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
wire [15:0]  wstrb;
wire         wlast, wvalid, wready, rlast, rvalid, rready, bvalid, bready;

cam_fb_pipe #(
    .AXI_DATA_WIDTH(128), .AXI_ADDR_WIDTH(32),
    .START_ADDR(32'h0), .BANK_BYTES(BANK),
    .MAX_IN_WIDTH(W), .MAX_OUT_WIDTH(OW)
) dut (
    .cfg_bayer(PHASE[1:0]), .cfg_pix_rev(1'b0),
    .cfg_gain_r(16'h0118), .cfg_gain_g(16'h0100), .cfg_gain_b(16'h015E),
    .i_pclk(pclk), .i_pclk_rstn(prst_n),
    .i_vs(s_vs), .i_hs(s_hs), .i_valid(s_valid), .i_raw(s_raw),
    .H_FRONT_PORCH(13'd8), .H_SYNC(13'd6), .H_VALID(OW[12:0]), .H_BACK_PORCH(13'd8),
    .V_FRONT_PORCH(13'd2), .V_SYNC(13'd2), .V_VALID(H[12:0]),  .V_BACK_PORCH(13'd3),
    .rst_n(rst_n), .o_clk(vclk), .o_hdmi_clk(hclk),
    .o_de(o_de), .o_hs(o_hs), .o_vs(o_vs), .o_r(o_r), .o_g(o_g), .o_b(o_b),
    .axi_clk(aclk),
    .awid(awid), .awaddr(awaddr), .awlen(awlen), .awsize(awsize), .awburst(awburst),
    .awcache(awcache), .awprot(awprot), .awlock(awlock), .awvalid(awvalid), .awready(awready),
    .arid(arid), .araddr(araddr), .arlen(arlen), .arsize(arsize), .arburst(arburst),
    .arcache(arcache), .arprot(arprot), .arlock(arlock), .arvalid(arvalid), .arready(arready),
    .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
    .rid(6'd0), .rdata(rdata), .rlast(rlast), .rvalid(rvalid), .rready(rready), .rresp(2'd0),
    .bid(6'd0), .bvalid(bvalid), .bready(bready));

axi_mem_model #(.DW(128), .AW(32), .STALL_PCT(20), .RD_LAT(12)) u_mem (
    .clk(aclk), .rst_n(rst_n),
    .awaddr(awaddr), .awlen(awlen), .awburst(awburst), .awvalid(awvalid), .awready(awready),
    .wdata(wdata), .wlast(wlast), .wvalid(wvalid), .wready(wready),
    .bvalid(bvalid), .bready(bready),
    .araddr(araddr), .arlen(arlen), .arburst(arburst), .arvalid(arvalid), .arready(arready),
    .rdata(rdata), .rlast(rlast), .rvalid(rvalid), .rready(rready));

// ---------------------------------------------------------------- 黄金数据
reg [9:0]  raw [0:W*H-1];
reg [23:0] exp_px [0:OW*OH-1];
initial begin
    $readmemh({PREFIX, "_raw.hex"}, raw);
    $readmemh($sformatf("%s_exp_p%0d.hex", PREFIX, PHASE), exp_px);
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
        for (y = 0; y < H; y++) begin
            s_hs <= 1;
            x = 0;
            while (x < W) begin
                @(posedge pclk);
                if ($urandom_range(99) >= GAP_PCT) begin
                    s_valid <= 1;
                    for (k = 0; k < 4; k++) s_raw[k*10 +: 10] <= raw[y*W + x + k];
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

// ---------------------------------------------------------------- HDMI 抓帧 + 逐像素比对
int  frm = 0, x = 0, y = -1, bad = 0, npx = 0, good_run = 0, first_good = -1, total_bad_frames = 0;
bit  dumped = 0;
reg  de_d = 0, vs_d = 0;
int  fd;
bit  cap_this = 0;

task automatic end_frame();
    if (frm > 0 || npx > 0) begin
        bit ok = (bad == 0) && (npx == W * H);
        $display("[%0t] out frame %0d : %0d px, %0d mismatch %s", $time, frm, npx, bad, ok ? "OK" : "");
        if (ok) begin
            good_run++;
            if (first_good < 0) first_good = frm;
        end else begin
            if (first_good >= 0) total_bad_frames++;  // 出现过好帧之后又坏 = 真错误
            good_run = 0;
        end
        if (cap_this) begin $fclose(fd); cap_this = 0; dumped = 1; end
    end
    frm++; bad = 0; npx = 0; y = -1;
endtask

always @(posedge hclk) begin
    vs_d <= o_vs;
    de_d <= o_de;
    if (o_vs && !vs_d) begin
        end_frame();
        if (good_run >= 1 && !dumped) begin
            fd = $fopen({PREFIX, "_cap.hex"}, "w");
            cap_this = 1;
        end
    end
    if (o_de && !de_d) begin y++; x = 0; end
    if (o_de) begin
        if (y >= 0 && y < H && x < W) begin
            if ({o_r, o_g, o_b} !== exp_px[(y/2)*OW + x/2]) begin
                if (bad < 10 && (first_good >= 0 || $test$plusargs("show_mm")))
                    $display("  MISMATCH frame %0d (%0d,%0d) got %h exp %h", frm, x, y, {o_r,o_g,o_b}, exp_px[(y/2)*OW + x/2]);
                bad++;
            end
        end else bad++;
        if (cap_this) $fdisplay(fd, "%h", {o_r, o_g, o_b});
        npx++;
        x++;
    end
end

// ---------------------------------------------------------------- DDR 内容检查（小端 XRGB8888）
function automatic int check_bank(int b);
    int n, errs = 0;
    for (n = 0; n < OW * OH; n++) begin
        longint wa = (b * BANK + n * 4) >> 4;
        bit [127:0] w = u_mem.rd_word(wa);
        bit [31:0]  p = w[(n % 4) * 32 +: 32];
        if (p !== {8'h00, exp_px[n]}) errs++;
    end
    return errs;
endfunction

// ---------------------------------------------------------------- 主流程
initial begin
    int b, e, nbank_ok;
    nbank_ok = 0;
    repeat (10) @(posedge aclk);
    prst_n = 1;
    rst_n  = 1;
    wait (frm > MAXFRM || good_run >= NGOOD + 1);
    @(posedge hclk);
    for (b = 0; b < 3; b++) begin
        e = check_bank(b);
        $display("DDR bank %0d @ %h : %0d / %0d pixel errors", b, b * BANK, e, OW * OH);
        if (e == 0) nbank_ok++;
    end
    $display("input frames=%0d  AXI: wr bursts=%0d rd bursts=%0d  protocol errors=%0d",
             in_frames, u_mem.n_wr_burst, u_mem.n_rd_burst, u_mem.n_err);
    if (good_run >= NGOOD && total_bad_frames == 0 && u_mem.n_err == 0 && nbank_ok >= 1)
        $display("=== tb_v03_pipe PASS  %0dx%0d phase=%0d : first good frame=%0d, %0d consecutive frames pixel-exact ===",
                 W, H, PHASE, first_good, good_run);
    else
        $display("=== tb_v03_pipe FAIL  good_run=%0d bad_after_good=%0d axi_err=%0d banks_ok=%0d ===",
                 good_run, total_bad_frames, u_mem.n_err, nbank_ok);
    $finish;
end

endmodule
