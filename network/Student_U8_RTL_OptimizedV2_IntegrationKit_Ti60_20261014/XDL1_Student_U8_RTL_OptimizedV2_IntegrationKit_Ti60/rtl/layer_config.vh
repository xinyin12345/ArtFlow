// Generated from SHA256-pinned U8 integer graph.
always @(posedge clk) if(state==NEW_LAYER) begin
case(layer_index)
0: begin // stem
ci=3;co=8;isp=8;osp=8;iw=W/1;ih=H/1;ow=W/1;oh=H/1;
dw=0;up2=0;k3=1;stride2=0;sign_in=0;wide_in=0;mode=0;center=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=0;cbase=0;ng=1;ogs=1;skip_mul=25'd0;end
1: begin // enc1_dw
ci=8;co=8;isp=8;osp=16;iw=W/1;ih=H/1;ow=W/2;oh=H/2;
dw=1;up2=0;k3=1;stride2=1;sign_in=0;wide_in=0;mode=3;center=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=9;cbase=2;ng=1;ogs=1;skip_mul=25'd0;end
2: begin // enc1_pw
ci=8;co=16;isp=16;osp=16;iw=W/2;ih=H/2;ow=W/2;oh=H/2;
dw=0;up2=0;k3=0;stride2=0;sign_in=1;wide_in=1;mode=0;center=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=10;cbase=4;ng=1;ogs=2;skip_mul=25'd0;end
3: begin // enc2_dw
ci=16;co=16;isp=16;osp=32;iw=W/2;ih=H/2;ow=W/4;oh=H/4;
dw=1;up2=0;k3=1;stride2=1;sign_in=0;wide_in=0;mode=3;center=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=12;cbase=8;ng=2;ogs=2;skip_mul=25'd0;end
4: begin // enc2_pw
ci=16;co=16;isp=32;osp=16;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=0;stride2=0;sign_in=1;wide_in=1;mode=0;center=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=14;cbase=12;ng=2;ogs=2;skip_mul=25'd0;end
5: begin // b0_reduce
ci=16;co=8;isp=16;osp=8;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=0;stride2=0;sign_in=0;wide_in=0;mode=0;center=1;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=18;cbase=16;ng=2;ogs=1;skip_mul=25'd0;end
6: begin // b0_spatial
ci=8;co=8;isp=8;osp=8;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=1;stride2=0;sign_in=0;wide_in=0;mode=0;center=1;src_slot=0;dst_slot=2;skip_slot=0;skip_sign=0;
wbase=20;cbase=18;ng=1;ogs=1;skip_mul=25'd0;end
7: begin // b0_expand
ci=8;co=16;isp=8;osp=16;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=0;stride2=0;sign_in=0;wide_in=0;mode=1;center=1;src_slot=2;dst_slot=0;skip_slot=1;skip_sign=0;
wbase=29;cbase=20;ng=1;ogs=2;skip_mul=25'd7356220;end
8: begin // b1_reduce
ci=16;co=8;isp=16;osp=8;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=0;stride2=0;sign_in=1;wide_in=0;mode=0;center=1;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=31;cbase=24;ng=2;ogs=1;skip_mul=25'd0;end
9: begin // b1_spatial
ci=8;co=8;isp=8;osp=8;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=1;stride2=0;sign_in=0;wide_in=0;mode=0;center=1;src_slot=1;dst_slot=2;skip_slot=0;skip_sign=0;
wbase=33;cbase=26;ng=1;ogs=1;skip_mul=25'd0;end
10: begin // b1_expand
ci=8;co=16;isp=8;osp=16;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=0;stride2=0;sign_in=0;wide_in=0;mode=1;center=1;src_slot=2;dst_slot=1;skip_slot=0;skip_sign=1;
wbase=42;cbase=28;ng=1;ogs=2;skip_mul=25'd11944935;end
11: begin // b2_reduce
ci=16;co=8;isp=16;osp=8;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=0;stride2=0;sign_in=1;wide_in=0;mode=0;center=1;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=44;cbase=32;ng=2;ogs=1;skip_mul=25'd0;end
12: begin // b2_spatial
ci=8;co=8;isp=8;osp=8;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=1;stride2=0;sign_in=0;wide_in=0;mode=0;center=1;src_slot=0;dst_slot=2;skip_slot=0;skip_sign=0;
wbase=46;cbase=34;ng=1;ogs=1;skip_mul=25'd0;end
13: begin // b2_expand
ci=8;co=16;isp=8;osp=16;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=0;stride2=0;sign_in=0;wide_in=0;mode=1;center=1;src_slot=2;dst_slot=0;skip_slot=1;skip_sign=1;
wbase=55;cbase=36;ng=1;ogs=2;skip_mul=25'd6978807;end
14: begin // dec1_pw
ci=16;co=12;isp=16;osp=16;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;up2=0;k3=0;stride2=0;sign_in=1;wide_in=0;mode=0;center=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=57;cbase=40;ng=2;ogs=2;skip_mul=25'd0;end
15: begin // dec1_dw
ci=12;co=12;isp=16;osp=16;iw=W/4;ih=H/4;ow=W/2;oh=H/2;
dw=1;up2=1;k3=1;stride2=0;sign_in=0;wide_in=0;mode=0;center=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=61;cbase=44;ng=1;ogs=2;skip_mul=25'd0;end
16: begin // dec2_pw
ci=12;co=8;isp=16;osp=8;iw=W/2;ih=H/2;ow=W/2;oh=H/2;
dw=0;up2=0;k3=0;stride2=0;sign_in=0;wide_in=0;mode=0;center=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=63;cbase=48;ng=1;ogs=1;skip_mul=25'd0;end
17: begin // dec2_dw
ci=8;co=8;isp=8;osp=8;iw=W/2;ih=H/2;ow=W/1;oh=H/1;
dw=1;up2=1;k3=1;stride2=0;sign_in=0;wide_in=0;mode=0;center=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=64;cbase=50;ng=1;ogs=1;skip_mul=25'd0;end
18: begin // rgb
ci=8;co=3;isp=8;osp=8;iw=W/1;ih=H/1;ow=W/1;oh=H/1;
dw=0;up2=0;k3=0;stride2=0;sign_in=0;wide_in=0;mode=2;center=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=65;cbase=52;ng=1;ogs=1;skip_mul=25'd0;end
default: begin end
endcase
end
