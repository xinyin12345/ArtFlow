# -*- coding: utf-8 -*-
"""Exact U8 v2: cached coefficients, wider DW capture, source-stat projection."""
from pathlib import Path
R=Path(__file__).resolve().parent
base=R/'baseline/rtl'
s=(base/'shared_mac.v').read_text()
s=s.replace('input init0,input init1,input [95:0] biases','input init,input [191:0] biases')
s=s.replace('if(init0 && o<4)ac[o]<=$signed(biases[(o%4)*24+:24]);\n     else if(init1 && o>=4)ac[o]<=$signed(biases[(o%4)*24+:24]);',
            'if(init)ac[o]<=$signed(biases[o*24+:24]);')
(R/'rtl/shared_mac.v').write_text(s,encoding='ascii')
s=(base/'center_div.v').read_text()
s=s.replace('input clk,input rst,input start,','input clk,input rst,input start,input project,')
s=s.replace('reg [2:0] state;','reg saved_project;reg [2:0] state;')
s=s.replace('0:if(start)begin saved_sum<=sum;', '0:if(start)begin saved_project<=project;saved_sum<=sum;')
s=s.replace('2:begin\n   negative', '2:if(saved_project)begin dynamic_bias<=product[47:0];done<=1;state<=0;end else begin\n   negative')
(R/'rtl/center_div.v').write_text(s,encoding='ascii')
s=(base/'student_u8.v').read_text()
def change(old,new):
    global s
    assert old in s,old
    s=s.replace(old,new)
change('REPLAY=8;', 'REPLAY=8,PROJ_REQ=9,PROJ_START=10,PROJ_WAIT=11,COEFF_REQ=12,COEFF_CAP=13;')
change('reg [4:0] mean_ch;', 'reg [4:0] mean_ch;reg [3:0] proj_oc,proj_ic;reg [3:0] proj_tap;reg [1:0] coeff_quad;')
change('fill_groups=dw?ogs:ng;', "fill_groups=dw?3'd1:ng;")
change('if(dw)for(p=0;p<8;p=p+1)begin\n if(saved_bank)dpatch1[saved_tap*128+(saved_pig*8+p)*8+:8]<=masked[p*13+:8];\n else dpatch0[saved_tap*128+(saved_pig*8+p)*8+:8]<=masked[p*13+:8];',
       "if(dw)for(p=0;p<16;p=p+1)begin\n if(saved_bank)dpatch1[saved_tap*128+p*8+:8]<=p<ci?line_data[p*8+:8]:8'd0;\n else dpatch0[saved_tap*128+p*8+:8]<=p<ci?line_data[p*8+:8]:8'd0;")
change('reg [95:0] bias_q;','reg [95:0] bias_cache[0:3];reg [83:0] mul_cache[0:3];\n reg [95:0] bias_q;')
change('wire [8:0] weight_addr=wbase+(dw?og:og*steps)+(dw?0:issue_index);',
       'wire projecting=state==PROJ_REQ||state==PROJ_START||state==PROJ_WAIT;\n wire [8:0] weight_addr=projecting?wbase+(proj_oc>>3)*steps+proj_tap*ng+(proj_ic>=12?1:0):wbase+(dw?og:og*steps)+(dw?0:issue_index);')
change('wire [7:0] coeff_addr=(state==MEAN_REQ', 'wire [7:0] coeff_addr=(state==COEFF_REQ||state==COEFF_CAP)?cbase+coeff_quad:(state==MEAN_REQ')
change('center_div center_unit(clk,rst,state==MEAN_START,center_sums[mean_ch],\n $signed(mul_q[mean_ch[1:0]*21+:21]),$signed(beta_q[mean_ch[1:0]*32+:32]),mean_area,mean_done,mean_value);',
       '''wire signed [23:0] projected_source_sum;
 wire signed [39:0] math_sum=projecting?{{16{projected_source_sum[23]}},projected_source_sum}:center_sums[mean_ch];
 wire [3:0] proj_lane=proj_ic>=12?proj_ic-12:proj_ic;
 wire signed [7:0] proj_weight=weight_q[((proj_oc%8)*12+proj_lane)*8+:8];
 wire signed [20:0] math_multiplier=projecting?{{13{proj_weight[7]}},proj_weight}:mul_q[mean_ch[1:0]*21+:21];
 center_div center_unit(clk,rst,state==MEAN_START||state==PROJ_START,projecting,math_sum,
 math_multiplier,$signed(beta_q[mean_ch[1:0]*32+:32]),mean_area,mean_done,mean_value);''')
