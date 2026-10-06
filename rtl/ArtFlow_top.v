
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2013-2021 Efinix Inc. All rights reserved.
//
// Description:
// Example top file for ti60f225 dev kit OOB design
//
// Language:  Verilog 2001
//
// ------------------------------------------------------------------------------

/////////////////////////////////////////////////////////////////////////////////
//`define SOFT_TAP 1
`include "ddr3_controller/ddr3_parameter.vh"
// `include "define.v"

module ArtFlow_top #(

	parameter                       RANK_RATIO         = 1,       // # of unique CS outputs per rank
	parameter                       ASYN_AXI_CLK       = `ASYN_AXI_CLK, 
	parameter                       RANKS              = `RANKS,
	parameter                       CK_WIDTH           = `CK_WIDTH,       // # of CK/CK# outputs to memory   
	parameter                       CKE_WIDTH          = `CKE_WIDTH,       // # of cke outputs
	parameter                       CS_WIDTH           = `CS_WIDTH,       // # of unique CS outputs
	parameter                       BANK_WIDTH         = `BANK_WIDTH,       // # of bank bits
	parameter                       ROW_WIDTH          = `ROW_WIDTH,       // DRAM address bus width
	parameter                       COL_WIDTH          = `COL_WIDTH,      // column address width
	parameter                       DM_WIDTH           = `DM_WIDTH,       // # of DM (data mask)
	parameter                       DQS_WIDTH          = `DQS_WIDTH,       // # of DQS (strobe)
	parameter                       DQ_WIDTH           = `DQ_WIDTH,      // # of DQ (data)
	parameter                       ODT_WIDTH          = `ODT_WIDTH,
	parameter                       DQ_CNT_WIDTH       = `DQ_CNT_WIDTH,       // = ceil(log2(DQ_WIDTH))
	parameter                       DQS_CNT_WIDTH      = `DQS_CNT_WIDTH,       // = ceil(log2(DQS_WIDTH))  
	parameter                       DRAM_WIDTH         = `DRAM_WIDTH,       // # of DQ per DQS   
	parameter                       DATA_WIDTH         = `DATA_WIDTH,
	parameter                       ADDR_WIDTH         = `ADDR_WIDTH,    
	parameter                       AXI_ID_WIDTH       = `AXI_ID_WIDTH,
	parameter                       AXI_ADDR_WIDTH     = `AXI_ADDR_WIDTH,
	parameter                       AXI_DATA_WIDTH     = `AXI_DATA_WIDTH
)
(


   // v05 board UART (115200 8N1, RX GPIOL_02 / TX GPIOR_28)
    input wire uart_rx,
    output wire uart_tx,

   //Clocks 
	input	wire	i_arstn,
    input	wire	i_mipi_rx_pclk,
    input wire  vid_clk_dvi2,
    input wire hdmi_tx_slow_clk,
    input  wire CLK_25M,
	output  wire    pll_inst1_RSTN,
	input	wire	i_pll_locked,
	input 	wire  	pll_locked,
	output  wire    pll_inst4_RSTN,
	input   wire    pll_inst4_LOCKED,
	output  wire  	USER_PLL_RSTN,
    output 	wire 	DDR3_PLL_RSTN,
	input 	wire  	user_pll_locked,
    //CSI Interface
    input	 wire		io_cam_sda_IN,
    output wire   io_cam_sda_OUT,
    output wire		io_cam_sda_OE,

    output io_cam_scl_OUT,
    input io_cam_scl_IN,
    output io_cam_scl_OE,

    output	wire		o_cam_rst_p,
    
    input	wire		i_cam_ck_LP_P_IN,
    input	wire		i_cam_ck_LP_N_IN,
    output	wire		o_cam_ck_HS_TERM,
    output	wire		o_cam_ck_HS_ENA,
    input	wire		i_cam_ck_CLKOUT,
    
    input	wire	[7:0]			cam_d0_HS_IN,
    input	  wire		      cam_d0_LP_P_IN,
    input	  wire		      cam_d0_LP_N_IN,
    output	wire		      cam_d0_HS_TERM,
    output	wire		      cam_d0_HS_ENA,
    output	wire		      cam_d0_RST,
    output	wire		      cam_d0_FIFO_RD,
    input	  wire		      cam_d0_FIFO_EMPTY,
    
    input 	wire	[7:0]			cam_d1_HS_IN,
    input	  wire		        cam_d1_LP_P_IN,
    input	  wire		        cam_d1_LP_N_IN,
    output	wire		        cam_d1_HS_TERM,
    output	wire		        cam_d1_HS_ENA,
    output	wire		        cam_d1_RST,
    output	wire		        cam_d1_FIFO_RD,
    input	  wire		        cam_d1_FIFO_EMPTY,
    
    input 	wire	[7:0]			cam_d2_HS_IN,
    input	  wire		        cam_d2_LP_P_IN,
    input	  wire		        cam_d2_LP_N_IN,
    output	wire		        cam_d2_HS_TERM,
    output	wire		        cam_d2_HS_ENA,
    output	wire		        cam_d2_RST,
    output	wire		        cam_d2_FIFO_RD,
    input	  wire		        cam_d2_FIFO_EMPTY,  
   
    input 	wire	[7:0]			cam_d3_HS_IN,
    input	  wire		        cam_d3_LP_P_IN,
    input	  wire		        cam_d3_LP_N_IN,
    output	wire		        cam_d3_HS_TERM,
    output	wire		        cam_d3_HS_ENA,
    output	wire		        cam_d3_RST,
    output	wire		        cam_d3_FIFO_RD,
    input	  wire		        cam_d3_FIFO_EMPTY,

	
	input 					tx_cal_clk_90edge,
  	input 					rx_cal_clk,
  	input 					tx_cal_clk,
	input                              core_clk,     // CORE CLK @ 100MHz
	input                              sdram_clk,    // SDRAM CK @ 400MHz
	// PLL status flags  
	output [2:0]                       pll_shift,  
	output [4:0]                       pll_shift_sel,
	output                             pll_shift_ena,  
	// memory interface ports
	output                             ddr_ck_hi,
	output                             ddr_ck_lo,
	output                             ddr_reset_n,
	output [CKE_WIDTH-1:0]             ddr_cke,     
	output [15:0]                      ddr_addr,     // 板上 DDR3 为 A0~A15；控制器只用 [ROW_WIDTH-1:0]，高位固定为 0
	output [BANK_WIDTH-1:0]            ddr_ba,
	output                             ddr_cas_n,
 
	output [CS_WIDTH*RANK_RATIO-1:0]   ddr_cs_n,
	output                             ddr_ras_n,
	output                             ddr_we_n,
	
	input  [DQS_WIDTH-1:0]             ddr_dqs_in_hi,
	input  [DQS_WIDTH-1:0]             ddr_dqs_in_lo,
	input  [DQ_WIDTH-1:0]              ddr_dq_in_hi,
	input  [DQ_WIDTH-1:0]              ddr_dq_in_lo,
	
	output [DQS_WIDTH-1:0]             ddr_dqs_oe,
	output [DQS_WIDTH-1:0]             ddr_dqs_oe_n,
	output [DQ_WIDTH-1:0]              ddr_dq_oe,  
	output [DQS_WIDTH-1:0]             ddr_dqs_out_hi,
	output [DQS_WIDTH-1:0]             ddr_dqs_out_lo,
	output [DQ_WIDTH-1:0]              ddr_dq_out_hi,
	output [DQ_WIDTH-1:0]              ddr_dq_out_lo,
	output [DM_WIDTH-1:0]              ddr_dm_hi,
	output [DM_WIDTH-1:0]              ddr_dm_lo,
	output [ODT_WIDTH-1:0]             ddr_odt,

       //LED
       output [3:0] led,


       // hdmi interface

    output tmds_tx_clk_TX_OE,
    output [9:0] tmds_tx_clk_TX_DATA,
    output tmds_tx_clk_TX_RST,
    output tmds_tx_data0_TX_OE,
    output [9:0] tmds_tx_data0_TX_DATA,
    output tmds_tx_data0_TX_RST,
    output tmds_tx_data1_TX_OE,
    output [9:0] tmds_tx_data1_TX_DATA,
    output tmds_tx_data1_TX_RST,
    output tmds_tx_data2_TX_OE,
    output [9:0] tmds_tx_data2_TX_DATA,
    output tmds_tx_data2_TX_RST


);

