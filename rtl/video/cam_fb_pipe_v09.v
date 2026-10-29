// ArtFlow v04: RAW binning, triple buffer, fair AXI scheduling, dual windows.
module cam_fb_pipe_v09
#(
    parameter STYLE_ENABLE = 0, STYLE_COUNT=8,
    parameter DUAL_WINDOW = 1, // 1: centered native-size pair; 0: legacy 2x fullscreen
    parameter [9:0] BLACK_LEVEL = 10'd0,
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_ADDR_WIDTH = 32,
    parameter START_ADDR     = 32'h0000_0000,
    parameter BANK_BYTES     = 32'h0040_0000,   // 4 MB / 帧（>= 960*540*4，4KB 对齐）
    parameter MAX_IN_HEIGHT  = 1080,
    parameter MAX_IN_WIDTH   = 1920,             // 摄像头每行 RAW 像素数上限
    parameter MAX_OUT_WIDTH  = 960               // 缓存里每行像素数上限（= 读出行缓存深度）
)
(
    // ------------------------------------------------ 配置（v05 起改为 RISC-V 寄存器）
    output stream_tick,stream_bad,stream_valid,
    output [9:0] stream_x,stream_y,output [23:0] stream_rgb,output [31:0] stream_epoch,
    input key_style_n,flash_miso,output flash_cs_n,flash_sck,flash_mosi,
    input      [1:0]    requested_layout,
    output     [1:0]    active_layout,
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

    // Read-only diagnostics, all in axi_clk. No feedback into video control.
    output [31:0] diag_state, diag_fifo, diag_written, diag_completed,
    output [31:0] diag_published, diag_rejected,
    output wire diag_bin_toggle, // one event per 256 binned beats, pixel domain
    output wire         capture_toggle, // AXI domain
    output reg          o_de,      // o_hdmi_clk 域，1920x1080
    output reg          o_hs,
    output reg          o_vs,
    output reg [7:0]    o_r,
    output reg [7:0]    o_g,
    output reg [7:0]    o_b,
    output reg o_display_rgb,

    // ------------------------------------------------ AXI4 主口（axi_clk 域）
    input [15:0] accel_paddr, input accel_psel,accel_penable,accel_pwrite,
    input [31:0] accel_pwdata, output [31:0] accel_prdata,
    output accel_pready,accel_pslverror,accel_irq,process_toggle,
    input                           axi_clk,
    input                           cnn_clk,
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
    input  [1:0]                    bresp,
    output                          bready
);

// synthesis translate_off
initial begin
    if (AXI_DATA_WIDTH != 128 || AXI_ADDR_WIDTH != 32 || MAX_IN_WIDTH < 4 || MAX_IN_WIDTH%4 != 0 ||
        MAX_IN_HEIGHT < 2 || MAX_IN_HEIGHT%2 != 0 || MAX_OUT_WIDTH != MAX_IN_WIDTH/2 ||
        DUAL_WINDOW != 1 || (DUAL_WINDOW && MAX_IN_WIDTH%8 != 0))
        $fatal(1,"Invalid cam_fb_pipe configuration: fixed 128-bit AXI / 2x geometry required");
end
always @(posedge o_clk) if(rst_n) begin
    if (H_VALID != MAX_OUT_WIDTH || V_VALID != MAX_IN_HEIGHT ||
        (H_SYNC+H_BACK_PORCH+H_VALID+H_FRONT_PORCH)*(DUAL_WINDOW?2:1) > 8191 ||
        V_SYNC+V_BACK_PORCH+V_VALID+V_FRONT_PORCH > 8191 || H_SYNC==0 || V_SYNC==0)
        $fatal(1,"Video timing does not match frame-store geometry");
end
// synthesis translate_on

