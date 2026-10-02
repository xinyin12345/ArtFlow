// =============================================================================
// tb_gamma_lut.v  --  ArtFlow v02 自检测试
// 新 gamma_lut（ROM 查表）与 v01 旧 gamma_correction 逐像素比对，
// 另外检查直通模式与 de 无效时输出为 0。
// 运行：cd sim ; vsim -do run_v02.do
// =============================================================================
`timescale 1ns/1ps
module tb_gamma_lut;
parameter OLD_FILE = "../rtl/gamma_conrrection/2P2.mem";
parameter LUT_FILE = "../rtl/gamma_conrrection/gamma_2p2_8b.mem";

reg clk = 0;  always #3.367 clk = ~clk;          // 148.5 MHz
reg rstn = 0;

reg        valid = 0, hs = 0, vs = 0, bypass = 0;
reg  [7:0] r = 0, g = 0, b = 0;

// ---------------- 旧模块（金标准，1 拍延迟）
wire [7:0] o_r_old, o_g_old, o_b_old;
wire       ov_old, ohs_old, ovs_old;
gamma_correction #(.DATA_WIDTH(8), .GAMMA_CURVE(OLD_FILE)) u_old (
    .i_pclk(clk), .i_rstn(rstn),
    .i_red(r), .i_green(g), .i_blue(b), .i_valid(valid), .i_hs(hs), .i_vs(vs),
    .o_red(o_r_old), .o_green(o_g_old), .o_blue(o_b_old),
    .o_valid(ov_old), .o_hs(ohs_old), .o_vs(ovs_old));

// ---------------- 新模块（2 拍延迟）
wire [7:0] o_r, o_g, o_b;
wire       ov, ohs, ovs;
gamma_lut #(.LUT_FILE(LUT_FILE)) u_new (
    .i_pclk(clk), .i_rstn(rstn), .i_bypass(bypass),
    .i_red(r), .i_green(g), .i_blue(b), .i_valid(valid), .i_hs(hs), .i_vs(vs),
    .o_red(o_r), .o_green(o_g), .o_blue(o_b),
    .o_valid(ov), .o_hs(ohs), .o_vs(ovs));

// 旧模块输出再延迟 1 拍，与新模块对齐
reg [7:0] r_old_d, g_old_d, b_old_d;
reg       v_old_d, hs_old_d, vs_old_d;
always @(posedge clk) begin
    {r_old_d, g_old_d, b_old_d}   <= {o_r_old, o_g_old, o_b_old};
    {v_old_d, hs_old_d, vs_old_d} <= {ov_old, ohs_old, ovs_old};
end

// 输入延迟 2 拍（直通模式参考）
reg [23:0] in_d1, in_d2;
reg        vin_d1, vin_d2;
always @(posedge clk) begin
    in_d1 <= {r, g, b};  in_d2 <= in_d1;
    vin_d1 <= valid;     vin_d2 <= vin_d1;
end

integer errors = 0, checks = 0;
reg     compare_en = 0;        // 1 = 与旧模块比；bypass 时与输入比

always @(posedge clk) if (compare_en) begin
    if ((^{o_r,o_g,o_b,ov,ohs,ovs}) === 1'bx ||
        (!bypass && (^{r_old_d,g_old_d,b_old_d,v_old_d,hs_old_d,vs_old_d}) === 1'bx))
        $fatal(1,"Unknown gamma output/reference; check LUT files");
    checks = checks + 1;
    if (!bypass) begin
        if ({o_r, o_g, o_b, ov, ohs, ovs} !==
            {r_old_d, g_old_d, b_old_d, v_old_d, hs_old_d, vs_old_d}) begin
            errors = errors + 1;
            if (errors <= 10)
                $display("[ERR] t=%0t new=%h%h%h v%b h%b s%b  old=%h%h%h v%b h%b s%b", $time,
                    o_r, o_g, o_b, ov, ohs, ovs, r_old_d, g_old_d, b_old_d, v_old_d, hs_old_d, vs_old_d);
        end
    end else begin
        if ({o_r, o_g, o_b} !== (vin_d2 ? in_d2 : 24'd0)) begin
            errors = errors + 1;
            if (errors <= 10) $display("[ERR bypass] t=%0t out=%h exp=%h", $time, {o_r,o_g,o_b}, in_d2);
        end
    end
end

integer i, k;
initial begin
    repeat (10) @(posedge clk);
    rstn <= 1;
    // 旧模块要 ~1026 拍才能把曲线从 BRAM 拷进寄存器数组
    repeat (1100) @(posedge clk);

    repeat (5) @(posedge clk);          // 输入保持 0，两条流水线状态一致
    compare_en <= 1;
    // 1) 全 256 灰阶扫描，三个通道错开
    for (i = 0; i < 256; i = i + 1) begin
        @(posedge clk);
        valid <= 1; hs <= 0; vs <= 0;
        r <= i; g <= 255 - i; b <= (i * 7) & 8'hFF;
    end
    // 2) 随机数据 + 随机 valid/hs/vs
    for (k = 0; k < 20000; k = k + 1) begin
        @(posedge clk);
        valid <= ($random & 3) != 0;
        hs    <= $random; vs <= $random;
        r <= $random; g <= $random; b <= $random;
    end
    // 3) 直通模式
    @(posedge clk); compare_en <= 0; bypass <= 1;
    repeat (3) @(posedge clk);
    compare_en <= 1;
    for (k = 0; k < 2000; k = k + 1) begin
        @(posedge clk);
        valid <= $random; r <= $random; g <= $random; b <= $random;
    end
    @(posedge clk); compare_en <= 0;

    if (errors == 0) $display("=== tb_gamma_lut PASS  (%0d cycles checked) ===", checks);
    else             $display("=== tb_gamma_lut FAIL  errors=%0d / %0d ===", errors, checks);
    $finish;
end
endmodule
