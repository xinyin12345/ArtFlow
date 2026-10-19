// Generated from frozen integer graph; register descriptors once per layer.
always @(posedge clk) begin if(state==NEW_LAYER) begin
ci=3; co=8; isp=8; osp=8; iw=W; ih=H; ow=W/2; oh=H/2;
dw=0; k3=1; stride2=1; sign_in=0; mode=0; src_slot=0; dst_slot=1; skip_slot=0; skip_sign=0;
wbase=0; cbase=0; ng=1; ogs=1; skip_mul=0;
case (layer_index)
0: begin // enc.0.conv
ci=3;co=8;isp=8;osp=8;iw=W/1;ih=H/1;ow=W/2;oh=H/2;
dw=0;k3=1;stride2=1;sign_in=0;mode=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=0;cbase=0;ng=1;ogs=1;skip_mul=36'd0;end
1: begin // enc.1.conv
ci=8;co=24;isp=8;osp=24;iw=W/2;ih=H/2;ow=W/4;oh=H/4;
dw=0;k3=1;stride2=1;sign_in=0;mode=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=9;cbase=2;ng=1;ogs=3;skip_mul=36'd0;end
2: begin // enc.2.conv
ci=24;co=48;isp=24;osp=48;iw=W/4;ih=H/4;ow=W/8;oh=H/8;
dw=0;k3=1;stride2=1;sign_in=0;mode=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=36;cbase=8;ng=2;ogs=6;skip_mul=36'd0;end
3: begin // body.0.reduce.conv
ci=48;co=24;isp=48;osp=24;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=0;stride2=0;sign_in=0;mode=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=144;cbase=20;ng=4;ogs=3;skip_mul=36'd0;end
4: begin // body.0.spatial.conv
ci=24;co=24;isp=24;osp=24;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=1;stride2=0;sign_in=0;mode=0;src_slot=0;dst_slot=2;skip_slot=0;skip_sign=0;
wbase=156;cbase=26;ng=2;ogs=3;skip_mul=36'd0;end
5: begin // body.0.expand.conv
ci=24;co=48;isp=24;osp=48;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=0;stride2=0;sign_in=0;mode=1;src_slot=2;dst_slot=0;skip_slot=1;skip_sign=0;
wbase=210;cbase=32;ng=2;ogs=6;skip_mul=36'd22485862064;end
6: begin // body.1.reduce.conv
ci=48;co=24;isp=48;osp=24;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=0;stride2=0;sign_in=1;mode=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=222;cbase=44;ng=4;ogs=3;skip_mul=36'd0;end
7: begin // body.1.spatial.conv
ci=24;co=24;isp=24;osp=24;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=1;stride2=0;sign_in=0;mode=0;src_slot=1;dst_slot=2;skip_slot=0;skip_sign=0;
wbase=234;cbase=50;ng=2;ogs=3;skip_mul=36'd0;end
8: begin // body.1.expand.conv
ci=24;co=48;isp=24;osp=48;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=0;stride2=0;sign_in=0;mode=1;src_slot=2;dst_slot=1;skip_slot=0;skip_sign=1;
wbase=288;cbase=56;ng=2;ogs=6;skip_mul=36'd3378372617;end
9: begin // body.2.reduce.conv
ci=48;co=24;isp=48;osp=24;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=0;stride2=0;sign_in=1;mode=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=300;cbase=68;ng=4;ogs=3;skip_mul=36'd0;end
10: begin // body.2.spatial.conv
ci=24;co=24;isp=24;osp=24;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=1;stride2=0;sign_in=0;mode=0;src_slot=0;dst_slot=2;skip_slot=0;skip_sign=0;
wbase=312;cbase=74;ng=2;ogs=3;skip_mul=36'd0;end
11: begin // body.2.expand.conv
ci=24;co=48;isp=24;osp=48;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=0;stride2=0;sign_in=0;mode=1;src_slot=2;dst_slot=0;skip_slot=1;skip_sign=1;
wbase=366;cbase=80;ng=2;ogs=6;skip_mul=36'd3863822326;end
12: begin // body.3.reduce.conv
ci=48;co=24;isp=48;osp=24;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=0;stride2=0;sign_in=1;mode=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=378;cbase=92;ng=4;ogs=3;skip_mul=36'd0;end
13: begin // body.3.spatial.conv
ci=24;co=24;isp=24;osp=24;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=1;stride2=0;sign_in=0;mode=0;src_slot=1;dst_slot=2;skip_slot=0;skip_sign=0;
wbase=390;cbase=98;ng=2;ogs=3;skip_mul=36'd0;end
14: begin // body.3.expand.conv
ci=24;co=48;isp=24;osp=48;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=0;stride2=0;sign_in=0;mode=1;src_slot=2;dst_slot=1;skip_slot=0;skip_sign=1;
wbase=444;cbase=104;ng=2;ogs=6;skip_mul=36'd3930531064;end
15: begin // dec.0.pw.conv
ci=48;co=24;isp=48;osp=24;iw=W/8;ih=H/8;ow=W/8;oh=H/8;
dw=0;k3=0;stride2=0;sign_in=1;mode=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=456;cbase=116;ng=4;ogs=3;skip_mul=36'd0;end
16: begin // dec.0.dw.conv
ci=24;co=24;isp=24;osp=24;iw=W/8;ih=H/8;ow=W/4;oh=H/4;
dw=1;k3=1;stride2=0;sign_in=0;mode=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=468;cbase=122;ng=2;ogs=3;skip_mul=36'd0;end
17: begin // dec.1.pw.conv
ci=24;co=12;isp=24;osp=16;iw=W/4;ih=H/4;ow=W/4;oh=H/4;
dw=0;k3=0;stride2=0;sign_in=0;mode=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=471;cbase=128;ng=2;ogs=2;skip_mul=36'd0;end
18: begin // dec.1.dw.conv
ci=12;co=12;isp=16;osp=16;iw=W/4;ih=H/4;ow=W/2;oh=H/2;
dw=1;k3=1;stride2=0;sign_in=0;mode=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=475;cbase=132;ng=1;ogs=2;skip_mul=36'd0;end
19: begin // dec.2.pw.conv
ci=12;co=8;isp=16;osp=8;iw=W/2;ih=H/2;ow=W/2;oh=H/2;
dw=0;k3=0;stride2=0;sign_in=0;mode=0;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=477;cbase=136;ng=1;ogs=1;skip_mul=36'd0;end
20: begin // dec.2.dw.conv
ci=8;co=8;isp=8;osp=8;iw=W/2;ih=H/2;ow=W/1;oh=H/1;
dw=1;k3=1;stride2=0;sign_in=0;mode=0;src_slot=0;dst_slot=1;skip_slot=0;skip_sign=0;
wbase=478;cbase=138;ng=1;ogs=1;skip_mul=36'd0;end
21: begin // rgb
ci=8;co=3;isp=8;osp=8;iw=W/1;ih=H/1;ow=W/1;oh=H/1;
dw=0;k3=0;stride2=0;sign_in=0;mode=2;src_slot=1;dst_slot=0;skip_slot=0;skip_sign=0;
wbase=479;cbase=140;ng=1;ogs=1;skip_mul=36'd0;end
default: begin end
endcase
end end