// ---------------------------------------------------------------- 2x2 合并
wire        bin_vs, bin_valid;
wire [63:0] bin_data;
reg [8:0] diag_bin_count = 0;
always @(posedge i_pclk or negedge i_pclk_rstn)
    if (!i_pclk_rstn) diag_bin_count <= 0;
    else if (bin_valid) diag_bin_count <= diag_bin_count + 1'b1;
assign diag_bin_toggle = diag_bin_count[8];

bayer_bin2x2 #(
    .BLACK_LEVEL (BLACK_LEVEL),
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
// Elaboration-time clock selection, never a runtime clock mux.
wire store_clk = DUAL_WINDOW ? o_hdmi_clk : o_clk;
wire [12:0] store_hfp = DUAL_WINDOW ? H_FRONT_PORCH<<1 : H_FRONT_PORCH;
wire [12:0] store_hsp = DUAL_WINDOW ? H_SYNC<<1 : H_SYNC;
wire [12:0] store_hbp = DUAL_WINDOW ? H_BACK_PORCH<<1 : H_BACK_PORCH;
wire [12:0] store_hvalid = DUAL_WINDOW ? H_VALID<<1 : H_VALID;

// AXI attributes are constant for aligned 128-bit INCR transfers.
assign awid=0, arid=0, awsize=4, arsize=4, awburst=1, arburst=1;
assign awcache=3, arcache=3, awprot=2, arprot=2, awlock=0, arlock=0;
wire [31:0] v_awaddr;
wire [7:0] v_awlen;
wire v_awvalid;
wire v_awready;
wire [127:0] v_wdata;
wire [15:0] v_wstrb;
wire v_wvalid;
wire v_wlast;
wire v_wready;
wire v_bvalid;
wire [1:0] v_bresp;
wire v_bready;
wire [31:0] v_araddr;
wire [7:0] v_arlen;
wire v_arvalid;
wire v_arready;
wire [127:0] v_rdata;
wire v_rvalid;
wire [1:0] v_rresp;
wire v_rlast;
wire v_rready;
wire [31:0] a_awaddr;
wire [7:0] a_awlen;
wire a_awvalid;
wire a_awready;
wire [127:0] a_wdata;
wire [15:0] a_wstrb;
wire a_wvalid;
wire a_wlast;
wire a_wready;
wire a_bvalid;
wire [1:0] a_bresp;
wire a_bready;
wire [31:0] a_araddr;
wire [7:0] a_arlen;
wire a_arvalid;
wire a_arready;
wire [127:0] a_rdata;
wire a_rvalid;
wire [1:0] a_rresp;
wire a_rlast;
wire a_rready;
wire accel_clk_ready;
video_reset_sync u_accel_reset(.clk(axi_clk),.rst_n(rst_n),.ready(accel_clk_ready));
wire freeze_valid,freeze_busy,retire_ack;wire [1:0] freeze_original_bank;
wire source_locked,original_valid,styled_valid,display_active;
wire [1:0] source_bank,original_bank,styled_bank,display_bank;
wire start,busy,done,failed,source_consumed;
wire [31:0] src_addr,dst_addr,cycles;
wire [31:0] style_status,ctrl_prdata;wire [4:0] completed_style;wire ctrl_error;
wire style_diag_addr=accel_paddr==16'h00ac || accel_paddr==16'h00b0;
wire render_active,render_valid,render_ready,render_error;wire [1:0] render_bank;wire [31:0] render_prdata;
wire render_select=accel_paddr>=16'hd0 && accel_paddr<=16'he8;
wire ctrl_ready;
assign accel_pready=render_select?render_ready:ctrl_ready;
assign accel_prdata=render_select?render_prdata:style_diag_addr ? (accel_paddr==16'h00ac ? style_status : {27'd0,completed_style}) : ctrl_prdata;
assign accel_pslverror=render_select?render_error:style_diag_addr?(accel_psel && accel_penable && accel_pwrite):ctrl_error;
wire local_grant,cnn_port_ready;
wire [31:0] m_awaddr;
wire [7:0] m_awlen;
wire m_awvalid;
wire m_awready;
wire [127:0] m_wdata;
wire [15:0] m_wstrb;
wire m_wvalid;
wire m_wlast;
wire m_wready;
wire m_bvalid;
wire [1:0] m_bresp;
wire m_bready;
wire [31:0] m_araddr;
wire [7:0] m_arlen;
wire m_arvalid;
wire m_arready;
wire [127:0] m_rdata;
wire m_rvalid;
wire [1:0] m_rresp;
wire m_rlast;
wire m_rready;
artflow_render_ctrl #(.REQUIRE_GRANT(1),.WIDTH(MAX_OUT_WIDTH),.HEIGHT(MAX_IN_HEIGHT/2),.BANK_BYTES(BANK_BYTES),.START_ADDR(START_ADDR)) u_render_ctrl(
 .local_grant(local_grant),
 .clk(axi_clk),.rst_n(accel_clk_ready),.freeze_valid(freeze_valid),.original_bank(freeze_original_bank),.style_bank(styled_bank),
 .display_active(display_active),.display_bank(display_bank),.paddr(accel_paddr),.psel(accel_psel && render_select),.penable(accel_penable),.pwrite(accel_pwrite),.pwdata(accel_pwdata),
 .prdata(render_prdata),.pready(render_ready),.pslverror(render_error),.result_valid(render_valid),.result_bank(render_bank),.active(render_active),
