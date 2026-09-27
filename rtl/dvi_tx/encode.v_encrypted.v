
`timescale 1 ps / 1ps

module encode #(
  parameter CH_NUM = 0
)(
  input            clk,    // pixel clock input
  input            rst_p,    // async. reset input (active high)
  input      [7:0] din,      // data inputs: expect registered
  input      [9:0] aux_data,
  input            c0,       // c0 input
  input            c1,       // c1 input
  input            de,       // de input
  output reg [9:0] dout      // data outputs
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
MGaD8NQgTWBMwaK9thVpXXLuEkCpLFdBVLK+oVcsv2veJoZlkOPFMemaQMS630a4
gZyCL5kqidKV9Qdmn8z1zxd9/gqNvS6PORDeTkXFJ9peKrED8wL4Egy59pMBdmw5
/jL3fmIb7XmhR12wonzkU0VQJP0EGolA4+sL/hKUTmgSTgqSFaZFf95fY8K7n7jS
ZaONsJlJt4iRNPVYxwvEzTfD8QXOpGRW7IkW8/OZUnD1hQlipGFwAZrU0eOTniJn
hhUbrsE/T0lgzZT0CAb9fcQsjYt1u+seCGRERnRoHUaHGtljh0JqwU2jwAi/vbgZ
+GXVQ9sXbEXX08JAyMYJXA==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
NmqFWtkbD6dI5GgSoSZI+Z72IMQWBS5KWX+0lm5Rkt56D6BtLg/rqHVrsalhERao
5TJpdRmCa+gLJeYwgtY0bOf7+un6YqXUo9aBjUWm8LOuSFJt4ZJoIqmlA9kpHIXm
wdQdFiR3a/8NHUgs6qXFJinICM7PYMg9E5kG+QrLIoA=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=4656)
`pragma protect data_block
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
`pragma protect end_protected
