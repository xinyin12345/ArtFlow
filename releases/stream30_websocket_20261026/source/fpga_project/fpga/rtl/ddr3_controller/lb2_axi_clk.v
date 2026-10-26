//***************************************************************/
//   ______   _   _   _                  _            _
//  |  ____| | | (_) | |                | |          | |
//  | |__    | |  _  | |_    ___   ___  | |_    ___  | | __
//  |  __|   | | | | | __|  / _ \ / __| | __|  / _ \ | |/ /
//  | |____  | | | | | |_  |  __/ \__ \ | |_  |  __/ |   <  
//  |______| |_| |_|  \__|  \___| |___/  \__|  \___| |_|\_\
//
// Moudel Name    : lb2_axi_clk.v
// Version        : 1.1
// Date Created   : 2023-04-23 10:37:59
// Last Modified  : 2023-04-23 10:37:59
// Abstract       : ---
//
//Copyright (c) 2020-2023 Elitestek,Inc. All Rights Reserved.
//
//***************************************************************/
//Modification History
//1.initial
//***************************************************************/


module lb2_axi_clk #(
parameter                       USER_DW    = 256,
parameter                       USER_MW    = 32,
parameter                       BANK_WIDTH = 3,
parameter                       COL_WIDTH  = 12,
parameter                       RANK_WIDTH = 2,
parameter                       ROW_WIDTH  = 16,
parameter                       ADDR_WIDTH = RANK_WIDTH + BANK_WIDTH + ROW_WIDTH + COL_WIDTH
)
(
input                           axi_clk, 
input                           core_clk, 
input                           rstn,   
input                           axi_rstn,   
input                           axi_user_en,  
input           [2:0]           axi_user_cmd,
input           [ADDR_WIDTH-1:0]axi_user_addr, 
output                          axi_user_ready, 

input                           axi_user_wren,   
input           [USER_DW-1:0]   axi_user_wdata,
input           [USER_MW-1:0]   axi_user_mask,
input                           axi_user_end,                                 
output                          axi_user_wrdy,  
   
output          [USER_DW-1:0]   axi_user_rd_data,      
output                          axi_user_rd_end,       
output                          axi_user_rd_valid, 

//----------------local bus----------------//
output                          lb_user_en,  
output          [2:0]           lb_user_cmd,
output          [ADDR_WIDTH-1:0]lb_user_addr, 
input                           lb_user_ready, 

output                          lb_user_wren,   
output          [USER_DW-1:0]   lb_user_wdata,
output          [USER_MW-1:0]   lb_user_mask,
output                          lb_user_end,                                 
input                           lb_user_wrdy,  
   
input           [USER_DW-1:0]   lb_user_rd_data,      
input                           lb_user_rd_end,       
input                           lb_user_rd_valid

);
//Parameter Define

//Register Define


//Wire Define
wire                            u1_wrreq;
wire    [ADDR_WIDTH+2:0]        u1_data;
wire                            u1_almfull;
wire                            u1_full;
wire                            u1_progfull;
wire                            u1_empty;
wire                            u1_rdreq;
wire    [ADDR_WIDTH+2:0]        u1_q;

wire                            u2_wrreq;
wire    [USER_DW+USER_MW:0]     u2_data;
wire    [USER_DW+USER_MW:0]     u2_q;
wire                            u2_almfull;
wire                            u2_full;
wire                            u2_empty;
wire                            u2_rdreq;

