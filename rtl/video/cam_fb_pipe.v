// =============================================================================
// cam_fb_pipe.v  --  ArtFlow v03 视频主通路
// -----------------------------------------------------------------------------
//   CSI RAW10 (4 像素/拍, i_pclk)
//     -> bayer_bin2x2  : 2x2 合并成 RGB，1920x1080 -> 960x540，XRGB8888
//     -> frame_buffer  : 写 DDR（三缓冲，每帧固定 BANK_BYTES），再按 1080p 时序读出
//                        读出时 960 像素/行 @ o_clk(74.25M)，每行重复 2 次 -> 960x1080
//     -> o_hdmi_clk(148.5M，与 o_clk 同源 2 倍频) 下采样：每个像素保持 2 拍
//                        -> 1920x1080，即水平 2 倍放大
//
// DDR 帧格式（给后面 v04~v07 用）：
//   帧 n 起始地址 = START_ADDR + n * BANK_BYTES（n = 0,1,2）
//   像素 (x, y) 位于 起始地址 + (y*960 + x)*4，32bit 小端 {8'h00, R, G, B}
//
// 顶层和仿真 (sim/tb_v03_pipe.v) 例化的是同一个模块，保证仿真比对的就是上板的逻辑。
// =============================================================================
module cam_fb_pipe
#(
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_ADDR_WIDTH = 32,
    parameter START_ADDR     = 32'h0000_0000,
    parameter BANK_BYTES     = 32'h0040_0000,   // 4 MB / 帧（>= 960*540*4，4KB 对齐）
    parameter MAX_IN_WIDTH   = 1920,             // 摄像头每行 RAW 像素数上限
    parameter MAX_OUT_WIDTH  = 960               // 缓存里每行像素数上限（= 读出行缓存深度）
)
(
    // ------------------------------------------------ 配置（v05 起改为 RISC-V 寄存器）
    input      [1:0]    cfg_bayer,       // 0 RGGB / 1 GRBG / 2 GBRG / 3 BGGR
    input               cfg_pix_rev,     // CSI 像素顺序：0 = [9:0] 为最左像素
    input      [15:0]   cfg_gain_r,      // Q8.8
    input      [15:0]   cfg_gain_g,
    input      [15:0]   cfg_gain_b,

    // ------------------------------------------------ 摄像头输入（i_pclk 域）
    input               i_pclk,
    input               i_pclk_rstn,
    input               i_vs,
    input               i_hs,
    input               i_valid,
    input      [39:0]   i_raw,

    // ------------------------------------------------ 输出时序（半速，o_clk 域）
    input      [12:0]   H_FRONT_PORCH,
    input      [12:0]   H_SYNC,
    input      [12:0]   H_VALID,          // 960
    input      [12:0]   H_BACK_PORCH,
    input      [12:0]   V_FRONT_PORCH,
    input      [12:0]   V_SYNC,
    input      [12:0]   V_VALID,          // 1080（输出行数）
    input      [12:0]   V_BACK_PORCH,

    input               rst_n,            // frame_buffer 复位（异步低有效）
    input               o_clk,            // 74.25 MHz
    input               o_hdmi_clk,       // 148.5 MHz，与 o_clk 同源、上升沿对齐

    output reg          o_de = 1'b0,      // o_hdmi_clk 域，1920x1080
    output reg          o_hs = 1'b0,
    output reg          o_vs = 1'b0,
    output reg [7:0]    o_r  = 8'd0,
    output reg [7:0]    o_g  = 8'd0,
    output reg [7:0]    o_b  = 8'd0,

    // ------------------------------------------------ AXI4 主口（axi_clk 域）
    input                           axi_clk,
    output [5:0]                    awid,
    output [AXI_ADDR_WIDTH-1:0]     awaddr,
    output [7:0]                    awlen,
    output [2:0]                    awsize,
    output [1:0]                    awburst,
    output [3:0]                    awcache,
    output [2:0]                    awprot,
    output                          awlock,
    output                          awvalid,
    input                           awready,
    output [5:0]                    arid,
    output [AXI_ADDR_WIDTH-1:0]     araddr,
    output [7:0]                    arlen,
    output [2:0]                    arsize,
    output [1:0]                    arburst,
    output [3:0]                    arcache,
    output [2:0]                    arprot,
    output                          arlock,
    output                          arvalid,
    input                           arready,
    output [AXI_DATA_WIDTH-1:0]     wdata,
    output [AXI_DATA_WIDTH/8-1:0]   wstrb,
    output                          wlast,
    output                          wvalid,
    input                           wready,
    input  [5:0]                    rid,
    input  [AXI_DATA_WIDTH-1:0]     rdata,
    input                           rlast,
    input                           rvalid,
    output                          rready,
    input  [1:0]                    rresp,
    input  [5:0]                    bid,
    input                           bvalid,
    output                          bready
);

