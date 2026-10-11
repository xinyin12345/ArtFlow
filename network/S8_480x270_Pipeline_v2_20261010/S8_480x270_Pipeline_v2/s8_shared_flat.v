// Shared exact integer CNN v2: concurrent window/MAC/output workers.
// One outstanding read; ready accepts command; response >=1 cycle later.
module s8_shared #(parameter EXT_W=480,EXT_H=270)(
 input clk,input rst,input start,output reg busy,output reg done,
 output reg mem_valid,output reg mem_write,output reg [23:0] mem_addr,
 output reg [63:0] mem_wdata,output [7:0] mem_wstrb,
 input mem_ready,input mem_rvalid,input [63:0] mem_rdata,
 output reg layer_done,output reg [4:0] layer_index,output reg [31:0] frame_cycles);
 localparam W=EXT_W,H=((EXT_H+7)/8)*8,ROW_CAP=8*W;
 localparam [9:0] CW=W,CW2=W/2,CW4=W/4,CW8=W/8;
 localparam IDLE=0,NEW_LAYER=1,RUN=2,NEXT_LAYER=3;
 reg [1:0] state;
 reg [5:0] ci,co,isp,osp;reg [9:0] iw,ih,ow,oh;
 reg dw,k3,stride2,sign_in,skip_sign;reg [1:0] mode,src_slot,dst_slot,skip_slot;
 reg [8:0] wbase;reg [7:0] cbase;reg [2:0] ng,ogs;reg [35:0] skip_mul;
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

 function [9:0] reflect;
 input signed [11:0] x;input [10:0] size;
 begin if(x<0)reflect=-x;else if(x>=size)reflect=(size<<1)-2-x;else reflect=x;end
 endfunction
 function [15:0] pixel_offset;
 input [9:0] x;input [5:0] pitch;
 begin case(pitch)
 8:pixel_offset=x<<3;16:pixel_offset=x<<4;
 24:pixel_offset=(x<<4)+(x<<3);48:pixel_offset=(x<<5)+(x<<4);
 default:pixel_offset=0;endcase end endfunction
 function [23:0] constant_product;
 input [9:0] r;input [15:0] c;integer b;
 begin constant_product=0;
 for(b=0;b<16;b=b+1)if(c[b])constant_product=constant_product+({14'd0,r}<<b);
 end endfunction
 function [23:0] row_offset;
 input [9:0] row;
 begin case({iw,isp})
 {CW,6'd8}:row_offset=constant_product(row,8*W);
 {CW2,6'd8}:row_offset=constant_product(row,4*W);
 {CW4,6'd24}:row_offset=constant_product(row,6*W);
 {CW8,6'd48}:row_offset=constant_product(row,6*W);
 {CW8,6'd24}:row_offset=constant_product(row,3*W);
 {CW4,6'd16}:row_offset=constant_product(row,4*W);
 {CW2,6'd16}:row_offset=constant_product(row,8*W);
 {CW2,6'd24}:row_offset=constant_product(row,12*W);
 default:row_offset=0;endcase end endfunction
 wire [15:0] row_bytes=pixel_offset(iw,isp);
 // Nearest-up2 3x3 DW windows contain at most 2x2 distinct source pixels.
 wire [3:0] taps=dw?4:(k3?9:1);
 wire [5:0] steps=dw?1:(k3?ng*9:ng);
 wire [2:0] fill_groups=dw?ogs:ng;
 // FRONTEND: fill alternating windows. Three input rows remain in shared RAM.
 localparam F_FREE=0,F_ROW0=1,F_ROW1=2,F_ROW2=3,F_READ=4,F_WAIT=5,
 F_COL0=6,F_COL1=7,F_PATCH=8,F_CAPTURE=9,F_PUBLISH=10,F_DONE=11;
 reg [3:0] fs;reg [9:0] fx,fy;reg [1:0] row_k;
 reg [9:0] tags[0:2];reg [2:0] tag_valid;
 reg [9:0] req_row;reg [1:0] req_slot;
 reg [23:0] req_base,load_base,front_offset;
 reg [1:0] loading_slot;reg [15:0] load_offset;
 reg [15:0] row_bases[0:2];reg [9:0] columns[0:2];reg [15:0] col_bytes[0:2];
 reg [3:0] ptap;reg [2:0] pig;reg [5:0] patch_index;reg fill_bank;
 reg [1:0] full;
 reg [95:0] patch0[0:35],patch1[0:35];reg [95:0] patch_q;
 reg [95:0] dpatch0[0:3],dpatch1[0:3];
 reg [17:0] dw_map[0:1];
 reg [23:0] offsets[0:1];reg [9:0] bx[0:1],by[0:1];reg last_pixel[0:1];
 wire signed [11:0] ycenter=stride2?{1'b0,fy,1'b0}:{2'b00,fy};
 wire signed [11:0] xcenter=stride2?{1'b0,fx,1'b0}:{2'b00,fx};
 wire [9:0] required_row=dw?
 (reflect($signed({2'b00,fy})+$signed({10'd0,row_k})-1,{ih,1'b0})>>1):
 reflect(ycenter+$signed({10'd0,row_k})-(k3?1:0),{1'b0,ih});
 wire [9:0] physical_row=(layer_index==0 && req_row>=EXT_H)?(2*EXT_H-2-req_row):req_row;
 wire [1:0] pky=ptap/3,pkx=ptap%3;
 wire [15:0] group_offset=dw?({13'd0,pig}<<3):(({13'd0,pig}<<3)+({13'd0,pig}<<2));
 wire [15:0] second_row=row_bases[1]!=row_bases[0]?row_bases[1]:row_bases[2];
 wire [15:0] second_col=col_bytes[1]!=col_bytes[0]?col_bytes[1]:col_bytes[2];
 wire [15:0] line_raddr=dw?
 (ptap[1]?second_row:row_bases[0])+(ptap[0]?second_col:col_bytes[0])+group_offset:
 row_bases[pky]+col_bytes[pkx]+group_offset;
 wire [15:0] line_waddr=(loading_slot==0?0:loading_slot==1?ROW_CAP:2*ROW_CAP)+load_offset;
 wire [95:0] line_data;
 reg read_pending,read_owner; // owner 0 frontend, owner 1 residual skip
 wire front_response=mem_rvalid&&read_pending&&!read_owner;
 wire skip_response=mem_rvalid&&read_pending&&read_owner;
 shared_line #(.W(W)) lines(clk,front_response,line_waddr,mem_rdata,line_raddr,line_data);
 reg line_valid,saved_bank;reg [5:0] saved_index;reg [2:0] saved_pig;reg [3:0] saved_tap;
 reg [95:0] masked;integer j,p;
 always @*begin
 masked=0;
 for(j=0;j<12;j=j+1)
 if((dw&&j<8&&saved_pig*8+j<ci)||(!dw&&saved_pig*12+j<ci))masked[j*8+:8]=line_data[j*8+:8];
 end
 always @(posedge clk)begin
 if(rst)begin line_valid<=0;saved_bank<=0;saved_index<=0;saved_pig<=0;saved_tap<=0;end
 else begin
 line_valid<=state==RUN&&fs==F_PATCH;
 saved_bank<=fill_bank;saved_index<=patch_index;saved_pig<=pig;saved_tap<=ptap;
 if(line_valid)begin
 if(saved_bank)patch1[saved_index]<=masked;else patch0[saved_index]<=masked;
 if(dw)for(p=0;p<8;p=p+1)begin
 if(saved_bank)dpatch1[saved_tap][(saved_pig*8+p)*4+:4]<=masked[p*8+:4];
 else dpatch0[saved_tap][(saved_pig*8+p)*4+:4]<=masked[p*8+:4];
 end
 end end end
 // COMPUTE: consume one window while the frontend constructs the other.
 localparam C_IDLE=0,C_SKIP=1,C_SKIPWAIT=2,C_REQ=3,C_B0=4,C_B1=5,
 C_MAC=6,C_WAIT=7,C_PUSH=8,C_DONE=9;
 reg [3:0] cs;reg consume_bank;reg [2:0] og;reg [5:0] issue_index;
 wire [9:0] ox=bx[consume_bank],oy=by[consume_bank];
 reg [63:0] skip_data;reg [143:0] main_lo,main_hi;
 reg [767:0] wrom[0:511];reg [767:0] weight_q;
 reg [79:0] brom[0:255];reg [143:0] mrom[0:255];
 reg [79:0] bias_q;reg [143:0] mul_q;
 initial begin
 $readmemh("mem/shared_weights.mem",wrom);
 $readmemh("mem/shared_bias.mem",brom);
 $readmemh("mem/shared_main.mem",mrom);
 end
 wire [8:0] weight_addr=wbase+(dw?og:og*steps)+(dw?0:issue_index);
 wire [7:0] coeff_addr=cbase+(og<<1)+(cs==C_B0?1:0);
 reg rd_valid,rd_last;
 always @(posedge clk)begin
 weight_q<=wrom[weight_addr];
 patch_q<=consume_bank?patch1[issue_index]:patch0[issue_index];
 bias_q<=brom[coeff_addr];mul_q<=mrom[coeff_addr];
 if(rst)begin rd_valid<=0;rd_last<=0;end
 else begin rd_valid<=state==RUN&&cs==C_MAC;rd_last<=issue_index==steps-1;end
 end
 wire mac_done;wire [159:0] acc;wire [287:0] dw_samples;
 genvar dwo,dwt;
 generate for(dwo=0;dwo<8;dwo=dwo+1)begin:dwout
 for(dwt=0;dwt<9;dwt=dwt+1)begin:dwtap
 wire [1:0] sample_index=dw_map[consume_bank][dwt*2+:2];
 assign dw_samples[(dwo*9+dwt)*4+:4]=consume_bank?
 dpatch1[sample_index][(og*8+dwo)*4+:4]:dpatch0[sample_index][(og*8+dwo)*4+:4];
 end end endgenerate
 shared_mac mac(clk,rst,rd_valid,rd_last,dw,sign_in,dw_samples,patch_q,weight_q,
 state==RUN&&cs==C_B0,state==RUN&&cs==C_B1,bias_q,mac_done,acc);
 // OUTPUT: independent accumulator snapshot, coefficients and write slot.
 localparam Q_IDLE=0,Q_LO=1,Q_HI=2,Q_WAIT=3,Q_WRITE=4;
 reg [2:0] qs;
 wire push=state==RUN&&((cs==C_WAIT&&mac_done)||cs==C_PUSH)&&qs==Q_IDLE;
 reg [159:0] qa;reg [63:0] qsk,result_codes;reg [143:0] qml,qmh;
 reg [23:0] qaddr;reg qcrop,qhalf;reg [2:0] qgroup;
 wire feed_hi=qs==Q_HI;wire [79:0] qacc=feed_hi?qa[159:80]:qa[79:0];
 wire [31:0] qskip=feed_hi?qsk[63:32]:qsk[31:0];wire [35:0] skip_codes;
 genvar s;
 generate for(s=0;s<4;s=s+1)begin:sx
 assign skip_codes[s*9+:9]={skip_sign&qskip[s*8+7],qskip[s*8+:8]};
 end endgenerate
 wire qvalid;wire [31:0] qcodes;
 shared_quant quant(clk,rst,state==RUN&&(qs==Q_LO||qs==Q_HI),mode,qacc,
 mode==1?skip_mul:36'd0,skip_codes,feed_hi?qmh:qml,qvalid,qcodes);
 // Completed output first, residual skip second, input row fill third.
 wire want_write=state==RUN&&qs==Q_WRITE&&!qcrop;
 wire want_skip=state==RUN&&cs==C_SKIP&&!read_pending;
 wire want_row=state==RUN&&fs==F_READ&&!read_pending;
 wire accept=mem_valid&&mem_ready;
 wire accept_write=accept&&mem_write;
 reg command_locked,locked_write,locked_owner;
 reg [23:0] locked_addr;reg [63:0] locked_data;
 wire selected_owner=command_locked?locked_owner:want_skip;
 wire accept_skip=accept&&!mem_write&&selected_owner;
 wire accept_row=accept&&!mem_write&&!selected_owner;
 assign mem_wstrb=8'hff;
 integer b;
 always @*begin
 mem_valid=0;mem_write=0;mem_addr=0;mem_wdata=result_codes;
 if(want_write)begin
 mem_valid=1;mem_write=1;mem_addr=qaddr;
 for(b=0;b<8;b=b+1)if(qgroup*8+b>=co)mem_wdata[b*8+:8]=0;
 end else if(want_skip)begin
 mem_valid=1;mem_addr={skip_slot,21'd0}+offsets[consume_bank]+(og<<3);
 end else if(want_row)begin mem_valid=1;mem_addr=load_base+load_offset;end
 // Keep command/address/data stable across backpressure, even if priority changes.
 if(command_locked)begin
 mem_valid=1;mem_write=locked_write;mem_addr=locked_addr;mem_wdata=locked_data;
 end
 end
 always @(posedge clk)begin
 if(rst)begin
 read_pending<=0;read_owner<=0;command_locked<=0;
 locked_write<=0;locked_owner<=0;locked_addr<=0;locked_data<=0;
 end
 else begin
 if(mem_rvalid)read_pending<=0;
 if(accept&&!mem_write)begin read_pending<=1;read_owner<=selected_owner;end
 if(accept)command_locked<=0;
 else if(mem_valid&&!command_locked)begin
 command_locked<=1;locked_write<=mem_write;locked_owner<=want_skip;
 locked_addr<=mem_addr;locked_data<=mem_wdata;
 end
 end end
 always @(posedge clk)begin
 if(rst)begin
 state<=IDLE;busy<=0;done<=0;layer_done<=0;layer_index<=0;frame_cycles<=0;
 fs<=F_FREE;fx<=0;fy<=0;row_k<=0;tag_valid<=0;req_row<=0;req_slot<=0;
 req_base<=0;load_base<=0;front_offset<=0;loading_slot<=0;load_offset<=0;
 ptap<=0;pig<=0;patch_index<=0;fill_bank<=0;consume_bank<=0;full<=0;
 cs<=C_IDLE;og<=0;issue_index<=0;skip_data<=0;main_lo<=0;main_hi<=0;
 qs<=Q_IDLE;qa<=0;qsk<=0;qml<=0;qmh<=0;qaddr<=0;qcrop<=0;qhalf<=0;qgroup<=0;
 result_codes<=0;
 end else begin
 done<=0;layer_done<=0;if(busy)frame_cycles<=frame_cycles+1;
 case(state)
 IDLE:if(start)begin busy<=1;frame_cycles<=0;layer_index<=0;state<=NEW_LAYER;end
 NEW_LAYER:begin
 fs<=F_FREE;fx<=0;fy<=0;row_k<=0;tag_valid<=0;front_offset<=0;
 ptap<=0;pig<=0;patch_index<=0;fill_bank<=0;consume_bank<=0;full<=0;
 cs<=C_IDLE;og<=0;issue_index<=0;qs<=Q_IDLE;qhalf<=0;state<=RUN;
 end
 RUN:begin
 case(fs)
 F_FREE:if(!full[fill_bank])begin
 if(fx==0)begin row_k<=0;fs<=F_ROW0;end else fs<=F_COL0;
 end
 F_ROW0:begin req_row<=required_row;fs<=F_ROW1;end
 F_ROW1:begin req_slot<=req_row%3;req_base<={src_slot,21'd0}+row_offset(physical_row);fs<=F_ROW2;end
 F_ROW2:begin
 row_bases[row_k]<=req_slot==0?0:req_slot==1?ROW_CAP:2*ROW_CAP;
 if(tag_valid[req_slot]&&tags[req_slot]==req_row)begin
 if(row_k==(k3?2:0))fs<=F_COL0;else begin row_k<=row_k+1;fs<=F_ROW0;end
 end else begin loading_slot<=req_slot;load_offset<=0;load_base<=req_base;fs<=F_READ;end
 end
 F_READ:if(accept_row)fs<=F_WAIT;
 F_WAIT:if(front_response)begin
 if(load_offset+8>=row_bytes)begin tags[loading_slot]<=req_row;tag_valid[loading_slot]<=1;fs<=F_ROW2;end
 else begin load_offset<=load_offset+8;fs<=F_READ;end
 end
 F_COL0:begin
 for(p=0;p<3;p=p+1)begin
 if(dw)columns[p]<=reflect($signed({2'b00,fx})+p-1,{iw,1'b0})>>1;
 else columns[p]<=reflect(xcenter+p-(k3?1:0),{1'b0,iw});
 end
 fs<=F_COL1;
 end
 F_COL1:begin
 for(p=0;p<3;p=p+1)col_bytes[p]<=pixel_offset(columns[p],isp);
 for(p=0;p<9;p=p+1)dw_map[fill_bank][p*2+:2]<=
 {row_bases[p/3]!=row_bases[0],columns[p%3]!=columns[0]};
 ptap<=0;pig<=0;patch_index<=0;fs<=F_PATCH;
 end
 F_PATCH:begin
 if(pig==fill_groups-1)begin
 pig<=0;if(ptap==taps-1)fs<=F_CAPTURE;else begin ptap<=ptap+1;patch_index<=patch_index+1;end
 end else begin pig<=pig+1;patch_index<=patch_index+1;end
 end
 F_CAPTURE:fs<=F_PUBLISH;
 F_PUBLISH:begin
 full[fill_bank]<=1;offsets[fill_bank]<=front_offset;bx[fill_bank]<=fx;by[fill_bank]<=fy;
 last_pixel[fill_bank]<=fx==ow-1&&fy==oh-1;
 fill_bank<=!fill_bank;front_offset<=front_offset+osp;
 if(fx==ow-1)begin fx<=0;if(fy==oh-1)fs<=F_DONE;else begin fy<=fy+1;fs<=F_FREE;end end
 else begin fx<=fx+1;fs<=F_FREE;end
 end
 default:begin end
 endcase
 case(cs)
 C_IDLE:if(full[consume_bank])begin og<=0;cs<=mode==1?C_SKIP:C_REQ;end
 C_SKIP:if(accept_skip)cs<=C_SKIPWAIT;
 C_SKIPWAIT:if(skip_response)begin skip_data<=mem_rdata;cs<=C_REQ;end
 C_REQ:cs<=C_B0;
 C_B0:begin main_lo<=mul_q;cs<=C_B1;end
 C_B1:begin main_hi<=mul_q;issue_index<=0;cs<=C_MAC;end
 C_MAC:if(issue_index==steps-1)cs<=C_WAIT;else issue_index<=issue_index+1;
 C_WAIT:if(mac_done&&!push)cs<=C_PUSH;
 default:begin end
 endcase
 if(push)begin
 qa<=acc;qsk<=skip_data;qml<=main_lo;qmh<=main_hi;
 qaddr<={dst_slot,21'd0}+offsets[consume_bank]+(og<<3);
 qcrop<=mode==2&&by[consume_bank]>=EXT_H;qgroup<=og;qs<=Q_LO;qhalf<=0;
 if(og==ogs-1)begin
 full[consume_bank]<=0;consume_bank<=!consume_bank;
 og<=0;
 if(last_pixel[consume_bank])cs<=C_DONE;
 else if(full[!consume_bank])cs<=mode==1?C_SKIP:C_REQ;
 else cs<=C_IDLE;
 end else begin og<=og+1;cs<=mode==1?C_SKIP:C_REQ;end
 end
 case(qs)
 Q_LO:qs<=Q_HI;
 Q_HI:qs<=Q_WAIT;
 Q_WRITE:if(qcrop||accept_write)qs<=Q_IDLE;
 default:begin end
 endcase
 if(qvalid)begin
 if(!qhalf)begin result_codes[31:0]<=qcodes;qhalf<=1;end
 else begin result_codes[63:32]<=qcodes;qhalf<=0;qs<=Q_WRITE;end
 end
 if(fs==F_DONE&&cs==C_DONE&&qs==Q_IDLE&&!read_pending)state<=NEXT_LAYER;
 end
 NEXT_LAYER:begin
 layer_done<=1;
 if(layer_index==21)begin busy<=0;done<=1;state<=IDLE;end
 else begin layer_index<=layer_index+1;state<=NEW_LAYER;end
 end
 default:state<=IDLE;
 endcase
 end end
endmodule

// 8 output lanes x 12 input products. DW evaluates nine taps in parallel.
module shared_mac(input clk,input rst,input issue,input last,input dw,
 input sign_in,input [287:0] dw_samples,input [95:0] samples,input [767:0] weights,
 input init0,input init1,input [79:0] biases,
 output reg finished,output [159:0] accum);
 reg v1,v2,l1,l2;
 reg signed [16:0] product[0:95];
 wire [1631:0] product_input;
 reg signed [19:0] sum[0:7];reg signed [19:0] ac[0:7];
 genvar o,i;
 generate for(o=0;o<8;o=o+1)begin:outlane
   assign accum[o*20+:20]=ac[o];
   for(i=0;i<12;i=i+1)begin:inlane
     wire [7:0] byte_in=samples[i*8+:8];
     wire [3:0] dwbyte;
     if(i<9)assign dwbyte=dw_samples[(o*9+i)*4+:4];else assign dwbyte=0;
     wire signed [8:0] a=dw?{5'd0,dwbyte}:{sign_in & byte_in[7],byte_in};
     wire signed [7:0] w=weights[(o*12+i)*8+:8];
     assign product_input[(o*12+i)*17+:17]=a*w;
   end
   // Explicit balanced reduction prevents a long chain of eleven adders.
   wire signed [17:0] s0=$signed(product[o*12])+$signed(product[o*12+1]);
   wire signed [17:0] s1=$signed(product[o*12+2])+$signed(product[o*12+3]);
   wire signed [17:0] s2=$signed(product[o*12+4])+$signed(product[o*12+5]);
   wire signed [17:0] s3=$signed(product[o*12+6])+$signed(product[o*12+7]);
   wire signed [17:0] s4=$signed(product[o*12+8])+$signed(product[o*12+9]);
   wire signed [17:0] s5=$signed(product[o*12+10])+$signed(product[o*12+11]);
   wire signed [18:0] s6=s0+s1,s7=s2+s3,s8=s4+s5;
   wire signed [19:0] s9=s6+s7;
   always @(posedge clk)begin
     if(v1)sum[o]<=s9+s8;
     if(init0 && o<4)ac[o]<=$signed(biases[(o%4)*20+:20]);
     else if(init1 && o>=4)ac[o]<=$signed(biases[(o%4)*20+:20]);
     else if(v2)ac[o]<=ac[o]+sum[o];
   end
 end endgenerate
 integer p;
 always @(posedge clk)if(issue)for(p=0;p<96;p=p+1)product[p]<=$signed(product_input[p*17+:17]);
 always @(posedge clk)begin
 if(rst)begin v1<=0;v2<=0;l1<=0;l2<=0;finished<=0;end
 else begin v1<=issue;v2<=v1;l1<=issue&&last;l2<=l1;finished<=v2&&l2;end
 end
endmodule

// Four exact integer requantizers. Products are summed BEFORE residual rounding.
module shared_quant(input clk,input rst,input valid_in,input [1:0] mode_in,
 input [79:0] accum,input [35:0] skip_mul,input [35:0] skip_codes,
 input [143:0] main_mul,output reg valid_out,output reg [31:0] codes);
 reg v1,v2;reg [1:0] m1,m2;
 reg signed [55:0] pm[0:3];reg signed [44:0] ps[0:3];
 reg signed [56:0] total[0:3];
 integer j;
 function [7:0] round_clip;
 input signed [56:0] z;input [1:0] mode;
 reg signed [25:0] t;
 begin
 t=$signed(z)>>>32;
 if(mode==2) begin
   if(z[31:0]>32'h80000000 || (z[31:0]==32'h80000000 && t[0]))t=t+1;
 end else if(z[31])t=t+1;
 if(mode==1) begin
   if(t>127)round_clip=8'h7f;else if(t< -128)round_clip=8'h80;else round_clip=t[7:0];
 end else if(t<0)round_clip=0;
 else if(mode==0 && t>15)round_clip=15;
 else if(mode==2 && t>255)round_clip=255;
 else round_clip=t[7:0];
 end endfunction
 always @(posedge clk)begin
 if(rst)begin v1<=0;v2<=0;valid_out<=0;end
 else begin
 v1<=valid_in;v2<=v1;valid_out<=v2;m1<=mode_in;m2<=m1;
 for(j=0;j<4;j=j+1)begin
   if(valid_in)begin
   pm[j]<=$signed(accum[j*20+:20])*$signed(main_mul[j*36+:36]);
   ps[j]<=$signed(skip_codes[j*9+:9])*$signed(skip_mul);
   end
   if(v1)total[j]<=$signed(pm[j])+$signed(ps[j]);
   if(v2)codes[j*8+:8]<=round_clip(total[j],m2);
 end
 end end
endmodule

// 16 independently addressed byte banks, three line slots. No frame RAM on chip.
module shared_line #(parameter W=480)(input clk,input we,input [15:0] waddr,
 input [63:0] wdata,input [15:0] raddr,output [95:0] rdata);
 localparam DEPTH=(3*8*W+15)/16;
 wire [127:0] q;
 reg [3:0] rotate;
 always @(posedge clk)rotate<=raddr[3:0];
 genvar b,l;
 generate for(b=0;b<16;b=b+1)begin:bank
   reg [7:0] ram[0:DEPTH-1];reg [7:0] qr;
   wire [3:0] delta=b-raddr[3:0];
   wire [15:0] ra=raddr+delta;
   always @(posedge clk)begin
     if(we && waddr[3]==(b>=8))ram[waddr[15:4]]<=wdata[(b%8)*8+:8];
     qr<=ram[ra[15:4]];
   end
   assign q[b*8+:8]=qr;
 end
 for(l=0;l<12;l=l+1)begin:rot
   wire [3:0] sel=rotate+l;
   assign rdata[l*8+:8]=q[sel*8+:8];
 end endgenerate
endmodule
