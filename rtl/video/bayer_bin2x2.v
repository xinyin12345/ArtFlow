// =============================================================================
// bayer_bin2x2.v  --  ArtFlow v03
// -----------------------------------------------------------------------------
// 2x2 Bayer 合并：每个 2x2 Bayer 块 (R, Gr, Gb, B) 直接合成 1 个 RGB 像素，
// 1920x1080 RAW -> 960x540 RGB，不做插值（没有 debayer 行缓存/插值误差）。
//
//   R = px(R 位置)
//   G = (Gr + Gb) / 2        （在乘增益时一起做，见下）
//   B = px(B 位置)
//   白平衡增益 Q8.8（256 = 1.0），10bit 精度下相乘后截到 8bit 并饱和：
//     R8 = min(255, (R10       * gain_r) >> 10)
//     G8 = min(255, ((Gr+Gb)   * gain_g) >> 11)
//     B8 = min(255, (B10       * gain_b) >> 10)
//   （与 tools/v03_golden.py 的 Python 模型逐位一致）
//
// 输入：CSI RX 像素口，4 像素/时钟，RAW10。
//   i_pix_rev = 0 : i_data[9:0]   是最左边的像素（Efinix CSI RX 手册的约定）
//   i_pix_rev = 1 : i_data[39:30] 是最左边的像素
// i_bayer：帧左上角 2x2 块的排列（= R 所在位置）
//   0 = RGGB  1 = GRBG  2 = GBRG  3 = BGGR
//   bit0 = R 在奇数列，bit1 = R 在奇数行
//
// 行/帧边界：
//   * i_hs 为行有效电平（与 v02 顶层 de & hs 的用法一致），下降沿 = 行结束；
//     行内 i_valid 允许有空拍（CSI 像素 FIFO 会断续输出）。
//   * i_vs 的任意边沿都把行计数清零（高有效/低有效/脉冲都能正确对齐第 0 行）。
//
// 输出：只在奇数行（每对行的第二行）输出，每拍 2 个像素：
//   o_data = {px1, px0}，px0 在左；px = {8'h00, R, G, B}（XRGB8888）
//   平均速率 = 输入的一半，峰值 2 像素/拍。
// 固定延迟：输入到输出 5 拍。
// =============================================================================
module bayer_bin2x2
#(
    parameter MAX_IN_WIDTH = 1920            // 每行 RAW 像素数上限（4 的倍数）
)
(
    input               clk,
    input               rstn,               // 同步复位，低有效

    input      [1:0]    i_bayer,
    input               i_pix_rev,
    input      [15:0]   i_gain_r,
    input      [15:0]   i_gain_g,
    input      [15:0]   i_gain_b,

    input               i_vs,
    input               i_hs,
    input               i_valid,
    input      [39:0]   i_data,             // 4 x RAW10

    output              o_vs,
    output              o_hs,               // 奇数行的行有效（仅供观察）
    output reg          o_valid,
    output reg [63:0]   o_data
);

localparam LB_DEPTH = MAX_IN_WIDTH / 4;
localparam AW       = (LB_DEPTH <= 2) ? 1 : $clog2(LB_DEPTH);

// ---------------------------------------------------------------- stage A：输入寄存 + 像素顺序统一
reg         a_vs = 1'b0, a_hs = 1'b0, a_valid = 1'b0;
reg  [39:0] a_data = 40'd0;              // {p3,p2,p1,p0}，p0 最左
always @(posedge clk) begin
    a_vs    <= i_vs;
    a_hs    <= i_hs;
    a_valid <= i_valid & i_hs;
    a_data  <= i_pix_rev ? {i_data[9:0], i_data[19:10], i_data[29:20], i_data[39:30]} : i_data;
end