.awaddr(m_awaddr),
.awlen(m_awlen),
.awvalid(m_awvalid),
.awready(m_awready),
.wdata(m_wdata),
.wstrb(m_wstrb),
.wvalid(m_wvalid),
.wlast(m_wlast),
.wready(m_wready),
.bvalid(m_bvalid),
.bresp(m_bresp),
.bready(m_bready),
.araddr(m_araddr),
.arlen(m_arlen),
.arvalid(m_arvalid),
.arready(m_arready),
.rdata(m_rdata),
.rvalid(m_rvalid),
.rresp(m_rresp),
.rlast(m_rlast),
.rready(m_rready));
artflow_accel_ctrl #(.INTERACT(1),.VERSION_ID(32'h41524609),.EARLY_RELEASE(1),.ORIGINAL_BASE(START_ADDR),.BANK_BYTES(BANK_BYTES),.STYLED_BASE(START_ADDR+3*BANK_BYTES)) u_accel_ctrl(
 .clk(axi_clk),.rst_n(accel_clk_ready),.paddr(accel_paddr),.psel(accel_psel && !render_select),
 .penable(accel_penable),.pwrite(accel_pwrite),.pwdata(accel_pwdata),
 .prdata(ctrl_prdata),.pready(ctrl_ready),.pslverror(ctrl_error),
 .retire_ack(retire_ack && !render_active && cnn_port_ready),.requested_style(style_status[9:5]),.completed_style(completed_style),
 .freeze_valid(freeze_valid),.freeze_busy(freeze_busy),.freeze_original_bank(freeze_original_bank),
 .original_valid(original_valid),.original_bank(original_bank),.original_seq(diag_published),
 .source_locked(source_locked),.source_bank(source_bank),
 .display_active(display_active),.display_bank(display_bank),
 .styled_valid(styled_valid),.styled_bank(styled_bank),
 .start(start),.src_addr(src_addr),.dst_addr(dst_addr),
 .busy(busy),.done(done),.failed(failed),.cycles(cycles),.source_consumed(source_consumed),
 .irq(accel_irq),.process_toggle(process_toggle),.completed(),.skipped(),.errors());
