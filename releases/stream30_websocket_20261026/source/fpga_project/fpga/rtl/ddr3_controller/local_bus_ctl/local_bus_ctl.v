//***************************************************************/
//   ______   _   _   _                  _            _
//  |  ____| | | (_) | |                | |          | |
//  | |__    | |  _  | |_    ___   ___  | |_    ___  | | __
//  |  __|   | | | | | __|  / _ \ / __| | __|  / _ \ | |/ /
//  | |____  | | | | | |_  |  __/ \__ \ | |_  |  __/ |   <  
//  |______| |_| |_|  \__|  \___| |___/  \__|  \___| |_|\_\
//
// Moudel Name    : ui_wrapper.v
// Version        : 1.1
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

module local_bus_ctl #(
parameter                       TCQ        = 100,
parameter                       CK_RATIO   = 2, 
parameter                       USER_DW    = 256,
parameter                       USER_MW    = 32,
parameter                       BANK_WIDTH = 3,
parameter                       COL_WIDTH  = 12,
parameter                       CWL        = 5,
parameter                       BUF_AW     = 5,
parameter                       RANKS      = 4,
parameter                       RANK_WIDTH = 2,
parameter                       ROW_WIDTH  = 16,
parameter                       ADDR_WIDTH = RANK_WIDTH + BANK_WIDTH + ROW_WIDTH + COL_WIDTH,
parameter                       MEM_ADDR_ORDER = "BANK_ROW_COLUMN"
)
(

input                           clk, 
input                           rst,   
input                           mc_user_en,  
input           [2:0]           mc_user_cmd,
input           [ADDR_WIDTH-1:0]mc_user_addr, 
output                          mc_user_ready, 

input                           mc_user_wren,   
input           [USER_DW-1:0]   mc_user_wdata,
input           [USER_MW-1:0]   mc_user_mask,
input                           mc_user_end,                                 
output                          mc_user_wrdy,  
   
output          [USER_DW-1:0]   mc_user_rd_data,      
output                          mc_user_rd_end,       
output                          mc_user_rd_valid,      

input           [BUF_AW-1:0]    wr_data_addr, 
input                           wr_data_en,             
input                           wr_data_offset,           
output reg      [USER_DW-1:0]   wr_data,          
output reg      [USER_MW-1:0]   wr_data_mask,     
input           [USER_DW-1:0]   rd_data,           
input           [BUF_AW-1:0]    rd_data_addr, 
input                           rd_data_en,             
input                           rd_data_end,            
input                           rd_data_offset,  

output          [BANK_WIDTH-1:0]mc_bank,                 
output          [2:0]           mc_cmd,                    
output          [COL_WIDTH-1:0] mc_col,                   
output          [BUF_AW-1:0]    mc_data_buf_addr,

output          [RANK_WIDTH-1:0]mc_rank,                           
output          [ROW_WIDTH-1:0] mc_row,                                   
output                          mc_use_addr,  
input                           accept_ns             

  );
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
nNdGzlZ57aPAVXyJ7zywwrkdqqdn0OH1P5XF/5Noshdl6oS+GnqPd03iG2+i3MbQ
pZvV5HpDoh/FLl0eTVfhKjU5iZGaZAjVkkTets+bJ/cryfpCNTji+GFC5MrwJ/33
qN925gYDQSoIg8/Dhrx25Q82zxMH0ZuONPrjgt0GzupHzZHi6LBuQsMeqsfNYKHP
u031rWP2OccQvVYXdNYIzW0kJddq7MBvR6qoC39Zw6ep9GWt6yAiSPlCEUiI4yaz
OV+Pw9TLEvm1DZmz5RVm74d16NDj4QKjsWvny7581O0gYaxNoQZ+2Pf0566fYOHA
rFZcyyBle9gjJTMNmQ8nxw==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
SFLnlrb3jbC+3vYDFdS8LGMkAuWq1Qy5vZLlgfaAs4hjTSk9+Kncj5sBK2JjHaaE
+1VI3SyrgSXAId2OSoDbxJiSoavGAWGLAaRHm3SfOzN0O39AEEo59FPsOOBmFcII
zkyWPcBssFK94dMR+Jxjx1DKb9Og+e0ae28weIjWWZ8=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=10688)
`pragma protect data_block
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
`pragma protect end_protected
endmodule