// ---------------------------------------------------------------- 行/列计数
reg          vs_d = 1'b0, hs_d = 1'b0;
reg          row_odd = 1'b0;
reg          line_has_data = 1'b0;
reg [AW-1:0] col = {AW{1'b0}};
wire         vs_edge  = vs_d ^ a_vs;
wire         line_end = hs_d & ~a_hs;

always @(posedge clk) begin
    vs_d <= a_vs;
    hs_d <= a_hs;
    if (!rstn || vs_edge) begin
        row_odd       <= 1'b0;
        line_has_data <= 1'b0;
        col           <= {AW{1'b0}};
    end else if (line_end) begin
        if (line_has_data)
            row_odd <= ~row_odd;
        line_has_data <= 1'b0;
        col           <= {AW{1'b0}};
    end else if (a_valid) begin
        line_has_data <= 1'b1;
        col           <= col + 1'b1;
    end
end

// ---------------------------------------------------------------- 行缓存：偶数行写，奇数行读（同址不冲突）
reg [39:0] lb [0:LB_DEPTH-1];
reg [39:0] lb_q = 40'd0;
always @(posedge clk) begin
    if (a_valid && !row_odd)
        lb[col] <= a_data;
    lb_q <= lb[col];
end

// ---------------------------------------------------------------- stage B：上下两行对齐
reg         b_valid = 1'b0;
reg  [39:0] b_bot   = 40'd0;
always @(posedge clk) begin
    b_valid <= a_valid & row_odd & ~vs_edge & rstn;
    b_bot   <= a_data;
end
wire [39:0] b_top = lb_q;

// ---------------------------------------------------------------- stage C：按 Bayer 相位取 R / G1+G2 / B
wire ph_x = i_bayer[0];
wire ph_y = i_bayer[1];

function [9:0] px;                       // 在一个 2x2 块里按 (行,列) 取像素
    input [19:0] top;                    // {右, 左}
    input [19:0] bot;
    input        r;
    input        c;
    begin
        case ({r, c})
            2'b00: px = top[9:0];
            2'b01: px = top[19:10];
            2'b10: px = bot[9:0];
            default: px = bot[19:10];
        endcase
    end
endfunction

reg        c_valid = 1'b0;
reg [9:0]  c_r  [0:1];
reg [10:0] c_gs [0:1];
reg [9:0]  c_b  [0:1];
integer k;
always @(posedge clk) begin
    c_valid <= b_valid;
    for (k = 0; k < 2; k = k + 1) begin
        c_r[k]  <= px(b_top[k*20 +: 20], b_bot[k*20 +: 20],  ph_y,  ph_x);
        c_b[k]  <= px(b_top[k*20 +: 20], b_bot[k*20 +: 20], ~ph_y, ~ph_x);
        c_gs[k] <= {1'b0, px(b_top[k*20 +: 20], b_bot[k*20 +: 20],  ph_y, ~ph_x)}
                 + {1'b0, px(b_top[k*20 +: 20], b_bot[k*20 +: 20], ~ph_y,  ph_x)};
    end
end

// ---------------------------------------------------------------- stage D：乘白平衡增益
reg        d_valid = 1'b0;
reg [25:0] d_pr [0:1];
reg [26:0] d_pg [0:1];
reg [25:0] d_pb [0:1];
always @(posedge clk) begin
    d_valid <= c_valid;
    for (k = 0; k < 2; k = k + 1) begin
        d_pr[k] <= c_r[k]  * i_gain_r;
        d_pg[k] <= c_gs[k] * i_gain_g;
        d_pb[k] <= c_b[k]  * i_gain_b;
    end
end

// ---------------------------------------------------------------- stage E：饱和 + 打包输出
function [7:0] sat_r;                    // (x >> 10) 饱和到 255，x 为 26bit
    input [25:0] x;
    sat_r = (|x[25:18]) ? 8'hFF : x[17:10];
endfunction
function [7:0] sat_g;                    // (x >> 11) 饱和到 255，x 为 27bit
    input [26:0] x;
    sat_g = (|x[26:19]) ? 8'hFF : x[18:11];
endfunction

always @(posedge clk) begin
    o_valid <= d_valid;
    o_data  <= {8'h00, sat_r(d_pr[1]), sat_g(d_pg[1]), sat_r(d_pb[1]),
                8'h00, sat_r(d_pr[0]), sat_g(d_pg[0]), sat_r(d_pb[0])};
end

// ---------------------------------------------------------------- vs / hs 与数据同延迟（A 之后再 4 拍）
reg [3:0] vs_sr = 4'd0, hs_sr = 4'd0;
always @(posedge clk) begin
    vs_sr <= {vs_sr[2:0], a_vs};
    hs_sr <= {hs_sr[2:0], a_hs & row_odd};
end
assign o_vs = vs_sr[3];
assign o_hs = hs_sr[3];

endmodule
