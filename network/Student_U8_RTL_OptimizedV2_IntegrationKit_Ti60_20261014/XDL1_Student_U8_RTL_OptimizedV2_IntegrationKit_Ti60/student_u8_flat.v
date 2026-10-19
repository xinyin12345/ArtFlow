// Exact U8 v2: cached layer coefficients, full-channel DW capture, single-pass centers.
// One outstanding read; ready accepts command; response >=1 cycle later.
module student_u8 #(parameter EXT_W=480,EXT_H=270)(
 input clk,input rst,input start,output reg busy,output reg done,
 output reg mem_valid,output reg mem_write,output reg [23:0] mem_addr,
 output reg [63:0] mem_wdata,output [7:0] mem_wstrb,
 input mem_ready,input mem_rvalid,input [63:0] mem_rdata,
 output reg layer_done,output reg [4:0] layer_index,output reg [31:0] frame_cycles);
 localparam W=EXT_W,H=((EXT_H+3)/4)*4,ROW_CAP=8*W;
 localparam [9:0] CW=W,CW2=W/2,CW4=W/4,CW8=W/8;
 localparam IDLE=0,NEW_LAYER=1,RUN=2,NEXT_LAYER=3,PREPARE=4,MEAN_REQ=5,MEAN_START=6,MEAN_WAIT=7,REPLAY=8,PROJ_REQ=9,PROJ_START=10,PROJ_WAIT=11,COEFF_REQ=12,COEFF_CAP=13;
 reg [3:0] state;
 reg [5:0] ci,co,isp,osp;reg [9:0] iw,ih,ow,oh;
 reg dw,up2,k3,stride2,sign_in,wide_in,skip_sign,center;reg [1:0] mode,src_slot,dst_slot,skip_slot;
 reg [8:0] wbase;reg [7:0] cbase;reg [2:0] ng,ogs;reg [24:0] skip_mul;
 reg stats_pass;reg [4:0] mean_ch;reg [3:0] proj_oc,proj_ic;reg [3:0] proj_tap;reg [1:0] coeff_quad;
 reg signed [39:0] center_sums[0:15];reg signed [47:0] dynamic[0:15];
 wire mean_done;wire signed [47:0] mean_value;
 wire [19:0] mean_area=(W/4)*(H/4);
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

 function [9:0] reflect;
 input signed [11:0] x;input [10:0] size;
 begin if(x<0)reflect=-x;else if(x>=size)reflect=(size<<1)-2-x;else reflect=x;end
 endfunction
 function [15:0] pixel_offset;
 input [9:0] x;input [5:0] pitch;
 begin case(pitch)
 8:pixel_offset=x<<3;16:pixel_offset=x<<4;
 32:pixel_offset=x<<5;
 default:pixel_offset=0;endcase end endfunction
 function [23:0] constant_product;
 input [9:0] r;input [15:0] c;integer b;
 begin constant_product=0;
 for(b=0;b<16;b=b+1)if(c[b])constant_product=constant_product+({14'd0,r}<<b);
 end endfunction
 function [23:0] row_offset;
 input [9:0] row;
 begin
 if(iw==CW)row_offset=constant_product(row,8*W);
 else if(iw==CW2)begin
 if(isp==8)row_offset=constant_product(row,4*W);else row_offset=constant_product(row,8*W);
 end else begin
 case(isp)
 8:row_offset=constant_product(row,2*W);
 16:row_offset=constant_product(row,4*W);
 32:row_offset=constant_product(row,8*W);
 default:row_offset=0;
 endcase end
 end endfunction
 wire [15:0] row_bytes=pixel_offset(iw,isp);
 // Nearest-up2 3x3 DW windows contain at most 2x2 distinct source pixels.
 wire [3:0] taps=dw?(up2?4:9):(k3?9:1);
 wire [5:0] steps=dw?1:(k3?ng*9:ng);
 wire [2:0] fill_groups=dw?3'd1:ng;
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
 localparam P_IDLE=0,P_ADDR=1,P_READ=2,P_WAIT=3;
 reg [1:0] pf_state,pf_slot;reg [9:0] pf_row;reg [15:0] pf_offset;reg [23:0] pf_base;
 wire [9:0] next_pf_row=fy+10'd1;
 reg [155:0] patch0[0:17],patch1[0:17];reg [155:0] patch_q;
 reg [1151:0] dpatch0,dpatch1;
 reg [35:0] dw_map[0:1];
 reg [23:0] offsets[0:1];reg [9:0] bx[0:1],by[0:1];reg last_pixel[0:1];
 wire signed [11:0] ycenter=stride2?{1'b0,fy,1'b0}:{2'b00,fy};
 wire signed [11:0] xcenter=stride2?{1'b0,fx,1'b0}:{2'b00,fx};
 wire [9:0] required_row=up2?
 (reflect($signed({2'b00,fy})+$signed({10'd0,row_k})-1,{ih,1'b0})>>1):
 reflect(ycenter+$signed({10'd0,row_k})-(k3?1:0),{1'b0,ih});
 wire [9:0] physical_row=(layer_index==0 && req_row>=EXT_H)?(2*EXT_H-2-req_row):req_row;
 wire [1:0] pky=ptap/3,pkx=ptap%3;
 wire [15:0] group_offset=dw?({13'd0,pig}<<3):(wide_in?(({13'd0,pig}<<4)+({13'd0,pig}<<3)):(({13'd0,pig}<<3)+({13'd0,pig}<<2)));
 wire [15:0] second_row=row_bases[1]!=row_bases[0]?row_bases[1]:row_bases[2];
 wire [15:0] second_col=col_bytes[1]!=col_bytes[0]?col_bytes[1]:col_bytes[2];
 wire [15:0] line_raddr=up2?
 (ptap[1]?second_row:row_bases[0])+(ptap[0]?second_col:col_bytes[0])+group_offset:
 row_bases[pky]+col_bytes[pkx]+group_offset;
 wire [15:0] line_waddr=prefetch_response?((pf_slot==0?0:pf_slot==1?ROW_CAP:2*ROW_CAP)+pf_offset):((loading_slot==0?0:loading_slot==1?ROW_CAP:2*ROW_CAP)+load_offset);
 wire [191:0] line_data;
 reg read_pending;reg [1:0] read_owner; // owner 0 frontend, owner 1 residual skip
 wire front_response=mem_rvalid&&read_pending&&read_owner==0;
 wire skip_response=mem_rvalid&&read_pending&&read_owner==1;
 wire prefetch_response=mem_rvalid&&read_pending&&read_owner==2;
 shared_line #(.W(W)) lines(clk,front_response||prefetch_response,line_waddr,mem_rdata,line_raddr,line_data);
 reg line_valid,saved_bank;reg [5:0] saved_index;reg [2:0] saved_pig;reg [3:0] saved_tap;
 reg [155:0] masked;integer j,p;
 always @*begin
 masked=0;
 for(j=0;j<12;j=j+1)
 if((dw&&j<8&&saved_pig*8+j<ci)||(!dw&&saved_pig*12+j<ci))begin if(wide_in)masked[j*13+:13]={line_data[j*16+11],line_data[j*16+:12]};
 else masked[j*13+:13]={{5{sign_in&&line_data[j*8+7]}},line_data[j*8+:8]};end
 end
 always @(posedge clk)begin
 if(rst)begin line_valid<=0;saved_bank<=0;saved_index<=0;saved_pig<=0;saved_tap<=0;end
 else begin
 line_valid<=state==RUN&&fs==F_PATCH;
 saved_bank<=fill_bank;saved_index<=patch_index;saved_pig<=pig;saved_tap<=ptap;
 if(line_valid)begin
 if(saved_bank)patch1[saved_index]<=masked;else patch0[saved_index]<=masked;
 if(dw)for(p=0;p<16;p=p+1)begin
 if(saved_bank)dpatch1[saved_tap*128+p*8+:8]<=p<ci?line_data[p*8+:8]:8'd0;
 else dpatch0[saved_tap*128+p*8+:8]<=p<ci?line_data[p*8+:8]:8'd0;
 end
 end end end
 // COMPUTE: consume one window while the frontend constructs the other.
 localparam C_IDLE=0,C_SKIP=1,C_SKIPWAIT=2,C_REQ=3,C_B0=4,C_B1=5,
 C_MAC=6,C_WAIT=7,C_PUSH=8,C_DONE=9;
 reg [3:0] cs;reg consume_bank;reg og;reg [5:0] issue_index;
 wire [9:0] ox=bx[consume_bank],oy=by[consume_bank];
 reg [63:0] skip_data;reg [83:0] main_lo,main_hi;
 reg [767:0] wrom[0:127];reg [767:0] weight_q;
 reg [95:0] brom[0:63];reg [83:0] mrom[0:63];reg [127:0] trom[0:63];
 reg [95:0] bias_cache[0:3];reg [83:0] mul_cache[0:3];
 reg [95:0] bias_q;reg [83:0] mul_q;reg [127:0] beta_q;
 initial begin
 $readmemh("mem/shared_weights.mem",wrom);
 $readmemh("mem/shared_bias.mem",brom);
 $readmemh("mem/shared_main.mem",mrom);
 $readmemh("mem/shared_beta.mem",trom);
 end
 wire projecting=state==PROJ_REQ||state==PROJ_START||state==PROJ_WAIT;
 wire [8:0] weight_addr=projecting?wbase+(proj_oc[3]?steps:0)+(ng==2?(proj_tap<<1):proj_tap)+(proj_ic>=12?1:0):wbase+(dw?og:(og?steps:0))+(dw?0:issue_index);
 wire [7:0] coeff_addr=(state==COEFF_REQ||state==COEFF_CAP)?cbase+coeff_quad:(state==MEAN_REQ||state==MEAN_START||state==MEAN_WAIT)?cbase+(mean_ch>>2):cbase+(og<<1)+(cs==C_B0?1:0);
 reg rd_valid,rd_last;
 always @(posedge clk)begin
 weight_q<=wrom[weight_addr];
 patch_q<=consume_bank?patch1[issue_index]:patch0[issue_index];
 bias_q<=brom[coeff_addr];mul_q<=mrom[coeff_addr];beta_q<=trom[coeff_addr];
 if(rst)begin rd_valid<=0;rd_last<=0;end
 else begin rd_valid<=state==RUN&&cs==C_MAC;rd_last<=issue_index==steps-1;end
 end
 wire signed [23:0] projected_source_sum;
 wire signed [39:0] math_sum=projecting?{{16{projected_source_sum[23]}},projected_source_sum}:center_sums[mean_ch];
 wire [3:0] proj_lane=proj_ic>=12?proj_ic-12:proj_ic;
 wire signed [7:0] proj_weight=weight_q[((proj_oc%8)*12+proj_lane)*8+:8];
 wire signed [20:0] math_multiplier=projecting?{{13{proj_weight[7]}},proj_weight}:mul_q[mean_ch[1:0]*21+:21];
 center_div center_unit(clk,rst,state==MEAN_START||state==PROJ_START,projecting,math_sum,
 math_multiplier,$signed(beta_q[mean_ch[1:0]*32+:32]),mean_area,mean_done,mean_value);
 wire mac_done;wire [191:0] acc;wire [575:0] dw_samples;
 genvar dwo,dwt;
 generate for(dwo=0;dwo<8;dwo=dwo+1)begin:dwout
 for(dwt=0;dwt<9;dwt=dwt+1)begin:dwtap
 wire [3:0] sample_index=dw_map[consume_bank][dwt*4+:4];
 assign dw_samples[(dwo*9+dwt)*8+:8]=consume_bank?
 dpatch1[sample_index*128+(og*8+dwo)*8+:8]:dpatch0[sample_index*128+(og*8+dwo)*8+:8];
 end end endgenerate
 shared_mac mac(clk,rst,rd_valid,rd_last,dw,dw_samples,patch_q,weight_q,
 state==RUN&&cs==C_B0,{bias_cache[{og,1'b1}],bias_cache[{og,1'b0}]},mac_done,acc);
 // OUTPUT: independent accumulator snapshot, coefficients and write slot.
 localparam Q_IDLE=0,Q_LO=1,Q_HI=2,Q_WAIT=3,Q_WRITE=4;
 reg [2:0] qs;
 wire push=state==RUN&&((cs==C_WAIT&&mac_done)||cs==C_PUSH)&&qs==Q_IDLE;
 reg [191:0] qa;reg [63:0] qsk;reg [127:0] result_codes;reg [83:0] qml,qmh;reg [383:0] qdynamic;reg write_half;
 reg [9:0] qx,qy;reg [23:0] qaddr;reg qcrop,qhalf;reg [2:0] qgroup;
 wire feed_hi=qs==Q_HI;wire [95:0] qacc=feed_hi?qa[191:96]:qa[95:0];
 wire [31:0] qskip=feed_hi?qsk[63:32]:qsk[31:0];wire [35:0] skip_codes;
 genvar s;
 generate for(s=0;s<4;s=s+1)begin:sx
 assign skip_codes[s*9+:9]={skip_sign&qskip[s*8+7],qskip[s*8+:8]};
 end endgenerate
 wire qvalid;wire [63:0] qcodes;
 shared_quant quant(clk,rst,state==RUN&&(qs==Q_LO||qs==Q_HI),mode,qacc,
 mode==1?skip_mul:25'd0,skip_codes,feed_hi?qmh:qml,feed_hi?qdynamic[383:192]:qdynamic[191:0],qvalid,qcodes);
 // Completed output first, residual skip second, input row fill third.
 wire want_write=state==RUN&&qs==Q_WRITE&&!qcrop;
 wire want_skip=state==RUN&&cs==C_SKIP&&!read_pending&&!stats_pass;
 wire want_row=state==RUN&&fs==F_READ&&!read_pending;
 wire want_prefetch=state==RUN&&pf_state==P_READ&&!read_pending;
 wire accept=mem_valid&&mem_ready;
 wire accept_write=accept&&mem_write;
 reg command_locked,locked_write;reg [1:0] locked_owner;
 reg [23:0] locked_addr;reg [63:0] locked_data;
 wire [1:0] selected_owner=command_locked?locked_owner:(want_skip?2'd1:(want_row?2'd0:2'd2));
 wire accept_skip=accept&&!mem_write&&selected_owner==1;
 wire accept_row=accept&&!mem_write&&selected_owner==0;
 wire accept_prefetch=accept&&!mem_write&&selected_owner==2;
 assign mem_wstrb=8'hff;
 genvar cr;
 generate for(cr=0;cr<16;cr=cr+1)begin:centers
 always @(posedge clk)begin
 if(rst || state==PREPARE)begin center_sums[cr]<=0;dynamic[cr]<=0;end
 else begin
 if(state==PROJ_WAIT&&mean_done&&proj_oc==cr)center_sums[cr]<=center_sums[cr]+$signed(mean_value[39:0]);
 if(state==MEAN_WAIT&&mean_done&&mean_ch==cr)dynamic[cr]<=mean_value;
 end end
 end endgenerate
 wire collect_statistics=state==RUN&&qs==Q_WRITE&&accept_write&&layer_index>=4&&layer_index<=12;
 source_stats #(.W(W/4),.H(H/4)) statistics(clk,rst||state==REPLAY||(state==PREPARE&&layer_index==4),
 collect_statistics,mode==1,qgroup[0],qx,qy,result_codes[63:0],proj_ic,k3?proj_tap:4'd4,projected_source_sum);
 integer b;
 always @*begin
 mem_valid=0;mem_write=0;mem_addr=0;mem_wdata=write_half?result_codes[127:64]:result_codes[63:0];
 if(want_write)begin
 mem_valid=1;mem_write=1;mem_addr=qaddr+(write_half?8:0);
 if(mode==3)begin for(b=0;b<4;b=b+1)if(qgroup*8+write_half*4+b>=co)mem_wdata[b*16+:16]=0;end
 else for(b=0;b<8;b=b+1)if(qgroup*8+b>=co)mem_wdata[b*8+:8]=0;
 end else if(want_skip)begin
 mem_valid=1;mem_addr={skip_slot,21'd0}+offsets[consume_bank]+(og<<3);
 end else if(want_row)begin mem_valid=1;mem_addr=load_base+load_offset;end
 else if(want_prefetch)begin mem_valid=1;mem_addr=pf_base+pf_offset;end
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
 command_locked<=1;locked_write<=mem_write;locked_owner<=selected_owner;
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
 pf_state<=P_IDLE;pf_slot<=0;pf_row<=0;pf_offset<=0;pf_base<=0;
 result_codes<=0;qx<=0;qy<=0;proj_oc<=0;proj_ic<=0;proj_tap<=0;coeff_quad<=0;stats_pass<=0;mean_ch<=0;write_half<=0;qdynamic<=0;
 
 end else begin
 done<=0;layer_done<=0;if(busy)frame_cycles<=frame_cycles+1;
 case(state)
 IDLE:if(start)begin busy<=1;frame_cycles<=0;layer_index<=0;state<=NEW_LAYER;end
 NEW_LAYER:state<=PREPARE;
 PREPARE,REPLAY:begin
 pf_state<=P_IDLE;pf_offset<=0;
 if(state==PREPARE)begin
 stats_pass<=0;
 end else stats_pass<=0;
 fs<=F_FREE;fx<=0;fy<=0;row_k<=0;tag_valid<=0;front_offset<=0;
 ptap<=0;pig<=0;patch_index<=0;fill_bank<=0;consume_bank<=0;full<=0;
 cs<=C_IDLE;og<=0;issue_index<=0;qs<=Q_IDLE;qhalf<=0;
 if(state==PREPARE)begin coeff_quad<=0;state<=COEFF_REQ;end else state<=RUN;
 end
 RUN:begin
 case(pf_state)
 P_IDLE:if(!k3&&next_pf_row<ih&&tag_valid[fy%3]&&tags[fy%3]==fy&&
 !(tag_valid[next_pf_row%3]&&tags[next_pf_row%3]==next_pf_row))begin
 pf_row<=next_pf_row;pf_slot<=next_pf_row%3;pf_offset<=0;pf_state<=P_ADDR;
 end
 P_ADDR:begin pf_base<={src_slot,21'd0}+row_offset(pf_row);pf_state<=P_READ;end
 P_READ:if(accept_prefetch)pf_state<=P_WAIT;
 P_WAIT:if(prefetch_response)begin
 if(pf_offset+8>=row_bytes)begin tags[pf_slot]<=pf_row;tag_valid[pf_slot]<=1;pf_state<=P_IDLE;end
 else begin pf_offset<=pf_offset+8;pf_state<=P_READ;end
 end
 endcase
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
 end else if(pf_state!=P_IDLE&&pf_row==req_row)begin end
 else begin loading_slot<=req_slot;load_offset<=0;load_base<=req_base;fs<=F_READ;end
 end
 F_READ:if(accept_row)fs<=F_WAIT;
 F_WAIT:if(front_response)begin
 if(load_offset+8>=row_bytes)begin tags[loading_slot]<=req_row;tag_valid[loading_slot]<=1;fs<=F_ROW2;end
 else begin load_offset<=load_offset+8;fs<=F_READ;end
 end
 F_COL0:begin
 for(p=0;p<3;p=p+1)begin
 if(up2)columns[p]<=reflect($signed({2'b00,fx})+p-1,{iw,1'b0})>>1;
 else columns[p]<=reflect(xcenter+p-(k3?1:0),{1'b0,iw});
 end
 fs<=F_COL1;
 end
 F_COL1:begin
 for(p=0;p<3;p=p+1)col_bytes[p]<=pixel_offset(columns[p],isp);
 for(p=0;p<9;p=p+1)dw_map[fill_bank][p*4+:4]<=up2?
 {2'd0,row_bases[p/3]!=row_bases[0],columns[p%3]!=columns[0]}:p;
 ptap<=0;pig<=0;patch_index<=0;fs<=F_PATCH;
 end
 F_PATCH:begin
 if(pig==fill_groups-1)begin
 pig<=0;if(ptap==taps-1)fs<=F_CAPTURE;else begin ptap<=ptap+1;patch_index<=patch_index+1;end
 end else begin pig<=pig+1;patch_index<=patch_index+1;end
 end
 F_CAPTURE:begin
 full[fill_bank]<=1;offsets[fill_bank]<=front_offset;bx[fill_bank]<=fx;by[fill_bank]<=fy;
 last_pixel[fill_bank]<=fx==ow-1&&fy==oh-1;
 fill_bank<=!fill_bank;front_offset<=front_offset+osp;
 if(fx==ow-1)begin fx<=0;if(fy==oh-1)fs<=F_DONE;else begin fy<=fy+1;fs<=F_FREE;end end
 else begin fx<=fx+1;fs<=F_FREE;end
 end
 default:begin end
 endcase
 case(cs)
 C_IDLE:if(full[consume_bank])begin og<=0;cs<=(mode==1&&!stats_pass)?C_SKIP:C_B0;end
 C_SKIP:if(accept_skip)cs<=C_SKIPWAIT;
 C_SKIPWAIT:if(skip_response)begin skip_data<=mem_rdata;cs<=C_B0;end
 C_REQ:cs<=C_B0;
 C_B0:begin main_lo<=mul_cache[{og,1'b0}];main_hi<=mul_cache[{og,1'b1}];issue_index<=0;cs<=C_MAC;end
 C_MAC:if(issue_index==steps-1)cs<=C_WAIT;else issue_index<=issue_index+1;
 C_WAIT:if(mac_done&&!push)cs<=C_PUSH;
 default:begin end
 endcase
 if(push)begin
 if(stats_pass)begin
 
 end else begin
 qx<=ox;qy<=oy;qa<=acc;qsk<=skip_data;qml<=main_lo;qmh<=main_hi;
 for(p=0;p<8;p=p+1)qdynamic[p*48+:48]<=dynamic[og*8+p];
 qaddr<={dst_slot,21'd0}+offsets[consume_bank]+(mode==3?(og<<4):(og<<3));
 qcrop<=mode==2&&by[consume_bank]>=EXT_H;qgroup<=og;qs<=Q_LO;qhalf<=0;write_half<=0;
 end
 if(og==ogs-1)begin
 full[consume_bank]<=0;consume_bank<=!consume_bank;
 og<=0;
 if(last_pixel[consume_bank])cs<=C_DONE;
 else if(full[!consume_bank])cs<=(mode==1&&!stats_pass)?C_SKIP:C_B0;
 else cs<=C_IDLE;
 end else begin og<=og+1;cs<=(mode==1&&!stats_pass)?C_SKIP:C_B0;end
 end
 case(qs)
 Q_LO:qs<=Q_HI;
 Q_HI:qs<=Q_WAIT;
 Q_WRITE:if(qcrop||accept_write)begin if(mode==3&&!write_half&&!qcrop)write_half<=1;else qs<=Q_IDLE;end
 default:begin end
 endcase
 if(qvalid)begin
 if(mode==3)begin
 if(!qhalf)result_codes[63:0]<=qcodes;else result_codes[127:64]<=qcodes;
 end else for(p=0;p<4;p=p+1)begin
 if(!qhalf)result_codes[p*8+:8]<=qcodes[p*16+:8];else result_codes[(p+4)*8+:8]<=qcodes[p*16+:8];
 end
 if(!qhalf)qhalf<=1;else begin qhalf<=0;qs<=Q_WRITE;end
 end
 if(fs==F_DONE&&cs==C_DONE&&qs==Q_IDLE&&!read_pending&&pf_state==P_IDLE)begin
 if(stats_pass)begin mean_ch<=0;state<=MEAN_REQ;end else state<=NEXT_LAYER;end
 end
 COEFF_REQ:state<=COEFF_CAP;
 COEFF_CAP:begin
 bias_cache[coeff_quad]<=bias_q;mul_cache[coeff_quad]<=mul_q;
 if(coeff_quad==(ogs<<1)-1)begin
 if(center)begin proj_oc<=0;proj_ic<=0;proj_tap<=0;state<=PROJ_REQ;end else state<=RUN;
 end else begin coeff_quad<=coeff_quad+1;state<=COEFF_REQ;end
 end
 PROJ_REQ:state<=PROJ_START;
 PROJ_START:state<=PROJ_WAIT;
 PROJ_WAIT:if(mean_done)begin
 if(proj_ic==ci-1)begin
 proj_ic<=0;
 if(proj_tap==(k3?8:0))begin
 proj_tap<=0;
 if(proj_oc==co-1)begin mean_ch<=0;state<=MEAN_REQ;end
 else begin proj_oc<=proj_oc+1;state<=PROJ_REQ;end
 end else begin proj_tap<=proj_tap+1;state<=PROJ_REQ;end
 end else begin proj_ic<=proj_ic+1;state<=PROJ_REQ;end
 end
 MEAN_REQ:state<=MEAN_START;
 MEAN_START:state<=MEAN_WAIT;
 MEAN_WAIT:if(mean_done)begin
 
 if(mean_ch==co-1)state<=REPLAY;else begin mean_ch<=mean_ch+1;state<=MEAN_REQ;end
 end
 NEXT_LAYER:begin
 layer_done<=1;
 if(layer_index==18)begin busy<=0;done<=1;state<=IDLE;end
 else begin layer_index<=layer_index+1;state<=NEW_LAYER;end
 end
 default:state<=IDLE;
 endcase
 end end
endmodule

// 96 shared products. U8/S8/S12 inputs normalized to signed 13 bits; ACC24.
module shared_mac(input clk,input rst,input issue,input last,input dw,
 input [575:0] dw_samples,input [155:0] samples,input [767:0] weights,
 input init,input [191:0] biases,
 output reg finished,output [191:0] accum);
 reg v1,v2,l1,l2;
 reg signed [20:0] product[0:95];
 wire [2015:0] product_input;
 reg signed [23:0] sum[0:7];reg signed [23:0] ac[0:7];
 genvar o,i;
 generate for(o=0;o<8;o=o+1)begin:outlane
   assign accum[o*24+:24]=ac[o];
   for(i=0;i<12;i=i+1)begin:inlane
     
     wire [7:0] dwbyte;
     if(i<9)assign dwbyte=dw_samples[(o*9+i)*8+:8];else assign dwbyte=0;
     wire signed [12:0] a=dw?{5'd0,dwbyte}:samples[i*13+:13];
     wire signed [7:0] w=weights[(o*12+i)*8+:8];
     assign product_input[(o*12+i)*21+:21]=a*w;
   end
   // Explicit balanced reduction prevents a long chain of eleven adders.
   wire signed [21:0] s0=$signed(product[o*12])+$signed(product[o*12+1]);
   wire signed [21:0] s1=$signed(product[o*12+2])+$signed(product[o*12+3]);
   wire signed [21:0] s2=$signed(product[o*12+4])+$signed(product[o*12+5]);
   wire signed [21:0] s3=$signed(product[o*12+6])+$signed(product[o*12+7]);
   wire signed [21:0] s4=$signed(product[o*12+8])+$signed(product[o*12+9]);
   wire signed [21:0] s5=$signed(product[o*12+10])+$signed(product[o*12+11]);
   wire signed [22:0] s6=s0+s1,s7=s2+s3,s8=s4+s5;
   wire signed [23:0] s9=s6+s7;
   always @(posedge clk)begin
     if(v1)sum[o]<=s9+s8;
     if(init)ac[o]<=$signed(biases[o*24+:24]);
     else if(v2)ac[o]<=ac[o]+sum[o];
   end
 end endgenerate
 integer p;
 always @(posedge clk)if(issue)for(p=0;p<96;p=p+1)product[p]<=$signed(product_input[p*21+:21]);
 always @(posedge clk)begin
 if(rst)begin v1<=0;v2<=0;l1<=0;l2<=0;finished<=0;end
 else begin v1<=issue;v2<=v1;l1<=issue&&last;l2<=l1;finished<=v2&&l2;end
 end
endmodule

// R24: one rounding after main + dynamic + skip; RGB ties to even.
module shared_quant(input clk,input rst,input valid_in,input [1:0] mode_in,
 input [95:0] accum,input [24:0] skip_mul,input [35:0] skip_codes,
 input [83:0] main_mul,input [191:0] dynamic_bias,
 output reg valid_out,output reg [63:0] codes);
 reg v1,v2;reg [1:0] m1,m2;
 reg signed [44:0] pm[0:3];reg signed [33:0] ps[0:3];
 reg signed [47:0] db[0:3],total[0:3];integer j;
 function [15:0] round_clip;
 input signed [47:0] z;input [1:0] mode;reg signed [24:0] t;
 begin
 t=$signed(z)>>>24;
 if(mode==2)begin
   if(z[23:0]>24'h800000 || (z[23:0]==24'h800000 && t[0]))t=t+1;
 end else if(z[23])t=t+1;
 if(mode==3)begin
   if(t>2047)round_clip=16'h07ff;else if(t< -2048)round_clip=16'hf800;else round_clip=t[15:0];
 end else if(mode==1)begin
   if(t>127)round_clip=16'h007f;else if(t< -128)round_clip=16'h0080;else round_clip={8'd0,t[7:0]};
 end else if(t<0)round_clip=0;
 else if(t>255)round_clip=255;
 else round_clip={8'd0,t[7:0]};
 end endfunction
 always @(posedge clk)begin
 if(rst)begin v1<=0;v2<=0;valid_out<=0;end
 else begin
 v1<=valid_in;v2<=v1;valid_out<=v2;m1<=mode_in;m2<=m1;
 for(j=0;j<4;j=j+1)begin
   if(valid_in)begin
     pm[j]<=$signed(accum[j*24+:24])*$signed(main_mul[j*21+:21]);
     ps[j]<=$signed(skip_codes[j*9+:9])*$signed(skip_mul);
     db[j]<=dynamic_bias[j*48+:48];
   end
   if(v1)total[j]<=$signed(pm[j])+$signed(ps[j])+$signed(db[j]);
   if(v2)codes[j*16+:16]<=round_clip(total[j],m2);
 end
 end end
endmodule

// 32 independently addressed byte banks, three line slots. No frame RAM on chip.
module shared_line #(parameter W=480)(input clk,input we,input [15:0] waddr,
 input [63:0] wdata,input [15:0] raddr,output [191:0] rdata);
 localparam DEPTH=(3*8*W+31)/32;
 wire [255:0] q;
 reg [4:0] rotate;
 always @(posedge clk)rotate<=raddr[4:0];
 genvar b,l;
 generate for(b=0;b<32;b=b+1)begin:bank
   reg [7:0] ram[0:DEPTH-1];reg [7:0] qr;
   wire [4:0] delta=b-raddr[4:0];
   wire [15:0] ra=raddr+delta;
   always @(posedge clk)begin
     if(we && waddr[4:3]==b/8)ram[waddr[15:5]]<=wdata[(b%8)*8+:8];
     qr<=ram[ra[15:5]];
   end
   assign q[b*8+:8]=qr;
 end
 for(l=0;l<24;l=l+1)begin:rot
   wire [4:0] sel=rotate+l;
   assign rdata[l*8+:8]=q[sel*8+:8];
 end endgenerate
endmodule

// Exact same-frame signed half-up(S_A*M/N), beta minus result.
module center_div(input clk,input rst,input start,input project,
 input signed [39:0] sum,input signed [20:0] multiplier,
 input signed [31:0] beta,input [19:0] area,
 output reg done,output reg signed [47:0] dynamic_bias);
 reg saved_project;reg [2:0] state;reg signed [60:0] product;
 reg signed [39:0] saved_sum;reg signed [20:0] saved_multiplier;
 reg signed [31:0] saved_beta;reg [31:0] n;
 reg negative;reg [63:0] numerator,quotient;reg [32:0] remainder;reg [6:0] count;
 wire [32:0] next_remainder={remainder[31:0],numerator[63]};
 wire ge=next_remainder>={1'b0,n};
 always @(posedge clk)begin
 if(rst)begin state<=0;done<=0;dynamic_bias<=0;end
 else begin
 done<=0;
 case(state)
 0:if(start)begin saved_project<=project;saved_sum<=sum;saved_multiplier<=multiplier;saved_beta<=beta;n<=area;state<=1;end
 1:begin product<=saved_sum*saved_multiplier;state<=2;end
 2:if(saved_project)begin dynamic_bias<=product[47:0];done<=1;state<=0;end else begin
   negative<=product[60];
   if(product[60])numerator<={3'd0,(~product+61'd1)}+{32'd0,(n>>1)}-64'd1;
   else numerator<={3'd0,product}+{32'd0,(n>>1)};
   quotient<=0;remainder<=0;count<=64;state<=3;
 end
 3:begin
   remainder<=ge?next_remainder-{1'b0,n}:next_remainder;
   numerator<=numerator<<1;quotient<={quotient[62:0],ge};count<=count-1;
   if(count==1)state<=4;
 end
 4:begin
   if(negative)dynamic_bias<=$signed(saved_beta)+$signed(quotient);
   else dynamic_bias<=$signed(saved_beta)-$signed(quotient);
   done<=1;state<=0;
 end
 endcase
 end end
endmodule

// Sum every reflected tap of a stored integer feature map while it is written.
// For each shift, source multiplicity is 0/1/2 per axis, hence 0/1/2/4 overall.
module source_stats #(parameter W=120,H=68)(input clk,input clear,input capture,
 input signed_codes,input group_hi,input [9:0] x,input [9:0] y,input [63:0] codes,
 input [3:0] read_channel,input [3:0] read_tap,output signed [23:0] value);
 wire [3455:0] all_sums;
 genvar c,t;
 generate for(c=0;c<16;c=c+1)begin:channel
 for(t=0;t<9;t=t+1)begin:tap
 reg signed [23:0] sum;
 wire [7:0] code=codes[(c%8)*8+:8];
 wire signed [8:0] v={signed_codes&&code[7],code};
 wire [1:0] cy=(t/3==0)?(y==1?2:(y==H-1?0:1)):
                  (t/3==1)?2'd1:(y==H-2?2:(y==0?0:1));
 wire [1:0] cx=(t%3==0)?(x==1?2:(x==W-1?0:1)):
                  (t%3==1)?2'd1:(x==W-2?2:(x==0?0:1));
 wire signed [10:0] increment=(cx==0||cy==0)?11'sd0:
       (cx==2&&cy==2)?($signed({{2{v[8]}},v})<<<2):
       (cx==2||cy==2)?($signed({{2{v[8]}},v})<<<1):$signed({{2{v[8]}},v});
 always @(posedge clk)begin
 if(clear)sum<=0;
 else if(capture&&group_hi==(c>=8))sum<=sum+increment;
 end
 assign all_sums[(c*9+t)*24+:24]=sum;
 end end endgenerate
 assign value=all_sums[(read_channel*9+read_tap)*24+:24];
endmodule