// ---------------------------------------------------------------- 2x2 合并
wire        bin_vs, bin_valid;
wire [63:0] bin_data;

bayer_bin2x2 #(
    .MAX_IN_WIDTH (MAX_IN_WIDTH)
) u_bin (
    .clk       (i_pclk      ),
    .rstn      (i_pclk_rstn ),
    .i_bayer   (cfg_bayer   ),
    .i_pix_rev (cfg_pix_rev ),
    .i_gain_r  (cfg_gain_r  ),
    .i_gain_g  (cfg_gain_g  ),
    .i_gain_b  (cfg_gain_b  ),
    .i_vs      (i_vs        ),
    .i_hs      (i_hs        ),
    .i_valid   (i_valid     ),
    .i_data    (i_raw       ),
    .o_vs      (bin_vs      ),
    .o_hs      (            ),
    .o_valid   (bin_valid   ),
    .o_data    (bin_data    )
);

// ---------------------------------------------------------------- 帧缓存
wire        fb_hs, fb_vs, fb_de;
wire [31:0] fb_data;

frame_buffer #(
    .I_VID_WIDTH    (64            ),
    .O_VID_WIDTH    (32            ),
    .START_ADDR     (START_ADDR    ),
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .WR_FIFO_DEPTH  (1024          ),
    .RD_FIFO_DEPTH  (1024          ),
    .BURST_LEN      (127           ),
    .FB_NUM         (3             ),
    .MAX_VID_WIDTH  (MAX_OUT_WIDTH ),
    .MAX_VID_HIGHT  (540           ),
    .BANK_BYTES     (BANK_BYTES    ),
    .DDR_LSB_FIRST  (1             ),
    .V_REPEAT       (2             )
) u_frame_buffer (
    .axi_clk        (axi_clk       ),
    .rst_n          (rst_n         ),

    .i_clk          (i_pclk        ),
    .i_vs           (bin_vs        ),
    .i_de           (bin_valid     ),
    .vin            (bin_data      ),

    .o_clk          (o_clk         ),
    .o_hs           (fb_hs         ),
    .o_vs           (fb_vs         ),
    .o_de           (fb_de         ),
    .vout           (fb_data       ),

    .H_FRONT_PORCH  (H_FRONT_PORCH ),
    .H_SYNC         (H_SYNC        ),
    .H_VALID        (H_VALID       ),
    .H_BACK_PORCH   (H_BACK_PORCH  ),
    .V_FRONT_PORCH  (V_FRONT_PORCH ),
    .V_SYNC         (V_SYNC        ),
    .V_VALID        (V_VALID       ),
    .V_BACK_PORCH   (V_BACK_PORCH  ),

    .awid (awid ), .awaddr (awaddr ), .awlen (awlen ), .awsize (awsize ), .awburst(awburst),
    .awprot(awprot), .awcache(awcache), .awlock(awlock), .awvalid(awvalid), .awready(awready),
    .awcobuf(), .awapcmd(), .awallstrb(), .awqos(),

    .arid (arid ), .araddr (araddr ), .arlen (arlen ), .arsize (arsize ), .arburst(arburst),
    .arprot(arprot), .arcache(arcache), .arlock(arlock), .arvalid(arvalid), .arready(arready),
    .arapcmd(), .arqos(),

    .wdata (wdata ), .wstrb (wstrb ), .wlast (wlast ), .wvalid(wvalid), .wready(wready),
    .rid   (rid   ), .rdata (rdata ), .rlast (rlast ), .rvalid(rvalid), .rready(rready), .rresp(rresp),
    .bid   (bid   ), .bvalid(bvalid), .bready(bready),

    .test_rd_fifo_rddata(), .test_wdata(), .test_rdata(), .test_BURST_LEN()
);

// ---------------------------------------------------------------- 2 倍频下采样 = 水平 2 倍
// o_clk 与 o_hdmi_clk 同源（USER_PLL 的 /40 和 /20 输出），每个 o_clk 像素被采到 2 次。
always @(posedge o_hdmi_clk) begin
    o_de <= fb_de;
    o_hs <= fb_hs;
    o_vs <= fb_vs;
    o_r  <= fb_data[23:16];
    o_g  <= fb_data[15: 8];
    o_b  <= fb_data[ 7: 0];
end

endmodule