change('state==RUN&&cs==C_B0,state==RUN&&cs==C_B1,bias_q,mac_done,acc);',
       'state==RUN&&cs==C_B0,{bias_cache[(og<<1)+1],bias_cache[og<<1]},mac_done,acc);')
change('reg [23:0] qaddr;', 'reg [9:0] qx,qy;reg [23:0] qaddr;')
change('if(push&&stats_pass&&og==cr/8)center_sums[cr]<=center_sums[cr]+$signed(acc[(cr%8)*24+:24]);',
       'if(state==PROJ_WAIT&&mean_done&&proj_oc==cr)center_sums[cr]<=center_sums[cr]+$signed(mean_value[39:0]);')
change('\n integer b;\n always @*begin', '''
 wire collect_statistics=state==RUN&&qs==Q_WRITE&&accept_write&&layer_index>=4&&layer_index<=12;
 source_stats #(.W(W/4),.H(H/4)) statistics(clk,rst||state==REPLAY||(state==PREPARE&&layer_index==4),
 collect_statistics,mode==1,qgroup[0],qx,qy,result_codes[63:0],proj_ic,k3?proj_tap:4'd4,projected_source_sum);
 integer b;
 always @*begin''')
change('result_codes<=0;stats_pass<=0;', 'result_codes<=0;qx<=0;qy<=0;proj_oc<=0;proj_ic<=0;proj_tap<=0;coeff_quad<=0;stats_pass<=0;')
change('stats_pass<=center;', 'stats_pass<=0;')
change('cs<=C_IDLE;og<=0;issue_index<=0;qs<=Q_IDLE;qhalf<=0;state<=RUN;',
       'cs<=C_IDLE;og<=0;issue_index<=0;qs<=Q_IDLE;qhalf<=0;\n if(state==PREPARE)begin coeff_quad<=0;state<=COEFF_REQ;end else state<=RUN;')
change('cs<=(mode==1&&!stats_pass)?C_SKIP:C_REQ;', 'cs<=(mode==1&&!stats_pass)?C_SKIP:C_B0;')
change('skip_data<=mem_rdata;cs<=C_REQ;', 'skip_data<=mem_rdata;cs<=C_B0;')
change('C_B0:begin main_lo<=mul_q;cs<=C_B1;end\n C_B1:begin main_hi<=mul_q;issue_index<=0;cs<=C_MAC;end',
       'C_B0:begin main_lo<=mul_cache[og<<1];main_hi<=mul_cache[(og<<1)+1];issue_index<=0;cs<=C_MAC;end')
change('qa<=acc;qsk<=skip_data;', 'qx<=ox;qy<=oy;qa<=acc;qsk<=skip_data;')
change('MEAN_REQ:state<=MEAN_START;', '''COEFF_REQ:state<=COEFF_CAP;
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
 MEAN_REQ:state<=MEAN_START;''')
change('// Accepted U8 student: concurrent window/MAC/output, exact same-frame two-pass centers.',
       '// Exact U8 v2: cached layer coefficients, full-channel DW capture, single-pass centers.')
# Capturing the last synchronous line result and publishing a bank may share a cycle.
change('F_CAPTURE:fs<=F_PUBLISH;\n F_PUBLISH:begin', 'F_CAPTURE:begin')
# Prefetch the next row of pointwise layers into a different existing line slot.
# This preserves the original one-outstanding-read interface and test latency.
change('reg [1:0] full;', '''reg [1:0] full;
 localparam P_IDLE=0,P_ADDR=1,P_READ=2,P_WAIT=3;
 reg [1:0] pf_state,pf_slot;reg [9:0] pf_row;reg [15:0] pf_offset;reg [23:0] pf_base;
 wire [9:0] next_pf_row=fy+10'd1;''')
