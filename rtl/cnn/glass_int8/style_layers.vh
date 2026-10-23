case(layer_index)
  0:begin // enc0
   ci<=3;co<=8;ng<=1;ogs<=1;iw<=W/1;ih<=H/1;ow<=W/1;oh<=H/1;
   row_words<=W/1*1;out_row_words<=W/1*1;
   kernel<=3;radius<=1;dw<=0;up2<=0;stride2<=0;
   center<=0;signed_input<=0;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=0;dst_slot<=1;skip_slot<=0;wbase<=0;cbase<=0;steps<=9;
  end
  1:begin // enc1_dw
   ci<=8;co<=8;ng<=1;ogs<=1;iw<=W/1;ih<=H/1;ow<=W/2;oh<=H/2;
   row_words<=W/1*1;out_row_words<=W/2*1;
   kernel<=3;radius<=1;dw<=1;up2<=0;stride2<=1;
   center<=0;signed_input<=1;has_skip<=0;relu<=0;rgb<=0;
   src_slot<=1;dst_slot<=0;skip_slot<=0;wbase<=9;cbase<=1;steps<=9;
  end
  2:begin // enc1_pw
   ci<=8;co<=16;ng<=1;ogs<=2;iw<=W/2;ih<=H/2;ow<=W/2;oh<=H/2;
   row_words<=W/2*1;out_row_words<=W/2*2;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=0;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=0;dst_slot<=1;skip_slot<=0;wbase<=18;cbase<=2;steps<=1;
  end
  3:begin // enc2_dw
   ci<=16;co<=16;ng<=2;ogs<=2;iw<=W/2;ih<=H/2;ow<=W/4;oh<=H/4;
   row_words<=W/2*2;out_row_words<=W/4*2;
   kernel<=3;radius<=1;dw<=1;up2<=0;stride2<=1;
   center<=0;signed_input<=1;has_skip<=0;relu<=0;rgb<=0;
   src_slot<=1;dst_slot<=0;skip_slot<=0;wbase<=20;cbase<=4;steps<=9;
  end
  4:begin // enc2_pw
   ci<=16;co<=32;ng<=2;ogs<=4;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*2;out_row_words<=W/4*4;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=0;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=0;dst_slot<=1;skip_slot<=0;wbase<=38;cbase<=6;steps<=2;
  end
  5:begin // res0_reduce
   ci<=32;co<=8;ng<=4;ogs<=1;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*4;out_row_words<=W/4*1;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=1;dst_slot<=0;skip_slot<=0;wbase<=46;cbase<=10;steps<=4;
  end
  6:begin // res0_spatial
   ci<=8;co<=8;ng<=1;ogs<=1;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*1;out_row_words<=W/4*1;
   kernel<=3;radius<=1;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=0;dst_slot<=2;skip_slot<=0;wbase<=50;cbase<=11;steps<=9;
  end
  7:begin // res0_expand
   ci<=8;co<=32;ng<=1;ogs<=4;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*1;out_row_words<=W/4*4;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=1;relu<=0;rgb<=0;
   src_slot<=2;dst_slot<=0;skip_slot<=1;wbase<=59;cbase<=12;steps<=1;
  end
  8:begin // res1_reduce
   ci<=32;co<=8;ng<=4;ogs<=1;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*4;out_row_words<=W/4*1;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=0;dst_slot<=1;skip_slot<=0;wbase<=63;cbase<=16;steps<=4;
  end
  9:begin // res1_spatial
   ci<=8;co<=8;ng<=1;ogs<=1;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*1;out_row_words<=W/4*1;
   kernel<=3;radius<=1;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=1;dst_slot<=2;skip_slot<=0;wbase<=67;cbase<=17;steps<=9;
  end
  10:begin // res1_expand
   ci<=8;co<=32;ng<=1;ogs<=4;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*1;out_row_words<=W/4*4;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=1;relu<=0;rgb<=0;
   src_slot<=2;dst_slot<=1;skip_slot<=0;wbase<=76;cbase<=18;steps<=1;
  end
  11:begin // res2_reduce
   ci<=32;co<=8;ng<=4;ogs<=1;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*4;out_row_words<=W/4*1;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=1;dst_slot<=0;skip_slot<=0;wbase<=80;cbase<=22;steps<=4;
  end
  12:begin // res2_spatial
   ci<=8;co<=8;ng<=1;ogs<=1;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*1;out_row_words<=W/4*1;
   kernel<=3;radius<=1;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=0;dst_slot<=2;skip_slot<=0;wbase<=84;cbase<=23;steps<=9;
  end
  13:begin // res2_expand
   ci<=8;co<=32;ng<=1;ogs<=4;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*1;out_row_words<=W/4*4;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=1;relu<=0;rgb<=0;
   src_slot<=2;dst_slot<=0;skip_slot<=1;wbase<=93;cbase<=24;steps<=1;
  end
  14:begin // res3_reduce
   ci<=32;co<=8;ng<=4;ogs<=1;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*4;out_row_words<=W/4*1;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=0;dst_slot<=1;skip_slot<=0;wbase<=97;cbase<=28;steps<=4;
  end
  15:begin // res3_spatial
   ci<=8;co<=8;ng<=1;ogs<=1;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*1;out_row_words<=W/4*1;
   kernel<=3;radius<=1;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=1;dst_slot<=2;skip_slot<=0;wbase<=101;cbase<=29;steps<=9;
  end
  16:begin // res3_expand
   ci<=8;co<=32;ng<=1;ogs<=4;iw<=W/4;ih<=H/4;ow<=W/4;oh<=H/4;
   row_words<=W/4*1;out_row_words<=W/4*4;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=1;signed_input<=1;has_skip<=1;relu<=0;rgb<=0;
   src_slot<=2;dst_slot<=1;skip_slot<=0;wbase<=110;cbase<=30;steps<=1;
  end
  17:begin // dec1_dw
   ci<=32;co<=32;ng<=4;ogs<=4;iw<=W/4;ih<=H/4;ow<=W/2;oh<=H/2;
   row_words<=W/4*4;out_row_words<=W/2*4;
   kernel<=3;radius<=1;dw<=1;up2<=1;stride2<=0;
   center<=0;signed_input<=1;has_skip<=0;relu<=0;rgb<=0;
   src_slot<=1;dst_slot<=0;skip_slot<=0;wbase<=114;cbase<=34;steps<=9;
  end
  18:begin // dec1_pw
   ci<=32;co<=16;ng<=4;ogs<=2;iw<=W/2;ih<=H/2;ow<=W/2;oh<=H/2;
   row_words<=W/2*4;out_row_words<=W/2*2;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=0;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=0;dst_slot<=1;skip_slot<=0;wbase<=150;cbase<=38;steps<=4;
  end
  19:begin // dec2_dw
   ci<=16;co<=16;ng<=2;ogs<=2;iw<=W/2;ih<=H/2;ow<=W/1;oh<=H/1;
   row_words<=W/2*2;out_row_words<=W/1*2;
   kernel<=3;radius<=1;dw<=1;up2<=1;stride2<=0;
   center<=0;signed_input<=1;has_skip<=0;relu<=0;rgb<=0;
   src_slot<=1;dst_slot<=0;skip_slot<=0;wbase<=158;cbase<=40;steps<=9;
  end
  20:begin // dec2_pw
   ci<=16;co<=8;ng<=2;ogs<=1;iw<=W/1;ih<=H/1;ow<=W/1;oh<=H/1;
   row_words<=W/1*2;out_row_words<=W/1*1;
   kernel<=1;radius<=0;dw<=0;up2<=0;stride2<=0;
   center<=0;signed_input<=1;has_skip<=0;relu<=1;rgb<=0;
   src_slot<=0;dst_slot<=1;skip_slot<=0;wbase<=176;cbase<=42;steps<=2;
  end
  21:begin // output
   ci<=8;co<=3;ng<=1;ogs<=1;iw<=W/1;ih<=H/1;ow<=W/1;oh<=H/1;
   row_words<=W/1*1;out_row_words<=W/1*1;
   kernel<=5;radius<=2;dw<=0;up2<=0;stride2<=0;
   center<=0;signed_input<=1;has_skip<=0;relu<=0;rgb<=1;
   src_slot<=1;dst_slot<=0;skip_slot<=0;wbase<=178;cbase<=43;steps<=25;
  end
 default:begin end
endcase
