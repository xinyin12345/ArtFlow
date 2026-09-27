// =============================================================================
// tb_test_pattern.v  --  ArtFlow v02 自检测试
// 缩小分辨率（96x24）跑色条模块，逐像素和期望颜色比对：
//   mode=1 常显色条 / mode=0 直通 / mode=2 上电 BOOT_FRAMES 帧后自动切回直通
// =============================================================================
`timescale 1ns/1ps
module tb_test_pattern;

localparam H_ACT = 96, H_FP = 4, H_SYNC = 4, H_BP = 8;
localparam V_ACT = 24, V_FP = 2, V_SYNC = 2, V_BP = 3;
localparam H_TOT = H_ACT + H_FP + H_SYNC + H_BP;
localparam V_TOT = V_ACT + V_FP + V_SYNC + V_BP;
localparam BOOT  = 2;

reg clk = 0;  always #3.367 clk = ~clk;
reg rstn = 0;
reg [1:0] mode = 2'd1;

// ---------------- 简易时序发生器（hs/vs 高有效）
reg [11:0] hc = 0, vc = 0;
always @(posedge clk) begin
    if (hc == H_TOT - 1) begin
        hc <= 0;
        vc <= (vc == V_TOT - 1) ? 0 : vc + 1;
    end else hc <= hc + 1;
end
wire de = (hc < H_ACT) && (vc < V_ACT);
wire hs = (hc >= H_ACT + H_FP) && (hc < H_ACT + H_FP + H_SYNC);
wire vs = (vc >= V_ACT + V_FP) && (vc < V_ACT + V_FP + V_SYNC);
// 摄像头数据用坐标编码，便于检查直通
wire [7:0] cam_r = hc[7:0], cam_g = vc[7:0], cam_b = 8'h5A;

wire [7:0] o_r, o_g, o_b;
wire o_de, o_hs, o_vs, active;
test_pattern #(.H_ACTIVE(H_ACT), .V_ACTIVE(V_ACT), .BOOT_FRAMES(BOOT)) dut (
    .i_clk(clk), .i_rstn(rstn), .i_mode(mode),
    .i_de(de), .i_hs(hs), .i_vs(vs), .i_r(cam_r), .i_g(cam_g), .i_b(cam_b),
    .o_de(o_de), .o_hs(o_hs), .o_vs(o_vs), .o_r(o_r), .o_g(o_g), .o_b(o_b),
    .o_active(active));

// 期望值（输入打 1 拍对齐）
reg [11:0] hc_d, vc_d; reg de_d, hs_d, vs_d, act_d; reg [23:0] cam_d;
always @(posedge clk) begin
    hc_d <= hc; vc_d <= vc; de_d <= de; hs_d <= hs; vs_d <= vs;
    cam_d <= {cam_r, cam_g, cam_b}; act_d <= active;
end

function [23:0] expect_bar(input [11:0] x, input [11:0] y);
    reg [2:0] idx;
    begin
        if (y >= V_ACT * 2 / 3) begin
            if      (x < H_ACT / 3)     expect_bar = 24'hFF0000;
            else if (x < H_ACT * 2 / 3) expect_bar = 24'h00FF00;
            else                        expect_bar = 24'h0000FF;
        end else begin
            idx = x / (H_ACT / 8);
            case (idx)
                0: expect_bar = 24'hFFFFFF; 1: expect_bar = 24'hFFFF00;
                2: expect_bar = 24'h00FFFF; 3: expect_bar = 24'h00FF00;
                4: expect_bar = 24'hFF00FF; 5: expect_bar = 24'hFF0000;
                6: expect_bar = 24'h0000FF; default: expect_bar = 24'h000000;
            endcase
        end
    end
endfunction

integer errors = 0, checks = 0, frame = 0;
reg     check_en = 0;
reg [23:0] exp_rgb;

always @(posedge clk) if (check_en) begin
    exp_rgb = (act_d && de_d) ? expect_bar(hc_d, vc_d) : cam_d;
    checks  = checks + 1;
    if ({o_de, o_hs, o_vs} !== {de_d, hs_d, vs_d} || {o_r, o_g, o_b} !== exp_rgb) begin
        errors = errors + 1;
        if (errors <= 10)
            $display("[ERR] mode=%0d x=%0d y=%0d out=%h exp=%h", mode, hc_d, vc_d, {o_r,o_g,o_b}, exp_rgb);
    end
end

// 帧计数：vc 回到 0 时
always @(posedge clk) if (hc == 0 && vc == 0) frame = frame + 1;

task wait_frames(input integer n);
    integer f0; begin f0 = frame; wait (frame >= f0 + n); end
endtask

initial begin
    // 从一帧开头附近释放复位，保证第一帧计数完整
    wait (vc == V_TOT - 1 && hc == 0);
    rstn <= 1;
    @(posedge clk); @(posedge clk); check_en <= 1;

    mode <= 2'd1; wait_frames(2);
    if (!active) begin errors = errors + 1; $display("[ERR] mode1 active=0"); end

    mode <= 2'd0; wait_frames(1);
    if (active)  begin errors = errors + 1; $display("[ERR] mode0 active=1"); end

    mode <= 2'd2;                   // 此时上电帧计数早已超过 BOOT -> 应为直通
    wait_frames(1);
    if (active)  begin errors = errors + 1; $display("[ERR] mode2 after boot active=1"); end

    // 重新复位，验证 mode2 的“先色条后摄像头”
    check_en <= 0; rstn <= 0;
    wait (vc == V_TOT - 1 && hc == 0);
    rstn <= 1;
    @(posedge clk); @(posedge clk); check_en <= 1;
    wait_frames(1);
    if (!active) begin errors = errors + 1; $display("[ERR] mode2 boot: active=0 too early"); end
    wait_frames(BOOT + 1);
    if (active)  begin errors = errors + 1; $display("[ERR] mode2 boot: still active"); end

    if (errors == 0) $display("=== tb_test_pattern PASS  (%0d cycles checked) ===", checks);
    else             $display("=== tb_test_pattern FAIL  errors=%0d / %0d ===", errors, checks);
    $finish;
end
endmodule