change('wire [15:0] line_waddr=(loading_slot==0?0:loading_slot==1?ROW_CAP:2*ROW_CAP)+load_offset;',
       'wire [15:0] line_waddr=prefetch_response?((pf_slot==0?0:pf_slot==1?ROW_CAP:2*ROW_CAP)+pf_offset):((loading_slot==0?0:loading_slot==1?ROW_CAP:2*ROW_CAP)+load_offset);')
change('reg read_pending,read_owner;', 'reg read_pending;reg [1:0] read_owner;')
change('mem_rvalid&&read_pending&&!read_owner;', 'mem_rvalid&&read_pending&&read_owner==0;')
change('mem_rvalid&&read_pending&&read_owner;', 'mem_rvalid&&read_pending&&read_owner==1;\n wire prefetch_response=mem_rvalid&&read_pending&&read_owner==2;')
change('lines(clk,front_response,line_waddr', 'lines(clk,front_response||prefetch_response,line_waddr')
change('wire accept=mem_valid&&mem_ready;', 'wire want_prefetch=state==RUN&&pf_state==P_READ&&!read_pending;\n wire accept=mem_valid&&mem_ready;')
change('reg command_locked,locked_write,locked_owner;', 'reg command_locked,locked_write;reg [1:0] locked_owner;')
change('wire selected_owner=command_locked?locked_owner:want_skip;', "wire [1:0] selected_owner=command_locked?locked_owner:(want_skip?2'd1:(want_row?2'd0:2'd2));")
change('accept&&!mem_write&&selected_owner;', 'accept&&!mem_write&&selected_owner==1;')
change('accept&&!mem_write&&!selected_owner;', 'accept&&!mem_write&&selected_owner==0;\n wire accept_prefetch=accept&&!mem_write&&selected_owner==2;')
change('else if(want_row)begin mem_valid=1;mem_addr=load_base+load_offset;end',
       'else if(want_row)begin mem_valid=1;mem_addr=load_base+load_offset;end\n else if(want_prefetch)begin mem_valid=1;mem_addr=pf_base+pf_offset;end')
change('locked_owner<=want_skip;', 'locked_owner<=selected_owner;')
change('result_codes<=0;qx<=0;', 'pf_state<=P_IDLE;pf_slot<=0;pf_row<=0;pf_offset<=0;pf_base<=0;\n result_codes<=0;qx<=0;')
change('PREPARE,REPLAY:begin', 'PREPARE,REPLAY:begin\n pf_state<=P_IDLE;pf_offset<=0;')
change('RUN:begin\n case(fs)', '''RUN:begin
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
 case(fs)''')
change('end else begin loading_slot<=req_slot;load_offset<=0;load_base<=req_base;fs<=F_READ;end',
       'end else if(pf_state!=P_IDLE&&pf_row==req_row)begin end\n else begin loading_slot<=req_slot;load_offset<=0;load_base<=req_base;fs<=F_READ;end')
change('qs==Q_IDLE&&!read_pending)begin', 'qs==Q_IDLE&&!read_pending&&pf_state==P_IDLE)begin')
# Frozen graph has <=16 channels, hence <=2 output/input groups. Use shifts
# and selects for addresses instead of spending DSPs on generic products.
change('reg [2:0] og;', 'reg og;')
change('(proj_oc>>3)*steps+proj_tap*ng', '(proj_oc[3]?steps:0)+(ng==2?(proj_tap<<1):proj_tap)')
change('(dw?og:og*steps)', '(dw?og:(og?steps:0))')
change('bias_cache[(og<<1)+1]', "bias_cache[{og,1'b1}]")
change('bias_cache[og<<1]', "bias_cache[{og,1'b0}]")
change('mul_cache[(og<<1)+1]', "mul_cache[{og,1'b1}]")
change('mul_cache[og<<1]', "mul_cache[{og,1'b0}]")
(R/'rtl/student_u8.v').write_text(s,encoding='ascii')
(R/'rtl/source_stats.v').write_text(r'''// Sum every reflected tap of a stored integer feature map while it is written.
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
''',encoding='ascii')
print('Built exact U8 v2 optimizations')
