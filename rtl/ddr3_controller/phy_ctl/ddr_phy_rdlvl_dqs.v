//***************************************************************/
//   ______   _   _   _                  _            _
//  |  ____| | | (_) | |                | |          | |
//  | |__    | |  _  | |_    ___   ___  | |_    ___  | | __
//  |  __|   | | | | | __|  / _ \ / __| | __|  / _ \ | |/ /
//  | |____  | | | | | |_  |  __/ \__ \ | |_  |  __/ |   <  
//  |______| |_| |_|  \__|  \___| |___/  \__|  \___| |_|\_\
//
// Moudel Name    : ddr_phy_rdlvl_dqs.v
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

module ddr_phy_rdlvl_dqs #(
parameter                       TCQ             = 100,
parameter                       DQS_CHECK_TIME  = 512,
parameter                       DQS_CNT_WIDTH   = 3,
parameter                       DQS_WIDTH       = 2
)
(
input                           clk,
input                           rst,
input                           rd_dqs_start,
input           [1:0]           dqs_bit_sample_err,

output          [7:0]           rd_level_dqs_check,
output  reg                     rdlvl_dqs_check_ena,
output  reg                     rd_level_dqs_done,
output  reg                     rdlvl_all_dqs_done,
output  reg                     rdlvl_dqs_shift_ena,
output  reg     [2:0]           rdlvl_dqs_phise_shift,
output  reg     [2:0]           rdlvl_shift
);

//Parameter Define
localparam              PHISE_TAPS     = 8;
localparam              PLL_SHIFT_NUM  = 4;
localparam              WIAT_CNT       = 25;
localparam              PLL_BLANK_NUM  = 64;
localparam              TAP_WTH        = clogb2(PHISE_TAPS);
localparam              WIAT_WTH       = clogb2(WIAT_CNT);
localparam              DQS_CHECK_WTH  = clogb2(DQS_CHECK_TIME); 
localparam              PLL_SHIFT_WTH  = clogb2(PLL_SHIFT_NUM); 
localparam              BLANK_NUM_WTH  = clogb2(PLL_BLANK_NUM);
            
localparam              IDLE           = 3'h0;
localparam              RD_DQS_WAIT    = 3'h1;
localparam              RD_DQS_CHECK   = 3'h2;
localparam              PLL_SHIFT      = 3'h3;
localparam              RD_DQS_LOOP    = 3'h4;
localparam              PLL_BLANK      = 3'h5;
localparam              DQS_CHECK_DONE = 3'h6;

//Register Define
reg     [2:0]                   cur_state;
reg     [2:0]                   next_state;
(* async_reg = "true" *)reg     [1:0]                   dqs_bit_sample_r1;
reg     [1:0]                   dqs_bit_sample_r2;
reg     [1:0]                   dqs_bit_sample_r3;
reg     [1:0]                   dqs_bit_sample_r4;
reg     [WIAT_WTH-1:0]          wait_cnt;
reg     [DQS_CHECK_WTH-1:0]     rd_level_dqs_cnt;
reg     [PLL_SHIFT_WTH-1:0]     pll_shift_cnt;
reg     [TAP_WTH-1:0]           rd_level_shift_cnt;
reg     [BLANK_NUM_WTH-1:0]     pll_blank_cnt;
reg     [PHISE_TAPS-1:0]        dqs_dynmic_shift;
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
//Wire Define
wire    [TAP_WTH-1:0]           calibrate_1tmp;
wire    [TAP_WTH-1:0]           calibrate_2tmp;
wire    [TAP_WTH-1:0]           calibrate_3tmp;
wire                            case_1tmp;
wire                            case_2tmp;
wire                            case_3tmp;
wire    [TAP_WTH-1:0]           tap_cnt;  

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
IeuMJCnPOwiMgaJQWcaAMQJBtJG3xAgHpNBsXdVBMFV9xSDe27HQ0ypbBy6EcJ/Z
QjQvfcr5D75+fwad2r4CM4JbF4+n+00pJi4Ey0+D0VHp1Os7gS75peusMQC7ZyuM
dLL+k0afwm+Ud48rjvlQJpcfVsVkySUl/Iaqi+1sRJt6brZ4GyQPqwmwy8ybEBfM
XTzFuG1TVRchKlPfp1lnzUmDPj9ihvsDFJg9i5TWhCo9YaaqKk+6WivccQz0XfNx
/BYOvFc7QQxQ4zS916G8VSThlLFcY35cNDfY3s+xH3czJeQb9MvIw3jFnwN1AU02
3XJsMSKCI1qCs8m1Y85eQw==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
S9cVbu2coao60uOwSHkbDVEVrrrrBAXfTd8AjGxqqj2jEwdLLAtN32WskDQG9z9e
Nrs/NMyU1gccsSnm//suOty/YyNVN1a/KC5PfRx43W1gtEjxsWjP8FQgo82CsZMg
L4DlnnZhFBU/dGqyqB23r2VwDDwZtmKeM3XjRv+Bbdg=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=13728)
`pragma protect data_block
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
`pragma protect end_protected
endmodule
