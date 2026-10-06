// =============================================================================
// gamma_lut.v  --  ArtFlow v02
// -----------------------------------------------------------------------------
// 8-bit Gamma 校正：R/G/B 各一块 256x8 ROM（推断为 BRAM），同步查表。
// 取代 v01 的 gamma_correction.v —— 旧模块把 1024 项曲线逐拍拷贝进
// 1024x10 的寄存器数组（约 1 万个 FF + 3 组 1024:1 大 MUX），资源和时序都很差。
//
//   延迟    : 固定 2 拍（数据 / de / hs / vs 同步延迟）
//   i_bypass: 1 = 直通（仍保持 2 拍延迟，切换时画面不错位）
//   de 无效期间输出 0，与旧模块行为一致
//
// LUT 文件：256 行，每行 2 位十六进制，由 tools/gen_gamma_lut.py 生成
// =============================================================================
module gamma_lut
#(
    parameter LUT_FILE = "./rtl/gamma_conrrection/gamma_2p2_8b.mem"
)
(
    input               i_pclk,
    input               i_rstn,
    input               i_bypass,

    input               i_valid,
    input               i_hs,
    input               i_vs,
    input      [7:0]    i_red,
    input      [7:0]    i_green,
    input      [7:0]    i_blue,

    output reg [7:0]    o_red,
    output reg [7:0]    o_green,
    output reg [7:0]    o_blue,
    output reg          o_valid,
    output reg          o_hs,
    output reg          o_vs
);

// ---------------------------------------------------------------- ROM x3
(* syn_ramstyle = "block_ram" *) reg [7:0] rom_r [0:255];
(* syn_ramstyle = "block_ram" *) reg [7:0] rom_g [0:255];
(* syn_ramstyle = "block_ram" *) reg [7:0] rom_b [0:255];

initial begin
    $readmemh(LUT_FILE, rom_r);
    $readmemh(LUT_FILE, rom_g);
    $readmemh(LUT_FILE, rom_b);
end

// ---------------------------------------------------------------- 第 1 拍：同步读 ROM
reg [7:0] q_r, q_g, q_b;          // ROM 输出（BRAM 读寄存器）
reg [7:0] d_r, d_g, d_b;          // 直通数据
reg       v_1p, hs_1p, vs_1p;

always @(posedge i_pclk) begin
    q_r <= rom_r[i_red];
    q_g <= rom_g[i_green];
    q_b <= rom_b[i_blue];
end

always @(posedge i_pclk) begin
    if (!i_rstn) begin
        {v_1p, hs_1p, vs_1p} <= 3'b000;
        {d_r, d_g, d_b}      <= 24'd0;
    end else begin
        v_1p  <= i_valid;
        hs_1p <= i_hs;
        vs_1p <= i_vs;
        d_r   <= i_red;
        d_g   <= i_green;
        d_b   <= i_blue;
    end
end

// ---------------------------------------------------------------- 第 2 拍：输出寄存
always @(posedge i_pclk) begin
    if (!i_rstn) begin
        {o_red, o_green, o_blue} <= 24'd0;
        {o_valid, o_hs, o_vs}    <= 3'b000;
    end else begin
        o_valid <= v_1p;
        o_hs    <= hs_1p;
        o_vs    <= vs_1p;
        if (!v_1p)
            {o_red, o_green, o_blue} <= 24'd0;
        else if (i_bypass)
            {o_red, o_green, o_blue} <= {d_r, d_g, d_b};
        else
            {o_red, o_green, o_blue} <= {q_r, q_g, q_b};
    end
end

endmodule
