// =============================================================================
// tb_bayer_bin2x2.v  --  ArtFlow v03 单元自检
//   输入：tools/v03_golden.py gen --w 64 --h 16 --out unit 生成的 RAW 和期望值
//   遍历：4 种 Bayer 相位 x 2 种 CSI 像素顺序 x 2 种 vs 形式（整帧高电平 / 帧头短脉冲）
//   每种组合 2 帧；行内 i_valid 随机断续（~30% 空拍），行消隐长度随机
//   每个输出像素与 Python 黄金模型逐位比对，并检查每帧输出像素数
// =============================================================================
`timescale 1ns/1ps
module tb_bayer_bin2x2;

localparam W = 64, H = 16;
localparam OW = W / 2, OH = H / 2;

reg clk = 0;  always #10 clk = ~clk;      // 50 MHz
reg rstn = 0;

reg  [1:0]  bayer   = 0;
reg         pix_rev = 0;
reg         vs = 0, hs = 0, valid = 0;
reg  [39:0] data = 0;

wire        o_vs, o_hs, o_valid;
wire [63:0] o_data;

bayer_bin2x2 #(.MAX_IN_WIDTH(W)) dut (
    .clk(clk), .rstn(rstn),
    .i_bayer(bayer), .i_pix_rev(pix_rev),
    .i_gain_r(16'h0118), .i_gain_g(16'h00FF), .i_gain_b(16'h015E),
    .i_vs(vs), .i_hs(hs), .i_valid(valid), .i_data(data),
    .o_vs(o_vs), .o_hs(o_hs), .o_valid(o_valid), .o_data(o_data));

reg [9:0]  raw [0:W*H-1];
reg [23:0] exp0 [0:OW*OH-1];
reg [23:0] exp1 [0:OW*OH-1];
reg [23:0] exp2 [0:OW*OH-1];
reg [23:0] exp3 [0:OW*OH-1];
initial begin
    $readmemh("unit_raw.hex",    raw);
    $readmemh("unit_exp_p0.hex", exp0);
    $readmemh("unit_exp_p1.hex", exp1);
    $readmemh("unit_exp_p2.hex", exp2);
    $readmemh("unit_exp_p3.hex", exp3);
end

function [23:0] expect;
    input integer i;
    case (bayer)
        2'd0: expect = exp0[i];
        2'd1: expect = exp1[i];
        2'd2: expect = exp2[i];
        default: expect = exp3[i];
    endcase
endfunction

// ---------------------------------------------------------------- 检查
integer idx = 0, errors = 0, checked = 0, frames = 0;
reg     o_vs_d = 0;
always @(posedge clk) begin
    o_vs_d <= o_vs;
    if (o_vs_d != o_vs) begin
        if (idx != 0) begin
            if (idx != OW * OH) begin
                errors = errors + 1;
                $display("ERROR: frame has %0d pixels, expected %0d (bayer=%0d rev=%0d)", idx, OW*OH, bayer, pix_rev);
            end
            frames = frames + 1;
        end
        idx = 0;
    end
    if (o_valid) begin : chk
        integer p;
        for (p = 0; p < 2; p = p + 1) begin
            if (idx >= OW * OH) begin
                errors = errors + 1;
                if (errors < 10) $display("ERROR: extra pixel (bayer=%0d rev=%0d)", bayer, pix_rev);
            end else if (o_data[p*32 +: 32] !== {8'h00, expect(idx)}) begin
                errors = errors + 1;
                if (errors < 10)
                    $display("ERROR: bayer=%0d rev=%0d pix(%0d,%0d) got %h exp %h", bayer, pix_rev,
                             idx % OW, idx / OW, o_data[p*32 +: 32], expect(idx));
            end
            idx = idx + 1;
            checked = checked + 1;
        end
    end
end

// ---------------------------------------------------------------- 激励
task send_frame(input integer vs_mode);   // 0 = vs 整帧高, 1 = vs 帧头短脉冲
    integer y, x, gap, k;
    begin
        @(posedge clk);
        vs <= 1;
        if (vs_mode == 1) begin repeat (4) @(posedge clk); vs <= 0; end
        repeat (6) @(posedge clk);
        for (y = 0; y < H; y = y + 1) begin
            hs <= 1;
            x = 0;
            while (x < W) begin
                @(posedge clk);
                if (($random & 3) != 0) begin
                    valid <= 1;
                    for (k = 0; k < 4; k = k + 1) begin
                        if (pix_rev) data[(3-k)*10 +: 10] <= raw[y*W + x + k];
                        else         data[k*10     +: 10] <= raw[y*W + x + k];
                    end
                    x = x + 4;
                end else begin
                    valid <= 0;
                    data  <= $random;              // 空拍数据是垃圾，必须被忽略
                end
            end
            @(posedge clk);
            valid <= 0; hs <= 0;
            gap = 3 + ($random & 7);
            repeat (gap) @(posedge clk);
        end
        repeat (5) @(posedge clk);
        vs <= 0;
        repeat (20) @(posedge clk);
    end
endtask

integer ph, rv, vm, f;
initial begin
    repeat (5) @(posedge clk);
    rstn <= 1;
    repeat (5) @(posedge clk);
    for (vm = 0; vm < 2; vm = vm + 1)
      for (rv = 0; rv < 2; rv = rv + 1)
        for (ph = 0; ph < 4; ph = ph + 1) begin
            bayer <= ph; pix_rev <= rv;
            for (f = 0; f < 2; f = f + 1) send_frame(vm);
        end
    repeat (20) @(posedge clk);
    if (errors == 0 && checked == 16 * 2 * OW * OH)
        $display("=== tb_bayer_bin2x2 PASS  (%0d frames, %0d pixels checked) ===", 32, checked);
    else
        $fatal(1, "=== tb_bayer_bin2x2 FAIL  errors=%0d checked=%0d (expect %0d) ===", errors, checked, 16*2*OW*OH);
    $finish;
end

endmodule