artflow_cnn_accel #(.LOCAL_ENABLE(1),.WIDTH(MAX_OUT_WIDTH),.HEIGHT(MAX_IN_HEIGHT/2),.STYLE_ENABLE(STYLE_ENABLE),.STYLE_COUNT(STYLE_COUNT)) u_accel_dma(
 .freeze_req(freeze_valid),.local_active(render_active),.local_grant(local_grant),.cnn_port_ready(cnn_port_ready),
 .local_araddr(m_araddr),
 .local_arlen(m_arlen),
 .local_arvalid(m_arvalid),
 .local_arready(m_arready),
 .local_rdata(m_rdata),
 .local_rvalid(m_rvalid),
 .local_rresp(m_rresp),
 .local_rlast(m_rlast),
 .local_rready(m_rready),
 .local_awaddr(m_awaddr),
 .local_awlen(m_awlen),
 .local_awvalid(m_awvalid),
 .local_awready(m_awready),
 .local_wdata(m_wdata),
 .local_wstrb(m_wstrb),
 .local_wvalid(m_wvalid),
 .local_wlast(m_wlast),
 .local_wready(m_wready),
 .local_bvalid(m_bvalid),
 .local_bresp(m_bresp),
 .local_bready(m_bready),
 .key_style_n(key_style_n),.flash_miso(flash_miso),.flash_cs_n(flash_cs_n),.flash_sck(flash_sck),.flash_mosi(flash_mosi),
 .style_status(style_status),.completed_style(completed_style),
 .clk(axi_clk),.cnn_clk(cnn_clk),.rst_n(accel_clk_ready),.start(start),.src_addr(src_addr),.dst_addr(dst_addr),
 .busy(busy),.done(done),.failed(failed),.cycles(cycles),.source_consumed(source_consumed),
 .awaddr(a_awaddr),
 .awlen(a_awlen),
 .awvalid(a_awvalid),
 .awready(a_awready),
 .wdata(a_wdata),
 .wstrb(a_wstrb),
 .wvalid(a_wvalid),
 .wlast(a_wlast),
 .wready(a_wready),
 .bvalid(a_bvalid),
 .bresp(a_bresp),
 .bready(a_bready),
 .araddr(a_araddr),
 .arlen(a_arlen),
 .arvalid(a_arvalid),
 .arready(a_arready),
 .rdata(a_rdata),
 .rvalid(a_rvalid),
 .rresp(a_rresp),
 .rlast(a_rlast),
 .rready(a_rready));
artflow_axi_mux u_axi_mux(.clk(axi_clk),.rst_n(accel_clk_ready),
 .v_awaddr(v_awaddr),
 .v_awlen(v_awlen),
 .v_awvalid(v_awvalid),
 .v_awready(v_awready),
 .v_wdata(v_wdata),
 .v_wstrb(v_wstrb),
 .v_wvalid(v_wvalid),
 .v_wlast(v_wlast),
 .v_wready(v_wready),
 .v_bvalid(v_bvalid),
 .v_bresp(v_bresp),
 .v_bready(v_bready),
 .v_araddr(v_araddr),
 .v_arlen(v_arlen),
 .v_arvalid(v_arvalid),
 .v_arready(v_arready),
 .v_rdata(v_rdata),
 .v_rvalid(v_rvalid),
 .v_rresp(v_rresp),
 .v_rlast(v_rlast),
 .v_rready(v_rready),
 .a_awaddr(a_awaddr),
 .a_awlen(a_awlen),
 .a_awvalid(a_awvalid),
 .a_awready(a_awready),
 .a_wdata(a_wdata),
 .a_wstrb(a_wstrb),
 .a_wvalid(a_wvalid),
 .a_wlast(a_wlast),
 .a_wready(a_wready),
 .a_bvalid(a_bvalid),
 .a_bresp(a_bresp),
 .a_bready(a_bready),
 .a_araddr(a_araddr),
 .a_arlen(a_arlen),
 .a_arvalid(a_arvalid),
 .a_arready(a_arready),
 .a_rdata(a_rdata),
 .a_rvalid(a_rvalid),
 .a_rresp(a_rresp),
 .a_rlast(a_rlast),
 .a_rready(a_rready),
 .awaddr(awaddr),
 .awlen(awlen),
 .awvalid(awvalid),
 .awready(awready),
 .wdata(wdata),
 .wstrb(wstrb),
 .wvalid(wvalid),
 .wlast(wlast),
 .wready(wready),
 .bvalid(bvalid),
 .bresp(bresp),
 .bready(bready),
 .araddr(araddr),
 .arlen(arlen),
 .arvalid(arvalid),
 .arready(arready),
 .rdata(rdata),
 .rvalid(rvalid),
 .rresp(rresp),
 .rlast(rlast),
 .rready(rready));
