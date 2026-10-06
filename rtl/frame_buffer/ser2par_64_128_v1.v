// =============================================================================
// ser2par_64_128_v1.v  --  ArtFlow v03
// 64bit 视频字 -> 128bit AXI 字，**低位在前**：
//   第 1 个输入字 -> [63:0]，第 2 个 -> [127:64]
// 配合 bayer_bin2x2 的 {px1,px0} 输出，DDR 里像素 n 位于字节地址 4n（小端 XRGB8888），
// 方便以后 RISC-V / 加速器直接按地址访问。
// 接口与 ser2par_32_128_v1 相同（frame_start/frame_end/frame_stable/frame_pix_num 语义一致）。
// =============================================================================
module ser2par_64_128_v1 #(
    parameter I_VID_WIDTH   = 64,
    parameter AXI_DDR_WIDTH = 128
)(
input   wire                        clk,
input   wire                        rst_n,
input   wire                        de,
input   wire                        frame_start,
input   wire                        frame_end,
input   wire                        frame_stable,
input   wire [23:0]                 frame_pix_num,
input   wire [I_VID_WIDTH-1:0]      vin,

output  wire                        fifo_wr_en,
output  wire [AXI_DDR_WIDTH-1:0]    fifo_wr_data
);

reg [1:0]   pre_state     = 2'd0;
reg [127:0] par_pix_data  = 128'd0;
reg         par_pix_valid = 1'b0;
reg         frame_cnt_end = 1'b0;
reg [23:0]  frame_cnt     = 24'd0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        frame_cnt <= 'd0;
    else if (frame_start)
        frame_cnt <= 'd0;
    else if (de && frame_stable)
        frame_cnt <= frame_cnt + 1'b1;
end

// 帧内字数为奇数时，用 frame_cnt_end 把最后半个 128bit 字补齐写出（960 宽时不会发生）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        frame_cnt_end <= 1'b0;
    else if (par_pix_valid)
        frame_cnt_end <= 1'b0;
    else if (frame_cnt + 1 == frame_pix_num && de)
        frame_cnt_end <= 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pre_state     <= 2'd0;
        par_pix_valid <= 1'b0;
    end else if (frame_end) begin
        pre_state     <= 2'd0;
        par_pix_valid <= 1'b0;
    end else if (frame_stable) begin
        par_pix_valid <= 1'b0;
        case (pre_state)
        2'd0: if (frame_start) pre_state <= 2'd1;
        2'd1: if (de | frame_cnt_end) begin
                  par_pix_data[63:0] <= vin;
                  pre_state          <= 2'd2;
              end
        2'd2: if (frame_cnt_end) begin
                  par_pix_data[127:64] <= vin;
                  par_pix_valid        <= 1'b1;
                  pre_state            <= 2'd0;
              end else if (de) begin
                  par_pix_data[127:64] <= vin;
                  par_pix_valid        <= 1'b1;
                  pre_state            <= 2'd1;
              end
        default: pre_state <= 2'd0;
        endcase
    end
end

assign fifo_wr_data = par_pix_data;
assign fifo_wr_en   = par_pix_valid;

endmodule