function integer log2;
	input	integer	val;
	integer	i;
	begin
		log2 = 0;
		for (i=0; 2**i<val; i=i+1)
			log2 = i+1;
	end
endfunction


//===============================================================================
//localparam
//===============================================================================
localparam WR_FIFO_DEPTH  = 1024;
localparam RD_FIFO_DEPTH  = 1024;

// localparam	MAX_HRES		= 12'd1920;
// localparam	MAX_VRES		= 12'd1080;
// localparam	HSP			= 8'd2;
// localparam	HBP			= 8'd88;
// localparam	HFP			= 8'd120;
// localparam	VSP			= 8'd2;
// localparam	VBP			= 8'd20;
// localparam	VFP			= 8'd20;

localparam CFG_DUAL_WINDOW = 1; // native 960x540 at (0,270) and (960,270)
localparam MAX_HRES = 1920;
localparam HFP      = 88;
localparam HSP      = 44;
localparam HBP      = 148;

localparam MAX_VRES = 1080;
localparam VFP      = 4;
localparam VSP      = 5;
localparam VBP      = 36;

//===============================================================================
// v05: white-balance reset defaults; runtime gains are controlled by Sapphire APB.
//===============================================================================
// 白平衡增益 Q8.8（256 = 1.0），取 v01 VIO 初值；v03 起在 2x2 合并时以 10bit 精度相乘
localparam [15:0] CFG_R_GAIN   = 16'h0118;   // 280 ≈ 1.09
localparam [15:0] CFG_G_GAIN   = 16'h00FF;   // 255 ≈ 1.00
localparam [15:0] CFG_B_GAIN   = 16'h015E;   // 350 ≈ 1.37
// Gamma：0 = 直通，1 = 查表
localparam        CFG_GAMMA_EN = 1'b1;
// v03：传感器 Bayer 排列（帧左上角 2x2）：0 = RGGB，1 = GRBG，2 = GBRG，3 = BGGR
//   替代 v02 的 CFG_SWAP_RB（RGGB <-> BGGR 就是 R/B 互换）。上板判定方法见 doc/v03_notes.md
localparam [1:0]  CFG_BAYER    = 2'd0;
// v03：CSI 像素顺序：0 = pixel_data[9:0] 是一行里靠左的像素（Efinix CSI RX 约定），1 = 反过来
localparam        CFG_PIX_REV  = 1'b0;
// 色条（自带独立 1080p60 时序，不依赖摄像头/DDR）：0 = 摄像头，1 = 常显色条，2 = 上电先显示约 5 秒色条再切摄像头
localparam [1:0]  CFG_PATTERN  = 2'd2;
//===============================================================================
//signal
//===============================================================================
   
