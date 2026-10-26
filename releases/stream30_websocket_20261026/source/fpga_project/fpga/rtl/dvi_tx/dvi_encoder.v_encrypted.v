`timescale 1 ps / 1ps
module dvi_encoder
(
	input           pixelclk,       // system clock
	input           rst_p,          // reset
	input[7:0]      i_bdata,       // Blue data in
	input[7:0]      i_gdata,      // Green data in
	input[7:0]      i_rdata,        // Red data in
	input           i_hs,          // hsync data
	input           i_vs,          // vsync data
	input           i_de,             // data enable
	input     [ 1:0] video_format,
	input 	  [ 6:0] video_VIC,
	input     [23:0] audio_L ,
	input     [23:0] audio_R ,
	input            audio_valid,
	input  [19:0]    audio_N,
	input  [19:0]    audio_CTS,
	input [3:0]      audio_sample_frequency,     
	input [3:0]      audio_word_length,

	output          [9:0]tmds_data0,
    output          [9:0]tmds_data1,
    output          [9:0]tmds_data2,
    output          [9:0]tmds_clk

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
MgAP8tzOM9z6fkEN7m8Co7AZXPxn37U2ZG9p9l+bbvXy0JJSr28wN2U0btij+vl9
BlAzzqz2UxvWDDxV6z7ciJMCghzMU4QJ4eM60aVUJ3BoS/pgHiG2U9KUHmwRArhf
xRF/+WdjimiLrT4kQJDAZvk+KwZC45tEeP1K01ik6KbJT1AxBHF3hA5pbl8DqUbI
0fdArrgmYtZOjkqbECD1nYWAIUggND0BtSqg4EiY7QeEX/b4cM40RJPF8+qTXhnz
VexxiXQfoOH1TFIT4hkn9nRJGmqrNhcOkO00EMzfxtV2+EtlB0cRTKpcd6w7RKcI
+AEHtiqTHnlCS/9ma8WFCQ==
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIF-SIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_block
Rws41J2mGvp0tAoV4GKAVkdVs2m51MkPtkeaxBeGX6MIpbommWyXgYzZ1aYfQkg8
Ot+2DM8s3it1q60WKWHyejWO606nd+09qemctFRAeWfxUGkb1XSAU/VQT9Led8Uh
dUxWD8zMW7l5NJFws0tsTZE8tBymKYzJ3f5/sTU9jYQ=
`pragma protect data_method="aes256-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=8032)
`pragma protect data_block
BhheAZSslnzjCGPuuUEfHORGDQu/hGLP+SHX4mrRTiUmWNE+HhabCLA6wOO3M4IN
MOC+YnqHJtf5ZXHqNV5Cxj2sU7hJX2/3vZxwFiWa3CekyuB0d3Rh1DARArD9Chtz
7MV1J2yUg1SAjL/Hs39Z1Coehr1EpinPf5duWafZGFqTQ9u0OHI0NyvaQBrdoWr3
TANcx6s7lWZu1k5k9Zu6NtGt6X4Y+v9RcKWUGXHImHSmkIgNlJgjBAQIUKBHAO8a
4ML8O1sgUPi3nW4Z4xAb24ofGQy5hQUfFscC/imLrbbvirrzDEcy10/XYAr8s/Ji
K7Z219azjBcN8dP0lPXAexF8p6R4BWffYEvb2eS8DHiZ5+PXkqxwDMEE+0qiZcor
yHYSZoblPqePqL3BfTWzS0h2WpyJEh2r7TbSDb1aal+ckZmFGHjBZMs3s5vJQpZ7
npxW+F64qP3DKfQSLti7e9UT7xedH8t6CQ6Rqzd/5ewvIxFDkvM0/9TePy47jv/s
nto3DdaHYaltPuv2xbxrrkfl9b16rms329FxJWsueEcu2Sfi8W0dqohoHc9mlLG7
nlMS8aobCRcfOja78kCsGVQhCYTsAmES/oDu0bxrQMUH3NJA4r7BaJehLLTkJv50
7waK21tWlGu4NwCP6MBWBNnWfL20yoaAhxuF7d3FeIzK65bwkWcHYAGeN6X/ZPHr
xIb8fsWrtBxcS5tEHvcdOgwSGKyBnaEyPmdGUKkyEQg9Ctao/cO5V6vwa1+4eK9v
L/lxIFQNJoHZifWYNvDA0NDzqwELM/UWsVURUoAIIq8EnjzYqKTFbiT3Dfe1rgk4
zvMNBbAKgUPzjLWV/phFLCWghQAAaR8rwDsKnt9T8Z0NUGdHOxxwD7u78rn717uw
dujuIcRCcClf2xb7Y10hIw34PU/ouDWJOcjWBrBkLwEOIr1qjVemRxpPF+Y7Xqhd
i0FVRK0qzGV31tMnEaHFU20TgelgfFNEy2hMIfrvooba7bWbA4R1mXngdMB/WC7s
eS853dJ9xZWgYTlT2RiBopkim7LBn93afmhJWMGKTKovWSk8RpMXwC+a/PoCVgmx
6ouM2XMnx67s6yeo/RWu1w5erq6NRH/RGfOOvWnnuNejsZ26yv4RM3XEH5y0UVFM
/LqSC81ya618zVEK7qkqhGR/RowJIyvw009N4qKuVcNk8tOLIddAnZYQB+R9bejt
b5DcS+r9pogRbRGi2+1pYpH0COjaUNlLUolZ95ZISJuMphYR6EZE3xAit/f5i+Yy
Kv/bV3Qjb+/+eTWX1QLOn71Lw3/QiUiIeZ4fQfO1PqyKnHt4LY8/d2ZOEqwD6/eN
YxKoNgeQXdFFU2FCF9gAmFeW08F5RhAm8Nrq19RyAyq7a05b2hrNUcF2rkHoAtpv
ChmbNSytHoUSX2WxcyEHRIXETC+lJnP1Hfejl6ut4PigS54yD+vBSSEYJVAPO9ee
wJ03qpvGCUGPdMDOPM+96v3A4SsUR+XKZIVBgw63LV2hKaVNs+DKwd9O9J6yFj/U
rLh5w0lW3K1LLSSEK9jBU/EdOG9whXp/yWgOr1vIC5Sa7HTQzBgpRjOCdLbpAWmI
TGgakFH1IJDM50COEwQffsS30PsPFyFd6wBgFgxkBMJq/kMLMQ/eamfgEBQ62TEW
JvH9Dav9TqkEZkE1653sv7KlQY3kJQ8lHj5WxcNx6QIchAWL2ZqUj45AUhZVr7A+
DZOYwHwdrp6G+83py0nx1OGDffUgkKkd5lUFGG+s8sJmkf+HcqyPrAdN0wB35lf+
n47lVEIFj2Q7/vowPC4xaauFqS6KTvOeNb2M6n0T6/KMYPG0k+bktA49T6UP7Bdd
Gj5XfsGlTph3o4UTItKyTrZlfI9IGd5MzgrvS03axnypf4GUjmN4o0nd1LNuGmgy
t8m3+PdyPlu6H6TnryY2exwUMBfINYYRya14HRO7sSXnPtK7bZxkgPd5IrMWNloj
Q/dpF14XgZBiT1+iTfVpu6QCWdOEO6j2IrL5zoMzsNbnLlBn2XqRCfY0vhRcNrFf
lbDMUMPZ3RYB+BEYoi2+beoK6I2fw8QHa8HUmbWva4UoD2LPevyMvdgIiaO+/q8Q
WAvIIDf3knlg2Hti81I96jrAb4wDx+63fillhXHzsikSycmyxoKYJsWtI4yt7A0T
wWnr5oK8qNRpxDMkjahwxUpYns/6e4vADeEbk8mkhNBzdLp9/HWZl2OIfUBHRffH
Tmsy+VfA/1MK0FOmsMybf+MSVzjlO/qQmwL0MFEF1hQv7ToVNVRB99+bMT6xULzQ
N9YPP5EDpuWuo8hG4Qj7WPfMtFpeltqPxwxXCWrkdyudt1jHv+wW4VsRo0Vxgd4M
V5NPiz66DpB/WbQEg7CUfanyY+eryr97f3GtV0bfTDsdMlM7hBJydXjw9ZZ4G142
j1X8vJ3CpqiQN0KmtCT3xQ14nlMsxhWtvTS2sL7Qpy0ldRoJin+dl1Afar09FUil
a3L9YxZrR7Cnx1XpBvrkNY29gabNlF0vg7bGY2Ee9GONkwqUfYfcZTvEeHQjSXiG
51XCJl+HpjpfRgCUE+D4WNvczU8H9Gw5/0tO1aQ52raHrvn4h0x/F/rFkethhOyV
YAj7bIhDK5zcb1XKvsMs33Oh/dRTtVnE8ZHHKRAaBHSy4vHY/1ndUn5ya1nsrogA
McZvyv53bQYmAVfgwusAfffT4OsuWdM/IdpG+qPsmVkS+gLLGX1iM/0TfErn/gEG
Y2E3Y01SRd+gPtB7QxCOs74lWlgIA+hHOItM+VtE3knzim1XQYN8Ug9u7BNJFRef
J+dR2NfkcKNo3u7ivE8yvZURYzdolSPUuXE4vb4c+Q2QsJKTX8Sce++KUok8isHY
8zX0uE8YdByrH7ExoE+LS7+TeX0nsQhsA3WVS4HZeKNqrMruOUOagiDM3hxDg2oA
C9q4TNC/uGLPJXHmTN7dkmXdbMSgoTqHGmeVx9LERIs9hbSRgOh8EPwDnn4NTvjY
mxFQSBa68j0AMuIWJkj2bKB9oM/JOeDq4A4GEPhWhugWLtKR33ollIkj23+IA//F
Coa45RDu29+eGjfxS0WLCRwdNc7O/N8A3CgOYXyaYFB2yCMxP1OeAzYDvtfXKwc3
LOeR0GRFLS4FAlUO+ZZEicW7VHRXnXXfdLZjHh2gF0NKNNYYxvTbsKb1Wu6FzKnw
qIpGBchMJWalom/5RVR65DEkweEiEc5D1hWvKnj5cfVhlMYKKBGc7q/DWulDRVrq
Kh0ibU2uUFR3zIu0iBCJ9bK9xiieGIQ8tcUX8VK3qjjYAzfWiB6CGs/mDZmbjOAa
trHKtqHVkXQJfrj2vtaYMt6GNVhBTceEsGewyIVD1AIrDF+j6/t2RAo5KSedkUW/
9DKYFreffkqEdCaN2PD7GmWx7TThJJWI6eGtqPEOAvM7R6pCWVk5qmD4cNo+iJHg
RcVMZNRoHVl9+2tt2qfF0LzXAw4VwMJoDYm5H4bALGDYWIsUIi3PnS3HNckghQsN
xCmwEr4Y+AP47Ej5APynZFfeDet3EjpUPC4vxynXnSXO8VZepBOwcmzVtlmPajkW
fQAIpJTA72cqms6EtXa1vGSoK36DTZVgHdJPfERSPEdD0Wr1/b6nOrKfdqnRBq/Z
oLxgj07XBbkqCnZI6gNF+/XFwvEXi6LxlhmHgc+W1Nf/fG/rW7q6iFZoKLwDEm8H
DwsvUD/D4AFiILvQbi7h9Hf/rRxxebSnbtuc4jF80WVkhhNSqJlm4Qru20Vuq9DP
WU8L+AlbTOr55762oi6BicYfYvIL+Ojn1YlP5/J23+oFe8olE0N4Ifur2iD9X1V7
wuqEW3rgrDexY2040W6RmBCr0oJ+3wBq/qxWi8tUDPXFuN8i+gLPEG2ZebnmbQW/
ES59iNqAL/xjOd4TU0gjqG0yoGyFtnU9csux9KcPkiOcDDTYvl0sl2XZ+oJIcc02
YS70AXmRi1VxWHHlEupWeHWLaO5gdQcSRDfH54N1CEbYq9bpK3Ju4yxcKNT02jNK
InXtqGKlg9+fM6tYlma4psCnxt3YwP6s01BkGnh8SkWHPYnte+nyfdKUTXksKUYX
vk5WdS9bS1MC4KtzbvSWCUpj4TLH9WzqnGzG57xoD5SZIbIyBCT43xJaJF/+bB06
6DJi/z8ZcoUnphDJya8tzMrRh1z0noAQlng1yDovHR1K7rb+PmLZA5yCI1pyVilK
XGqWyltY1qMQETqJrOt12f+G9gln5PGUTTYL8h6AJMMoTL5+3JG6MOnN60OaSsYI
1uRIrHRlNrSXltUZyG72HKrKpryqPjcT0MZF1vTQQ+x0MrLwUaZ605UHHU+ciXLo
qPsRy+v3AcSJ5Ke8qKrVfk9gUQbZRb6hEWxzfFRi/oc0aKGbXNJxr3Zdfb0yZPxo
20nMltohO3lf6AaSlkqGdJxVrWqILOTtzuGao0kLmT3m4yRVnVo6QDrmL7Vdn9cI
z++NHAAe0O1oj8vhFkXLmwZLSCvBWxefI6m7PN/Dlo6TzQI+GvG3ihEeWP4Wfedo
spK0gJ6ZZFZqf9f3GoS2RzP7YIgiqqyPO6aE1nGh/3qvd7enQO+h6YeqHpFmtvhR
uUtZUMtYGGqzjJyIfI5VTVGEQ8FLajqdfaYRjQe4Rs/d4FjvmpljingXfT0lViEd
6vrFs7i6Vm909nVfqpleJkd8CYSnlgkjazVM4PcnGnyLuTNBFmALPixRPE/F5sA2
/r+kR9Q+8+5rxWcrDXIpJRKdDDELb8osMDxU/R8bX1mjNv+Nm9/UGVwhINgj93ig
uzgWsIXJlwx0QysBvkEMvp1WkwVRKO0Ytk7m5tQlF51fowKdug7fgnkQDmqtmn0b
H1d5L4lu8I43XJVMLXllaXA90QmlkHY3+Us1rBn0B8yMcWtCXEylaaCY4NAGBrg5
l4FlFeD8tcPaQHMferGnytFrmumyUrSEFtVTAY8dK/OU/WNm70b+UuOtk3aJlFD/
79RoZWE8f9hb91jaHHRhVvtjn5Qa38MC4TvJG+JxFOXM/rjyLfhuA/E2K+Upujcg
B9N7TU4uqN7y00/k+qq3p4PyDL3OihmRNZuNLpwosAB3MLy4rz8o1Rn1O9XsBCi1
BFzCm2DOengaU/JNLr/cwwndab5VmGG65qUtmPje4p2VvVvSH+8nCkyLrKjdN38x
K6KaPAg4zS3YzvgQJtuEA4ZqdbyUGw1EDSI4s+3rEglsX9kUBgOyyPlA/tDf/sXi
uHrsC1zcpupyFaigz4QroHFoG1QjyAIWdFo4UM5jEJVF0PxicyNG58i1Plb66Oxn
R7UeF4F9EOcA2vsYgAaflzeNjGJBycqbMtPMWUclkm2KyZHyjWTF1o0a19c41yI0
6jqPMmCkJxB6UzeVZxuHffe8l4CmPmF3/VcILXbOnR/gQbZw6y3FWk15BCKjjoqZ
nQFa4WeBpvgz17rD3DzRMXxXv9xvFZHzbh+fpruOh/tH+AVlkKg8MbGZ7GIORBUG
z94xEo41oGNssfBb8sYkNZrtVC9vbahCnbhS5YJwSPXuHp4u4w+69tEOvXsEaAlC
veQ3z3wEjd9T4LXXWx5u/2M0nMhERaVOwyYn5fjmedai3uTQ11x19mBYxfpoIjGK
nsNY8z3ABiPixI5gxY2l4IfBNtj/w72mFVO2uGNyCmCmlyzUke2FmzYjROjwaz+H
CmclLe59oXswTesnExEWPEX7eHlnwPVBvEpQJWGZnebQAo1erlL0dOToXLKCy62L
uBTJ3XaQLkkgEn5myL4pYX1xrCUDe6jRAfzk/DHwMbpa05SSItsFrWvfWzZ61Sqr
yKA08TArpHL2+pVkIUqbqaFZuVgNaeuUEyjxs9GkKfx1cbubR5H4b9MxoJZ+8Nwk
ytIXKoojWgB1GKUqSqRjUy/q/XbA/V3PKFozsgxitrDh+RiVixf5HqAEQp/BZbzs
qawxAuRSJbeji9zefY+v7Q77AHNmSVuqvOy6O58vqRMHZu0aQzD0d6TPOoWdl9bo
RGOpTcIurRbcWXwQEVTFrLHBZFHNY9A9fT3BO+sKNz3A16DAerucd+E40xJQGz5t
T3b5LLXGmlQP+ZIL1TXpi/NrenVzwuwbYOPdq8CHI+OzaD541HKk5jhgFqyh6gI/
5k/xQAHy33wZcquWtLb9LWWfygPkR1N7378wdrnTUudmZ0BQoQQoN95X7qw5mg4X
zEbSqp6yXeBBSPU1NFhDmYCYHyI18knyH1VrcHpkKzbqG1e+wHsBsztJX32AEqFH
CaAHtSUs4yOF/pA626uSrUL8stH4K0jyd9nTGilkQS5GEK/hpiEdSRed7dG/Ywya
XT5q1wi9ZrvfSPuhz8W1bTXzUEHLlqrv0uaw8nuQsxc1HGhZadFvAIxp0ozTI7oU
hwmLjcijiXbUokhapuo1uHJoUw7/75/cySS1+ISlAmDs1+L6BWMLnvJRJutQtrZX
fgLfPeKA3gh9gdhkaVvrkmzvDF2kouZE0Ag8FGAQlakOPHlpPcAe0+tHAsFVnCqi
6UZttdovBCCnfgJQVJTXMHKf8KUoMRQeHE3A/wmBCw+XWK6Bu6+RQS+mYPHO9VVh
rjPj5C0rG6yJwzeVtOAZWObNDzfNukt8A5jmXHuQeVJwUAIeRLxieU9WwfCURKdl
nLdNZ3htHTr9K0EsBQa5sqnoDm44sDvg/+4caBGKrqA1MfOSq/dUKbaXQpBI0Lme
konEceWZh604zdZpcIhF005fKL8URUUvM2z2rl/eI/h43oAq3+R+xBuFsE6AbB7s
dS3JxNxx1tPBSGkfIYVGPXTMEX8U9AeBLDkjFdnLKtyeR6UXFvC5bTB7oiyxx80e
g42j9cRBTq6ShtKLNx5gUTjI8DTCsHuVcPuSxsLv+0DD9P4xNlfRHAtCcjF4b9GC
B7mddKaW6b0kuxzsQxRO+qkceg2yOT+frl94NP43aWCqW01u140urNSpSsKFS4Xc
Ydo6d2Em6v1J6PSq/5PwBRfKuA0kPPrgqNc0TTFXp1qocg2V1oe/fyzDCYUVourX
pDXuoAou3Nk0IRqbhyQtTtELb9rDTuiLfe5kQWiQP0mNm3XopW/c+Lc9cTPWtlRY
KM2/2JQ+tT6TG+eJjaW6WMlq6NPO+R70mlEQKLYp6qpZMfOzsn5u1YUpr0J0EwOb
TC3eDEYBS40HHY8A1ZCQKi9FpFed5kFx5bu5BnCRinMhCJc7xfQASZDL2qzgS/hI
LlNp9en7K/17j9SE0yxff0SxlIh9fkhlTZJWzLpGTJSssNoO/RbpLuBigX1O5/sd
ilarO23NWryu/VJq50WqN0wW9DC1FN/5L0IJRX2svfK15ElHhoB7zpOJnwbt17n3
pNb8dR9ZZ80AgCNsOURZ44d0i+tebmfGO/2CxWXxnr3DN+L5lO7Eni4Fuc5jnxAW
PsbDp2EcrXoO8YgMY9iF+lba7CD0p/nTNCVDcn2R+ZAwU17cHO+CINisb2UXZQ7O
4QbLFSBHSBo9KOmdDty7m+1JDYrwpnVFLNMVA70dYp7wARn/PeLku1Df7sj+Pf/h
csCsXX1pTpdO7Qjdu87rtS77aLSHk7jkngzkCRqNDn5wPqOj4hCisLni7x7UbL8p
opLZ0KQOXdc5VyIlZVOqDIFNX/0c8gwdjGwcA6adDeeD0ZTKSkhSK9f0ykdOuXT3
wWvzyypKZSHFKJLeahb7fOV1snZkiODaXiAdEWpUaWFmzJJj2zVegBNs6giGVEb+
UDYb6zdvA3sM2Kr+4Qp6fxbLRwM4UJdEvPnR4/G/X8z8wI84Fa/Py/tDfID3akXS
iRVoSIEe0QvUlgSru5A6q7yAGKtk2LZPZcFp19EUIpM/qwWJTflrKdRl1Vq+VEbs
jdt4L2hArlda6aFQnjz4usBY5JbdhMhdwawhjHVDGU1tBUgq7obnywxVTvfMMeWL
aAvNTcxI0kaWkPAi53prh/dtlCcyd00js/lWuB429qQNHXzWA64CVuvVTSWf6wge
/Qmi/AS+5OFYaHog9JAqpP09eikKT4eERAwPLWez2HH5+DzAkiFWgnN5ic8q+TsD
9nMN5DbZmXO5Xslgp20JB+uNK18+fIc+r3bKcRv3nezAJqQ2xhp7CHMH2qtge8EW
+xeAkjwus58AJDvsSPRNiXTIaUFZ0nfIew90cbzIpjyWjW4dRNxWRYpIP/hdUYfb
crEJ0PoZL7AqsTeEY7lpEm20evuIFwQ8JXx6OwUZVvevMZ5qjX7alxaQ04f4C4+L
ViA0Tdtp2PZP0AXPrKENRb5+okzQYXn+e95fgBekhQPuOpw/CqtK5EuTaRM8egGv
SHihw6KtopmGql7DTrT0p9a12yDub/nNIxcoFzQ2LBp0xhPi3/x8AaOqli3PLpI4
DyFltmG2OViYb6qX3+a7E7LF559Idetl1SQ93h4F7RUD/JVXBN17AcMoPLp+iBnh
rrYBNwRtlvmPfuYXiZuh8Ma3vmbEBm2FnTHFZ4/qCB5YquHhZnEDxQk4IR6ci8u+
LLBaK2netDxltp/XDrV2UvJqlAzNkhMVdCHabzNQu0+qxgHGPSsOsijqO2X9cjLB
kr14GHIBWBX9HFTB5Sd0r+M/qkHCexubu3wC/ixYquNYbcsjMG+rfHVAueSeLByi
69yCkTvf7rOw2+lILnuH37XEEQAURDnp7ZyCbETFvxF3Fv9Bx2FtGWcujwNxhvtS
EkPDR3L1akPgnAiPIbqKumH5NBEspOMKOIJ4BEYygVqLJt1TBjfMQiEUeW97VE5v
8L1nq4IoLC515tWzL03byTS+0mn0Y+waQGd9qbHfaiPjATjtMyipZX8XFcCeJQJc
NZZVwDrKI8e1fm922KyHP1odx8iSsCw5jyWtfEx+G79rDrqroVLzhhMAqxQzq1OK
4QIu8sUfHSF8GvZsOvFhY/1T0U1UJytdNTZd+CdXrutAsPEdLl2CZRlrFtsishW7
q232f2rVeArRP6hzyGrZLnY/hfm3bUY5NS3RKMBFmBq7uF6YUSKLbx4s9xg0NIhX
Yvek0yag0V+XXc6cKqLhJpoWBJWEFKl4a3+OdRG2y2pSnCevI8tEvdZBSynlM9ve
kX1JE1qZcd+XUM6IXFOZOnGGgGsX5zzqKjfJRaupXvHhpr6D+BWmFB7oq/L0U58C
403jzz8Mo806ME3vA3+xihOgCc22Jtx3VViRfI5cLRsZU21DOecFzgNkZRHkQBNz
y/1dv4j3ySj9kPVeeP24DDGoKKKh/cPV0VdKtkqkhf+qIE6bktyE6zACBvSExTv2
Mxas0zw1l7m/8inxaVmgxf+dO8Ji9igLKPV1HjG1xWEQMbwlVA8EyaZC0HcEyFp2
4jnKQq/b0QvtdyFX0hpPdStoiw8+wRbfLjZ/BwWPaBNvERLofv6+NHJmYqXd+Ysj
Z7iP8b4QUxWdL3jCsxqfpspQKOYv67qt7H0yYzZgos0wiI787PdHJy1mzPruQiSh
YnjKXJN2x6uiXueVfGYYe8ZxLhZ/7Hpc39ObbZmllN+dSV19/5cSiWsjEfSr4sY3
jB6GKLUjJ5cV5JI5UuCfes8J9Fea1i1WuacMERtZ/GnTpLlHUhNjoz/UanLKhNPr
XFpfKgf9yMVT/A+SwNqNr8Wfj4IykOLQilGz0VcwR2fcWQYX8eTx/azJmF/jSx+C
u+qYQsmegttm1hd+79x9JAhnsvJbh5tZiS4fUfkM5mSIy3Iq4ZnUixY5t3JrDVml
KMzVgKT6kvihxLHpbojTdbMJvWyXK1cUzYwdfg9mK6pqEL/3C2tg/lBxMCbVGLuQ
VrKrWhwVrl1ORktzOzp5O/JOQoByZ+jYr4cerQA7XittFKju4/p6lIHdMdEI0+nH
3Q/M0l9qbtidS2ObtVQ+0DvD+azoaHsZty8xpnAwfZ1IiEJS/rQmgA4c6+qEm4z0
EXHTC9AXkucbutFDSkwc6qLBUWUBUTyBCB2nl1hfd4ryL3cevGXzvxXtixflJWrg
zDKaLeJaihleoVYi9pMH19X6FKi+E3mdm7ZeISBz6LGEJG1Gmu3NwubZFDclweEX
TENy2SmqwWA5QNNwDZUYTLCS2xL9EFs71hk2lNDeV5gDCzWgnG9njcDBHgEvHrJW
FCVKTx9SEA+yx6+IRAtcZ1aTqjNkS4LsLFkaDYECJ1Yc/gt39kQ7ONLwJMapCOuh
VHc1EhVsbtjAp0TdHjTtooTy/WBR7vOv+2B3n4dZFYL5VaHifDAlQ887BTeVJ21U
uOxxGiE+6Yc4Y3hhCn6e+jyGJ+Ql+EOasztFkVvKSRm1a5DEt98zb/8KkdV+RROh
TNYqJ3OtYxxfoZ2OcChUNv8FE5toi/GA3qqVsg/akQVaVF19J1B8Emc+AqiL4gHH
KzeFBzOKz/ykL4EmpuJ64nLbTsGLqZ85TeKy0nh8+I2BI7pEXYPjdodC4wBAUawk
h2ozA7ueYdvghiALhlnf9UuNRv7wuMgJT6KiUAh9sydyc97JLTyXHjLbhjCmftDI
UWPt6f7qsWqHVSKGQ6TTp4JnVEHJooUaQtIj3Zvd1XXtFAuxyrkS8OvKPIiNOlLi
R2yKFgTR9kiuL0y7JXAhj/CU+fXfWONsdeLLgiv4QIcLy5zLuANFZCNGy/DMAI+U
j7Lk1J/z8DuDJZHR9/MhiYxlD5Q30Mb5fmv+KYgIfgSXCKS6Sg4mRhM+VsL0JCQK
FzayuTZsoHM+yo95d7jusg==
`pragma protect end_protected
