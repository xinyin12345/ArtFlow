//***************************************************************/
//   ______   _   _   _                  _            _
//  |  ____| | | (_) | |                | |          | |
//  | |__    | |  _  | |_    ___   ___  | |_    ___  | | __
//  |  __|   | | | | | __|  / _ \ / __| | __|  / _ \ | |/ /
//  | |____  | | | | | |_  |  __/ \__ \ | |_  |  __/ |   <  
//  |______| |_| |_|  \__|  \___| |___/  \__|  \___| |_|\_\
//
// Moudel Name    : ddr_mpr_rdlvl.v
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
module ddr_mpr_rdlvl # (
parameter                       TCQ               = 100,
parameter                       DQS_CNT_WIDTH     = 3,
parameter                       CK_RATIO          = 4,
parameter                       DRAM_WIDTH        = 8,      // # of DQ per DQS
parameter                       DQ_WIDTH          = 64,
parameter                       DQS_WIDTH         = 2
)
(
input                           clk,
input                           rst,
input                           mpr_rdlvl_en,

input                           phy_rddata_valid,
input           [2*CK_RATIO*DQ_WIDTH-1:0]     
                                phy_rd_data,
output  reg                     mpr_rdlvl_dly

);
//Parameter Define

//Register Define
reg     [DRAM_WIDTH-1:0]        mux_rd_fall0_r;
reg     [DRAM_WIDTH-1:0]        mux_rd_fall1_r;
reg     [DRAM_WIDTH-1:0]        mux_rd_rise0_r;
reg     [DRAM_WIDTH-1:0]        mux_rd_rise1_r;
reg     [DRAM_WIDTH-1:0]        mux_rd_fall2_r;
reg     [DRAM_WIDTH-1:0]        mux_rd_fall3_r;
reg     [DRAM_WIDTH-1:0]        mux_rd_rise2_r;
reg     [DRAM_WIDTH-1:0]        mux_rd_rise3_r;
reg                             mpr_rd_rise0_prev_r;
reg                             mpr_rd_fall0_prev_r;
reg                             mpr_rd_rise1_prev_r;
reg                             mpr_rd_fall1_prev_r;
reg                             mpr_rd_rise2_prev_r;
reg                             mpr_rd_fall2_prev_r;
reg                             mpr_rd_rise3_prev_r;
reg                             mpr_rd_fall3_prev_r;
reg                             rd_active_r;
reg                             rd_active_r1;
reg                             rd_active_r2;
reg                             rd_active_r3;
reg                             rd_active_r4;
reg                             rd_active_r5;
reg     [3:0]                   mpr_rdlvl_cnt;
reg     [2:0]                   stable_idel_cnt;
reg                             inhibit_edge_detect_r;
reg                             idel_mpr_pat_detect_r;

//Wire Define   
wire    [DQ_WIDTH-1:0]          rd_data_rise0;
wire    [DQ_WIDTH-1:0]          rd_data_fall0;
wire    [DQ_WIDTH-1:0]          rd_data_rise1;
wire    [DQ_WIDTH-1:0]          rd_data_fall1;
wire    [DQ_WIDTH-1:0]          rd_data_rise2;
wire    [DQ_WIDTH-1:0]          rd_data_fall2;
wire    [DQ_WIDTH-1:0]          rd_data_rise3;
wire    [DQ_WIDTH-1:0]          rd_data_fall3;
wire    [DQS_CNT_WIDTH:0]       rd_mux_sel_r;

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
Hh6GZmfGPCPgXh6/M01kowWiwjYc6v1uzHSlxmcLlIsZnQ63LhKzzu+2VTQnLrzp
omR8NHPnIT24I7XNLpVmOljKikktYhDUQhvhh0mUu+pvAHgM17unDNc2chDMYHpM
uYNYsR2SEhlI88uNPN7bt7Hr8uMHi2y6Lp6Wa1wKpQyhbrobdFsKQXIAPdMxOMIR
DZMy79Z94G4PQfV1z4HFtAOTULMS0OStXOOvWDfRefHwH6nn0HNhMB1DoURsn4E9
MoZ+Du+FFUzyukoHEKPswVrv+V6djofhWwI6RhO2Dra3eaiX+YkJkGtix9NfoqSM
HFHcPb5Gkt1yhFmCoc1+1w==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
C6lqTkaDqQ1Q+VdxvNl5dDErge4yXw5J0/1luh3QdVTt0c7R64Uy68uNuTGBBIUe
n+8hNeJuWbSRbMsEidLCfTmDHr+W730Yp4oerJGrJuW6Bctll6EJNe0QN/XLK8z3
TRj1xaczcazSUecIBBcXhbTZjZqfqGyQhZo8gGYEDuA=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=9408)
`pragma protect data_block
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
`pragma protect end_protected
endmodule
