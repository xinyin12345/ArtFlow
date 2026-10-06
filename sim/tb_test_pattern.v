// =============================================================================
// tb_test_pattern.v  --  ArtFlow v02 自检测试（色条带独立时序版本）
// 缩小分辨率（96x24）：
//   mode=1 : 输出时序必须等于内部时序（与输入无关），颜色逐像素比对
//   mode=0 : 输出 = 输入打 1 拍
//   mode=2 : 复位后 BOOT_FRAMES 帧色条，然后切直通
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

// ---------------- “摄像头”输入：故意用与色条无关的时序和数据
reg [7:0] in_cnt = 0;
wire in_de = in_cnt[3];
wire in_hs = in_cnt[5];
wire in_vs = in_cnt[7];
always @(posedge clk) in_cnt <= in_cnt + 1'b1;
wire [7:0] cam_r = in_cnt, cam_g = ~in_cnt, cam_b = 8'h5A;

wire [7:0] o_r, o_g, o_b;
wire o_de, o_hs, o_vs, active;
test_pattern #(.H_ACTIVE(H_ACT), .H_FP(H_FP), .H_SYNC(H_SYNC), .H_BP(H_BP),
               .V_ACTIVE(V_ACT), .V_FP(V_FP), .V_SYNC(V_SYNC), .V_BP(V_BP),
               .BOOT_FRAMES(BOOT)) dut (
    .i_clk(clk), .i_rstn(rstn), .i_mode(mode),
    .i_de(in_de), .i_hs(in_hs), .i_vs(in_vs), .i_r(cam_r), .i_g(cam_g), .i_b(cam_b),
    .o_de(o_de), .o_hs(o_hs), .o_vs(o_vs), .o_r(o_r), .o_g(o_g), .o_b(o_b),
    .o_active(active));

// ---------------- 参考时序（与 DUT 同时复位）
reg [12:0] hc, vc;
always @(posedge clk) begin
    if (!rstn) begin hc <= 0; vc <= 0; end
    else if (hc == H_TOT - 1) begin hc <= 0; vc <= (vc == V_TOT - 1) ? 0 : vc + 1; end
    else hc <= hc + 1;
end
wire r_de = (hc < H_ACT) && (vc < V_ACT);
wire r_hs = (hc >= H_ACT + H_FP) && (hc < H_ACT + H_FP + H_SYNC);
wire r_vs = (vc >= V_ACT + V_FP) && (vc < V_ACT + V_FP + V_SYNC);

function [23:0] expect_bar(input [12:0] x, input [12:0] y);
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

// 期望值：所有输入打 1 拍
reg [26:0] exp_q;          // {de,hs,vs,rgb}
reg        act_d;
always @(posedge clk) begin
    act_d <= active;
    if (active)
        exp_q <= {r_de, r_hs, r_vs, r_de ? expect_bar(hc, vc) : 24'd0};
    else
        exp_q <= {in_de, in_hs, in_vs, cam_r, cam_g, cam_b};
end

integer errors = 0, checks = 0, frames = 0;
reg     check_en = 0;
always @(posedge clk) if (check_en) begin
    checks = checks + 1;
    if ({o_de, o_hs, o_vs, o_r, o_g, o_b} !== exp_q) begin
        errors = errors + 1;
        if (errors <= 10)
            $display("[ERR] t=%0t mode=%0d act=%b out=%b%b%b_%h exp=%h", $time, mode, act_d,
                     o_de, o_hs, o_vs, {o_r, o_g, o_b}, exp_q);
    end
end
always @(posedge clk) if (rstn && hc == H_TOT - 1 && vc == V_TOT - 1) frames = frames + 1;

task wait_frames(input integer n);
    integer f0; begin f0 = frames; wait (frames >= f0 + n); @(posedge clk); end
endtask

initial begin
    // ---- mode 1：常显色条
    mode = 2'd1;
    repeat (5) @(posedge clk); rstn <= 1;
    @(posedge clk); @(posedge clk); check_en <= 1;
    wait_frames(2);
    if (!active) begin errors = errors + 1; $display("[ERR] mode1 active=0"); end

    // ---- mode 0：直通
    mode <= 2'd0; @(posedge clk);
    wait_frames(1);
    if (active)  begin errors = errors + 1; $display("[ERR] mode0 active=1"); end

    // ---- mode 2：复位后先色条再直通
    check_en <= 0; rstn <= 0; mode <= 2'd2;
    repeat (5) @(posedge clk); rstn <= 1;
    @(posedge clk); @(posedge clk); check_en <= 1;
    wait_frames(1);
    if (!active) begin errors = errors + 1; $display("[ERR] mode2: active=0 too early"); end
    wait_frames(BOOT);
    if (active)  begin errors = errors + 1; $display("[ERR] mode2: still active after boot"); end
    wait_frames(1);

    if (errors == 0) $display("=== tb_test_pattern PASS  (%0d cycles checked) ===", checks);
    else             $display("=== tb_test_pattern FAIL  errors=%0d / %0d ===", errors, checks);
    $finish;
end
endmodule
