
module simple_dual_port_ram
#(
   parameter DATA_WIDTH       = 8,
   parameter ADDR_WIDTH       = 9,
   parameter OUTPUT_REG       = "TRUE",
   parameter RAM_INIT_FILE    = "",
   parameter RAM_INIT_RADIX   = "HEX"
)
(
   input [(DATA_WIDTH-1):0]   wdata,
   input [(ADDR_WIDTH-1):0]   waddr, raddr,
   input                      we, wclk, re, rclk,
   output [(DATA_WIDTH-1):0]  rdata
);

   localparam MEMORY_DEPTH = 2**ADDR_WIDTH;
   localparam MAX_DATA     = (1<<ADDR_WIDTH)-1;
   
   reg [DATA_WIDTH-1:0] ram[MEMORY_DEPTH-1:0];
   wire [DATA_WIDTH-1:0] r_rdata_1P;
   reg [DATA_WIDTH-1:0] r_rdata_2P;
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
BF2LdCtuDZkPo4+GCvIsfsXre6zQX9WGc6PoWdxQI1hCDJ2PetKVOQZoWfEvkrzc
pX9z6mjge9Ko6MScTv27JFG7VUUZxWs/72tURbAUFaQhxMTQR1V9UKbOBYgWoW6q
5VsPrxzKSygmIbm1f66vBYlsDNtqervmf13ytW16aWre2nLUg6Gr2jMqaV0eaPyT
L0PmLTHCdSslYENMNb3jzvasNHvMcAUN2MSIcLEnYefNIz9jnbda7j6X1fxEfgjV
2lkW7IoA/8HWgnNeGCSGCKlt4rxa/lEMtAHfaTVwGfSDKU1WgFxXd93mMveAW1ZX
6lrPA/IikZgeH1vbmUFPFw==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
CVePkbNS6SbYgiLeaGpSs6+mbOTYC0tw6igx2pJyiVmOtqOdlVKyPxT0OY4k1oed
JwZckALvoaiY0ozh/rb8r+B42RVALYPPvLCmrcEz+Pq4DohnQAqihuIs1ic2dv7O
mPOif99GIxXXcnR5CkmTzlpUbMkyYClie/PrmwyY1ew=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=960)
`pragma protect data_block
3Wx5eSHkVx8W1h125IQc/x8aI9I8gUKP+Kq87NR8PZ5V0tc4yTJbUPPirRwUKS00
nxIVQtg20vYJTsZXUJ51O/1/0KFufKa6xggVtFP53YgLfjjViEoEZPapXsEJ3IyF
Ew0L9Ni9N483dT77Yio6Uq0n+PvAofTOGqnLZPa32JA7NGaNtQGz/PSYYYwwMApo
6XJaOhiw17e0B64FFqAFq+lZwHKBo73/Dewd/knGlLM+2iLniGw6a0tt7PQ+ctAK
5911dyMjKaD26HrXD8ZY+iKXUuKEeL4crISlmABHr5n3/MqoVmW6npsO1/WFT9AB
gmK5TKoRI3GGc8M4qvY+KBC0phSpKOW/UaNN97GFd0o08EEBFcbWOUg2/UEOlIgr
Wze8iNgMCgikA9x0lca9kh869Dmj1nNAZOKiXAqwm7pAhdnIW9UH8jqGyE1ZLicg
kSXlccBfeIbxOGzkMZHSd0xMVaiAWYx8yO1MMaISDUtYIKV0M5Gbz6ZQOUpdTHLl
4YflnDGgOPKUpLtxf1hP2gzzeBIXO4DeALN26FA2xDihwQIuia4n69MOnKMt+Oeu
ueqAqj0Ec+6CoV4liEu6OL45gh5bhslpiOHo/402I3KEPYtsKC3/ztjcfbGorWZ+
w2G/R5ZnFT6kL4FtgHNTDfViZsPMKeiLh+pbjndqUaVQIsL2yXjBKVqJVXhsQaS5
th7xwFOoH6mJAdXrhBIzrQLEQixJSfgCaw+YFOFEMWUhzZwQ4ep11MTPrbJ/zWz6
utS5LboAF5+0ipo1NumZfLbAwpdnCVvqKDU3zx9+DB9Lyb9bl/fjm1ur5b1sZtyl
Buuici+t9M3TqftwpHUDInopAv9mC1Ti28llmVFjyAhk2i4IuFy/Sz6DcMrr4zln
p9JAJ2b1XyLrBxhoPGyw2Bz+ByjkcJOUnsfpnH+EL39SdAlQUSeBxp1oQoi2iAz0
8CpIrW1GO/9LQX/BDpcKq7f4koFAxk2cvGAmR5b0RrNEYc/mv3La59dFBF6EgAs3
lW84rSa0xOaDJ92D7nOBUwVlCYOB8MUDuOt/J0daoI3pMlbgTDd9YxG0NHdOgqqi
KYPY7u8CVX2YnNIC914qqBqYNyl54qocgmurrf6SjoMmUgs6UvdAFeqOP6Bvtue1
LDK3GBcUozzip6d2MTZWlnvcO5D/VgSiw7MPwJsz/SNdbXz11EqgCuj5gsTkBAUh
HJkSqW/kZPWN+1i3pyoAISFzAGfEMqq6thmPGUreAZAd6KLoQbcvToC83beTkKjL
`pragma protect end_protected

endmodule