rgb_frame_store_v07 #(
    .INTERACT(1),.WIDTH(MAX_OUT_WIDTH), .HEIGHT(MAX_IN_HEIGHT/2), .DUAL_WINDOW(DUAL_WINDOW),
    .ADDR_WIDTH(AXI_ADDR_WIDTH), .START_ADDR(START_ADDR), .BANK_BYTES(BANK_BYTES)
) u_store (
    .stream_tick(stream_tick),.stream_bad(stream_bad),.stream_valid(stream_valid),
    .stream_x(stream_x),.stream_y(stream_y),.stream_rgb(stream_rgb),.stream_epoch(stream_epoch),

    .freeze_valid(freeze_valid),.freeze_original_bank(freeze_original_bank),.retire_ack(retire_ack),
    .requested_layout(requested_layout),.active_layout(active_layout),
    .source_locked(source_locked),.source_bank(source_bank),
    .original_valid(original_valid),.original_bank(original_bank),
    .styled_valid(styled_valid),.styled_bank(render_valid ? render_bank : styled_bank),
    .display_active(display_active),.display_bank(display_bank),
    .diag_state(diag_state), .diag_fifo(diag_fifo),
    .diag_written(diag_written), .diag_completed(diag_completed),
    .diag_published(diag_published), .diag_rejected(diag_rejected),
    .capture_toggle(capture_toggle),
    .rst_n(rst_n), .i_clk(i_pclk), .i_vs(bin_vs), .i_valid(bin_valid), .i_data(bin_data),
    .o_clk(store_clk), .H_FRONT_PORCH(store_hfp), .H_SYNC(store_hsp), .H_VALID(store_hvalid),
    .H_BACK_PORCH(store_hbp), .V_FRONT_PORCH(V_FRONT_PORCH), .V_SYNC(V_SYNC),
    .V_VALID(V_VALID), .V_BACK_PORCH(V_BACK_PORCH),
    .o_de(fb_de), .o_hs(fb_hs), .o_vs(fb_vs), .o_data(fb_data),
    .axi_clk(axi_clk), .awaddr(v_awaddr), .awlen(v_awlen), .awvalid(v_awvalid), .awready(v_awready),
    .wdata(v_wdata), .wstrb(v_wstrb), .wlast(v_wlast), .wvalid(v_wvalid), .wready(v_wready),
    .bvalid(v_bvalid), .bresp(v_bresp), .bready(v_bready),
    .araddr(v_araddr), .arlen(v_arlen), .arvalid(v_arvalid), .arready(v_arready),
    .rdata(v_rdata), .rlast(v_rlast), .rvalid(v_rvalid), .rresp(v_rresp), .rready(v_rready)
);

// Dual mode is native HDMI-clock pixels; legacy mode samples each half-rate pixel twice.
always @(posedge o_hdmi_clk) begin
    if (!rst_n) begin
        o_display_rgb <= 0; o_de <= 0; o_hs <= 0; o_vs <= 0; o_r <= 0; o_g <= 0; o_b <= 0;
    end else begin
    o_display_rgb <= fb_data[24];
    o_de <= fb_de;
    o_hs <= fb_hs;
    o_vs <= fb_vs;
    o_r  <= fb_data[23:16];
    o_g  <= fb_data[15: 8];
    o_b  <= fb_data[ 7: 0];
    end
end

endmodule
