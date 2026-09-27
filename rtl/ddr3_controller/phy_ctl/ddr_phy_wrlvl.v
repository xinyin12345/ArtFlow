//***************************************************************/
//   ______   _   _   _                  _            _
//  |  ____| | | (_) | |                | |          | |
//  | |__    | |  _  | |_    ___   ___  | |_    ___  | | __
//  |  __|   | | | | | __|  / _ \ / __| | __|  / _ \ | |/ /
//  | |____  | | | | | |_  |  __/ \__ \ | |_  |  __/ |   <  
//  |______| |_| |_|  \__|  \___| |___/  \__|  \___| |_|\_\
//
// Moudel Name    : ddr_phy_wrlvl.v
// Version        : 1.0
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

module ddr_phy_wrlvl # (
parameter                       TCQ         = 100,
parameter                       DQ_WIDTH    = 64,
parameter                       DRAM_WIDTH  = 8,
parameter                       DQS_WIDTH   = 2
)
(
input                           clk,
input                           rst,
input                           wr_level_start,
input                           write_calib,
input                           wl_sm_start,
input                           dq_bit_sample_ok,

output          [7:0]           wrlvl_dq_check,
output  reg                     dqs_invert ,
output  reg                     dq_check_en ,
output  reg                     wrlvl_rank_done ,
output  reg                     wr_level_done ,
output  reg                     wrlvl_shift_ena,  
output  reg     [2:0]           wrlvl_phise_shift,
output  reg     [2:0]           wrlvl_shift
   );

//Parameter Define
localparam              PHISE_TAPS     = 8;
localparam              PLL_SHIFT_NUM  = 4;
localparam              WL_DQS_NUM     = 16;
localparam              PLL_BLANK_NUM  = 64;

localparam              PLL_SHIFT_WTH  = clogb2(PLL_SHIFT_NUM); 
localparam              WL_DQS_WTH     = clogb2(WL_DQS_NUM); 
localparam              TAP_WTH        = clogb2(PHISE_TAPS);
localparam              BLANK_NUM_WTH  = clogb2(PLL_BLANK_NUM);
 
localparam              IDLE           = 3'h0;
localparam              WLDQSEN_WAIT   = 3'h1;
localparam              DQS_WAIT       = 3'h2;
localparam              WL_EADG_CHECK  = 3'h3;
localparam              PLL_SHIFT      = 3'h4;
localparam              SEND_DQS_INC   = 3'h5;
localparam              SEND_DQS_INVERT= 3'h6;
localparam              DQ_CHECK_DONE  = 3'h7;

//Register Define
reg     [2:0]                   cur_state;
reg     [2:0]                   next_state;  
reg     [WL_DQS_WTH-1:0]        wrlvl_check_cnt;
reg     [PLL_SHIFT_WTH-1:0]     pll_shift_cnt;
reg     [2:0]                   wr_level_shift_cnt;
reg     [BLANK_NUM_WTH-1:0]     pll_blank_cnt;
(* async_reg = "true" *)reg                             dq_bit_ok_r1;
reg                             dq_bit_ok_r2;
reg                             dq_bit_ok_r3;
reg     [7:0]                   dq_dynmic_shift;
reg                             check_err;
reg                             check_err_r;
reg     [TAP_WTH-1:0]           rising_tap;
reg                             rising_tap_vld;
reg     [TAP_WTH-1:0]           next_rising_tap;
reg                             next_rising_tap_vld;
reg     [TAP_WTH-1:0]           first_rising_tap;
reg                             first_rising_tap_vld;
reg     [TAP_WTH-1:0]           failling_tap;
reg                             failling_tap_vld;
reg     [TAP_WTH-1:0]           next_failling_tap;
reg                             next_failling_tap_vld;
reg                             replace_flag;
reg     [TAP_WTH-1:0]           calibrate_tap;
reg                             last_flag;
reg                             clean_flag;
reg     [3:0]                   check_err_cnt;
reg                             dqs_invert_r1;
reg                             dqs_invert_r2;

//Wire Define
wire    [TAP_WTH-1:0]           calibrate_1tmp;
wire    [TAP_WTH-1:0]           calibrate_2tmp;
wire    [TAP_WTH-1:0]           calibrate_3tmp;
wire                            case_1tmp;
wire                            case_2tmp;
wire                            case_3tmp;
wire    [TAP_WTH-1:0]           tap_cnt;  
wire                            dqs_invert_edge;
//wire    [7:0]                 check_debug = 8'b01111111;
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
XMP0sqQ6cHpiq+KSKTsdX5LswQIa0GecK3kRHd093wdfl5lt9xlymoqgVxZoerGE
HNrjzx6mzp3sWMNWpKAuTKQJpHZx2nfB/ycvNt7PAaNiPrg+t1EnG+MehjyfpzE7
OJxoQ5XxZgv7oSxkN9V7JDCX2ZklKBIQRkLCiPp4/Gt6I3uLo9ttjJbKMX6lryft
yYt+geuCaTVR6fE//FBRaT+luGp0s7GxIJvpBnovklY/v57ZjO9e3YjWPemyljWj
lIWpR5XHJXcdCZKE6fJG5xX39mdyC96+8x8XSm5dGeCTFgPk3zroWvOHKLE3zAE0
+mKzq3ehyEvOxC3IW8teGw==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
cWqhPLCUNZZqF+6Vlk3wvb6yxTerJ1m6lRnVWIt8CrJ0abcmzMkpUMGVO2CEoQab
bNsK2i3QI+Ie1p3aJ9yxAhjZYML5O0vJxyP8RakNJ8Ydl26LLWOuVKPYXRUCKY2K
6F6/3qquYNc6dd7gceLU4vXAf4LQetJlYADJch2Q8mM=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=15504)
`pragma protect data_block
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
`pragma protect end_protected
endmodule
