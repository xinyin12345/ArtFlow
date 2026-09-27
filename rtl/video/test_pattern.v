// =============================================================================
// test_pattern.v  --  ArtFlow v02
// -----------------------------------------------------------------------------
// 色条发生器，内置独立的视频时序（在 hdmi_tx_slow_clk 上自己数 1080p60），
// 所以显示色条时**不依赖摄像头 / DDR / frame_buffer**：
// 只要 USER_PLL、复位和 HDMI 编码输出正常，就一定能出色条。
// 用它可以把“输出链路问题”和“摄像头/DDR 链路问题”分开。
//
// 画面布局（H_ACTIVE x V_ACTIVE）：
//   上 2/3 : 8 条竖条，从左到右  白 黄 青 绿 品红 红 蓝 黑
//   下 1/3 : 3 块纯色，从左到右  纯红 | 纯绿 | 纯蓝
//   -> 左下角必须是红、右下角必须是蓝，否则输出端 R/B 接反
//
// i_mode : 0 = 摄像头直通（输出 = 输入打 1 拍）
//          1 = 常显色条（使用内部时序）
//          2 = 上电后先显示 BOOT_FRAMES 帧色条，再切到摄像头
//              （切换瞬间显示器会重新同步一次，属正常现象）
// 内部时序 hs/vs 为高有效，与 frame_buffer 输出一致。
// =============================================================================
module test_pattern
#(
    parameter H_ACTIVE    = 1920,
    parameter H_FP        = 88,
    parameter H_SYNC      = 44,
    parameter H_BP        = 148,
    parameter V_ACTIVE    = 1080,
    parameter V_FP        = 4,
    parameter V_SYNC      = 5,
    parameter V_BP        = 36,
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

localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
localparam V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;
localparam BAR_W   = H_ACTIVE / 8;
localparam X_1_3   = H_ACTIVE / 3;
localparam X_2_3   = H_ACTIVE * 2 / 3;
localparam Y_2_3   = V_ACTIVE * 2 / 3;

// ---------------------------------------------------------------- 内部时序
reg [12:0] h_cnt;
reg [12:0] v_cnt;
reg [11:0] x_in_bar;
reg [2:0]  bar_idx;
reg [15:0] frame_cnt;

wire g_de = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
wire g_hs = (h_cnt >= H_ACTIVE + H_FP) && (h_cnt < H_ACTIVE + H_FP + H_SYNC);
wire g_vs = (v_cnt >= V_ACTIVE + V_FP) && (v_cnt < V_ACTIVE + V_FP + V_SYNC);

always @(posedge i_clk) begin
    if (!i_rstn) begin
        h_cnt     <= 13'd0;
        v_cnt     <= 13'd0;
        x_in_bar  <= 12'd0;
        bar_idx   <= 3'd0;
        frame_cnt <= 16'd0;
    end else begin
        if (h_cnt == H_TOTAL - 1) begin
            h_cnt <= 13'd0;
            if (v_cnt == V_TOTAL - 1) begin
                v_cnt <= 13'd0;
                if (frame_cnt != BOOT_FRAMES)
                    frame_cnt <= frame_cnt + 1'b1;
            end else
                v_cnt <= v_cnt + 1'b1;
        end else
            h_cnt <= h_cnt + 1'b1;

        // 竖条序号（避免除法）：有效区外清零，行首从 0 开始
        if (h_cnt >= H_ACTIVE - 1) begin
            x_in_bar <= 12'd0;
            bar_idx  <= 3'd0;
        end else if (x_in_bar == BAR_W - 1) begin
            x_in_bar <= 12'd0;
            bar_idx  <= bar_idx + 1'b1;
        end else
            x_in_bar <= x_in_bar + 1'b1;
    end
end

assign o_active = (i_mode == 2'd1) ||
                  ((i_mode == 2'd2) && (frame_cnt != BOOT_FRAMES));

// ---------------------------------------------------------------- 色条颜色
reg [23:0] pat_rgb;   // {R,G,B}
always @(*) begin
    if (v_cnt >= Y_2_3) begin
        if      (h_cnt < X_1_3) pat_rgb = 24'hFF_00_00;   // 纯红
        else if (h_cnt < X_2_3) pat_rgb = 24'h00_FF_00;   // 纯绿
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
    end else if (o_active) begin
        o_de <= g_de;
        o_hs <= g_hs;
        o_vs <= g_vs;
        {o_r, o_g, o_b} <= g_de ? pat_rgb : 24'd0;
    end else begin
        o_de <= i_de;
        o_hs <= i_hs;
        o_vs <= i_vs;
        {o_r, o_g, o_b} <= {i_r, i_g, i_b};
    end
end

endmodule
