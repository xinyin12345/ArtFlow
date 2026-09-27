//***************************************************************/
//   ______   _   _   _                  _            _
//  |  ____| | | (_) | |                | |          | |
//  | |__    | |  _  | |_    ___   ___  | |_    ___  | | __
//  |  __|   | | | | | __|  / _ \ / __| | __|  / _ \ | |/ /
//  | |____  | | | | | |_  |  __/ \__ \ | |_  |  __/ |   <  
//  |______| |_| |_|  \__|  \___| |___/  \__|  \___| |_|\_\
//
// Moudel Name    : phy_ctl.v
// Version        : 1.2
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
`timescale 1 ps / 1 ps

module phy_ctl # (

parameter                       DEBUG_WIDTH     = 25,
parameter                       TCQ             = 100,     
parameter                       AL              = "0",     
parameter                       BANK_WIDTH      = 3,       
parameter                       BURST_MODE      = "8",     
parameter                       CK_WIDTH        = 1,       
parameter                       CL              = 5,
parameter                       COL_WIDTH       = 12,      
parameter                       CS_WIDTH        = 1,       
parameter                       CKE_WIDTH       = 1,       
parameter                       CWL             = 5,
parameter                       DM_WIDTH        = 8,       
parameter                       DQ_WIDTH        = 64,      
parameter                       DQS_CNT_WIDTH   = 3,       
parameter                       DQS_WIDTH       = 8,       
parameter                       DRAM_WIDTH      = 8,       
parameter                       RX_CLK_SEL        = 5'b00100, //rx_cal_clk  PLL out sel
parameter                       TX_CLK_SEL        = 5'b01000, //tx_cal_clk  PLL out sel
parameter                       TX_CLK_90EDGE_SEL = 5'b00001, //tx_cal_clk_90edge  PLL out sel
parameter                       CK_RATIO        = 4,       
parameter                       RANK_RATIO      = 1,       
parameter                       RTT_NOM         = "60",    
parameter                       RTT_WR          = "120",   
parameter                       tCK             = 2500,    
parameter                       tRFC            = 110000,  
parameter                       tREFI           = 7800000, 
parameter                       RANKS           = 4,
parameter                       ODT_WIDTH       = 1,
parameter                       ROW_WIDTH       = 16      
)
(
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
// PLL status flags  
output  reg [2:0]               pll_shift,  
output  reg [4:0]               pll_shift_sel,
output                          pll_shift_ena,   
// debug port 
output      [2:0]               rdlvl_shift, 
output      [2:0]               wrlvl_shift, 
output      [DEBUG_WIDTH-1:0]   ddr_phy_debug, 
output                          phy_mc_ctl_full,
output                          phy_mc_cmd_full,
output                          phy_mc_data_full,
output                          init_calib_complete,
output                          phy_rddata_valid,
output      [2*CK_RATIO*DQ_WIDTH-1:0]           
                                phy_rd_data,
input       [CK_RATIO-1:0]      mc_ras_n,
input       [CK_RATIO-1:0]      mc_cas_n,
input       [CK_RATIO-1:0]      mc_we_n,
input       [CK_RATIO*ROW_WIDTH-1:0]             
                                mc_address,
input       [CK_RATIO*BANK_WIDTH-1:0]            
                                mc_bank,
input       [CS_WIDTH*RANK_RATIO*CK_RATIO-1:0] 
                                mc_cs_n,
input                           mc_reset_n,
input       [1:0]               mc_odt,
input       [CK_RATIO*CKE_WIDTH-1:0]      
                                mc_cke,

input       [3:0]               mc_aux_out0,
input       [3:0]               mc_aux_out1,
input                           mc_cmd_wren,
input                           mc_ctl_wren,
input       [2:0]               mc_cmd,
input       [1:0]               mc_cas_slot,
input       [5:0]               mc_data_offset,
input       [5:0]               mc_data_offset_1,
input       [5:0]               mc_data_offset_2,
input       [1:0]               mc_rank_cnt,
input                           mc_wrdata_en,
input       [2*CK_RATIO*DQ_WIDTH-1:0]     
                                mc_wrdata,
input       [2*CK_RATIO*(DQ_WIDTH/8)-1:0] 
                                mc_wrdata_mask,
// DDR bus signals
output                          ddr3_ck_hi,
output                          ddr3_ck_lo,
output      [CKE_WIDTH-1:0]     ddr3_cke,
output                          ddr3_reset_n,
output      [CS_WIDTH*RANK_RATIO-1:0]
                                ddr3_cs_n,
output                          ddr3_ras_n,
output                          ddr3_cas_n,
output                          ddr3_we_n,
output      [BANK_WIDTH-1:0]    ddr3_ba,
output      [ROW_WIDTH-1:0]     ddr3_addr,

output                          ddr3_dqs_oe,
output                          ddr3_dq_oe,
input       [DQS_WIDTH-1:0]     ddr3_dqs_in_hi,
input       [DQS_WIDTH-1:0]     ddr3_dqs_in_lo,
input       [DQ_WIDTH-1:0]      ddr3_dq_in_hi,
input       [DQ_WIDTH-1:0]      ddr3_dq_in_lo,
        
output      [DQS_WIDTH-1:0]     ddr3_dqs_out_hi,
output      [DQS_WIDTH-1:0]     ddr3_dqs_out_lo,
output      [DQ_WIDTH-1:0]      ddr3_dq_out_hi,
output      [DQ_WIDTH-1:0]      ddr3_dq_out_lo,
output      [DM_WIDTH-1:0]      ddr3_dm_hi,
output      [DM_WIDTH-1:0]      ddr3_dm_lo,
output      [ODT_WIDTH-1:0]     ddr3_odt  
  
  );
//Parameter Define
localparam              CLK_PERIOD = tCK * CK_RATIO;

//Register Define

//Wire Define 
wire    [2*CK_RATIO*DQ_WIDTH-1:0]phy_wrdata;
wire    [CK_RATIO*ROW_WIDTH-1:0] phy_address;
wire    [CK_RATIO*BANK_WIDTH-1:0]phy_bank;
wire    [CS_WIDTH*RANK_RATIO*CK_RATIO-1:0] 
                                phy_cs_n;
wire    [CK_RATIO-1:0]          phy_ras_n;
wire    [CK_RATIO-1:0]          phy_cas_n;
wire    [CK_RATIO-1:0]          phy_we_n;
wire                            phy_reset_n;
wire    [3:0]                   calib_aux_out;
wire    [CK_RATIO-1:0]          calib_cke;
wire    [1:0]                   calib_odt;
wire                            write_calib;
wire                            wl_sm_start;
wire                            wl_sm_start_dly;
wire                            calib_ctl_wren;
wire                            calib_cmd_wren;
wire                            calib_wrdata_en;
wire    [2:0]                   calib_cmd;
wire    [1:0]                   calib_seq;
wire    [5:0]                   calib_data_offset_0;
wire    [5:0]                   calib_data_offset_1;
wire    [5:0]                   calib_data_offset_2;
wire    [1:0]                   calib_rank_cnt;
wire    [1:0]                   calib_cas_slot;
wire    [CK_RATIO*ROW_WIDTH-1:0]mux_address;
wire    [3:0]                   mux_aux_out;
wire    [3:0]                   aux_out_map;
wire    [CK_RATIO*BANK_WIDTH-1:0]
                                mux_bank;
wire    [2:0]                   mux_cmd;
wire                            mux_cmd_wren;
wire    [CS_WIDTH*RANK_RATIO*CK_RATIO-1:0]   
                                mux_cs_n;
wire                            mux_ctl_wren;
wire    [1:0]                   mux_cas_slot;
wire    [5:0]                   mux_data_offset;
wire    [5:0]                   mux_data_offset_1;
wire    [5:0]                   mux_data_offset_2;
wire    [CK_RATIO-1:0]          mux_ras_n;
wire    [CK_RATIO-1:0]          mux_cas_n;
wire    [1:0]                   mux_rank_cnt;
wire                            mux_reset_n;
wire    [CK_RATIO-1:0]          mux_we_n;
wire    [2*CK_RATIO*DQ_WIDTH-1:0]              
                                mux_wrdata;
wire    [2*CK_RATIO*(DQ_WIDTH/8)-1:0]          
                                mux_wrdata_mask;
wire                            mux_wrdata_en;
wire    [CK_RATIO-1:0]          mux_cke ;
wire    [1:0]                   mux_odt ;  
    
wire                            dqs_locked_start;
wire                            dqs_locked_done;
wire                            rdlvl_all_dqs_done;
wire    [1:0]                   dqs_bit_sample_err;
wire                            rdlvl_dqs_check_ena;
wire    [DQS_WIDTH-1:0]         wrlvl_dqs_hi;
wire    [DQS_WIDTH-1:0]         wrlvl_dqs_lo;
wire    [DQS_WIDTH-1:0]         ddr_dqs_out_hi;
wire    [DQS_WIDTH-1:0]         ddr_dqs_out_lo;
wire                            wr_level_start;  
wire                            wrlvl_dqs_oe;  
wire                            calib_dq_oe;  
wire                            calib_dqs_oe;  
wire                            wr_level_done;  
wire                            wrlvl_rank_done; 
wire                            wr_level_delay; 
wire                            dqs_invert; 
wire                            dq_check_en; 
wire                            dq_bit_sample_ok; 
wire                            rdlvl_dqs_shift_ena;
wire                            wrlvl_shift_ena;
wire    [2:0]                   rdlvl_dqs_phise_shift;
wire    [2:0]                   wrlvl_phise_shift;
wire    [DM_WIDTH-1:0]          ddr_dm_hi;
wire    [DM_WIDTH-1:0]          ddr_dm_lo;
wire                            phy_rddata_valid_w;
wire    [2*CK_RATIO*DQ_WIDTH-1:0]              
                                phy_rd_data_w;
wire                            mpr_rddata_valid;
wire    [2*CK_RATIO*DQ_WIDTH-1:0]              
                                mpr_rd_data;
wire                            wrcal_rddata_valid;
wire    [2*CK_RATIO*DQ_WIDTH-1:0]
                                wrcal_rd_data;
wire                            mpr_rdlvl_dly;
wire                            idelay_ld;
wire                            wrcal_resume;
wire                            wrcal_pat_resume;
wire    [31:0]                  phy_ctl_wd;  
wire                            phy_dqs_oe;
wire                            phy_dq_oe;
wire                            phy_ctl_full;
wire                            phy_cmd_full;
wire                            phy_data_full;
wire    [2:0]                   shift;  
wire    [4:0]                   shift_sel;
wire                            shift_ena; 
wire                            phy_rst; 
wire    [6:0]                   init_cur_state;
wire    [7:0]                   rd_level_dqs_check;
wire    [7:0]                   wrlvl_dq_check;
reg                             pll_shift_wl_sel;
wire    [16-1:0]                debug_fifo;
wire    [16-1:0]                overflow_fifo;
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
UHerAjCQAfq1CbY4nVURP9fAMOj2iGcREABC52h0ELPAHJuhpnJAId65IWe6X7Mc
+uwUz3D8T5vQwsYSQVApLNihhELGbb9dH6D0GVE3DNa7D8CrBVPuewnyQEhnf1cB
JWdbiU3QiYstGBR22e4u5Cipk4u7Spyv7OO+PC/phjg4snk0dkrHme5/1Iv13jrH
hNkJMay1wWr4aFOdD72SfX5mkrCY+U9bEkrizLNvuWt46teyCNqLZWAc+1YVhy42
+SE3DmAKxm4mf6gwJ2lzYSlo78iMpxMfCJcSUAolakcBwK3qK+LUDIeQTocQE55S
BxiBF46eS6OrxRhqdhzDOw==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
NG3YLhzsz0phO4XXhh+qqbPOg8zVUeQrigLF3R4vsLJYk4ZsXRsUVB02XaOCDbcR
ZlqHMY4W8/6F1L3tnHE4VOHbkQAD1u9r5xaKVyZO4A6zwO14OMWOuUgCC2K7iSl/
HtzCMwdogsgYm6KEf7rgb1ND3SLPxC5x5rC5XO85pro=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=22672)
`pragma protect data_block
rG0guJTQRfRObL/5KmFa6/crvzd8CrUz7Nsqa6sVZj5warRxKCwJZ/8sJoIkzMQs
ckUGctfjUZYmc0LhVRHNg7rnql4p7qwaAZOPm3MHym0OEZIsFIcYovcf1FXgM0mt
i8Riu8t85vOrrUCLaMNmNYfQS0hI25kCZ9oVH7NQEs2jyt4dIj0IauFUfINGVwap
DWIhTPUR0o7/3xM0xn7XgA7imKtNldfb5d4MIDljqUh5X8DFj4eKtRQxOlh4rP7M
xYZTLxIzGv1F1/oDDNwacuh11Q7BjNUidZeGAKzlnCL/faD/UGLvjMA+SYxQeoJk
bWZ3VC6OVjiODDo8Ky05Ocfq2tR68orH3+SSKjZWoJhALONV0TTHunm85Z9WIw14
ptHujfQiNRDgJdXcaAZhwWTpPi6TBnYvG45TG3Y4E0E7pSE3j2FP5F1d7JTAxA9s
ozM/nW5QF/loleyPexdI0E4somx3BTSEOlZ+kkCCxFB6l1DzQK2sD//gMSdXbziO
5dytAYalfOA3VyyP2mWCtlyVUVDyjNH71/G5UQnTUXFdUeI3Re8TUtH43acXXTu+
iyIBzgEE0M5jhlj5SUhCbQrV+iVhD2dHL0zAEr6OIix5/53p4CWgJivYSN8TSngC
o96b349urh3TniC5lDaq10I00VsB/xfy8pu3yolbRIqmmvNiKYNB1cT1RSzspLNm
qI8uIsbh3Nm93yfZadMvdE/7c5dbNjcMAQ6/MDf303m8oY6xmCjkZPB+3d7KnNF4
2/zAncI9+q4aCaohvIwS+TIy+qzeQ0R+/JPgiFfcsjazaKN58mflZq7ZcZIuCsNa
JBrKMQPwlu9SwkmgYT1hLhPFTRgm2V1YMtF3VhGTi7FO0a3b0sm5MR1EZ9+svRkk
Qi0ujx9jTyC6K0aIPyJGrw7eyW1F4U1JBxhTDFo6JyrzkcduvZd+h/k7SgpNYIok
cvIpqfwVD0Z8cXj/N5LH7cPdNFg96sagJteuFIO+xaYzR/D0uNyH7wpLqrIaL74i
3ajPNDxYL5hggNX62ranrLwHSoNlGmzfp2oX6VGQgbeW5Fp9EwvQNaEZg7dm/uVm
rQ9YdjuqsQqdBnEFDoISW7NtMKR5/W4H7IdXnhoTxHIB99sUV/ptN3381CEv1gjV
dTrovcmxNImuivh/r1AKEHHtEEWwceirnDwRe/ffFLr1WtOhixi0m090LuSCJT4c
Doaea9rj+AXdYMNNXcjwcs8oPtl26oWeO8TddFcqJQtVitQkZfa4DoysrkPgvkp1
YlOH3armYSP8spHH+yKC1Arg32gHZQkeSNbxPxIAXg8Aj5CcLM/yqo+9wlTmY6y9
f7rlMRtTNH5hWHfW8OOzY9oqIt3WiwFGlMMIyh00JkP6I4Ry86AHFjqgB1bcTkQU
Pgn1fhJ0To0NyURn6JkT6jXaF+Hj+NQU4QMMLoJoUqNsyPp8L/dXlkeRW2V0LWG+
zru57aPuDr+CdhwHbhXlivGpZga+nlvvLuMieNX/RbZWRSTwVE/w1JJfh3Ih+9mQ
HXyjONhgKm6WjxXP0St1wEjv7gycgOjOoZR726OCeA2LJ0WyodaJw83CqZ9NnXRz
OBc1G0Mhjo3XpB7B1Q7G7A34UaIer7abtSVzY6SXZfFoFuZVYdIMYqNBlK6LxKf8
6rNuluc3/6lRlJAB7zmXk65jKUWyua9Ne4U2g0iUrMQ3B1J7OX48czJgw+QSttzy
Njj6VW4xfTkpikosDgtlQabEEG1boWtsfu5OP3zS6TCKZEAY764qGAppn6SPtzlb
0u30IrykW1Tyt+bfTtLM6tokmD+M9qceHP4tOaD1qLt58m8K9WQwZd/2UzhtldVc
s/cmGybICjg4AGiTKM3FnAIOsFhCoodoyuCrqeNHJI4uK2aeJCVdyS8KRZ4htFLA
kdaebl7nzdpsKrGP/M+RZYLjRQ8lTcuZrTY6y99pIeYtBXRwdQXYtP9uOR1vsk7d
iPfJP/cO9J4bFKc2RHSq1Qqtq0q1+x6QinEtVR5qXBMeE3ozKU8tLjY1jAulmvEa
KSIxQL3mhpPwGauO23mEfYrUZIVLQSeznlP9NbYMw1TedYZP1eNEBwKUBkZqy+j7
xIJSMlHia7Yn4HVCs/NRcIRzB2x5867X/XPhCTyvjtyXMUrU60LZaW76gDTFUUMn
/7pTlQ6qfs1nAnvM6RVH+A6F/7yUBkihse3ia2c0kziink+M7XIC6aLrMzNE8eZS
pl0o7IrhQDo7fQtr2QPFi3vFrFQ1mEnk5ZpFfvcmOE7i6PPCfBgkp5U52mP6ia7d
KX1pBgHGAMQ4k4SHYB9BiKWcyAWnhTPtTcGynAdWIxruVpj8NFz/bVu/VRW/jTci
99tbajiqSC3YH610zli5DPg1q2kYa8FUZx63vt2zV7fTzNzJ8QLoicsWCo02O7j3
awzE/U3NPpTV9COBxbNnM5ZDA7EOwLK7xpn87mdQp56Xrovgbm01Bz8sI0rzjMn8
TAxn9S1CbXoIti41Xc9JMwdRLmm7HHOuJLecc4ZQ0TY99RNlsSk9IoyuygslT/pL
UJMrLi1HXlAeJSFpTnv/Rz9OXhwStFKZL7BHS+b+3dLw4fbhYXJH7+CHZd6GyezU
CEaSoo9WCLnKARYv4L617SRNdI/6anM5DNioUH8xilvP7xfNp13FpTfTaCPTwdtT
uBZJAGP84utzX8HvKSzwgzViQ6Lkey7VIwvyOT4kuv74JN4Eib2UdgvphepBLNPf
kozOu3aVk+T+zuxD6i696iKQKbpzye52Ubtu/GpSFI5Zwdr+WfLGO2zhxBHYPfAS
zldM1fKUC7WTmDfIzp8QoFTkZ6RTpZLmP0lP4MCSJCuRomN+NF7OnUAu21kMboJa
/JoIqmRekNL/Jr7LYa3bpvKNYjodmMziCJoVIrxwZHSlStW3W/oj+YOUIoWqLi3G
MpPwbwIrTO0lc24RepijskXCn3EQTKR4yEugfdLYEelmeuUwNgnpEtQjWelr4IN5
5Qdo2BucGFdk0ElrhcORKyEvZ7D9qCoSZyST/vAVrGXEaELmrwmXzR/Yt0yV9Xpj
huQaQbMlj6tE4rBdAj+Ok9EzO9pEBzkBw5mCbTcK2aIk2qa8Z+5t7CgFZzxtfKIz
LKXZC38m49dk9mdc5iX4079cmYtHFfp7xaJgGbO9Q8yK+TzduYuliWLnTQS+GjLv
tQ1xgPZSg/Fmg8XO7Wwlj7HL/5l/qy7U71QX8xJfjFg2ra1n8F9BUckKpOEEwspW
e8x5eR95VrJfcmmjMJ+qqLKZ6+u+ppkUx66265zKt8RYK7kY7wHYWdNS4wREhhUf
rLDxdWMPJNpKEHlt0wdQHiFD9Gjtal9bxp1v1JFuPl0nMs0tCMD3l6pR/kuWpNzO
TRlOZy4iKfi7xRXSooT4QZddBqiTLbWZhh1/YTMWfwGkxungjig7zoc4iEbBhJkI
HDbOerdCImbAKMPy7ocIUrXjTKxdjNlMQf42zsoBa+NvsN3QVZ/vDbwHZrHJViLy
u4dU4EGEKqK1aw0G/JnX6JsSat/si0Fciw4EUVqQumWq7mS4Jhrk4c+4LMfX1Llh
iokDdHz5TlTd9A3T1JCslP0kkLwkeIj8NSieu8qGgJ2is3q/i1+KVZGy0kBAXRtx
qQb+E7BuRpD5g5jncYeqqAcRM7cHiNLa5zY7ndEyji/BM/LAyB2oJO9tsiChk2UM
3O7fSTkhi2T1sIfLK3VCKMlxFm3HSWV/0PtUjplcpMROSbuYOr9ILqfE8Cqr4Zqn
YsczDp+dkKkjGoITiE24xaUK6uxTm5evaUMMKA8MeGG0eTG26qGGb0svMX6hlcLe
1FBrLcdqSc0fwy4Y2SqjmOlGbONf2yoR4RRvlG69HRR5PN9BsUQU+Mk7UUuXEgjg
ofliP0y9OncA8Enrc4WwVQ3Rb0L7TWcnDH4TZiS/fEr51lhTx+HxSN/SrRCivB7r
vlWKmov9gFOqWgj/01AyZasvqe4F8a88UDo4v8dRrMH8zRDChtkZ+LAE53ImAue9
MdVt3jdGWmwMfVj1l8Wi11OJYabhKhwLZhSBIxlD/Gb2Zkee7u2Bl/Iqp6aMVVtg
AJdKm203sbD1tMURPHdTZcBsn/f7EWKtQe5UnDu1Z4x6LZqUjYycTwcr5vmqkOTj
oq5/Z1FANbeRam3mBgxdjx8NIOiIZG7yttcAeV5orO47ElJK3FGyrWB+nuflbOqB
i8+2uKNodcu+jRjLN0VV23mBw8M2WXrbbTJtFqsnAsRRu0Ogl5hpjwVudzfMXqt4
hzIMfsFJvEN6/AXTlx9rbLvzE4ce+COv7OsuCqaqSQK5gWaDSPW3QsJXe2POPrSW
t8gYynPXO0dZcKgMifxOj18iDtzGNZBUlC80xEAtPWXMa1F4PQKsT+Nr8wup6lPf
zKBfrbCmKquhIZQHjst1yIBj7U0bZfK9/+HAqOsqYvULm1fM2/9hN/raIMJgTA4h
gjrLd7M4sEZnqwsOb064Iq3g2dq9u7SHNxbXO8UNobhkEtW4NTbWTjZBHzUJElv6
hyuM4mZKhWYNl8H0dY8qKc3V3O0ldh8zu1nlUmXIkr4/s3uk23sRzPz36H3wp75f
Wf2XOLdR56Qvlcycu5y/+JavBSVdGaz1fRg9KT/V8O+PJ0G3rFuSv+DIhEY4jNLe
/EqjXWfC/hKUF4KXBKOo2pmK0yvqGQxVY/l8zzYpgdqzpRkbM5W/78rKwR0JVoBj
8SScpbM6bsIIFhZr72X2zlVSl4jdrH1TAPsQItiMHgNUmX1+6tGEFp67hWPznYNJ
FhE8b65gXdb0VFkLG5nEW7uMKoqwCaH8kz4VibD74WyZ11A2jAFYdAM3DdkS0FDP
1t35z1EF10aSBM11LK5Awmt7QEkVzwmieyaKwBXpi9IK6ts0agEeFXn78z4thGDc
agCcCC6moGGyN1QU7bspIFiy6YYMbAzWSx+tteefftVxtOUqsBGi/kBgKt7aGdQP
CnCb5CfmLQj5q2Q3hoi9xxPderYToh06petIWdJM44esWIFYRkPu0rxVYS8pSCa+
Xegsa92gK+D+w6A3LGHZhhNRyGJ4bD8xlsYvLx/pJnj8GpJBezLZoZIGsbtw1G6I
fkB0bDHgvxchQQgfkCs0jmP+X2CcR3wTqsDtlguVRTGkbBiz1i0lvd7C9iBG1Q+f
4LBBhUgXj0EyA/aUlOTUEksbjpNY6RvusyV8xprOLkG08Vi7FEJo8Uc0DNqkNnAA
JnpyQyE3pCCMDZfaJJf3BMJQEHPtNXYo/Wm/Y3bGXsgntHP9T9NotpLN/IbAbyTr
4+WyatA9iMN39vWXU6/9aZknvmruIBZsHW8ViasRcWInA2acAbSti7dUXixUeMbR
NlzPCCUW23qKr9hvFP3zo2ovRVJPiShy9LCvYQil9+fUDr4JHMNFVmBbQFb52rMN
PqkBLOqcY3e+c43+D3VbS9KHPCxhK0HzlVUXAa9Or4BU8UHgpC9iOpc3BWg1WIcb
5SHcopiO9MC2h0OyD39a1Ih9VR0tJCL/4rYK54OTlmrexDekS/1Mnw3M0X/JSkW3
6x3BYhwOVR20oDxHIe8swp+ACNtRxh2brU7KmHNnwI+XWjUhE9hcsPo7S3ItBuej
KbdBzdqUOdTtz2VC627y5qG8PnmF55FPkUsJ309hFeklQFmal6gYw79zJ4a8IljX
hF+gtCFbmLpK+BtwpBqhl/DPw2Q/nEcc8rub3FIyRpwMfxKCAZeoPe8jXiFX4KXj
JvkOGgGiaQC48qlHNRf/GbIT/xWC35T4OwmAHnPTP6aRlgz5m8Q3IU9uKxtPaApk
MymRvxH6TAHcfiXPK/ppkhwqeMpYCnH8IvGaQrwnFDEQN/Vi/RnQdZQgiXnma3JC
6yAicrdKIUDja3PP96dXmttIRKywCD+HVejL9voKWRkzIfpE6fYkVl4K7ZZOoRLl
LEU8J6N+iMB7ka70aLhtvBbBlYLSxEAIKGGWXlpKWdl51Hb8xEyjkh8UL7Wq7MKJ
WHS9qGdVeLDabGBDD0/9/I6fCI0yNVlU5uk56FAWyCJUtTEhZ6qicSoMC0txO4Wp
d1iH9UOG4nCpDVgyAL/xsbCTz7gmUNdT2rdvFpDiBiOLaA1oBlXHecKd41Y068DF
ahZGmr9r+VxtMpl5u1oM4opS1gDrAINC0hJdkhZ/BicZACh+RlAFFqduOKNw4fJQ
wDPl8hSl3I4bTAPsRcEoW3yGoPD0cJnaHVXZT9Uz6KZp4JfeiA75r+zz+ukmixGe
X+0jyxDt36OSxsohh/BGCzE5XhyM8Ln5CcL4CpjVR+5fFkYnaWDqKiE1xmTenR77
o+6O+GIkWXHpX1xppNv7oSMqSnou0D7TTsqxE85BVwkVPr9WCeXmA7zhsMWHOqro
frYpa2SjdVBlwZYG+bKYvcLn6ZEEyKOmdg6vZOB0CLhfUOnif23SldAB6+hKhxLo
p1LiKo0ITZgW6ClenrdX4TUSV8lTow4u5Tz+F4H57NtTuNhpP7fmOKxHjaxIqu09
e5E4e3xlBmuWRkhSOjuZqXpv2adIJwNHj7o4FB0CYB7l8+Z6htiR8OP0VKcqwAzQ
bgdLgkY3mZ1YIT/koRzx5UvbG1wIYIFBRps1syCJR7f07NGNOqsdRsYtbyuNfavW
8RuRRhV40rAmuy8ZgF5wJA8SRkEA7tQG4cmMkD4IxLxh67mp2aC2SNkRBgHuQ9g9
6kqB9x5R1vlzBm+E7vw1duPea+2V+3rAQYFmTF1qONQR6msmDsZIXvP07upzhKyz
gDA/lggBzkiSGfm/k17GgQN4WHY1g5QP0Oglp7cnb0IExZF5WdPeGjuAqbkrC/PC
BDbc4AeUW6ejwEbJe9LD6xSt/PyFW7DZ/9pSS4YWftxjcGswweiYbpzDPdsvN1Le
dU/BACxAu4HxQr/1rLN+5Ufezcy/DaWhwBOlbemsGrZOTwR+EGBWjw2EBa3h6t/p
62GXndV5xaAezeMUNmI4uM9z8XDRrPoYxcCNivjUGv61oWDqpSsbcwvQA483qL7r
2WqKxazZKud7qa8XqR+FgH0UBisM+0SYTGSCdJel3BbHlBg64bn5nd539JsJxQeB
X12+iDinX35jYGh0nobTdkGEzCo6dMH0OYjgNEYohspinutaXxDRXrkrxpEoTmRu
EdQhwFrxx6j0TwcneEOdd3xYE0hXuozE8OXgGB7p1n6XknQJLJbWoH8DnIt9BNlE
yoDxlY1R07ergP1+vsmVO4TOF8Xe29t9JD83ZHXs4FM6X4ubXPv9tvf9aKeOGN83
psTrCjub9UrqxvI8kARZi32ksn8yMy/jPI3FZV+fUQQsDdA+P24YI/12SJ4X7CdI
Wy+czu8ywTE3tM7gmQWzaWBVjbf1+LwrriFZ8a3eJZ5A/0/R4gyMzALZcyRSK44s
GrZ9IuBaxakAHeqQ0Q+B7G46ezzm/TjXxC0ZeFdHn7Hs0DyfOLmHKKw4biJC6Gl5
qbhGUZ4QLrOXbTHaVDsUfKByuJwiQpZMN/Hrq49htipwlCDXQbMxg9Y3dwGcqs92
C+RHnMwg8fyXsuAopKrdBWsoAWwTbB0+emzCCBsn+1UogNLFEAzWUDjnPKEPxscM
0Xx/zM9XEv1lPzqIJvJ8vQT5mk3ZCXXLXdMUm3FXCMRm/YtPD7uS7mZJwHzoy0UJ
v6gH8zIqfIQwu3zGoomnxnQ3S9IjNTPtLcPKPdEN4jdfnI/Xi98nEnCbds9/pPUB
B45NhEZB4fV27J+m8G9aQH1IckvBvDU8T7u9HQllrSmr0iJU2cyY1BmcxF98wMoI
senxq3Jd6dyVrV8piSXBzkZqxs/SDI1vC6384Z2gjdU6EvLRf8Xu1nZTJoDKg+qt
uKxTMBL3YWidT2yXxZ6qNyEwFBjib8Un2+1Wl/e+u7aeBTYsXs65MYC20kt9FgQ6
Zd+851sNIl68G98QJ/lzfeRUJ8e9j2ar6mMdnZEoB8NtBJm8ZzJEcojYoj7JMY95
02c+slmKbUorU/EaIJVE5KeXQpzuWIUWauGOGGunLF0BUL4BymOe0VCTjWbBVOTG
mYMfwYJBetHyNiIpFgNDKi6Bzed7hZTw4T2EIFZbH/MTRDm5C0i6aWHpQNjMn0nm
misnGXRDnbjGaeTWuiU+1nQvn4M9VA5y+ltbvIujb0Ua/A5OZ6dZIo4jaUyP1F/M
xg4v6xqhHq7golwyZp4ehWRuHc5R8/bxeVKVMCPoK1gtnat5mSi8mxx5Ps0+dHGd
1BMAKUu8MJ7AgA4i2Eqpx3i1lgijUMqG5Z1i+6JVqMwMko0PNOEfuiSp832lTVdt
HdcESqz67xnoSPiudQaBpaO+LQ1Dpgx5Bllne0UhVmORleF16CQMt/UgUYkMJLHT
F5K9xDdubWlnAJaiuG0XH+uHxr77CA8abE80TkDAO/mO0XxoHOVI4Y8tYxlR80cB
ztSUsXg4sTl0FCDW78cV/x98IliZZ5BOdIUQlA5FaslxfKTRO/6azPGwjwV3vEbW
hE3hxDzCrpDHplhljNN9qgTngbAwXoBkDww3NAz83SAlDN1iBytFziI2EK2eucSH
MP0IyCqjqPZctssncMrP+NpTqfJVnYFZM3tp8sgbU8Wci5iHx5sV4WntNYFrwOEQ
odjQPLjBxie2yac1vCAaPEaTem91wvyBTrvVxpG/N+VD1N8JYf/+fBa00UMQH7dO
H8YSKT+WzI1UUlG5GYfhpeGMpj3oOS32ctJqi9X12YJ6nIofKppliCRC1dRxnFU9
VdUWG0T0RGhMRT2ylA03QNZfta5k+lFxUvv4geUQHgswOb1FQnOw4Cr1JNoPzZK+
WWWnHfsNKv1vxBlILKQ71muOmLNFj4L7FNOa9ubyJbT0UKJWpCjGOc9rkDEW72ja
yPfvMlzWnXaKyQFGxVh8qWsr19I8Zy7MNJKHNbnfijh1EIyv5+WkCwAQ2HQO6fQA
NuXdSSirYIEKRZB6TOIvYRIFlxKm9Q31uN5dFhr/HfUJG4n0mE6vDkpiSkNyw8wp
N1u6C/brIFKz8MrrDySG1if+UP54tUgHvcTCLv8y/jNjGjRjy9qofJMOxr/Y9izV
JwWV9F1UTJayqf1VPHknCs+iYB02/nohGtFeIdvU8oJWT9MqGT3VY7Q6yVI8pVWw
HyzJkfPspbYX8nhUPdTTZStLQEyeZdjYCCSGch9zfY5iGlDOOkICoeDld6m+7gZe
xhiscpHFzl/z8uSsVbS0FByNNSnB40NXzKciexhxUnMFHJA6jSPp71cXjXYZ6Dg/
XEfAEqqk3b+h10PfrzhA+2mqC7F8Qnhtf/O2DlckpOy7xk6nCFYaQWZIySF7SbOK
hq6SLdWKkPlrs7swkwrID6MAUUEaVRH1UY3L46e0Io0f9SXN+VoR+7iYCGBVNOe2
YOc/maEoU6wG5M3xYkBSlDjjkO/syZehyK83gm1jWwnt5YKRUa1Q+nIIvoSzLz9Y
Awknk0X8HC1uBoZxT/9r18E5WHth3GSaT8jmZw2686njZAoUJBOcE/s081RznBNi
0j7mxuKA7WvlaZRYbLuUmbDXbsYG3RIZ3437AJqGpAxwH6dyQPdeUjNEuEKKlZsD
8w5Y43bc1+jc5GmLUe3xb/eS6w61xurjKcl9kUnsgNaiy4CVjUe2OX5alb/CMXnj
jnYvPb4o6KayfGLgzdB7qgBmoJTgfFOQyJ+cE4VQ+bUKyTEaJsBqAjPmP2JauARE
tz9/FKZuLAFuTymUu2awQpxYXP3raQNWDI1guYHVbXQST0IrLhjJ/7TKoERfmrW4
FYXdg5FU57as59SRIg9BKkmM6E/+jRYAPsxXjeQbZZdAMLYEfloxV1OU2dj1GX9V
Eux6gZ9AvtF2Gi4Jch70fiWjYwJrKfhq9/oM+XQnw3DsvqM6MK8KGrP285UCacj2
VmWgIImLWraPyF3H6O6hLS8+S1GxJhRa0XEpfFUnyEduddUIl76uajst18BjT+8T
cT42B4FKKgxx1US2uOnlpTO5QMXzLdajed++9hbWWpqKvXCyGos3/o8T8HjNf7ji
IvT1hPtG7M1dMATfplJPhgrZdaLOei612kpuD86d10e944nKw13VekWhC7LLaLw8
rqrJRTOHxy0JKgsHNW0Dl26nRw6Zf/GVA2HCBwxcwYhycU/uZSaiKr2Ag/KmYY8J
ry6no+aVs8PZB5l6/oBRqvM6rhmdeEm6/ZSOZL2wCO8qUvCJQjeu19NLzT2kbRHV
19PEPHgQKdCViVEis0uwyveNYPzHSvha30hXrCq1Qoqr12TdRZAhnreUfr7bMVL7
QOiYfCe+WDp9qSjc5TXhDdyXygRzxVGVO/fZqyjHfYg+kkZEJlgyxGjFQDcKit61
qiA+KLVAUehMNT8fXX4DWlrFgZlWbk8LJuEjo1dFpf+kAOlpUSBCV/RLqR95hxYR
BbfhptWeZ6XP2uOzgELLYMdId2js6mOvA9GUmcEtHt9Bv0JK1iRlIDZDKyS4rAEf
EnPSRwbODJz8NvmgT0SIT9db4eihn6YqXh1xAwszqx3N1bIwIVb+Xm44arv4S01z
nUjlqspx68nPnau03ATFDl/RiZNuQdyyBrifle9o8BMvdNRKt/xlM6gfn1f4dqh3
Tl1D60fCeTj/5WEZi9lU5NR3/NgjbNbG819szMEFmwwZwkOyc57Xt4aqa5YVSg4n
nQdocPwvcf3fgR2R7NY4gKfzDknbJ/LQU7xp/Muw6jpt+YiV4OltxhwBGsQBl38S
yQPgDNIyke0WiKIZjx2KqXnh3uBHlJyPREdu2LX5zp915FKz7cEIf/rsuRa6mUzD
z0mYlqbEGYMu+6I+fpgW19uK7EmWFap0Lsh6+EPJ7LLVqj9JcGGZPuFRH66He+cm
CSz7mrdAxdV0YQCJ0kAdAUg1I3x0oVwtBQBaEyN79GbLQBcm781S7gm/N/XK82sv
o+QfMurtL4t7fcL0e/pOPmwoXji2eu9rRYs6ZFEJxM+cBJrvWJiax8F49VoUKs1G
Ceu4jhGuTF1m0bBsMihYRQqBPOVs+BX1Qz2g7BOw6e5Uj6f3L/6gbIYMDT1RMIYH
dg1GbjlAgOGZLM8KmLgOOvgWtc3f3rL2gpzWJEssQVdfalcl89cQfxW0iBm/lEWf
7t1GhvcX/q5QBrxcq4fu0uvz26W+Tc6OzXw6wG/Ywei+lM/QIxRNWnwZ+rp65Qyh
WY/g8KUgN4Q36aP86CHqknnXT3dp3ghhf1kn7JZAeowdYza/5yGR4XmXUdaBSvaC
A+UXzsYvYwygwBfKLxVOcSHfrsW0XQAhNnYYOx/tzICiA/EGb9reMmzL/++GP4uD
3pwrG+dX1N3+JOuJnSM6IZOcNGbjrOmkm2qkIlMYxvWwy3RoSrMLHAeKmIkM5Py6
bi3gvfTS94jBsxVvocW+gXQbPtMMg9+fAPGhSGIOgtAUiTxFpkpeanBZQLvVG/7h
2gCW68i5O6PO57h5T479K8jFAQzSEoFzmOs1AfGzkSpLNdI+nA0yOUEaQxACNRCH
owNNAJHr7Np+XqEqZtx3NBgx41eUuSijzmBbh9PIhEwkRkdfLu6VvD8mRXZ2LVcc
U6wKvUJO+z0Fdo6LB19iCkXCEr20BEh6xC26zyKdf0MdApzMg7srk/Qt6jLsCnvu
hUZFLeXMfA8OlGzo70TQmimIjotc2/apm3ok4a5FnrZVOSMdr9q/727+GFQdwC0N
h0e9ElwxgiC7raLszKodEhr2CLglhANFaIwJGy4L16Ezg7XTa0xYmT1QBCSdRtO2
DRI3v1RjKEphyejiVAQtBykU6QfyMZnEpXAqgzUjOKBQBt3oUYch4js3KOMYZqR5
75kjhrDXyYqpi+fV+KCiQqvGDPNrysZQQQIwM79IiaDXgD2qKdCIRmKiqp04R9uq
qGOI0HV8shjTuJDG85aCpCSXtFI8jQNfyTFYo4Q4ERNrPjDIQ0ccaThHBS/y1Y37
KDD8Y+ED+DUqffSoSiCq6O99pqdO8F+FXuWnSpfL79iK2I1l1E7i1uWMFVOOLuOd
+AbUPGIPMrZsrPzuuK8tYPQ4sN193DWHfzN7Oc0lqCiKV8FZ6ae9j37FwjNlVktC
1vxrhXFZPzjc52KZv9xGjmspny7hvQfAwyHovrmKOM1pgkEeIupIIy/mJgaQaMDq
LA0YMiSELAo5H0g4MezVNgBwuKeXdhUWcGQhiOvFCv5V8J9pTd9gNGpckvwC/WvH
EttgSvCUny8J8Yl7sWubDV16BcSuogq3NVzyuAcJiCuJ70v5pIN2dKEV+vaR9XLm
Q6Vnw1+ipMKi6F+L9B9MMJOh6s604f0F/qbPBQzEwtR8AhMQ/BmYzWWvahdeT0Zi
54R4LWFgExJ2XKlV5kzGVTafKHQ1qJID0YrBE1Ykugl4YyOP69Albd5Tua7ECI1l
O5xILgPC7bCd1AQLbSBZ73ZE2imeTRzNxO5+qskv5MJUYPZhIVVjsaQelP/YkFO6
lkaT2C6b18itUKDUUZXvolWy17/AsXJP9aPg4oyONFeLSJIw3PsPCG8/BGXPqFma
WR8+sUE/jrmbSIfAfkM4hwBS0+o/3SBHH6DYcqey7nYRb6lDS3NKx1eOdetqAYSK
cPbmSZaZHgG87WS/EuwvnIT9mBnIGZbMwH+02/WI4RCR3whuOQ5XhxSPm5d5454D
MUGM4irPi9wjJEfNjMhXtXlYXa0/As9z7IgN5rxZVbvoM3IR3AixITYYR6+7q9yY
xRjCEmyISqzShR/vKD2dtNZlBZTTm0Vnfp3HXpzy5xuwEFubhXC9M3V8o2ae0u9T
CnRCPlY9gX/Aqeb5/J9U6dVCUnJdbHi1Wc7xVBUsyATU3RNd2Ig2rVEygSHkbltY
pyNBTfoUJWNl33WDbC0dq9UGxhHsWn2TqWPRjvTCN4JEp2jBM6UhpWY3c4ELFSZA
tGH9rovYyQsGDYdbMyH3bbZziIvgh/CWoCLNLeQdW1XD9d8B5ODCMpq7W63WH7uT
WJ3IAm2K8FbCqwTIEoSSOVU8zBjwpJbfq04ToBIY2J0fW7a1EJXhJH3inaBRqlSu
8vPIjhrLmozw4Wn1dFeUhhy1DkV2P6IMnEaWy3udgBozhsqH4xKR3tUymFib0RwQ
3F+4CBKsQ3AZXkW77YFHkTxf3Z8etpJXkk98caJTL663/5QTEradHmkkuTnxLbve
Cslw7WB7TJ0ho9RN190bWSK/XwqHtv4qxJTwjiwwG7shEuWEOqFt05jc1Vx5/Qof
wwhmZDY9EnKf4zkqU5avfP8Dq/y/yjQKzx71Rj/TdQ4wfjIQ1/GEayXlofYSKSb2
S48SbF8IFymZ/vSOhh8pjNx5yPz5NtGgd93nUmNzywGn3l64i5pvc48koUreHC54
QtQhDp/MXHgU7xq+MzTr+g/hq2SfnfZuBTXW0pcQZjRMafsOx06DYOWspXvjRwT2
QVRzaNAH3/QHP5b7VzGuryR2XCedEfwDjOO4ugPObstAj8QdKyirLp8o16xAf0Wr
g/pPn4Rj8E1G6KnZqqM6HS55v1pbErlTJGafryMpXiDDRNt+ewaUzZlhcYLoHz35
PuO6Uf9X4IrrHPu773mWWHbH+FSAhcJCgkJkv6KdFhiSz7N7fNBBSDSuywvNf8Ao
TOMCkyHxoy4Sq9YmgWOGE81CTxPpvsTl1C2DvTbIe75F+pGQQ578oobifOoRoEzZ
R6IJs758/4j4g48nOCXxQeTFqOso/NixFdHBRiU3UVcnXT4fJhPV+JNH6G3CCyi0
PZ4aGTipdh/dU27bM/VIDeCA96WpIuHBVlCyBymoak70Vfi9wzwHe+nn0CRsK1wp
ZM4t+9q4CyPd7JFXJGjDMnxFrpJHe8oK3JyihwwngeRHbIkNEP6/UxjlI/+i6kuf
ZDhLrzJHAwE2hz6DaxAzaKXhZCfRsbIlCPOQnivKtPU8pTqg45HAX5zoMB2QcEEJ
bgBHb4TD7uuGUmiU0uH7VfZ4HDb0qhzU6yyI8eu2MgCCbJYCL9k/Q8lFt5pEXVl7
BElLgb4lLqeKqxRpR7KpkX9K3ew1dxtJG0JrU3JXkjyGM34pj51w2U3WhvDMI7S3
9yXAlyxAV239tamHETOgoVviVWa46AP3dnbklMpXFt57MVlRA2XwtLiLhO2Lwdpr
2kvOKmF1E19+bppbcTIW2yin87e1U13HQ7Iy+rSNVvcQ3t8JRzVDMM7K2YwQ057W
5W/TG6/k1tQ2mjqC6Gb2Px+jLJzKok12x5lyx1D0W/X72gr2rKIcw7voP6CfDXq4
lx4hpseiqfxoAv4MSm5SlMWKjyKV/8WjuVCYtegO3nI5B+Vxex5W1+XqEfMBB5y/
zVFhvF4Tag+8VJDmEGWq5gRxAHoxT0KjAhh7b1985yHTVKsccw+NK+fJklGJv8Wh
xmvwQPReCjsFtGc5xe8NzR4yj+SQM6Xe7rLAWMexirPWFPmt8h3oV58GYDEPXrU/
gIS5CM0Ye5ztql63Fza/ArQLyguhHqpaJCavPKcWsPlmFCLSmyGcKkhG1J587eJo
35swKA88mT6DfGZSmjlKfp9vGDqgvrebdGgnwr1wNeZD2LG6JN4tQaYqQD8k4IPt
IONM3+H44758hj6xXAMrQFeV5gYagJDmBbl6niydQPVQxchIRyR++TBSEmng+zvU
ZiBf2i6eGvNdontZ6I6+2CSQVOhGkunpJEWHiNaP2nKVfpBywWHiQT1yT5O5kx32
U9vnFx9oDlOrVGM76GdJ+/Udnq8gR8lRhJ/eZEl8K2EAcTpZmLux51ivZ04xyXn8
D6kxOj0InWCeYBVs72RB/mWv9Q7CMF5f7IeQXN1MDNpUwftNM+o3qRuvjGQh7JyB
meUK47b0/Qnjd6SGnQl1AvoFBkPvauEc5UY7dvkpq0MkI5eTP6RDZukIkTy6kV7+
VXRz9FYeb3GGMscVNR3/F7kN2dvCT9nrfYOpJ8dV7Zsn9suZDs6kuFidzEyOPrHx
gLoTn7gTG23ohS8fG1P6rYk+zUXjJuxRNTS7Sp4loh+aFPUVBMoJY1bF5bwFfAgr
AgUYGmuJliSQx6GBqmgFRrbMgP5JffaWktbBMeTSgBIXgDwrkjPVOQIXaY8UDPOj
WszO3l+jc18Y59LKavRZ6poJL3ye/GsvmKf0TpIVugxE2l8WnYJzgvEaGT2De1ff
eD5XIDwICrIn1s8s52ZZLIi1QbPESm6md6/pNu13Ikog/VZ6k8eAUseghIdo5TRu
Ew7jTuN1JacOn7oS5DxvM+fyIcmgV8i5ZAEKooHTvGaGWbrcBt2yrDlAjrbYuQcY
zx+VEIJgqIHkELD+NGLS1ozse1ujIYb+2JEyUBO5WIQauHwEt8uhCp7n1y+GQua6
aEWe1R/WbZzX4tJX19w32RydC5o1cHrAhcp4fis1avC9Wd3CzH8FmWlzcO+tHdrU
ZcK01ywKg+t+j1s91mY/AVJFpFSZuJWofqZsJSv4T4fdgxaSQ3XuyRiDLELH3yEs
NxQjCtK1Ela+AoA6tSO0vDi0LVKlV7n3LoNgn8WMa+sh8xfIxlc7KiWJHO6m3Xb5
P0ScBUNAPDWd3UuEix49zYc+V4A38iU0/LsQ7Ccc7kLF6HDsh6rx+pQQy5xE8pwP
SP1UNhemrPMo7PNwbo60qqq/Br07otpE1GoE7fOwJzoVgw0yX1i2O4/8Rt6ZDZqc
2uhPOq21VpX1dUQwWPRB1TZMEPA1lPThvCbZhdTkvkUdq9uJSt+q+poNXUMeOYJC
ffbuUBDz2/4eEyYKbIU7BiG7Wv1PPx1hLpda/FOUtZ54R0YI/E6jTBJvn4r87NUu
KopfdGOMvdFV1AkMLphKlmaTp2VDmiw4lbentiVyprtZSRTZNOOEB6jxbHgHPOdl
SLpk6kCulNno2hjdb2Y8H5Ww4khhL1Ii/mT2CNJGS8vioa2eHeTWN5m0v160+7aQ
5J0zEufHYXHTjaQSwQQiMj0Hl8JKXct4ADau0cNGx6+/RyVlk/cgJ6jDxTY5N7Cd
bw76EMMOyZT4VnJBWyjmvfaJ+HwgmgosL88YjQQATa3yuFp8z6Q60+ifC/eoIJyl
a5kDAftu3ZZYRdymGac1zRljDYfTKCq/P8lHggbJBSIAqE81T3CkolWLyP2W/KnY
kl7ov7T6wa/EJwWKKSVIyOOJ2gj6/Bh34g9X+SVV/SuCGPW8Af7OBdByWmAS3mz7
Q4CIQ9V60L9dD7XipvYnTfObNKgVSEm3ORzvlwUhE/wFcN+GaTpg4TjjxGg5gq2D
jo91sTwKuKZxs0OE2kSLfEdVW7D7HCTh0F7TK2RbVQ7IBFatW9C86wxWdHMdUeMo
KhIoBWGOSCuXh4RAituYz/wnKP6QWJj9BQ38q5EdniF3REmU4hP6oX11Jh2TpBJ9
yaTuCr42m7Vwg43CE0nhyazeAIS7TD4e4HYN/Vpy8UWf80/BX2ilG1VUjGXuJBrU
DOILDWi0fOzeEUGu6VUM5flY96mBZnN0hffU8S3FHVtyxnsEZT0HCgkS2P/aJin+
I+41VWwpORR9z79GY3nU4ac8MbCBTAko5sz4V4D8H2O4qRQbtgnXdniFDxlRds5f
O/rYwODle+IYGPTpagTGRZZpdbPa76VAzdE3ycm9dj6QCdiGT7k1YzO23BGly7s5
f/i8kZQcTj3kcBnyhiWoLqGqPtm2L5MeJfxCP6RuWSv37BxnrBAODAYMIGJF80YG
46fwvjG8+Dq+Rtakpo0dTBQhRFxMX2WBRtxcB+eBJqkoYOncE7FKqpqEexcoXDEy
dSfmL6qAiMyxH6GpuP/XEYRwkIYY3fg8URSDiQ2AD4Ky8iSrtHZfEMfhnDHZiO6i
CFGt7yFiS/pHTEhNm+fWFu+NC13/jC11tQ3stnNtR+PxKeEzrPPgJ3ocbMYYonX6
JkqytvDbGu5Vw9NU27ceLx1srHORwPvHGdlvQVPsnQ6pPdC3marfjQnsFVd2z7yH
s6OnKymiV1xMzhjxel6at95sUd25DPqseL0PQoTZJzHOFT3mobQb1ixzkLDnUo+h
tH+Wedm2CxEpzTYuhVcEPTrlO09V2W1Ni/FSRbsoK2hA6ZKeto/js+pPHKLhMjPn
gCN6Tp0jVdjB27yT4PSxanj3SM3GoS+x3a0t88wZYvLX8oB2sn9sbqkNYn+fTphj
GzLnrLtslsW/oWbluGgKNwJn19IoVAPqkjmfnFzlkFY19QjnGvX5hCG0dfDoxaCK
GQ6Fxbg7LPeOz2+iM0LpL/NIOMWSliJM3DtZC1WgB3qDyhI5BuPx8+2VEgWNCwUD
i+k1QNwuW5NTOKefdMugAWgJ43hmHLZiwWXi5IGl/SLF68tAhDD96T7dVaLCp7VU
AP7qeLeOv3sHmZf6UeH2kbnGLwHpipzjzyJee/dg77+u9ERO8bVFqa0AT9+d9x3j
e134DvfAtXpXtMCuewFkw3t5dwdhjUvlPb+48c141x45rfvBE1QYAwSOru3MgTMu
7x4hECetayy3canNn4xzmk/IBjuC4GctwuecGOHmnj142u0ZnyT9T7+VAZ/NVmuX
f5VxfOIjsYS3xpLtDW59AqYPH4imuutqlZvERhZfKAUZezL96yvzNh4B5VT4di65
LOwSSrTjIYTq2aksBdvL/fzA0h+p04asLzo8+3tFzaaF5cPUuM6tOytP6EWyURu4
ccScelirHO3DAArfEnvheAOQLGlpLzi+duUrW6thF6pjA3gmexjLe2IWdvrCJDcq
Q5WCjNbgV8sAJiYeVu1OJZ5HfR76QcUtrswdlofRRXokqOVRzOKSldsDsn7b75G9
he6R19I8wanTnyhqjwoGd6lt5kRbIQCSx/bwQ0sVSE+w56sSV4EKj5T3GioKJrGO
rkG4BtnYOIclz5h/KoZlixpQmyxgFK3x3pBfpdo8WzOyrWC1AzYePljy9pkC7S/F
zXCIFX+f7PzqlJYzjtqcuZNMglef7uRT9uSHYrcrFgRpaXs0zz1ErxpnJgHYdqyF
YERVhwWS8RCNXh2H00HS+HsEGxdAknFAjcSU3GYBN84xBEawynZ8w0/5zcxFJsSW
zXMjy2v0YBatWLAnK/lKtyfYs6pKLmdk52u28HA/LBrUM7s5TaWsYmc8L3Hucvhd
1gPLPRM5OFp9TJtQjDLiWw8cBJ6kOBd22Om2JxH6u5zsR+APn3r/0TWiG3EirOy/
iSBhsDOAbQ0WcwASocG+2L2tb5AU31aFkPTO4eioAZnK6W14jlfEV9OrI2C4qNkn
z53StGejwZ0Qrb3bIDae/Y+y/uEm+bhJeyjRXPjXBFeFCX8lpwPWoRliv01F4jYb
ax4Lwhk61+eg1lX4lEeZRazo7PDWiYn97j1WsF9RfRF6sy1wMZhzu8j3FHttfJZP
CFyf6sF94ilaXyh210jE5Isx+g8mAtnBMpjOA0htvi1LoGKH6S6U4gV6kEwFDI66
XtNonCKb0gb8aQMUS61rU9tCoV6ytWSmBDV9B6E45x5+s6ilEexnyiMxaDIgP3QN
ZLxGt1CyZ0oAMi25c+1UhXLCu5+XeG8N0jvWrd8bRsQ1Uw1Sd4Exihvqd4xaE8au
cWOwkXSuaO0/hInLzO0jQ2B6FkQbcr5Rz5+Azx6j5k0CXMuCFjbqiBG/Bckv/79z
ee8Pm5tLItDAOAaOof9yaFdkeeBDWYaQ0CDf0mWbkh4f37UGOfAHKIvVxzpNLTJ0
XsEtCENwQncj5HIirSE5TM9foJ8sTutTthc5ZtKvKMnmUomFFYKYz++RyzoQ/oNq
brDWsS4+SwVXUDRu5QAsiVSTPm2evz08ubFLDNQL+d8m1u2nZnEGOh5Y6Lr9mYJE
FhnX2xo9sjwISPDSAOaqhqi+96ZcbGADMByNQE9/pVgZIIkN6j6/d5x6v9F5OK4B
lfnTDyii4nPdHKFpsnpFYxa9dw7rmSv2K07V4yZHdYxlWMQKu092UIHXvpxnbjk6
2N7VvXKk6Pn3qcmiLpSrycjLmdb21ceqew6iP4k3A8UcHMSyxpWojRAyvvJrwuJd
ZZZC96STyL45M7rhdYn9VjdlYGzTnr6HABaPk7KC/ZnGUaiV/zUDP4GIy3bpVUDk
pFja37/8Ors57VEJTVPw95Ncmv0JVHcU8tEZNbpMWIvJR4bIc8WqxeNkxpnMaqeY
betK2h/OlX5p37rbY2XrZYHPo1z9YkvfNdo8VzfszDk30Lu3dTFGgzbkmt+2vqyn
KldAYAMYtNjHnwTn3ATLVMnGyuJUwcSB1omQJC6F83Shn8Tmiv7ichA0QH8111Zb
xeWBF8AqOGVPZxKgehM4n8X0W2ZDkLJBSCGK9ZFN4x+/mF2bvLP5boLBm1+Wz8Yb
RuwEOo0CbtuMqhyZSuQLChBxGyJqeiSsmYBYjmulAiIcVpz7n99U/hgmq3NaVigO
g1y/WRVgreAocy05W3KjrRtX8E3L0R+/lCGGtvKXCMCjEMNL4vNaVMr7O9onz9ka
O4jEx3aXJDUXuiFu7bU/E7+tl6ZV09lTzVSGHO6Wfqsy7yaY7yFtMHAgqK5b4Fnu
3ud6u6cE5akjQTuhsEHVZlMP1kUy6IVcxFELTGpovkAmW4/cOdboJ/6W8Qk7QYyw
IjCZQ0pFSLP+JEAqBr+rHs6vtFqMeXSkJzBJcJ/To4kCcJi6vTxcYNtg1ugFCuUl
dhG8wqD16Ixkx9llsv/o8TILwU982oFPBaURcM8Y0H13Gms5VXsFsyJuzo4PoSmg
0nEVJUeKxrUVdbn/m9kWpKidDW5V9C2bCC84Nfd4uRvd55E7IgeXxQ0NqCqmuD2o
Xc6tSSdZd9CA1bAnINun4tedDDGjXB1QCRMqMM8ogjYc33N6VtMEzdqm0i0OthJ8
cBh4u5lnp5kFVBMAmmm7Tl8DaBsbsv9Tt2flYHoeEP23dMLUC9cpXU3lTiDxm/7G
jve1aEcj/3X9cS3vkb89VOx9IZjnTB3QqF1Kt6hzUH0YwSnGItlR3xWnbSbbQcl6
IKPidQNYTxtCn/Zq6TMr3EbrK7NQzMHMd8KCGWbz8ZjUeezgOtxMG7+K9/SgccDR
gjPDEshrxthkS2JXVnWqLKKELSBAuGIzXRzy6ncFA9V4GJK0/ZS+Pv/FOHH4iX1T
r/wszhrLd/s0IonsAA9odt1A7hqfzc6rL/6+U16ibtDTcH4jOUG7urC8gJMyEQJS
CWG7W6fwkrj2fHGsomdZR87zZQM1rxs5pqfWlg8PcVtBNy63EjExgREGvMRamB4p
OsOW9edlfi6lenShKKqtyQPyWM5MKM2hv66w4fWMfVN6iFrLSmd4Q/kiuKYCA7L1
1iZhFwjAXt0jBQ9WsZzlQ9ojneHasvDD0TMEfQohEb+hDJBUsdCr7alCUhFjUD2N
gWw/bEQT3X3fyHpGu1UX/NmDT+egloj/cB1L3vjFjJ+gc43vdqcuq79msjYH1xlF
ceXNqhZ0AfzEAYtF4HRithdKXivuXmj1lfeiH4MRsDmcEv9ZIT3+UcJfJisqpNbQ
abwg2CaovLvcsUwBUMvovQevSiZxihsJv1xLFPjiE6wh4QCsREhYV0YBboFOPSp7
Cf+jwwc9kts42bKKewHJwW8zvXl0VnxiZnQzwbrggij4foBS2Eg9W9UrHlXl3P7H
i+WO2IqNhpBPZ4G/jzbJ5EnzdoxgaboN7imW6PVy/bIcmME02V7b9Wpnq1y9xbYJ
o5o2Y8V5oHa7NiHRULUJLCwKzRw/nfVjaXIPRnhQw562MN0Rx7byWvdndkJngXC2
CkzcKV+G9G4ghrUgqyVh5l243fFCCHlgAuR8JWZxiOOXGH0GFbpI9xUXJnftfXV6
KA34UffLoFpiE0so2SXcgVvi5LttBlYyrAZCMhCYzHph59mzJy+mNBp/mbdNL46j
sMa4xkOQrbGZbvKug/KPzjbvxXDZ2Z8ANStw8PWEY3WBFi/Uz2YuAhRma9unkrZ7
Xt/A1ZziWviCRsE8saETsslKEw4diWzD2T6LETlCWbaVig4ShXUk4bY3LfSprXc0
fCq4nhsnOcYsq76o6hHy/Vkk7HZQHO3i+Z2Mn58nNSM5WnFo/w0jz8RtqGcrLs4j
ltm5tfP3ocXa5gpgIsc7Wid4RPbf5+ExyF8UC8Bo8yCG92Xnptb7mWbx1UrvijD4
3mt7akP+ZBVCIu1xeanJoYooEEeyJYNrF0pSzsqAlKiey81JKLtt/G+jWoTafnJE
GMHuSWeZDABDP7gbetqzCKJ2I31+NcKDBu8jqL0qQVWOfNG1vrkkd1NEQimNJvCy
qpkTKEu5pU3Ai5vFl7G/wC2J8Z3FPQRJS8UGbQzyQqesGrD61Oz1rYreDpyCva7e
3RoAxkCs/8wxQNMqaJ5o73zPO7aOTDwQLZtOluYUL2+Dqj+Kg6cE1hvShduwO5in
e/6mhk3CIePaugHjd1YDVEbckrZq7ce7wiy3H5U2GKG3N2hwnoabRu466eF9/9B9
537n1rAjSQabHbmezSmru5ieN5Z5CxZbDEpyDQHteiXvv8fPXkA/BxlrDjuZYPay
HY/9iJoLFJdvEdwe+KB/j68H9OOE6/YIWN5WICXkdEitUIPSM4lunwXGSWl3MBqH
sxF5QIVgPUKZTtCmzIJUTaVM7xYsFgE9KnmLRsi12PIg5fMwme3bVp3jrhlt4H7m
rRi/6Rb0mE8Q6NXuIIDZcab6oaha9eYOegGia8W7pAx5o3MJFIJvxDAq8Uf+Qr09
ksrUKkNe+9AOMLxe+it/IsUhN5bA4WnMy0jNyuPPdT90ncRLtew9+6HxNXS8zvIR
UsKyt0YT7ZiC3pVg31m+WQSaUDXIP9D22th39binPnRW5+mNaNdq/aZ3m+MCav/3
v0oQbmE/fi7CxWofg0bRM7pNtGqro/DpoJEw6KU4L4/KJ4BNyCsrkGgAc4fPZw2X
C9T0tq3DaGYzoRCf2jCw1r/33SrOD/gKPz5FxTT3+I8nHfhifhg0UCmhczHC1RMW
3ntRq99TXivy8u2Cr+Y+cABwTk5byIrah1GucwnnblG3UWflA6VOCUx8D1rhPk6C
DWSYnFseuH3U/b6FnVBZ4T2o7rq0PjPEUGzna15KdUfTarS4vFzHzquUN9M/JZIw
VVS9ibJIJfAik78LV9s2tYG9TQqDblwGSQXoXwLBtOcAw28lp6QfA5k8HoT2vlAt
opRLeD4QhaSQolrFgiKozs7EBDAuSrjph7wgTILjB6YVR1cU5E1B/P8qZXb7qd3b
eUA8vLJIECOpfuz1sOCtkAh6l8O4Xlof37KI/0QhER9ppVO62cC1C95HzGmpQ1LL
qOcL2KbU514eHLkQFCR2CYpJeKPIHTa7AgHVdrxZpJTmj3RPcPr8U89grZFI/F1N
TbDr25nUNLw5o902aAoNYmB7j25GkGedrjCwqBqU51e1RRJwuBs41jsyieB6pjX9
rm4bx2lVbw8ZAIA1nEEQVA2jqCHEzsPzx744x6UDBiKHspSUBp7U32dfwmreXO/Z
A/EoisNpIlNLetngzflbbPHvID6zj0spSVLUGvx+KKBW9QK+pUr/hqYZMmpLpOI/
V6r9urxbRkVBTRHvTNL7EgUjafBYLs6l+LK5fweE3Zz5KwO5O9yIHs4NcRlMhb4G
LB1YvHNc97qUV/s3kOXSL8z/+oRcZ60jZ+YK/NckPGxsidp2bh4dJtTQoy/vC9/i
YRDkbFFkaFHS+tNcxMMCBi8SzcLG0XVer34feBsHfSM25RiPUTiJgkNNieUg9PdR
5KmL7azhD72+c42wb9VbwpfE26KLIqA5k1oZ60QVzjrLJmJ/gyQaucGXbE9dVAar
0rcFxqpBV5tBir5ZxZ4GsGLUhJtlvTpr1Oa7sQ6a7AYnSwAVNSvOV7pBWW1RSZjs
aBFVDEyWZ4G2hyLBIiNWzeDkXVYIyciugXVVCNzTT/sUb2vyQDvz1JIHSK4gAmbG
AMKM3mr01ADItw60d9VeI/fsTHjaU00JYQn2729ZxV/OtsC8E5d++KO99WiezpdY
WsznTtZGjoZivbRC7eft1Z7kRqcE2x7DnrjNhXPAmANrTPPxa9nUl+9dPttDDPFx
ogdiP7heuZbivBZ1Vhnm52HZcMB8M4bdgZexi1EUpQcnGTLYcHB1tgQF96QLWTE4
rSogBr4xvWM2JZt1yfypb5cnNaxzmoszrPqL65zIi0JDkOV3QDFSxPCfzKIJxv5a
klhKFlJmHgcDkkZo0keLDH74jWInzBm7LMJLkbISi/2XDyUnElyqON95R15O3LqW
lnimx/cH1rwJFdz8PGfXTtSJtwK3+qK8Jk1B8E12qvmMX4T5w7ViixgRnKvMg1EW
1z7eoDox1wmmLCkGnL6ESvlqYx2SSF7MFWcO3VgV9lG0pQjvAHPRBikGXlAT49qI
s4Rc4eq8rP6ANV+cWK3fzyLK70h4Lfm2HDKr0AnDB5WhJ+ETuq0auw3tjshUUzHP
Q0pRJ4gAT9At2Mj389DJfutQ9UAiXf+MpGajl1RB1FVVBMU8XQq7PcbAi4QaO2jA
Pa3fmM2PMvRjWQQ9x6W4RBsGWsToHJDye3wkxu15sv1B8Pi1jXLbdzwd9ZSS7avn
0fHNgrjjphptPN8ioLroLshMe2477jvNpCrYSmY0qXSCq09a4EVFkIOg/E9ANarD
s5DxOYnDteA7vkbgCMgahXKjMV7+OwquB7/snP5nuJLFNp3oOvBhEz4coWKTlzC5
e7BD1RhEZHhXjXTomSwPQxZrhqoGNkb03qgByBV+uIjQAZ1JK29+tJWaaHwnf5wg
HK7/ujis7N/nK8u0CSsMsYk+BJVLYDOw8+8gpiPKWrgWfxrc5CFu8r2H+odxfEBX
YpIqckRow2h9DAHnj8tL3h1yONpUqDv6TFrSg26HWxs0DxRU3BLaZ7LcQ4KNm6rG
cAbETsbyimWJ/QGX+v4AJKGxmoEDnAaS/OaM9sjGGMOxSObGpqbPkgGLCwuO+8Qg
krz4PXBGnxshxPNwruvbHabe7h8AD64Kst9cl60p5jeqFqdAD8kwZCRE5xW/lmbA
UJxMqxx9rNf6FzLcuHyqtDeXAbwQQ1RXipc3xNZ0tUyonp8IKON7el5zdbpueCFh
SxigadFVcxkqPhDd0FjRsvAjHInggC9S1l9VC3g4fJ+nN3Gk39gfAiubJRBCadx1
/Ca21kVz0DxXuRQkKNBF8Qs/Kaj1Ee9YJA0Mgz6zK06fJXTzQpUYTN/YiIaeT64+
BSFI19f2As/VfngQ7QmQasyar4A9UIz6oVdiS/eRa6CRsRe+6+xOG7he3I3Ljl9x
7zXCLZrwB0YwnGSGSsHV0KrgZ5vrRRT5K8FHF0ydzHlp4G92qo5MtUKJZ9Izar+S
myhEx4yXV1YxG2Gb3fryV6OirdjKtfp8EJWS0KD03RO/1qJxpltfe41h9GhWXXUu
FRTdKR8tciWLM4ROcbZ3I/sLjPQV8qGM5q6ZpdVUQ7ocbL95kzMfOwgr6tAccVTR
PN2oRjme7N68gwgbZm1TG2Du7Uvsq/+GmcEEUv1mhVZ3/NbpgKYgSh5HrqK2eoF7
Z7GlFEWBUkeMUgqJZxw8U22puvnlk/hEH7MpqGx5INgdiFpQZ+vV9fGlCwtDE98y
gqHMP4lW9QXdi++wcsesCD30R9kZjkrnUN3raq+VKOEusSdMtXTnyf9Z5zGYJowA
S/gtwSmDKwvVKvZeZxEnVdTyOWveuYbFsXRuUfFLNWiI64hCbUWb4qWkBrD/TYq8
CC7iRZmUzrD5WjtIVh8zmdpUhL6ECu1Kyd9DQChRY86BTvYuvQGcb52sCtkeooFv
PsF/oZc68XYqnf87BC3I5A0xvlTtYS1NjkafNF6gArtPuls8KBySuO1hKNsU0bzI
D1a+yv7oXiksx4bb1BBtEdG5zAPg/eSUvuSGdAbTS/BM/JK+7f4Z3KWMlS/tZhX2
C7izH7cnhAt2eiW3y4wSuMls3Q32fN/UPvQErfyXYnAmfQCB9WBDNGk+KJzmeWbp
W6hsA70/k4wSKPZP8LoASdJGubCwd6EHq8Vmt6RTN5qnpBQNv1tx1JcMjh/0/71o
qQlg2mUAlnJURAOTsvxVoPajRWWhxPIggWmqvbpflxSB8aiktNcvjBOs8rc7vfQa
SRhjSIBID63XveAxlEy5SwWMwT4DQ3Sc/rO6ZtAVpiVPI4pkxKBZcHwqSvYIpUMk
s2ZgzDNyKepa9CyzqI/IG+wo+udxTVhJ3jv99ooQpwHhZldIw5uOKS0L44dxcAZu
x9fllJltxrg8H8rAdZ0vygwrlvlGimhklH93lVbS75SBy8Er/BPCt4/7C7vbb4a/
KGo+jJkYvrNBm0xLjzmNPx5ZhEpzkCugU+9Z5RirL7HDwF/pGBcGqDegpC7DKQ+d
cIB23cggAV2ZptuPhLVgabVKVVjTOqF6NF0ShM69ukWLA4Ys0L+plCNhtK4obILM
tKIf/fqh7rFccV3YI3PjBBEhgG6V7qtp1q7vKpgtKYsEQvsc0rRGlXpItnhATjRX
iD5unPTxMZGUTyLcArYcx3OYg5yqjg6SLLeEWXRT55JBc+L4oHAHPZpv97eZAGNf
y4tLkCE5gJ+J2D56FXyK/u4UQ4VizZ5bG8a+syO39eZIoB3l+PoXJZ5qUCVWOF6k
T4v+wgo1PCcKI8vaUNzMfH+7W0YbbfybehilMfQJD6NJW29Fcg5K8PI4PAs8eY8c
W/5iX7wl6cW2tx1gAKzq96wRk/GeovojpF9c1EuRZz8tPZ1pcfmEfiteFBYmAEGU
4i7t7P74R5KKP9Hei/84MhIdfcdwwKf/sTmYQ+aWH7XOHeRPLyZi+R3+C+wlAc6t
76wdfcrf9qQ5adYyYFfpvsY7VokZrRj++o5brNgKqwJE6vcq4MtPk/ZNGqFV735G
T3696+owLNUCCRyKe22ZIBNG1UlzmIxfyKTpfRME/0LhHzeVWXiZQxMNjPOzzkSm
lpnXQFrVuCdIOW2oYPba0nhfxCWHvHsHJ0Ntr1FLWFznMxFTTLA+UKWH/0Tpc3O5
qhvxuMM1ePDKe8jOg6HlSt/cnkn25WhORNRoFUgXWnCIwsZfEJ2FLsE6sN2M0F5V
l4Zr7gGXDNX+chGJuHaall5Oli0M1+815oJGIC4RJ/9Axb6Z4+GiZcGJHO/PxIpz
mDw/Te22he+GCQG+LpmxFLUBx2X/4+1T/Y+pLM7jvljUaV1Fd3f6jO9f71EJY2q3
LK4jdaxmpk2AC+p7CxwZqlW43OnJJhnNbQMoJfIRtybxwzgoeAor2jducy906nQQ
2RKrDZ57Jail00q+siqMAo9ncdahaKKL923FBh0BFikZ8r8OODkIA22ujxM56wqa
+ErxxvXJ5GCJx7HU1P9zOHm/PnrtYj3y/zW4D6qgbIDxupKqXvYEH6fIwmarQKyW
7Cvh05+HoaZ4hHOVtAkYUueZoFYEk8OtTX8jK0r1Ohs5E6IcNPlBxbMiefFsYnah
5xKEgRrkQKniEcRV6R2CsChOlc5jB4APIjmt3dks2LvpcKuqmkL25z9JvrXzWStv
p8KzY39AKYwCFnEwIathjUAZXpExvZZNAHjgHKIjG2sLmUL59mkRJO8e1uOSCU9S
9Y08ZhAPz4zie9HNr7biK6XRF4khVSEQ0NiJLA/CtJeq2T0/1PSIFs7zKX8KiVQk
IjH9q9Ojc+C7m6WlM0fG6iSOjtBtEN14bn+66VyXxGZliywjVe72J+J2t0mywMfq
vbVe/p13PbHoN7/I4LjrwZq0epiZNjgxsz+frcsBdHz0d5KdiFmraTCvoOfpPafe
JVwGMPDzFOqF6I9nnHQtETMP98p0gGmiqT1ihRxLutr65exCXdONIv6iKmfbPgIq
jr6QzWVbmdwsawTnOdy5URA8ahYM6SE6koQm95reiB2/EZoGasvGjfwNh+O0erPO
wiFdY+75X0Yly0JcOC4UpuQYLg8tQSIwcVgPF1JQaokrvqMuGKPgWHI4sn+1PRb2
GM7bfQ/khR5DYBbzgbAfc8jvAy58CjrI/9QAjEnJBayyiqjW5uWE5WTX5prp2uSi
YNxkAtHjMOAZY24nwALScW27TOETXqaJIzu/XBKiqF5I/aOjrqlNNY9aGblwNwXY
tJofPbEdYvjndA1LIN8bKc9+NTZ9cyFGwNrn+SqlGBNjEZFH7nGTiu8WDpTnfTyj
B9gGqQRNUPhQXiN5rFJQax/1PfbUfTW8eXbpD0TsfXOT6b3WZdO8um40Ylv6nkE+
bJCCgxrBjxgCWZa2jPQly3wfxSdYK+NExRAmPVVp5dZi7GrzfY2JUD2FS0+3srIj
HsaF3P+AA2D4xGRMRSj9wjBqyek4JEK2GSmTpk5rPz9HYYGN+3lsM299pcG7c91D
42DarKFunkgvGjVFxKMO6+M8uyO0D+YU5RcWiJ9ksZ6NV5L3MlzobTW0Nw0xxOHh
blgQGlEG8hQiSWbMGwRCHam1EDkCX6ytC+UiTxgpD2rSTq5sZBLn1tkOYOlxiixZ
5Uk7ecUW+dBXOXhd908GtzI4q1fNVFDkeaPZoRE52bwKCudlmUbQPD8BM1slylh+
WXVbnjjTMbhZEQtXFJ8XvbghBDEFXkrSb7FVlGyLzo7lnxKPVY5jcaujd+HjNBcY
AT0YWPExEy8dJKKIO0wo+CzMZ4qHjbja4k1JM0vsEKYjm3t9tdnXmzicg7iHx44I
945F26KW4SS0Ur8Zpkum7yVh34efdjM/VI+RJ+LNH1uhgsQ3tcf2UDZPM1TXw7SQ
M92w/iZKL7g5vMrv/PL2xiSD+7cTDoS9oLlLaHIVl8exM3zA2M/venylraEZVzTc
epTtwlPwEUssEudciHxYpeuRmNIEaWuoIQsTXMj0hJdSCl/tCUV2PF0K6ycw7b7H
8UUFVb34yHiIvOP/YZyu2Lr9DLIg8Ep8yFawe60foc1fbS7yzoamRncQHr5GU8fr
FU9v4Z+eXPSTJpA8WfreRwV5bYnIA1yNTa6ZptwjhZmRxaxlmsSsuLSo2IJoWuPl
yJgGURuvuDitYTJmTCGGoLTPGNMKJBPVYB8PgAY4YCSc8pSkqyQpIL2cAzI8zlK/
B9FIABmsQN4y3KTjlS9KUC0/TugApYkvjolIldSKkNflnCMlgpwdDb1iSLFtzRqK
7ZQfcOMtKs71rgxGkUBQkVNanzVas8TwBnxH22elhQf8sjZjI4S9F1hu17zq99VE
wIZmRL/sCghat0bwq9wKaaAxJxzFfNnNQvd/CnKcmwG2ZhUCbxjYKvq57bz8u6Di
oGgEQJC6S7j1yiz5C76Pd9NrXOc7Zs2x5Yw7q+9aqBiIfV5O1x6tVcCAEidmUIlj
hzt90LWapss4N8r1Tf/Eh4YbZEHAeO8h4UbaAcwsgD1To+cavnnlAXUqG3m49PUf
etkfibwIG9AaYYKhYhqmwXNJApmTBxqtEeVAtGbPHK/uJ8oHnDBfpCxEnJg4A34D
4Lpe7jyAsvy9KVdNUPQeYiLps6yx/SdUZ2VJMajdcSSpfEf65YnBUkGSCAr7jIqQ
pGaTxsdu6QqSCzQ0nloViVF/Hwc9vzATzWIBo2uQOT3+mRuROzEyzi8uQZ11SWH4
bM83V6AkhNg8aTdBhRcxHWft197bAkixX9jNtNdTTGyiam8WwG3HLZUe6wHX5bhF
QQgSf5sKI8Z90r3Zx0UUWJK32uYo5hbFoi4XNPh2wEPkY6NjIXOAQKsyiqWLnitA
qcPfce8dtPvHtMduKEbxWYwaFgVQ17sm99g7GZ1BRk2DLIrkT/3gkE6nfFHErO7f
6ypAgAZXm0A/ACnMbenSwSUXBpKy6B1VBwXB7H07KDCFQrN7hhyk03snbCj6j4KW
U67zD0riWh2OQrAt789H5tnYpkUoPDjvWLmrcqqpgItdwlvJX4N5bOmCpYrFhBNm
BCJfpETSoyaPvGO0+8CrJ5WGxNI8vcHiNb2T5AUNeIKK5q6PDEs7idQiep3+SQxn
J8hJr++EmBP5RsPoD/1CHvviyftbXxQw8emDo68psvY7K/rAh8wgqAjTqyNFa4MD
D75uSypdQiltF0OmsWUENLpllaXb3vogdCI9rWcXoLXAlf/kEAhrwhdDotI+yd2C
boL3+6Wwe5OOJ0ArmLKNr8S0krAv3Qpd8lu1GAVVJIdQVEYpYkxrFjQnHYbuu+Qh
bLNWXnMOq38XgwroX2EV/D4erJUnxuKN8UCgStFfvKAu6HXmT3QDGLD0htWeUtd5
Q2OHdvEUxBc/nlF1YjK22qod/Gc00G/vK2tvo/67KWh3NPXJ1bEc72ZHR+/AhDAL
pOJFDIz5FcSzkIRRyokhxJMe5rHMRspnTYaPV8Sif7s6oEfdUhMby72LPiyXmCe1
p5Uj9O2O345aq9SCz9lh5fysykiWEnSxDx6SDFVjk/FsValvOIga1pv+dd8lcLlP
xGM5UgD4YglIUmq0X7dnEIi8QK1+Qyh/OQ7DjLEcWWenvz4rUfxQ5bOt+TilGRSp
fEQzfluHfH9UoSosHoxKIwSYioHbagE2cTjMpYt0VMweNkAgCC/CiDgg9xYHTkop
YcQurBqXYIucMElUvvkGU24jENgkv3/UEcXbfnoSeLFG6o0fC5M3T4/BPDG3qjl1
4aXE5Rtyy8fyrSHmAun3a10AkbyjhnMW236LUYo7gFLDWp9VjuwZ00DbowHGELye
N7D0uRDN9Sjq4L5yFRiWNNMusWsbv4MNItBtgUVYyrB8CcE5lbrglkVXf1dlsbfh
olPx1uNpRuWD4xv/sbg4ctp4RelnPS6vbJhjYoznwNyhajzh3tylac3NtcGqQkEv
tUC6nNzhCpw3kfDbTBRgvaAabRcDZ3qGffhmmGHOv+DFuU/s2LTXvAnOcoiyQ0l7
9F99/OpiWCf6OZrmSXKwARR6jxKgtd3CJrrKA242d0uD/Iia6Bks7/E0ahsYUdNG
g6rV5maiDOxnMCWYwShZ8loDDVHqExlvP8pAE6wkqM4PRt5obkV1PSMcEZzjdRIc
A6bVj+7ZcFBOncOezcYW5OqVWxNRYVDb+i5YgJrgg0Aw6HCDg1Wffc1qQNGZzDGE
7KmNZfvxcd3eE2ioNmWpVfHazi6Hn90KV2rDUdetbDqtI8pP2CQz46llb84nd9Yk
NGCaQwKTbbvGZwCql0ms9ay/WP5DWdQ15LFEyzJnUDzV3xS3maCBszBqwxIg593o
EJ+ayLSbWB4jnegTdj4IGkALIgLNuqvgFRNAQQ9sgz/Ipvkd/LfhmcQV4cARViJe
Xo2RTlFINJVOXZCg74LGMQ==
`pragma protect end_protected
endmodule