wire                              app_sr_active;
wire                              app_ref_ack;
wire                              app_zq_ack;
wire                              cal_done;

// Slave Interface Write Address Ports
wire [AXI_ID_WIDTH-1:0]           s_axi_awid;
wire [AXI_ADDR_WIDTH-1:0]         s_axi_awaddr;
wire [7:0]                        s_axi_awlen;
wire [2:0]                        s_axi_awsize;
wire [1:0]                        s_axi_awburst;
wire [0:0]                        s_axi_awlock;
wire [3:0]                        s_axi_awcache;
wire [2:0]                        s_axi_awprot;
wire                              s_axi_awvalid;
wire                              s_axi_awready;
// Slave Interface Write Data Ports
wire [AXI_DATA_WIDTH-1:0]         s_axi_wdata;
wire [(AXI_DATA_WIDTH/8)-1:0]     s_axi_wstrb;
wire                              s_axi_wlast;
wire                              s_axi_wvalid;
wire                              s_axi_wready;
// Slave Interface Write Response Ports
wire                              s_axi_bready;
wire [AXI_ID_WIDTH-1:0]           s_axi_bid;
wire [1:0]                        s_axi_bresp;
wire                              s_axi_bvalid;
// Slave Interface Read Address Ports
wire [AXI_ID_WIDTH-1:0]           s_axi_arid;
wire [AXI_ADDR_WIDTH-1:0]         s_axi_araddr;
wire [7:0]                        s_axi_arlen;
wire [2:0]                        s_axi_arsize;
wire [1:0]                        s_axi_arburst;
wire [0:0]                        s_axi_arlock;
wire [3:0]                        s_axi_arcache;
wire [2:0]                        s_axi_arprot;
wire                              s_axi_arvalid;
wire                              s_axi_arready;
// Slave Interface Read Data Ports
wire                              s_axi_rready;
wire [AXI_ID_WIDTH-1:0]           s_axi_rid;
wire [AXI_DATA_WIDTH-1:0]         s_axi_rdata;
wire [1:0]                        s_axi_rresp;
wire                              s_axi_rlast;
wire                              s_axi_rvalid;




////////////////////////////////////////////////////////////////
// System & Debugger
wire    w_arstn;
// wire	w_sysclk_mcu_arstn;
// wire	w_sysclk_mcu_arst;
wire	w_mipi_rx_pclk_arstn;
wire	w_mipi_rx_pclk_arst;

wire		       w_mipi_rx_vs;
wire		       w_mipi_rx_hs;
wire	       w_mipi_rx_de;
wire	[63:0]			w_mipi_rx_data	;

wire					io_systemReset;



//===================================================================================================
//reset module
//===================================================================================================