wire                            u3_wrreq;
wire    [USER_DW:0]             u3_data;
wire    [USER_DW:0]             u3_q;
wire                            u3_almfull;
wire                            u3_full;
wire                            u3_empty;
wire                            u3_rdreq;
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
boiaeuM5AC/9+5LU+PbgY3R2YW80tBrlxgBq3sVaeKYAXYbjpykvNPcZl8z88Xsq
uVeWmtHmwPqaiaPCuW0YSMf+OuBrukArsrKuCTkWIVJzo5yPrLJ8Zc0lgoddNWuo
61zSCa8PuKO/JPiMpAJ1c7XTQTVloOOAhJq8n1ZY7LsKXKXLLATT8NtACgGfsE4j
2cC3cu/dB9oLk5vaWyMV+nUnzZrV/FWRmw47vWyDo1t5jQ64iJ3EFkTjQtiC59IT
w1+/4JUtlQmQBwG21mTyEmWhNpC3gB8KvoGDwvpEQ/BxBWrr0YovMuZMhNuOdEIn
/D4ybcx4JTxmR107GbrOBQ==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
XeTTvp7yTFxrRmGrmL9MaWJk6RJKkAkVkBtQgBwNqQZWGGL5Uzy1qaGPjAU8wKkI
GMzRVd+icKMr4P0aChKbbewoQM8G6mA1DcSLrmsh02szXrHZdYq4XFAsXtS8/RYe
NW5VY75HdrD1gGr2KI6SK3P9xHXGvh6wCWvpVtLG2Cs=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=8032)
`pragma protect data_block
hBroPnVJ4gyiTpwMmFy3QPiSbCEZUUe9MsSO9AV5STA3nEB2yn2tnijjfCJWnTUa
hxprOmeX1HX1v0+gY+HH2ym8J1KoMdaicrHZKbpeSxGEpC7G9FKqgjKTnBoceiYl
Jejvomgj81PwSq38STN+cuRPxsMe5f+XpvZ/oX8e3vb4KaFuA0SH6lVNTc2/i/Hh
/KLIa7gJnT8+Y0p7vhUPrAycZDd/M3fg1u1A3BSp9t/Ylfi0X6cge/7ljOKeGZSt
2YjNH8N52/zUjy9mrnuGkrBxXoJYke6XwyL2BgxRgaA5ZBg6l3QBWCWFWWMYEA5d
C9BnOEpqfCTQ6Cfzg2SYvzYEeLGjrlx/9YRYtZu3oKZ8qjpp8sD57Z4/zNovW/K7
HlThogXgvyTCc8gGoagabSIfWoQ+Ll43vmOeIWgzyqXLZ+1im1ddqVicjcheLqO9
VZBlf25OxIRPq73L+72hUh9JGchoAX6cYf+CjnnJqOIZGstBFRdIfxmU5J7fQtAW
n7aH+ZutvKkY1mqwUCgt70E+iX4FJbNiWIwhL4cXAmjM6W8/F6XvvKdTbZMESn7z
5W4myxuBk6dOd77XA1AjO8m1A3ahB7HcbXFmTK9fwD9vZErDaZkN9Fr+8QwnJbQG
5gDLMizzqW+KPV977iYI0h7wPCd4x/J/B4FNjYxf135vXkBeR/Qnh8X1QlOHgcXd
x2i35OZ4U2iEZuYYqvi1kEH170ws87haFwE2xaDe1Y1JsqQn4uZU8Jy4FJ0Q+Jan
qcB+/faGlbFNxZo4V+lo8KRpsidsIWjlYmVkNv6Gu7GRlILXbQGVlTUvocIfT9SA
YrX4iASCgDa7Q58Q11m8OzyGk0OX2DiBn55Yw87DnuayXBf63R7RLmeu/HHP9Ko0
NbaALr3krEg49OfVpgVIIspgcKRhAX5SgCGtX9KeNzcugEmlhD/KK4aXClCfMbMo
rJYE+xPKTb8M96IGt90BLhQXqM/XDO5amdYIOwtyU37pDpNH0JAMsRsYL6xihe57
h4HW5BQlv9yLXPSoYOnXoC+iqAlTOnMrsUgxopBxYRXttNyn4X0wdT2MmPD2eCVh
q8j5fqllB/1LKsGBU+Us7VBMhRWHqqPGBUoY8iLE0q58aVYy7kuodjGD8B5rJjlm
vyEmTj7YxvHOAJxysUMb6bbE53AZh4RM334FtKLErBAarPE5FuCpq4DE+xbPMNYb
khoBf+Nmtm1nv4tv/ESJ0zeYR4pwAWD/kMDMIFJ0dYyvhQ/PyYLJElkLzm1wX8V3
wMMEDCoASnl3EijuCS2xI6onB5NU2oXkZt3QImZ2MZO9RV8YnekYGv3ZyqqwdcbP
hFIiI4zktD+PqmoODpDCEk/CG4ElH7voa9e74v+OmcRCMhNB2Al0G086GSm3W9TB
hsaqdmmiQYlfi/WbpZ/vO4YKFVy+5vHhFMl9O4YJB3Bt/p31MGB5GsX/IY8S97Uv
EyFVUgbaV80FA6tQwwKaNl3Za7bmFWHTLhbrAv6ItZuvpHX9v57Khzwgt2Q+z9jf
h9g3mwmkjf7h6YpnhfG5A1owlC1MHzsCSs5ZTpM70t0VNcwL3+D+Lprlx4cS/r49
SHQ4xNrjLrkP3gd63SJUE6Uvq0c1kQ6ZcimjsfQ1jP8mtc93LT9OimPjkemJUGze
LRpNF66VGdTgOWc1gyolUPgLONZq0ePtjFS1EQCq1avt94zO60X98AH3aCYnhrWX
hH/GweyBBPSRkr6JYdI4z9FLpA3KxUdWGW4r2QsfWH1KG44R3zBX7gcBVVg7QvNX
eDOiDepivME37GWrU9nS6S9iiWhfKwwIzrXGQhfzxGV9WKHcIhdcHjA+o82kXo18
E6vvxJYWOs2IE7mGukPllD6oxaS0sDsuuuVYXae03NyGfybct3Xo/tj77gRvGf/j
OzrcRLb1r2ExqZqukqfTCd9ME7VH7JymZw3Y0QZcx9UEq0kvEQs5m+ktJtRnek2a
9/LsHDBxVSTFbInTyL0fnDqpRZwQfC3RouVUlcNZyXXYBLnb0JNEj+2A08Befnik
yqxk38cqvTC4WEamJGhkYS7s9Rf8OZBu1/BdikIdXmNo3w9QgLAWeLvqGQYw8rYx
Uv55Xzv6PkUEbfvDelt5fMGDPAPqFWt3991HnG0tzSMCW8HVGUDU/cl6D5MBdNED
psbr+kSu2IUtVaowva4/txuFG8XubAj+zHT+Izv52GNKi5iqtALAV+BG9OTOhIwG
C38jQ8ZPyt3OcAb1htEqikhosIqtULVvb+uw2Xg8Y4fSzDgFcaW/0PKD+Z3Xg1vw
Y39ywuhEMp2gFN/GolVTwpl7DtOSCVOsdyhyop0RdIYRyvRe3LnUYQmMIrxwwUSM
weBiEF0JkqcdtpXOnX94A4HdRxZiZadL783m4hGAIdDIO+hY4nzcHuMVULZrhQOf
3ljiO4LMOmuaB49g9JoJE+VVTfYuTmJr1jxszAhql2VeTCvczGPkE6j5shEEquqw
J8NSUzqwxpauv9vLh2EN7KXV05cKN5CqAqsvU69+kmZDwyaGP1bvkjaeuOZf6c3+
4jWIlKhJ3aO2p304gzPWorL/Fg4rNydXAKqS/tjKJdZ27qxxDO0FkamhNgJGvp/n
EnxJppOyGKzhfwVskvuWdNc76G4gKzfDv4rTmy8KvPWIUwQ+joN4XudVFRxgz7Sa
hqmvw1v8VXaZMH/o6L9kcmoBmH6ajyeBVTYVxQD4EOG8hBdj5e6p0I0DmMo7+HTa
pZ7u8Y4RRpQd+NmUwla8060rJ/wPtUZ9nhyIvx0rsqjFD9ySvV9MQ6oyFRVgU0mP
+PgLYE7Jzar6In26OajxyM4j+uIJauoGtWnq09jwwc5O/4mLMojwKTqkO6/J1a1C
bodHMfyLYiIaPFAntzLVT1WjYb5pzRBRH7FUkVKQSseXjamziTPuwZdmPHj1BzIF
SqK6ZgO3XYzFhuOXf993mta91ytMsrfU3Uq8Hm9/DS+WafDleSc1kavQluvC8YGO
FS7ZOIoXuQqhjdoJWqfShkchEmwPewN2EVSzHA3RUftrb5Ja6MZUr21Lj4ZO6FSW
fIwm6egnXo6Yp1a6QHqq1qTm8CWoTJic7wPwLbQ8cLWypIr2QTLb0zEdYSuD8hSO
FP+7ysbMQ1vDeQDiksIfaN7yk9zqR+H96vAmrBIky+G/ZhUqZA9sBuZjXslIyqmE
RzRR/xWTc65WOuROkA3xoorhPgjYpuVwGQybpAhYCWOBrCZDV1TnMf+aqh6iZjiT
XMuPbpj1rtt7hd9eMqGmg6PzeBX2rDdZ8E1oQLg0E6Ct64EROAEuc3lbpsAyFZ9R
iqtbRKZP6u0AlRcTd63mlMf0s7VaJxEI6DSeguNW/gy2KReDea1QgETwW3dzrHv5
q+TPpAVyMm2DINktpCSpkHG89O0jC9oIqJi5D4xVZqsLZ4zwK07FUpHYjW75aGlu
vGcbo9v6erJJqztzt3fOwox2R36wwhJKsBwcM8Zd3QVrM4yIgH0VemOMxlm4d/FS
027G0MBGUcBzLK5kytTCp1R8qrNLeUJ6OaQiEmkqOvIzFMn8gp55OVfkH7d0K5vy
7uOhX2BdVvFKTQUK3k8sZ2tYW7hEerhpR/pG/Jxy4exEalCoIhj+1zxuy3vvRoBW
8jIgaE6ww//Plbwp9yo5cnvqI/TBlIEIZ6teGwNQbgPzUWlYG3TQrHKsObj5C7zf
vMLig4kbHTCRsrBEoy9+x1VwGDCRvQj7KLrd7o4waqXElE+wM78+NCm/35dEyA7l
AkWwrhaoCuf89HsQgc3XFppQjoz9fOTsQBi3RVpZdUexxVT4BCQpdkUE+pI6eiJj
++M+PpUV03XKABw/0B9QlC/4jz1Yyo95ERR8Y9V9EsvUZslD7aqFjn4Qcjtzbs2s
g/eDuKBDeVmfUhNM7ctJ4TtnPC7QPN24xzgGcgt5sbITxLTAPchcLyFzght2byqM
esDIHTBSLDuvZyAOHeITAYg6xoaDxzPx1e+As3AEoLQZz3VtmIDM5aWPhUSlRIU2
6xocP6yFeVdkzieIPx4Z5GPo9rC2T6V5RRrM3xZTJ+VLp0Qxe3nmfg4Ez4PXN79g
5H/fOrovlPCkP7/eOpxIv6GUma+SGk6EcobqXwj2IpCeDLC6GJZvbyT5Apc6wdFd
f9w84SKYB8KaFG4e8dibJA6diZCDlz68S7hcZHQytAjJdmIzbNlaYhJRp46re7tH
5x3/toBJdWG/JJeVo5+MKunlKim6OSY0I0G2KGKxNVVHmYTiRWynFjtlhgRCmd2X
iO7ImNIb5b8YlaYwW7sU3WfC8hyPYNquLXz304N32oT9dkiMWinDLBSBGAaz2Wxx
UhqNG0cZ8dUqcvGMjwPTNiai5n/VCpR4oxx1inliXn8/qOuD6q5idjmV4+keOVLH
kW6hp+WhAIdRoksWGpUVHc9KZaet1H4tEGd7EdeR+BNPxR2cvDRGnaj1n+agGAnP
TZp1QORPqDkdelsp1z+QmIL6aVouUnkJjL40m9mzYc6wcSY4upsxW/LGIjgWmFOU
U8uM/YSDm7Ch07jQgUbzOp9Onu6hhleBb2ki4yxOd38+Mp65zGbpdxrsmn/P9eF2
x4Qkml+oI74wiDuIqjxn17SPxXgc3EsEAKhpYjch7FDyw1Cp8NCKe/jLRfmioebo
tZZhdB8DtS4JEhHXzJfb8qmVEqUw2uJ85G6KdsTWIZnFYYRzthUue1ZCZ831ANlT
x92cslZfFGsO1QwisPOpyWZ3M3SRIuspyHlRxDscDkyKU9Az4HnrN7jfKMTn4xSZ
xvOWje2AyfNjj9azQH5Aazuw9DYW3YYTHkQx0n7tb89NgVPuDN5YTORGreF5TpvE
nhcfLBMGqhSjwPPZxNnvYLLyZhHxi+xxfKrcCg7DmkJgNlN4su6XExplcic8e0zp
oC8CG6RxeckCGm9MgybkKZyUcdi05jdE2W8frvounDoWCtY65G9IsJq581kvu6Vi
ESI7nnliRcUUz2UvqMqgENYW3OCvz0CEEYClbvaWhovY5kXG01WvJcGea3YaKKlh
kN39J5PfjqxO0DywTeYnxrY2JFWBHL2o7N0Nc7N3iWD3OaTCRSpUb1EV2/cnSNTl
LK+WRh22BLRim0TD5NYhue1SFAdoj85TsfHlHzPK2pMBI3b+mQgcHmaoB79ptzYH
gVZ/JEv1ilZ6rxmOgv5LlML8aiH8emFEvot/ragKgt6ACbzkZGmXw1jSU5TzBuwl
gGV/LG2jQjMUaP6isz+A+19cQBfeYUHl/pnUjC60uDhJN+DRue7GeQzAUSLFipuw
qN72VbZRwNvWlzFBy4kXxi/PuaPAFwvIfhLeT9XIGODUWjBN1YzOiJiIyAHqsGQ7
HHt/DmRGA0VW3fPbAC+DjW8GohXyltIxDXCimf0zPFcWgaN05VLT3OQ+ed7wdCfJ
7jRYakn/ACAH/VOzZwybs8PrwCuJoNUTWWk8FIo9cvn+3uzIEF2319dt62kx7khF
p3oU9yodqTJxpHKJfi6u5LURXwmypFolGwRkGZaNJHqC+ssaTp6jQbxvSpWDlmBM
yk/VUL2M37y2OssNm8a7MssdCsxQzxGYgzwRQnz3bTIK6vuPm0YZ7DjqpeGrAcw/
H9EVarC7d+l7L44G3OM6PT1pVs4Rz59NZzd/sg/VTyQ8uExSFg9T5IlGsCa+D3ev
JiHjWiB0ltuv7Gd87q8M3K0p56fT+YgD2Rih8vRnxV0aFwrT3qzwTFMcOeY1vtHi
K8I4McERG0F6xJQXY0E+Ddh+Rjo+N85pLyYWvOUHedeLMv7lNxqRz4Pq8kNIORiw
mKiWxVWh0mnFyyTy7xW56hPYmwx+/eg2cs+vXEUWC4pVuqwwhAHYPs7vqH4ntfpp
trU/BjhZxlCieqVwptBYjAfBDqyJ4h2R/7y828FJ24ONwJGiEA3o24ULT1nfTgiT
xCFACoNcsxTwSHtryFMBcYkWM/sBtAMHdWk2Ux03F7OtonFR6SXV++igQVF97rZN
fgiHzXamOd62Za/H9/9lID3TQDlHAURzZ99BFGdh/dVWi8T1JnkqwRK6oYD3dhJ2
v0YuI89yrMue7PxG8RcXapI/QusBuONdeT4VFT11LdNQQLULj+bzrB9dT9RQLoHu
W/26FR3VrMLSnIG6/PFss1RMRPJNHNIePOPm0bCplcR0SsOpMe9PsEkeohozFWmF
plLoWEiT4jZn4cgasjQ+kK1CQa6prwxtiDV5RI1sBSTqn9l/JSrfKFW8gBK1XeA7
g/ST5jCqZntc9kjfYHjyqcvGfBnaY1A2QMjpTLMq3wpIOxQe41fBubighV/oyyQ7
/Qm0J+VMiStT5ds9vWxhVX+4i1qlnfQEuqqUSiPBO84ki6/Qt3LIw61onlQnjLID
FzvLuXKjZsQSSjubHQELBQjG0965AEs0n+fvNFgOavklbioxWgBKLcO6zjPM2aUs
rMxia0nysPnBtEBuoiOuKbR5kvwhytHvX95EyTJIANJKeNB6zWF0JdlByRPUuTqr
1VeHi9MAqpB8TZ5CAjQ0a+U7jM1gDVUerHfgWDdjsbN95H8KUcwKkEQChRbce8DO
upBwF4u2z84lJ1Whpu04tDkDxSYOjzyg02Jctd5kDy80VW1Kq+otY1GA39WXKCh+
tvOpH8SVm2NJq0pcFCndIN1ZeEE+4LIR0W4YMn4sp9izdc42UaDdM3EvLlSscLZz
NTGVIdEXMw1Ai2PrQoXXf4nAZLEktjfOf6hepDYU5/NPsGZMyWj+piidzzx9Jvug
v3R+uY7/hHdgecoO8/khnJ6Jhb+ggafjkIFfNQnGBz/9nUihU6R6Y4pEjDKvKQh/
8yXCUXotfUqcLfCl5ciS4aPGVEkvqmLecIN4lbcZfFBmhOGMxS+dEcy9Tmw8FiJE
bA2VKdbwa5Np5ErFL+DKwq5RZ5948UD+haluGerBNYcrAxM9hHwD2USkMSJ3eq6A
mUdpl0+i4UWRhv0Nw/KJV6SzygKRyeYqGCzCpaWk0ZpRxp4ImStBtBi1mI4TgyYS
rkdHjN2VJTn1009L0Dh2b4CT+gW103z+1qXz3c2MBUiCblqiXsTE3ER/9ZvivMjI
lxqbcNu/IY6LiQ5NcpIl2hmvjWD948cC15wCqAcNgFU1JlxBDQbgVIb95Xa0sP00
Um+T3RvJjo3q4feuuPSCeg7iygw2Ieo0sFV8+u6YCw/M/WQRxU3ALJgxmbmppWMF
yJgVunsfe/m/xOceqgKdfcQ+Upa0+dDjxpaA+pz1rOEaRWPBEI6fovw71w+Kr78s
XF9ymVdohxrIDlht5T+pRGS6PpY5s6/aDGPKgf7ICGULi9PPqbF3z5f6Z1urn6Iw
lSHswHxWYpt4isHz+RiIubfbPDE4CjqTButGIu24vO0g1stGBW7C0YyU6W7k7S00
EtODRB5lfpXx32vnPURWucChdJB8gNl0zQCOxcV88Il5Ws1PMKaKOu2HxWNdsFNo
yaaiPueE3ve1oGrD0YbClLLpPEB8Qwzo3W0KUa/NhyFCDj/KpvZFAZ0PZs+08F9H
gj53tD9KErgW8dtiOFM/wLMCLwdlzJ0CXkdUyv2Aes6jHdPpGiV2e0iCL2XdSgQh
YqhnUCqNVi2LilzYajkAMoYK5/8hO16+cZRawBbPcCu3HhKO8fSeOghmdjixfg80
SsrmgovFG+6ki7xWRaP9UoFGHUp+9IabBJZmb9IpKSVsXvdAPmku5st8ABUFiYX3
fxQkPHr+s446mbEzc5ws1jWnuRC21rR+1cKK8R7bmRvEgb23fEM+zrcbK/eFeMK2
OJ3c6Yrf1IB5qsb+urQyvG0tsp/hSgLqxisGXh6+WZozhoSeejOagoZrFStp3BA0
oX3Jrfaow/1r2324eocXvCcMVJqrYAkT69xYgfya8sjKlHckq2ym0fhZWlVNIZzk
htm38+GquWzBlAY/7TQoGZuk+oid+u2psxHsHtQxEjmdnCgO45aQ5lxM4kzKQtzA
ATQmn1SWqzxZvZCVwTVo7nwC9khky0ciCylNytrwsYXYvvrUGT1RgewjaqwamLxP
ym/SqSCBruDVvmlwjSwnOKJ/bfl7QFp30eJtEh0NOsLB5ICbwt+lWGwKxYcXbVHL
hmzIoAkgZS4BeTV390OiH4Lh2jEosCK5oFgCHgd51o3e0AlZyIHXhc+9ZNv7hdE6
8O19q/LoqjOLK9arc9EW65uo6H7hT1WSeII+ABVfUcsY/WCQZdLMHWSo2u3d5aU2
/ld4y0yUqJioD6RfyY/MDfEAr037buP2ceD78+bc/0Ve3aY+AI9OfWeSP06Lcu7/
waWoke8r3EN7xJY9q50Pcl1W38Dub36KbNSij3e8d/fMMJtU7VUtcC4vMpB/9o3W
aOelTkMb78vCT+DxWN82GF25K9s3tIdmkjHPwI1cmhCTE3OzPBmf6/D0SEfib//J
lrcenn9GvOVTNqSL6279P++lSTTfe5OI8i25hMixq3Rirq3ifTvWO89KHbQqSTPZ
aKPjD5qRZ9nlacGdzxRwjQOQC30YjdXQUhKG7mlIR2oADzCbOOMuOXhJlfv8Mxuw
rJqjLYegRB1M/esdRAvmHdE2nYBpLz2AMQnfgdeO8HP4tWSKIJJX4hz8AsWG6gAG
P/N1bPyYRK2oICx9u6LVrLq7P9GBAWuD9OkWFhDtqYY1/WcV9F1+fVqrE0ipX0bD
FHSOYeNMVr+asaczFQz9yeXI8E6RazV+8VTk0c66CFN5azXUrbG79bg8yUivn7lN
KpoGHL9P0EmMly9Tq2fqMZ9PfZJlumLXFYqtrC4/Yu8BWsojAoadDlB3wG2TnyLs
YMTXv7FTAszZ2tD7MfY8HzlGsbgu2bPZ30OO0+JvdXamyZ9EI7o2156P3PVAd6Is
YGwCWvuMXQOfAD/Yp1wD328gKcqxxHJcvZ1qIK8EnF3KEq4zCqsyVs1motT8vyQ9
yuIwYhVl8mMdTAgeAJgYVtKCpFQQohIue3lWlFtDctEYrDxwEPrKvHLgIKhYtQ5U
FLvRZ7fAdOqZJJ9f4qtYsviKlYCISjYjIDvvnUS5be/oiTtKbrURcwkQ1RMEbgsx
/y2FXc0DrKMJvQBhtZRibwDFlOnLvV77R7MWFCH3F1BCxR+8Wf+dxnkIdwQxDH3T
ZdRHkc8eu92Bb35lsdn6Jguz31Sj+9EkkSl+jZkgBWNirxju5sgW0r71ZnLB88mF
b17oHIXi9q5D4xs+c1Krih6JRCBDFD3LSng4FeyiDkhxahkHIF68VwrfgE9SI+zT
iqJmIr4ejrubCASBR3ACO/qeWtUyRztXPQDF+6yWx45v3Iq7oGgO1MbPkXLLiwgP
Pzd+5nT5Xo3xs5O7ifqmxCm8mrJOl8PxZF5MiRMq7L/XmV2U7fny084Zsc/5MClS
GSafro8w79oqxQaIsDQidOsdgRJ5zavtKdsPDFQWN4Hvr4TDIQ7eMrh+ZgpKiSi1
E5YWtcVoahCjJvFOi3k3SSMVeumWIIKh7Je0/H/ICfGNUnCVm2sSEHO8tT5Q2wib
z0sXIuU9fAJudfOqVlVve72oqZRu4FP8RhcgYbCIqd45FV7M1c9pitK0d2GrfGUV
OO3m7zUAX43lKJcMoW5H4i7hYrUIEWHD78GVxbFtAuzUtWw5CBDyPGFgpIwM+VSg
QwELU0uJTTHZAf2emxzTA6bSiAj3AnMR+S4tsHA0stWQYXKgjnYQwWmGTksD0jCt
ytg5lNPtG5UDLst7KadxZvr5zfbMKUgdre/rznviZ5gTvbgw0mTRerR4HBx0hGF8
4G0lEOcfSEepasdSmvlwnonTeMAxVj1kVuAt1DC8nttyONQ3/CxgS8aELrojxyF8
2Bc8Q/ozRFq1v4DCHwzHdkPB1XrUcoEvxvjRWz/o5mucZLOCiGrg95qLx5QoUOV9
FO6qI9EIumNm6bxgcuaAs9/8qGPJ1tji4kZud1S8hQpqqmL3dD1gOTgWh+3yiTtH
YHL1ssiM/ELnFkdj9dgaiLssFt1FsExjBqNqAwzI6afwet4NTFhlKQvbUV1pwz+J
ZKq4cZmify7gzEsKwzWu9q9JcZpB70XC32x0ac9y27v21xOtCj2a47wRAkNqcTZ+
c1IrNjRY60YOwDX3WMlgrR4wW1KcubfoCPA1j05AraqU4MSJ2c9EhVURNa84xx7F
K9kxiT89tKf6ZQRL36Ge67IOXev5BYrx6hSMHnfG3GsLWWVjwtsvV2T+or8s7wIM
6mgyQgP7cs7sEu/lB3+TnTJRZyYWCsmHRYN736JAxhao0oJSluRbkQvAeTxEZmUJ
gkWWIJhLk2S1fRKfKXujGivbgGEo4SeKvJNblC0poFj5dAK1tXDJkiyqkaAFZtCt
py4Il7NZC/IYHqna69lyLaz55u3iX8jgeHxtiLnX83147JHUO2qO5ah+rLNfC9a3
YG4c/LknNNyb4IZnCxSsA4qP0n2M/x0G8bDA13oO30jzfyziKcwTLz/fVKApaDm4
KSZ483I4EtJ3Nl61C+rcp/q7TJH1xNlTi9nGHpgD7IRVH/MmqCZwICJ+DnIHK93I
zrObI57RHW2wEghSr2cx/Mlnlz9cv0PixEBRYvsQdA7ZUyOtcslvoJpv3A83wDdz
bsnt/APHIZP54sG7nCnr2WodkB/nVZuDdWnyQ0pgPjCbaQogUhoFlDrFKtl1yt8E
uc5HklC3RDp8xOUeW9B0yQ==
`pragma protect end_protected
endmodule



