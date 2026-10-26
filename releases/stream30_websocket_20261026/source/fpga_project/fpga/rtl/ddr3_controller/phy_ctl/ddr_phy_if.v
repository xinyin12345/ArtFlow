//***************************************************************/
//   ______   _   _   _                  _            _
//  |  ____| | | (_) | |                | |          | |
//  | |__    | |  _  | |_    ___   ___  | |_    ___  | | __
//  |  __|   | | | | | __|  / _ \ / __| | __|  / _ \ | |/ /
//  | |____  | | | | | |_  |  __/ \__ \ | |_  |  __/ |   <  
//  |______| |_| |_|  \__|  \___| |___/  \__|  \___| |_|\_\
//
// Moudel Name    : ddr_phy_if.v
// Version        : 1.3
// Date Created   : 2023-02-23 10:37:59
// Last Modified  : 2023-02-23 10:37:59
// Abstract       : ---
//
//Copyright (c) 2020-2023 Elitestek,Inc. All Rights Reserved.
//
//***************************************************************/
//Modification History
//1.initial
//***************************************************************/


  `timescale 1ps/1ps
module ddr_phy_if #(
parameter                       tCK          = 1500,        
parameter                       WL           = 5,           
parameter                       nCL          = 5,                   
parameter                       CK_RATIO     = 4,           
parameter                       BANK_WIDTH   = 2,
parameter                       RANK_RATIO   = 1,           
parameter                       DQ_WIDTH     = 64,
parameter                       DQS_WIDTH    = 8,
parameter                       DM_WIDTH     = 8,
parameter                       ROW_WIDTH    = 14,
parameter                       CS_WIDTH     = 1,
parameter                       ODT_WIDTH    = 1,
parameter                       CKE_WIDTH    = 1       

)(
// clock & reset
input                           core_clk,            // CORE CLK @ 100MHz
input                           sdram_clk,           // SDRAM CK @ 400MHz
input                           rx_cal_clk,          // SDRAM CK @ 400MHz
input                           tx_cal_clk,          // SDRAM CK @ 400MHz
input                           tx_cal_clk_90edge,   // SDRAM CK @ 400MHz
input                           sdram_rst,
input                           rx_clk_rst,
input                           tx_data_rst,
input                           rst,
input                           tx_clk_rst,

input                           phy_cmd_wr_en,
input                           phy_data_wr_en,
input           [31:0]          phy_ctl_wd,
input                           phy_ctl_wr,
output                          phy_ctl_full,
output                          phy_cmd_full,
output                          phy_data_full,
output                          wl_sm_start,
output  reg     [1:0]           dqs_bit_sample_err,
output  reg                     dq_bit_sample_ok,
output  reg                     ddr_dq_vld_r,
input                           dq_check_en,
input                           rdlvl_dqs_check_ena,
input                           idelay_ld,
input                           wrlvl_rank_done,
input                           wr_level_delay,
input                           mpr_rdlvl_dly,
input                           mpr_rdlvl_en,
input                           dqs_invert,
// From/to calibration logic/soft PHY
input                           init_calib_complete,
input           [CK_RATIO-1:0]  mux_cke,
input           [CS_WIDTH*RANK_RATIO*CK_RATIO-1:0] 
                                mux_cs_n,
input           [CK_RATIO-1:0]  mux_ras_n,
input           [CK_RATIO-1:0]  mux_cas_n,
input           [CK_RATIO-1:0]  mux_we_n,
input           [CK_RATIO*BANK_WIDTH-1:0] 
                                mux_bank,
input           [CK_RATIO*ROW_WIDTH-1:0]  
                                mux_address,
input           [1:0]           mux_odt,
input           [2*CK_RATIO*DQ_WIDTH-1:0] 
                                mux_wrdata,
input           [2*CK_RATIO*DM_WIDTH-1:0] 
                                mux_wrdata_mask,
input                           mux_reset_n,
output                          phy_rddata_valid,
output           [2*CK_RATIO*DQ_WIDTH-1:0]
                                phy_rd_data,
output           [8-1:0]        debug_fifo,                                
output           [8-1:0]        overflow_fifo,                                
// DDR bus signals
output                          ddr_ck_hi,
output                          ddr_ck_lo,
output           [CKE_WIDTH-1:0]ddr_cke,
output                          ddr_reset_n,
output           [CS_WIDTH*RANK_RATIO-1:0]
                                ddr_cs_n,
output                          ddr_ras_n,
output                          ddr_cas_n,
output                          ddr_we_n,
output           [BANK_WIDTH-1:0]
                                ddr_ba,
output           [ROW_WIDTH-1:0]ddr_addr,
               
input            [DQS_WIDTH-1:0]ddr_dqs_in_hi,
input            [DQS_WIDTH-1:0]ddr_dqs_in_lo,
input            [DQ_WIDTH-1:0] ddr_dq_in_hi,
input            [DQ_WIDTH-1:0] ddr_dq_in_lo,

output  reg                     phy_dqs_oe,
output  reg                     phy_dq_oe,
output           [DQS_WIDTH-1:0]ddr_dqs_out_hi,
output           [DQS_WIDTH-1:0]ddr_dqs_out_lo,
output  reg      [DQ_WIDTH-1:0] ddr_dq_out_hi,
output  reg      [DQ_WIDTH-1:0] ddr_dq_out_lo,
output  reg      [DM_WIDTH-1:0] ddr_dm_hi,
output  reg      [DM_WIDTH-1:0] ddr_dm_lo,
output  reg      [ODT_WIDTH-1:0]ddr_odt

);

//Parameter Define
localparam CWL_M =  WL ;//+ nAL;
localparam CMD_WTH = (CKE_WIDTH+3+ (CS_WIDTH*RANK_RATIO)+BANK_WIDTH+ROW_WIDTH) *CK_RATIO;
localparam DFIFO_WTH =2*CK_RATIO*(DQ_WIDTH + DM_WIDTH);
localparam FIFO_DEPTH =16;
localparam WR  = 4'b0100;
localparam RD  = 4'b0101;
localparam POS = 2'b10;
localparam NEG = 2'b01;

//Register Define
reg                             u1_wrreq_r;
reg     [CMD_WTH+1:0]           u1_data_r;
reg                             u2_wrreq_r;
reg     [31:0]                  u2_data_r;
reg                             u4_wrreq;
reg     [2*CK_RATIO*(DQ_WIDTH)-1:0]    
                                u4_data;
reg     [CK_RATIO-1:0]          rd_data_cke  ;
reg     [CS_WIDTH*RANK_RATIO*CK_RATIO-1:0]
                                rd_data_cs_n ;
reg     [CK_RATIO-1:0]          rd_data_ras_n;
reg     [CK_RATIO-1:0]          rd_data_cas_n;
reg     [CK_RATIO-1:0]          rd_data_we_n ;
reg     [CK_RATIO*BANK_WIDTH-1:0]
                                rd_data_ba   ;
reg     [CK_RATIO*ROW_WIDTH-1:0]       
                                rd_data_addr ;
reg                             rd_data_cke_r1;
reg                             mux_odt_r1;
reg                             mux_odt_r2;
reg                             mux_odt_r3;
reg     [WL+1:0]                mux_odt_delay;
reg                             rd_data_cs_n_r1;
//reg                             rd_data_cs_n_r2;
reg                             rd_data_ras_n_r1;
//reg                             rd_data_ras_n_r2;
reg                             rd_data_cas_n_r1;
//reg                             rd_data_cas_n_r2;
reg                             rd_data_we_n_r1;
//reg                             rd_data_we_n_r2;
reg     [BANK_WIDTH-1:0]        rd_data_ba_r1   ;
//reg     [BANK_WIDTH-1:0]        rd_data_ba_r2   ;
reg     [ROW_WIDTH-1:0]         rd_data_addr_r1 ;
//reg     [ROW_WIDTH-1:0]         rd_data_addr_r2 ;
reg                             ddr_ctl_wren;
reg                             wr_cmd_en;
reg     [1:0]                   mem_dqs_out;
reg     [2*CK_RATIO*DQ_WIDTH-1:0]
                                mem_dq_out   ;
reg     [2*DQ_WIDTH-1:0]        mem_dq_out_r1;
reg     [2*CK_RATIO*DM_WIDTH-1:0]      
                                mem_dm_out   ;
reg     [2*DM_WIDTH-1:0]        mem_dm_out_r1;
reg     [DQ_WIDTH-1:0]          ddr_dq_in_hi_r1;
reg     [DQ_WIDTH-1:0]          ddr_dq_in_hi_r2;
reg     [DQ_WIDTH-1:0]          ddr_dq_in_hi_r3;
reg     [DQ_WIDTH-1:0]          ddr_dq_in_lo_r1;
reg     [DQ_WIDTH-1:0]          ddr_dq_in_lo_r2;
reg     [DQ_WIDTH-1:0]          ddr_dq_in_lo_r3;
reg     [DQS_WIDTH-1:0]         ddr_dqs_in_hi_r1;
reg     [DQS_WIDTH-1:0]         ddr_dqs_in_hi_r2;
reg     [DQS_WIDTH-1:0]         ddr_dqs_in_hi_r3;
reg     [DQS_WIDTH-1:0]         ddr_dqs_in_lo_r1;
reg     [DQS_WIDTH-1:0]         ddr_dqs_in_lo_r2;
reg     [DQS_WIDTH-1:0]         ddr_dqs_in_lo_r3;
reg     [1:0]                   wr_data_cnt;
reg     [2*CK_RATIO-1:0]        rd_dq_ena;
reg                             rddata_valid_reg;
reg     [2*CK_RATIO*DQ_WIDTH-1:0]
                                rd_data_reg;
reg     [WL+2:0]                wr_data_en;
reg     [WL+4:0]                wr_ctl_en;
(* async_reg = "true" *)reg     idelay_ld_r1;
(* async_reg = "true" *)reg     idelay_ld_r2;
(* async_reg = "true" *)reg     idelay_ld_r3;
reg                             wrcal_delay;
reg                             rdlvl_check_ena_r1;
reg                             rdlvl_check_ena_r2;
reg                             rdlvl_check_ena_r3;
reg                             rdlvl_check_ena;
reg                             wrlvl_check_ena;
(* async_reg = "true" *)reg     dq_check_en_r1;
(* async_reg = "true" *)reg     dq_check_en_r2;
(* async_reg = "true" *)reg     dq_check_en_r3;
reg                             dq_in_hi_r1;
reg                             dq_in_hi_r2;
reg                             dq_in_lo_r1;
reg                             dq_in_lo_r2;
reg     [1:0]                   dq_bit_sample_cnt;
reg     [DQS_WIDTH-1:0]         dqs_sample_err;
(* async_reg = "true" *)reg     ddr_rden_r1;
(* async_reg = "true" *)reg     ddr_rden_r2;
(* async_reg = "true" *)reg     ddr_rden_r3;
reg     [1:0]                   dqs_sample_reslut[DQS_WIDTH-1:0];
(* async_reg = "true" *)reg     ddr_wren_r1;
(* async_reg = "true" *)reg     ddr_wren_r2;
(* async_reg = "true" *)reg     ddr_wren_r3;
(* async_reg = "true" *)reg     ddr_wren_r4;
(* async_reg = "true" *)reg     ddr_wren_r5;
reg     [3:0]                   stable_cnt[DQS_WIDTH-1:0];
reg     [DQS_WIDTH-1:0]         dq_in_hi_or_prev;
reg     [DQS_WIDTH-1:0]         flag_ck_posedge;
reg     [DQS_WIDTH-1:0]         flag_ck_negedge;
reg     [DQS_WIDTH-1:0]         rd_data_edge_detect_r;
reg     [nCL+6:0]               rd_data_en_ctl;
reg                             rd_data_en;
reg                             wl_dqs_out_en ;
reg                             wl_dqs_en     ;
reg                             wl_dqs_en_r1  ;
reg                             wl_dqs_en_r2  ;
//Wire Define
wire                            u1_wrreq_ns;
wire    [CMD_WTH+1:0]           u1_data_ns;
wire                            u1_wrreq;
wire    [CMD_WTH+1:0]           u1_data;
wire                            u1_almfull;
wire                            u1_full;
wire                            u1_progfull;
wire                            u1_empty;
wire                            u1_rdreq;
wire    [CMD_WTH+1:0]           u1_q;
wire                            u2_wrreq_ns;
wire    [31:0]                  u2_data_ns;
wire                            u2_wrreq;
wire    [31:0]                  u2_data;
wire    [31:0]                  u2_q;
wire                            u2_almfull;
wire                            u2_full;
wire                            u2_empty;
wire                            u2_rdreq;
wire                            u3_wrreq;
wire    [2*CK_RATIO*(DQ_WIDTH/8+DQ_WIDTH)-1:0] 
                                u3_data;
wire    [2*CK_RATIO*(DQ_WIDTH/8+DQ_WIDTH)-1:0] 
                                u3_q;
wire                            u3_almfull;
wire                            u3_full;
wire                            u3_empty;
wire                            u3_rdreq;
wire    [2*CK_RATIO*(DQ_WIDTH)-1:0]    
                                u4_q;
wire                            u4_almfull;
wire                            u4_full;
wire                            u4_empty;
wire                            u4_wrreq_temp;
wire                            u4_rdreq;
wire    [2*DQ_WIDTH-1:0]        ddr_dq_data;
wire                            cmd_fifo_afull;
wire                            cmd_fifo_full;
wire                            ctl_fifo_full;
wire                            ctl_fifo_afull;
wire    [CMD_WTH+1:0]           phy_din;
wire    [3:0]                   ddr_cmd;
wire    [2:0]                   phy_cmd;
wire    [5:0]                   phy_data_offset;
wire                            wr_data_en_ns;
wire                            wr_data_en_temp;
wire                            wr_ctl_en_temp;
wire                            dqs_bit_and_hi;
wire                            dqs_bit_and_lo;
wire                            wr_dqs_en0;
wire                            wr_dqs_en1;
wire                            wr_dq_in_en;
wire    [DQ_WIDTH/8-1:0]        dq_in_hi_or;
wire    [DQ_WIDTH/8-1:0]        dq_in_lo_or;
wire    [DQ_WIDTH-1:0]          ddr_dq_out_hi_temp1;
wire    [DQ_WIDTH-1:0]          ddr_dq_out_lo_temp1;
wire    [DM_WIDTH-1:0]          ddr_dm_hi_temp1;
wire    [DM_WIDTH-1:0]          ddr_dm_lo_temp1;
wire    [DQ_WIDTH-1:0]          ddr_dq_out_hi_temp2;
wire    [DQ_WIDTH-1:0]          ddr_dq_out_lo_temp2;
wire    [DM_WIDTH-1:0]          ddr_dm_hi_temp2;
wire    [DM_WIDTH-1:0]          ddr_dm_lo_temp2;
wire    [2*DQ_WIDTH-1:0]        mem_dq_out_r0;
wire    [2*DM_WIDTH-1:0]        mem_dm_out_r0;
wire    [1:0]                   dqs_sample_edge  [DQS_WIDTH-1:0];
wire    [1:0]                   dqs_sample       [DQS_WIDTH-1:0];
wire    [DQS_WIDTH-1:0]         dqs_sample_r     [1:0]          ;
wire    [5:0]                   u1_rdata_cnt;
wire    [5:0]                   u1_wdata_cnt;
wire                            u1_rdreq_temp;
reg     [1:0]                   u2_rd_cmd_cnt;
wire                            u2_rdreq_temp;
wire    [5:0]                   u2_rdata_cnt;
wire    [5:0]                   u2_wdata_cnt;
reg                             rd_ctl_en;
reg     [1:0]                   u1_rd_cmd_cnt;
reg                             rd_cmd_en;
//Encryption begin
`pragma protect begin_protected
`pragma protect version=1
`pragma protect encrypt_agent="ipecrypt"
`pragma protect encrypt_agent_info="http://ipencrypter.com Version: 20.0.8"
`pragma protect author="author-a"
`pragma protect author_info="author-a-details"

`pragma protect key_keyowner="Efinix Inc."
`pragma protect key_keyname="EFX_K01"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=256)
`pragma protect key_block
VTlkE1fkA9o0AYxFbsYf5r5SA589xtLZmgCsIIsNNHdoPiqW3WSYPDQL4fKBdPxC
CbbjGmJZO8Vgi/cvxakwIdC0h8SrCPtaOujhwzFD0jOHd60+BL8xPfnLqZxa78QC
/f3pW9ickzHp69aKdpaeFMr3p0v9wZvaAD7cpHfIDC1zGpAnwgj7sJjTqQNF8UzS
CYn9rxV02Y/qYRlU4J22C8CD4wM2T8Z2ePzC0rTwxJDDaU3Y07WzvqoZeRCGhDw8
mvvblY2PTKtksrTfcuZbuI1u6QlPPu6uW5YMM2QGpjXfotEYd+Md6LmcwGqWfyLX
T1FRS0X36Xlhhjn49bKblg==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
AHTsOOnvaHGWXQvtGr1wOQ9pOnutDmoJaETRDFeJ/5I64d0RebQ2xHcG53lo6RV+
zS7Efn7sNl1/7FA6TbbP5bclSIdmy2u+4T0oQzFtXpLGw2t6GyVAsNXZQfHWJ+b+
U3tCFrmheT85hKlFpyfMhuMwUVu2ny9HqvNTu/PbwNs=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=30112)
`pragma protect data_block
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
Gj3LgGfJFeIXJJPbj3I9Lg==
`pragma protect end_protected
endmodule