assign w_arstn  		       = i_arstn & i_pll_locked & pll_locked & user_pll_locked;
assign pll_inst1_RSTN  		= i_arstn;
assign USER_PLL_RSTN      		= i_arstn;
assign DDR3_PLL_RSTN 		= i_arstn;
reset_ctrl
#(
	.NUM_RST		(2),
	.CYCLE			(1),
	.IN_RST_ACTIVE	(4'b00),
	.OUT_RST_ACTIVE	(4'b10)
)
inst_reset_ctrl
(
	.i_arst		({2{w_arstn}}),//({{4{i_pll_locked}},                  {2{i_arstn}}}),
	.i_clk			({2{i_mipi_rx_pclk}}),
	.o_srst		({w_mipi_rx_pclk_arst, w_mipi_rx_pclk_arstn})
);



reg [25:0] cnt = 'd0;
always @( posedge core_clk)
begin 
       cnt <= cnt + 1'b1;
end
assign led[0]  = cal_done ? cnt[24] : 1'b0;   // DDR 校准完成后闪烁
assign led[2] = camera_ready;
assign led[3] = camera_reset;
// DDR3 A14/A15 必须驱动为 0：MRS 命令要求保留位为 0，悬空/上拉会导致 DDR 初始化失败
assign ddr_addr[15:ROW_WIDTH] = {(16-ROW_WIDTH){1'b0}};

//========================================================================================================
//MIPI RX
//========================================================================================================
wire i_mipi_clk ;
assign i_mipi_clk = core_clk;

		assign	cam_d0_RST		= 1'b0;
		assign	cam_d1_RST		= 1'b0;
		assign  cam_d2_RST = 1'b0;
    assign  cam_d3_RST = 1'b0;
	
wire [15:0] mipi_debug_out;
		

		csi_rx_controller inst_efx_csi2_rx
		(
              .reset_n			(i_arstn),
              .clk				(i_mipi_clk),
              .reset_byte_HS_n	(i_arstn),
              .clk_byte_HS		  (i_cam_ck_CLKOUT),
              .reset_pixel_n		(w_mipi_rx_pclk_arstn),
              .clk_pixel			  (i_mipi_rx_pclk),
              
              .Rx_LP_CLK_P		  (i_cam_ck_LP_P_IN),
              .Rx_LP_CLK_N		  (i_cam_ck_LP_N_IN),
              .Rx_HS_enable_C		(o_cam_ck_HS_ENA),
              .LVDS_termen_C		(o_cam_ck_HS_TERM),
              
              .Rx_LP_D_P			({cam_d3_LP_P_IN, cam_d2_LP_P_IN, cam_d1_LP_P_IN, cam_d0_LP_P_IN}),//(r_mipi_rx_data_LP_P_IN_2P),
              .Rx_LP_D_N			({cam_d3_LP_N_IN, cam_d2_LP_N_IN, cam_d1_LP_N_IN, cam_d0_LP_N_IN}),//(r_mipi_rx_data_LP_N_IN_2P),
              .Rx_HS_D_0			(cam_d0_HS_IN),//(r_mipi_rx_data_HS_IN_2P[0*8+:8]),
              .Rx_HS_D_1			(cam_d1_HS_IN),//(r_mipi_rx_data_HS_IN_2P[1*8+:8]),
              .Rx_HS_D_2			(cam_d2_HS_IN),
              .Rx_HS_D_3			(cam_d3_HS_IN),
              .Rx_HS_D_4			(),
              .Rx_HS_D_5			(),
              .Rx_HS_D_6			(),
              .Rx_HS_D_7			(),
              .Rx_HS_enable_D		({cam_d3_HS_ENA    ,cam_d2_HS_ENA    ,cam_d1_HS_ENA    ,cam_d0_HS_ENA    }),//( w_cam_d_HS_ENA),
              .LVDS_termen_D		({cam_d3_HS_TERM   ,cam_d2_HS_TERM   ,cam_d1_HS_TERM   ,cam_d0_HS_TERM   }),
              .fifo_rd_enable		({cam_d3_FIFO_RD   ,cam_d2_FIFO_RD   ,cam_d1_FIFO_RD   ,cam_d0_FIFO_RD   }),
              .fifo_rd_empty		({cam_d3_FIFO_EMPTY,cam_d2_FIFO_EMPTY,cam_d1_FIFO_EMPTY,cam_d0_FIFO_EMPTY}),
              .DLY_enable_D		       (),
              .DLY_inc_D			(),
              .u_dly_enable_D		(),
              .u_dly_inc_D		       (),
              
              .axi_clk			(1'b0),
              .axi_reset_n		       (1'b0),
              .axi_awaddr			(6'b0),
              .axi_awvalid		       (1'b0),
              .axi_awready		       (),
              .axi_wdata			(32'b0),
              .axi_wvalid			(1'b0),
              .axi_wready			(),
              
              .axi_bvalid			(),
              .axi_bready			(1'b0),
              .axi_araddr			(6'b0),
              .axi_arvalid		       (1'b0),
              .axi_arready		       (),
              .axi_rdata			(),
              .axi_rvalid			(),
              .axi_rready			(1'b1),
              
              .hsync_vc0			(w_mipi_rx_hs),
              .hsync_vc1			(),
              .hsync_vc2			(),
              .hsync_vc3			(),
              .vsync_vc0			(w_mipi_rx_vs),
              .vsync_vc1			(),
              .vsync_vc2			(),
              .vsync_vc3			(),
              .vc				(),
              .word_count			(),
              .shortpkt_data_field        (),
              .datatype			(),
              .pixel_per_clk		(),
              .pixel_data			(w_mipi_rx_data),
              .pixel_data_valid	       (w_mipi_rx_de),
              .irq				(),
              .mipi_debug_out(mipi_debug_out)
		);

//     wire		       w1_mipi_rx_vs;
// wire		       w1_mipi_rx_hs;
// wire	       w1_mipi_rx_de;
// wire	[39:0]			w1_mipi_rx_data	;
// sensor_clipper  sensor_clipper_inst (
//     .clk(i_mipi_rx_pclk),
//     .i_vs(w_mipi_rx_vs),
//     .i_hs(w_mipi_rx_hs),
//     .i_de(w_mipi_rx_de),
//     .i_dat(w_mipi_rx_data[39:0]),

//     .o_hs(w1_mipi_rx_hs),
//     .o_vs(w1_mipi_rx_vs),
//     .o_de(w1_mipi_rx_de),
//     .o_dat(w1_mipi_rx_data)
   
//   );


wire mdebug_pixel_fifo_full     = mipi_debug_out[0] ;
wire mdebug_pixel_fifo_empty    = mipi_debug_out[1] ;
wire mdebug_crc_error           = mipi_debug_out[2] ;
wire mdebug_ecc_1bit_error      = mipi_debug_out[3] ;
wire mdebug_ecc_2bit_error      = mipi_debug_out[4] ;
wire mdebug_undersize_pkt_error = mipi_debug_out[5] ;
wire mdebug_line_vc0_error      = mipi_debug_out[6] ;
wire mdebug_frame_vc0_error    = mipi_debug_out[10];   
wire mdebug_receive_error      = mipi_debug_out[14];


//========================================================================================================
//
//========================================================================================================
		

//*************** imx219 config********************/
// mipi_config_imx219_top u_config_imx219(
// 										.i_sys_clk(CLK_5M)    	,    /////48M 
// 										.sys_rstn(vid_rst_n )    ,
// 										.o_sen_rst_n(o_cam_rstn)  	,
										
										// .o_iic_sda_OE(io_cam_sda_OE) ,
										// .i_iic_sda(io_cam_sda_IN)   	,
										// .o_iic_sda(io_cam_sda_OUT)   	,
										// .o_iic_scl(io_cam_scl)    	
										// ); 	

// Sapphire runs from its own 8 KiB BRAM at 100 MHz. Video retains exclusive DDR.
wire soc_reset_n;
wire [15:0] control_paddr;
wire control_psel, control_penable, control_pwrite;
wire [31:0] control_pwdata, control_prdata;
wire control_pready, control_pslverror;
wire [15:0] camera_gain_r, camera_gain_g, camera_gain_b;
wire camera_reset, camera_ready;

artflow_soc u_soc (
    .clk(core_clk), .reset_n(w_arstn), .system_reset_n(soc_reset_n),
    .uart_rx(uart_rx), .uart_tx(uart_tx),
    .i2c_scl_i(io_cam_scl_IN), .i2c_scl_o(io_cam_scl_OUT), .i2c_scl_oe(io_cam_scl_OE),
    .i2c_sda_i(io_cam_sda_IN), .i2c_sda_o(io_cam_sda_OUT), .i2c_sda_oe(io_cam_sda_OE),
    .paddr16(control_paddr), .psel(control_psel), .penable(control_penable),
    .pwrite(control_pwrite), .pwdata(control_pwdata), .prdata(control_prdata),
    .pready(control_pready), .pslverror(control_pslverror)
);

// Both mailbox endpoints share reset assertion; pixel release is synchronized.
(* async_reg = "true" *) reg [1:0] control_pixel_reset = 2'b00;
always @(posedge i_mipi_rx_pclk or negedge soc_reset_n) begin
    if (!soc_reset_n) control_pixel_reset <= 2'b00;
    else control_pixel_reset <= {control_pixel_reset[0], 1'b1};
end
(* async_reg = "true" *) reg [1:0] camera_ready_sync = 2'b00;
always @(posedge i_mipi_rx_pclk or negedge soc_reset_n) begin
    if (!soc_reset_n) camera_ready_sync <= 2'b00;
    else camera_ready_sync <= {camera_ready_sync[0], camera_ready};
end

// A sensor reset may omit Frame End. Explicitly terminate that partial frame,
// then wait for a fresh CSI frame boundary before admitting new RAW pixels.
wire capture_vs, capture_hs, capture_valid;
wire [39:0] capture_raw;
artflow_camera_gate u_camera_gate (
    .clk(i_mipi_rx_pclk), .rstn(control_pixel_reset[1]),
    .camera_ready(camera_ready_sync[1]),
    .raw_vs(w_mipi_rx_vs), .raw_hs(w_mipi_rx_hs),
    .raw_valid(w_mipi_rx_de), .raw_data(w_mipi_rx_data[39:0]),
    .video_vs(capture_vs), .video_hs(capture_hs),
    .video_valid(capture_valid), .video_data(capture_raw)
);

artflow_control #(
    .DEFAULT_R(CFG_R_GAIN), .DEFAULT_G(CFG_G_GAIN), .DEFAULT_B(CFG_B_GAIN)
) u_control (
    .pclk(core_clk), .presetn(soc_reset_n),
    .paddr(control_paddr), .psel(control_psel), .penable(control_penable),
    .pwrite(control_pwrite), .pwdata(control_pwdata), .prdata(control_prdata),
    .pready(control_pready), .pslverror(control_pslverror),
    .pixel_clk(i_mipi_rx_pclk), .pixel_resetn(control_pixel_reset[1]),
    .pixel_vs(capture_vs), .pixel_hs(capture_hs), .pixel_valid(capture_valid),
    .cal_done(cal_done), .gain_r(camera_gain_r), .gain_g(camera_gain_g), .gain_b(camera_gain_b),
    .camera_reset(camera_reset), .camera_ready(camera_ready)
);
assign o_cam_rst_p = !w_arstn || !soc_reset_n || camera_reset;

//=====================================================================================
// v04: CSI RAW -> 960x540 RGB -> scheduled DDR triple buffer -> centered dual windows
//=====================================================================================
wire vid_rst_n;
wire hdmi_tx_de;
wire hdmi_tx_hs;
wire hdmi_tx_vs;
wire [7:0] hdmi_tx_rdata;
wire [7:0] hdmi_tx_gdata;
wire [7:0] hdmi_tx_bdata;

cam_fb_pipe #(
  .DUAL_WINDOW    (CFG_DUAL_WINDOW),
  .AXI_DATA_WIDTH (AXI_DATA_WIDTH ),
  .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH ),
  .START_ADDR     (32'h0000_0000  ),
  .BANK_BYTES     (32'h0040_0000  ),   // 每帧 4 MB：帧 0/1/2 = 0x000000 / 0x400000 / 0x800000
  .MAX_IN_HEIGHT  (MAX_VRES       ),
  .MAX_IN_WIDTH   (MAX_HRES       ),
  .MAX_OUT_WIDTH  (MAX_HRES/2     )
) u_video_pipe (
  .cfg_bayer      (CFG_BAYER      ),
  .cfg_pix_rev    (CFG_PIX_REV    ),
  .cfg_gain_r     (camera_gain_r  ),
  .cfg_gain_g     (camera_gain_g  ),
  .cfg_gain_b     (camera_gain_b  ),

  .i_pclk         (i_mipi_rx_pclk ),
  .i_pclk_rstn    (w_mipi_rx_pclk_arstn),
  .i_vs           (capture_vs     ),
  .i_hs           (capture_hs     ),
  .i_valid        (capture_valid  ),
  .i_raw          (capture_raw    ),

  .H_FRONT_PORCH  (HFP/2          ),
  .H_SYNC         (HSP/2          ),
  .H_VALID        (MAX_HRES/2     ),
  .H_BACK_PORCH   (HBP/2          ),
  .V_FRONT_PORCH  (VFP            ),
  .V_SYNC         (VSP            ),
  .V_VALID        (MAX_VRES       ),
  .V_BACK_PORCH   (VBP            ),

  .rst_n          (vid_rst_n      ),
  .o_clk          (vid_clk_dvi2   ),
  .o_hdmi_clk     (hdmi_tx_slow_clk),
  .o_de           (hdmi_tx_de     ),
  .o_hs           (hdmi_tx_hs     ),
  .o_vs           (hdmi_tx_vs     ),
  .o_r            (hdmi_tx_rdata  ),
  .o_g            (hdmi_tx_gdata  ),
  .o_b            (hdmi_tx_bdata  ),

  .axi_clk        (core_clk       ),
  .awid (s_axi_awid ), .awaddr (s_axi_awaddr ), .awlen (s_axi_awlen ), .awsize (s_axi_awsize ),
  .awburst(s_axi_awburst), .awcache(s_axi_awcache), .awprot(s_axi_awprot), .awlock(s_axi_awlock),
  .awvalid(s_axi_awvalid), .awready(s_axi_awready),
  .arid (s_axi_arid ), .araddr (s_axi_araddr ), .arlen (s_axi_arlen ), .arsize (s_axi_arsize ),
  .arburst(s_axi_arburst), .arcache(s_axi_arcache), .arprot(s_axi_arprot), .arlock(s_axi_arlock),
  .arvalid(s_axi_arvalid), .arready(s_axi_arready),
  .wdata (s_axi_wdata ), .wstrb (s_axi_wstrb ), .wlast (s_axi_wlast ), .wvalid(s_axi_wvalid),
  .wready(s_axi_wready),
  .rid   (s_axi_rid   ), .rdata (s_axi_rdata ), .rlast (s_axi_rlast ), .rvalid(s_axi_rvalid),
  .rready(s_axi_rready), .rresp (s_axi_rresp ),
  .bid   (s_axi_bid   ), .bvalid(s_axi_bvalid), .bresp(s_axi_bresp), .bready(s_axi_bready)
);


ddr3_top                 u_ddr3_top
(

.axi_clk                (core_clk            ),
.core_clk               (core_clk            ),
.sdram_clk              (sdram_clk           ),  
.rx_cal_clk             (rx_cal_clk          ),
.tx_cal_clk             (tx_cal_clk          ),
.tx_cal_clk_90edge      (tx_cal_clk_90edge   ),
.rstn                   (w_arstn             ),      
.pll_shift              (pll_shift           ),
.pll_shift_sel          (pll_shift_sel       ),
.pll_shift_ena          (pll_shift_ena       ),       
///////////////DDR BUS
.ddr_ck_hi              (ddr_ck_hi           ),
.ddr_ck_lo              (ddr_ck_lo           ),
.ddr_cke                (ddr_cke             ),    
.ddr_reset_n            (ddr_reset_n         ),
.ddr_cs_n               (ddr_cs_n            ),
.ddr_ras_n              (ddr_ras_n           ),
.ddr_cas_n              (ddr_cas_n           ),
.ddr_we_n               (ddr_we_n            ),     
.ddr_addr               (ddr_addr[ROW_WIDTH-1:0]),
.ddr_ba                 (ddr_ba              ),

.ddr_dqs_oe             (ddr_dqs_oe          ),
.ddr_dqs_oe_n           (ddr_dqs_oe_n        ),
.ddr_dq_oe              (ddr_dq_oe           ),
.ddr_dqs_in_hi          (ddr_dqs_in_hi       ),
.ddr_dqs_in_lo          (ddr_dqs_in_lo       ),
.ddr_dq_in_hi           (ddr_dq_in_hi        ),
.ddr_dq_in_lo           (ddr_dq_in_lo        ),

.ddr_dqs_out_hi         (ddr_dqs_out_hi      ),
.ddr_dqs_out_lo         (ddr_dqs_out_lo      ),
.ddr_dq_out_hi          (ddr_dq_out_hi       ),
.ddr_dq_out_lo          (ddr_dq_out_lo       ),

.ddr_dm_hi              (ddr_dm_hi           ),
.ddr_dm_lo              (ddr_dm_lo           ),
.ddr_odt                (ddr_odt             ),

// Application interface ports
.app_sr_req                     (1'b0),
.app_ref_req                    (1'b0),
.app_zq_req                     (1'b0),
.app_sr_active                  (app_sr_active),
.app_ref_ack                    (app_ref_ack),
.app_zq_ack                     (app_zq_ack),

// Slave Interface Write Address Ports
.s_axi_awid                     (s_axi_awid        ),
.s_axi_awaddr                   (s_axi_awaddr      ),
.s_axi_awlen                    (s_axi_awlen       ),
.s_axi_awsize                   (s_axi_awsize      ),
.s_axi_awburst                  (s_axi_awburst     ),
.s_axi_awlock                   (s_axi_awlock      ),
.s_axi_awcache                  (s_axi_awcache     ),
.s_axi_awprot                   (s_axi_awprot      ),
.s_axi_awqos                    (4'h0              ),
.s_axi_awvalid                  (s_axi_awvalid     ),
.s_axi_awready                  (s_axi_awready     ),
// Slave Interface Write Data Ports
.s_axi_wdata                    (s_axi_wdata       ),
.s_axi_wstrb                    (s_axi_wstrb       ),
.s_axi_wlast                    (s_axi_wlast       ),
.s_axi_wvalid                   (s_axi_wvalid      ),
.s_axi_wready                   (s_axi_wready      ),
// Slave Interface Write Response Ports
.s_axi_bid                      (s_axi_bid         ),
.s_axi_bresp                    (s_axi_bresp       ),
.s_axi_bvalid                   (s_axi_bvalid      ),
.s_axi_bready                   (s_axi_bready      ),
// Slave Interface Read Address Ports
.s_axi_arid                     (s_axi_arid        ),
.s_axi_araddr                   (s_axi_araddr      ),
.s_axi_arlen                    (s_axi_arlen       ),
.s_axi_arsize                   (s_axi_arsize      ),
.s_axi_arburst                  (s_axi_arburst     ),
.s_axi_arlock                   (s_axi_arlock      ),
.s_axi_arcache                  (s_axi_arcache     ),
.s_axi_arprot                   (s_axi_arprot      ),
.s_axi_arqos                    (4'h0              ),
.s_axi_arvalid                  (s_axi_arvalid     ),
.s_axi_arready                  (s_axi_arready     ),
// Slave Interface Read Data Ports
.s_axi_rid                      (s_axi_rid         ),
.s_axi_rdata                    (s_axi_rdata       ),
.s_axi_rresp                    (s_axi_rresp       ),
.s_axi_rlast                    (s_axi_rlast       ),
.s_axi_rvalid                   (s_axi_rvalid      ),
.s_axi_rready                   (s_axi_rready      ),
//DEBUG       
.wrlvl_dq_check                 (wrlvl_dq_check    ) ,
.rd_level_dqs_check             (rd_level_dqs_check) ,
.init_cur_state                 (init_cur_state    ) ,
.idelay_ld                      (idelay_ld         ) ,
.mpr_rdlvl_dly                  (mpr_rdlvl_dly     ) ,
.cal_done                       (cal_done          ) 
);

// v03：旧的 debayer（插值）和 HDMI 入口的 2 像素拼接已由 cam_fb_pipe 取代，源文件归档在 _archive/v03_debayer/

//==============================================================================
// 视频通路复位：PLL 锁定后延时约 0.9 s（2^26 / 74.25 MHz）再释放
//==============================================================================

reg [26:0] dly_cnt = 'd0;

always @( posedge vid_clk_dvi2 or negedge w_arstn )
begin
  if( !w_arstn )
    dly_cnt <= 'd0;
  else
    dly_cnt <= dly_cnt[26] ? dly_cnt : (dly_cnt + 1'b1);
end

assign vid_rst_n = dly_cnt[26];





//=================================================================================
//hdmi tx ctrl 
//=================================================================================
assign tmds_tx_data0_TX_OE = 1'b1;
assign tmds_tx_data1_TX_OE = 1'b1;
assign tmds_tx_data2_TX_OE = 1'b1;
assign tmds_tx_clk_TX_OE   = 1'b1;

assign tmds_tx_data0_TX_RST = 1'b0;
assign tmds_tx_data1_TX_RST = 1'b0;
assign tmds_tx_data2_TX_RST = 1'b0;
assign tmds_tx_clk_TX_RST   = 1'b0;

wire [9:0] tmds_data0;
wire [9:0] tmds_data1;
wire [9:0] tmds_data2;
wire [9:0] tmds_clk ;
wire [7:0] gamma_rdata ;
wire [7:0] gamma_gdata ;
wire [7:0] gamma_bdata ;
wire gamma_valid;
wire gamma_hs;
wire gamma_vs;

// ---------------------------------------------------------------- 色条叠加
wire [7:0] pat_rdata;
wire [7:0] pat_gdata;
wire [7:0] pat_bdata;
wire       pat_de;
wire       pat_hs;
wire       pat_vs;
wire       pat_active;

test_pattern #(
  .H_ACTIVE    (MAX_HRES),
  .H_FP        (HFP     ),
  .H_SYNC      (HSP     ),
  .H_BP        (HBP     ),
  .V_ACTIVE    (MAX_VRES),
  .V_FP        (VFP     ),
  .V_SYNC      (VSP     ),
  .V_BP        (VBP     ),
  .BOOT_FRAMES (300)
) u_test_pattern (
  .i_clk    (hdmi_tx_slow_clk),
  .i_rstn   (vid_rst_n       ),
  .i_mode   (CFG_PATTERN     ),
  .i_de     (hdmi_tx_de      ),
  .i_hs     (hdmi_tx_hs      ),
  .i_vs     (hdmi_tx_vs      ),
  .i_r      (hdmi_tx_rdata   ),
  .i_g      (hdmi_tx_gdata   ),
  .i_b      (hdmi_tx_bdata   ),
  .o_de     (pat_de          ),
  .o_hs     (pat_hs          ),
  .o_vs     (pat_vs          ),
  .o_r      (pat_rdata       ),
  .o_g      (pat_gdata       ),
  .o_b      (pat_bdata       ),
  .o_active (pat_active      )
);
assign led[1] = pat_active;     // LED1 亮 = 正在显示色条


gamma_lut
#(
	.LUT_FILE	("./rtl/gamma_conrrection/gamma_2p2_8b.mem")
)
inst_gamma_lut
(
	.i_pclk		(hdmi_tx_slow_clk),
	.i_rstn		(vid_rst_n),
	.i_bypass	(~CFG_GAMMA_EN),

	.i_red		(pat_rdata    ),
	.i_green	(pat_gdata    ),
	.i_blue		(pat_bdata    ),
  .i_valid	(pat_de       ),
  .i_hs     (pat_hs       ),
  .i_vs     (pat_vs       ),
	.o_blue		(gamma_bdata		),
  .o_green	(gamma_gdata	  ),
	.o_red		(gamma_rdata		),
	.o_valid	(gamma_valid	  ),
  .o_hs     (gamma_hs       ),
  .o_vs     (gamma_vs       )
);

dvi_encoder dvi_encoder_m0
(
	.pixelclk      		(hdmi_tx_slow_clk          ),// system clock
	.rst_p         		(~vid_rst_n      ),// reset
	.i_bdata      		(gamma_bdata ),
	.i_gdata     		  (gamma_gdata ),
	.i_rdata       		(gamma_rdata ),
  .i_de            	(gamma_valid ),
	.i_hs         		(gamma_hs    ),
	.i_vs         		(gamma_vs    ),  
	
  .video_format     (video_format), //// 00 = RGB, 01 = YCbCr 4:2:2, 10 = YCbCr 4:4:4
  .video_VIC        (0),
	.audio_L			    (audio_L),
  .audio_R			    (audio_R),
  .audio_valid		  (audio_valid),
  .audio_N                (6144),     //(20'h01880),//     
  .audio_CTS              (148500),      //(20'h28488),//      
  .audio_sample_frequency (audio_samp_freq),    //(3'b000),// 
  .audio_word_length      ({audio_samp_word_len,audio_max_word_length}),//(4'b1011),//

	.tmds_data0    		(tmds_data0),
  .tmds_data1    		(tmds_data1),
  .tmds_data2    		(tmds_data2),
  .tmds_clk      	  (tmds_clk  )
);
assign tmds_tx_clk_TX_DATA   = ~tmds_clk;
assign tmds_tx_data0_TX_DATA = ~tmds_data0;
assign tmds_tx_data1_TX_DATA = ~tmds_data1;
assign tmds_tx_data2_TX_DATA = ~tmds_data2;


endmodule
