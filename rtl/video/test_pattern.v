// =============================================================================
// test_pattern.v  --  ArtFlow v02
// -----------------------------------------------------------------------------
// 在已有视频时序上叠加色条（不自己产生时序，直接复用 de/hs/vs），
// 用来确认从这里到 HDMI 口的 R/G/B 通道顺序正确。
//
// 画面布局（H_ACTIVE x V_ACTIVE）：
//   上 2/3 : 8 条竖条，从左到右  白 黄 青 绿 品红 红 蓝 黑
//   下 1/3 : 3 块纯色，从左到右  纯红 | 纯绿 | 纯蓝
//   -> 左下角必须是红、右下角必须是蓝，否则 R/B 接反
//
// i_mode : 0 = 摄像头直通
//          1 = 常显色条
//          2 = 上电后先显示 BOOT_FRAMES 帧色条，再自动切到摄像头
// 延迟 1 拍；vs/hs 极性无关（行计数在 vs 任意跳变时清零）。
// =============================================================================
module test_pattern
#(
    parameter H_ACTIVE    = 1920,
    parameter V_ACTIVE    = 1080,
    parameter BOOT_FRAMES = 300          // 1080p60 下约 5 秒
)
(
    input               i_clk,
    input               i_rstn,
    input      [1:0]    i_mode,

    input               i_de,
    input               i_hs,
    input               i_vs,
    input      [7:0]    i_r,
    input      [7:0]    i_g,
    input      [7:0]    i_b,

    output reg          o_de,
    output reg          o_hs,
    output reg          o_vs,
    output reg [7:0]    o_r,
    output reg [7:0]    o_g,
    output reg [7:0]    o_b,
    output              o_active         // 1 = 当前输出的是色条
);

localparam BAR_W   = H_ACTIVE / 8;
localparam X_1_3   = H_ACTIVE / 3;
localparam X_2_3   = H_ACTIVE * 2 / 3;
localparam Y_2_3   = V_ACTIVE * 2 / 3;
localparam EDGE_MAX = BOOT_FRAMES * 2;  // vs 每帧两个跳变沿

// ---------------------------------------------------------------- 计数
reg [11:0] x_cnt;
reg [11:0] x_in_bar;
reg [2:0]  bar_idx;
reg [11:0] y_cnt;
reg        de_d, vs_d;
reg [15:0] vs_edge_cnt;

always @(posedge i_clk) begin
    if (!i_rstn) begin
        de_d        <= 1'b0;
        vs_d        <= 1'b0;
        x_cnt       <= 12'd0;
        x_in_bar    <= 12'd0;
        bar_idx     <= 3'd0;
        y_cnt       <= 12'd0;
        vs_edge_cnt <= 16'd0;
    end else begin
        de_d <= i_de;
        vs_d <= i_vs;

        // 列计数：de 低时清零
        if (!i_de) begin
            x_cnt    <= 12'd0;
            x_in_bar <= 12'd0;
            bar_idx  <= 3'd0;
        end else begin
            x_cnt <= x_cnt + 1'b1;
            if (x_in_bar == BAR_W - 1) begin
                x_in_bar <= 12'd0;
                bar_idx  <= bar_idx + 1'b1;
            end else
                x_in_bar <= x_in_bar + 1'b1;
        end

        // 行计数：vs 任一跳变清零，de 下降沿 +1
        if (i_vs != vs_d)
            y_cnt <= 12'd0;
        else if (de_d && !i_de)
            y_cnt <= y_cnt + 1'b1;

        // 上电帧计数（饱和）
        if ((i_vs != vs_d) && (vs_edge_cnt != EDGE_MAX))
            vs_edge_cnt <= vs_edge_cnt + 1'b1;
    end
end

assign o_active = (i_mode == 2'd1) ||
                  ((i_mode == 2'd2) && (vs_edge_cnt != EDGE_MAX));

// ---------------------------------------------------------------- 色条颜色
reg [23:0] pat_rgb;   // {R,G,B}
always @(*) begin
    if (y_cnt >= Y_2_3) begin
        if      (x_cnt < X_1_3) pat_rgb = 24'hFF_00_00;   // 纯红
        else if (x_cnt < X_2_3) pat_rgb = 24'h00_FF_00;   // 纯绿
        else                    pat_rgb = 24'h00_00_FF;   // 纯蓝
    end else begin
        case (bar_idx)
            3'd0:    pat_rgb = 24'hFF_FF_FF;   // 白
            3'd1:    pat_rgb = 24'hFF_FF_00;   // 黄
            3'd2:    pat_rgb = 24'h00_FF_FF;   // 青
            3'd3:    pat_rgb = 24'h00_FF_00;   // 绿
            3'd4:    pat_rgb = 24'hFF_00_FF;   // 品红
            3'd5:    pat_rgb = 24'hFF_00_00;   // 红
            3'd6:    pat_rgb = 24'h00_00_FF;   // 蓝
            default: pat_rgb = 24'h00_00_00;   // 黑
        endcase
    end
end

// ---------------------------------------------------------------- 输出寄存
always @(posedge i_clk) begin
    if (!i_rstn) begin
        {o_de, o_hs, o_vs} <= 3'b000;
        {o_r, o_g, o_b}    <= 24'd0;
    end else begin
        o_de <= i_de;
        o_hs <= i_hs;
        o_vs <= i_vs;
        if (o_active && i_de)
            {o_r, o_g, o_b} <= pat_rgb;
        else
            {o_r, o_g, o_b} <= {i_r, i_g, i_b};
    end
end

endmodule
