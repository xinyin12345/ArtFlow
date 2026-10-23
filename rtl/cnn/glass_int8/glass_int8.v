module glass_int8 #(parameter EXT_W=480,EXT_H=270)(
 input clk,rst,start,output reg busy,done,
 input param_bank,cfg_valid,cfg_bank,input [1:0] cfg_kind,input [9:0] cfg_addr,input [575:0] cfg_data,
 output reg mem_valid,mem_write,output reg [23:0] mem_addr,
 output reg [63:0] mem_wdata,output [7:0] mem_wstrb,
 input mem_ready,mem_rvalid,input [63:0] mem_rdata,
 output reg layer_done,output reg [4:0] layer_index,output reg [31:0] frame_cycles);
// Exact signed INT8 arithmetic; ROM weights remain replaceable.
// Window preparation, MAC, quantization and writes overlap. Centers retain
// the original two passes and sum/8192 rounding without approximation.
localparam W=EXT_W,H=((EXT_H+3)/4)*4;
localparam IDLE=0,CONFIG=1,COEFF_REQ=2,COEFF_CAP=3,INIT=4,RUN=5,MEAN=6,REPLAY=7,NEXT=8;
reg [3:0] state;
reg [5:0] ci,co;reg [2:0] ng,ogs,kernel,radius;
reg [9:0] iw,ih,ow,oh,row_words,out_row_words;
reg dw,up2,stride2,center,signed_input,has_skip,relu,rgb,stats_pass;
reg [1:0] src_slot,dst_slot,skip_slot;
reg [8:0] wbase;reg [5:0] cbase;reg [6:0] steps;reg signed [24:0] skip_mul;
always @(posedge clk)if(state==CONFIG)begin
 `include "rtl/cnn/glass_int8/style_layers.vh"
 `include "rtl/cnn/glass_int8/packed_layers.vh"
end
function [9:0] reflect;
 input signed [12:0] x;input [10:0] n;
 begin if(x<0)reflect=-x;else if(x>=n)reflect=2*n-2-x;else reflect=x;end
endfunction
function [23:0] row_offset;
 input [9:0] y;input [9:0] words;reg [23:0] p;
 begin p=y*W;if(words==2*W)row_offset=p<<4;else if(words==W)row_offset=p<<3;
 else if(words==W/2)row_offset=p<<2;else if(words==W/4)row_offset=p<<1;else row_offset=0;end
endfunction
function [12:0] cache_base;
 input [2:0] slot;
 begin case(slot)0:cache_base=0;1:cache_base=W;2:cache_base=2*W;3:cache_base=3*W;4:cache_base=4*W;default:cache_base=5*W;endcase
 if(row_words==2*W)cache_base=cache_base<<1;end
endfunction
reg [4:0] coeff_load;reg [615:0] coeff_q;reg [1:0] og_pipe[0:5];
// Serially loaded four-deep coefficient taps map to SRL resources.
wire [1:0] coeff_tap=ogs[1:0]-2'd1-og_pipe[4];
wire [79:0] model_coeff_q;wire [24:0] model_skip_q;
wire [83:0] model_rgb_mul;wire [95:0] model_rgb_bias;
reg [1:0] og;reg [6:0] step;wire [575:0] weight_q;
wire [8:0] model_coeff_addr={cbase,3'b0}+coeff_load;
wire [6:0] model_weight_addr=7'(wbase+og*steps+step);
glass_model_params model_params(
 .clk(clk),.read_bank(param_bank),.weight_addr(model_weight_addr),.weight_q(weight_q),
 .coeff_addr(model_coeff_addr),.coeff_q(model_coeff_q),.layer_addr(layer_index),.skip_q(model_skip_q),
 .rgb_mul(model_rgb_mul),.rgb_bias(model_rgb_bias),
 .cfg_valid(cfg_valid),.cfg_bank(cfg_bank),.cfg_kind(cfg_kind),.cfg_addr(cfg_addr),.cfg_data(cfg_data));
always @(posedge clk)begin

 if(state==COEFF_REQ)skip_mul<=model_skip_q;
end

genvar coeff_lane,coeff_bit;
generate for(coeff_lane=0;coeff_lane<8;coeff_lane=coeff_lane+1)begin:coefficient_lane
 for(coeff_bit=0;coeff_bit<77;coeff_bit=coeff_bit+1)begin:coefficient_bit
  reg [3:0] history;
  always @(posedge clk)begin
   if(state==COEFF_CAP && coeff_load[2:0]==coeff_lane)
    history<={history[2:0],model_coeff_q[coeff_bit]};
   coeff_q[coeff_lane*77+coeff_bit]<=history[coeff_tap];
  end
 end
end endgenerate

reg signed [39:0] sums[0:31];reg [4:0] mean_ch;
wire signed [23:0] mean_lane_value[0:7];
wire signed [39:0] mean_rounded=(sums[mean_ch]+40'sd4096)>>>13;
wire [1:0] mean_tap=ogs[1:0]-2'd1-og_pipe[5];
// Means are consumed only by replay, after all channels have been loaded.
// The statistics pass never emits its quantized (mean-dependent) result.
genvar mean_lane,mean_bit;
generate for(mean_lane=0;mean_lane<8;mean_lane=mean_lane+1)begin:mean_cache_lane
 for(mean_bit=0;mean_bit<24;mean_bit=mean_bit+1)begin:mean_cache_bit
  reg [3:0] history;
  always @(posedge clk)
   if(state==MEAN && mean_ch[2:0]==mean_lane)
    history<={history[2:0],mean_rounded[mean_bit]};
  assign mean_lane_value[mean_lane][mean_bit]=history[mean_tap];
 end
end endgenerate

localparam F_ROWS=0,F_LOAD=1,F_SKIP=2,F_FREE=3,F_PREP=4,F_GATHER=5,F_DRAIN=6,F_SEAL=7,F_ADV=8,F_DONE=9,F_ADDR0=10,F_ADDR1=11;
reg [3:0] fs;reg [9:0] fx,fy;reg [2:0] row_k,loading_slot;
reg [9:0] tags[0:5];reg [5:0] tag_valid;reg [12:0] row_bases[0:4];
reg [9:0] sent,received,load_words;reg [23:0] load_base,front_offset;
reg loading_skip,load_active,load_prefetch;reg [9:0] loading_tag;reg [4:0] tap;reg sliding;
reg fill_bank,consume_bank;reg [1:0] full;
// Mutually exclusive graph shapes share the same 36x64-bit window bank:
// Channel-major: 3x3x32 uses four groups of nine words. RGB uses first 25.
reg [63:0] win0[0:35],win1[0:35];
reg [255:0] skip0,skip1;
reg [23:0] offsets[0:1];reg [9:0] ys[0:1];
wire signed [12:0] yc=stride2?$signed({2'b00,fy,1'b0}):$signed({3'b000,fy});
wire signed [12:0] xc=stride2?$signed({2'b00,fx,1'b0}):$signed({3'b000,fx});
wire [9:0] needed_row=up2?reflect(yc+$signed({10'd0,row_k})-$signed({10'd0,radius}),{ih,1'b0})>>1:
 reflect(yc+$signed({10'd0,row_k})-$signed({10'd0,radius}),{1'b0,ih});
wire [2:0] needed_slot=kernel==5?needed_row%6:kernel==3?{1'b0,needed_row[1:0]}:{2'b0,needed_row[0]};
// One spare row per kernel ring permits DDR reads while the current row runs.
// 5x5: six W-word rows; 3x3: four W-word rows; 1x1: two <=2W rows.
wire [12:0] next_uncached=(up2?((yc+radius)>>1):(yc+radius))+1;
wire [9:0] prefetch_row=next_uncached[9:0];
wire [2:0] prefetch_slot=kernel==5?prefetch_row%6:kernel==3?{1'b0,prefetch_row[1:0]}:{2'b0,prefetch_row[0]};
wire [9:0] prefetch_physical=(layer_index==0 && prefetch_row>=EXT_H)?2*EXT_H-2-prefetch_row:prefetch_row;
wire can_prefetch=fx==0 && fy<oh-1 && next_uncached<ih &&
 !(tag_valid[prefetch_slot] && tags[prefetch_slot]==prefetch_row);
wire [9:0] physical_row=(layer_index==0 && needed_row>=EXT_H)?2*EXT_H-2-needed_row:needed_row;
// Split reflection/row selection from constant-stride DDR address generation.
// F_ADDR0/F_ADDR1 provide two settling clocks after every coordinate change.
reg [9:0] physical_row_q,prefetch_physical_q;
reg [23:0] needed_base_q,prefetch_base_q;
always @(posedge clk)begin
 physical_row_q<=physical_row;prefetch_physical_q<=prefetch_physical;
 needed_base_q<={src_slot,21'd0}+row_offset(physical_row_q,row_words);
 prefetch_base_q<={src_slot,21'd0}+row_offset(prefetch_physical_q,row_words);
end
wire [2:0] tky=kernel==5?tap/5:kernel==3?tap/3:0;
wire [2:0] tkx=kernel==5?tap%5:kernel==3?tap%3:0;
wire [9:0] column=up2?reflect(xc+$signed({10'd0,tkx})-$signed({10'd0,radius}),{iw,1'b0})>>1:
 reflect(xc+$signed({10'd0,tkx})-$signed({10'd0,radius}),{1'b0,iw});
wire [12:0] col_words=ng==4?({3'd0,column}<<2):ng==2?({3'd0,column}<<1):{3'd0,column};
wire gather_skip=has_skip && !stats_pass && tap==25;
wire [12:0] line_addr=gather_skip?6*W+fx*ogs:row_bases[tky]+col_words;
wire [255:0] line_q;
wire front_read=state==RUN && load_active && sent<load_words && sent-received<4;
wire read_accept=mem_valid && mem_ready && !mem_write;
wire front_response=state==RUN && load_active && mem_rvalid;
glass_line4 #(.CAP(7*W)) u_lines(clk,front_response,
 loading_skip?13'(6*W+received):13'(cache_base(loading_slot)+received),mem_rdata,line_addr,line_q);
reg line_valid,line_bank,line_skip;reg [4:0] line_tap;
wire gathering=state==RUN && fs==F_GATHER;
always @(posedge clk)begin
 if(rst)line_valid<=0;else line_valid<=gathering;
 line_bank<=fill_bank;line_tap<=tap;line_skip<=gather_skip;
 if(line_valid && line_skip)begin if(line_bank)skip1<=line_q;else skip0<=line_q;end
end
wire [255:0] window_write=rgb?{4{line_q[63:0]}}:line_q;
genvar wi;
generate for(wi=0;wi<36;wi=wi+1)begin:window_storage
 always @(posedge clk)begin
  if(line_valid && !line_skip)begin
   if((rgb && line_tap==wi && wi<25) || (!rgb && line_tap==wi%9))begin
    if(line_bank)win1[wi]<=window_write[(wi/9)*64+:64];else win0[wi]<=window_write[(wi/9)*64+:64];
   end
  end
  if(state==RUN && fs==F_FREE && !full[fill_bank] && fx!=0 && kernel>1 && !stride2)begin
   if((rgb && wi<25 && wi%5<4) || (!rgb && kernel==3 && wi%3<2))begin
    if(fill_bank)win1[wi]<=win0[wi<35?wi+1:wi];else win0[wi]<=win1[wi<35?wi+1:wi];
   end
  end
 end
end endgenerate
// Dispatch one group immediately after the preceding group; tagged pipeline
// carries its bias/mean index, residual and destination through all stages.
reg computing;
reg [647:0] input_q;
// Mode-specific selectors expose the fixed layer shapes to synthesis. No
// model numbers occur in these selectors; another same-shape ROM is replaceable.
wire [63:0] window_words[0:35];genvar ww;
generate for(ww=0;ww<36;ww=ww+1)begin:window_mux
 assign window_words[ww]=consume_bank?win1[ww]:win0[ww];
end endgenerate
wire [63:0] dw_words[0:8];wire [63:0] stem_words[0:2],rgb_words[0:2];
wire [1:0] std_group=ng==4?step[1:0]:ng==2?{1'b0,step[0]}:2'd0;
wire [63:0] standard_word=kernel==1?window_words[std_group*9]:window_words[step[3:0]];
genvar wt,il;
generate for(wt=0;wt<9;wt=wt+1)begin:dw_select
 assign dw_words[wt]=window_words[wt+og*9];
end
for(wt=0;wt<3;wt=wt+1)begin:row_select
 assign stem_words[wt]=step[1:0]==0?window_words[wt]:step[1:0]==1?window_words[wt+3]:window_words[wt+6];
 wire [4:0] index=5'(step*3+wt);
 assign rgb_words[wt]=index<25?window_words[index]:64'd0;
end endgenerate
wire [647:0] selected;
generate for(il=0;il<72;il=il+1)begin:input_select
 wire [7:0] scalar;
 if(il%9==8)begin
  assign scalar=dw?dw_words[il%9][(il/9)*8+:8]:layer_index==0?stem_words[(il%9)/3][(il%3)*8+:8]:
   rgb?rgb_words[(il%24)/8][(il%8)*8+:8]:8'd0;
 end else begin
  assign scalar=dw?dw_words[il%9][(il/9)*8+:8]:layer_index==0?stem_words[(il%9)/3][(il%3)*8+:8]:
   rgb?rgb_words[(il%24)/8][(il%8)*8+:8]:standard_word[(il%9)*8+:8];
 end
 assign selected[il*9+:9]={signed_input && scalar[7],scalar};
end endgenerate
wire issue=state==RUN && computing;
reg [5:0] valid_pipe,first_pipe,last_pipe;
reg [23:0] addr_pipe[0:5];reg [63:0] skip_pipe[0:5];
reg [5:0] emit_pipe;
reg signed [16:0] product[0:71];reg signed [17:0] sum2[0:35];
reg signed [18:0] sum4[0:17];reg signed [19:0] sum8[0:8];
reg signed [16:0] ninth0[0:7],ninth1[0:7],ninth2[0:7];
reg signed [21:0] dot[0:7];reg signed [23:0] accum[0:7];
wire [615:0] active_coeff=coeff_q;
wire [63:0] active_skip=skip_pipe[5];
wire group_ready=valid_pipe[5] && last_pipe[5];
wire [23:0] result_addr=addr_pipe[5];
wire result_emit=emit_pipe[5];
integer i;
always @(posedge clk)begin
 input_q<=selected;
 if(rst)begin valid_pipe<=0;first_pipe<=0;last_pipe<=0;emit_pipe<=0;end
 else begin
  valid_pipe<={valid_pipe[4:0],issue};first_pipe<={first_pipe[4:0],step==0};
  last_pipe<={last_pipe[4:0],step==steps-1};
  emit_pipe<={emit_pipe[4:0],!stats_pass && (!rgb || ys[consume_bank]<EXT_H)};
 end
 og_pipe[0]<=og;addr_pipe[0]<={dst_slot,21'd0}+offsets[consume_bank]+{19'd0,og,3'd0};
 skip_pipe[0]<=consume_bank?(skip1>>(og*64)):(skip0>>(og*64));
 for(i=1;i<6;i=i+1)begin og_pipe[i]<=og_pipe[i-1];addr_pipe[i]<=addr_pipe[i-1];skip_pipe[i]<=skip_pipe[i-1];end
 for(i=0;i<72;i=i+1)product[i]<=$signed(input_q[i*9+:9])*$signed(weight_q[i*8+:8]);
 for(i=0;i<36;i=i+1)begin
  if(rgb)sum2[i]<=$signed(product[i*2])+$signed(product[i*2+1]);
  else if(i<32)sum2[i]<=$signed(product[(i/4)*9+(i%4)*2])+$signed(product[(i/4)*9+(i%4)*2+1]);
  else sum2[i]<=0;
 end
 for(i=0;i<18;i=i+1)sum4[i]<=$signed(sum2[i*2])+$signed(sum2[i*2+1]);
 for(i=0;i<9;i=i+1)sum8[i]<=$signed(sum4[i*2])+$signed(sum4[i*2+1]);
 for(i=0;i<8;i=i+1)begin
  ninth0[i]<=product[i*9+8];ninth1[i]<=ninth0[i];ninth2[i]<=ninth1[i];
  if(rgb)begin if(i<3)dot[i]<=$signed(sum8[i*3])+$signed(sum8[i*3+1])+$signed(sum8[i*3+2]);else dot[i]<=0;end
  else dot[i]<=$signed(sum8[i])+$signed(ninth2[i]);
 end
end
reg [7:0] qvalid;reg [23:0] qaddr[0:7];wire [63:0] quant_result;
integer q;
always @(posedge clk)begin
 if(rst)qvalid<=0;else qvalid<={qvalid[6:0],group_ready && result_emit};
 qaddr[0]<=result_addr;for(q=1;q<8;q=q+1)qaddr[q]<=qaddr[q-1];
end
genvar lane;
generate for(lane=0;lane<8;lane=lane+1)begin:quant
 wire signed [23:0] total=(first_pipe[5]?$signed(active_coeff[lane*77+:24]):accum[lane])+$signed(dot[lane]);
 reg signed [23:0] centered;reg signed [20:0] mul;
 reg signed [31:0] beta0,beta1;
 reg signed [7:0] skip_code;
 reg signed [44:0] main_product;reg signed [32:0] skip_product;reg signed [47:0] wide;
 wire signed [47:0] rounded=(wide+48'sd8388608)>>>24;
 reg signed [7:0] code0,code1,code2;
 reg [7:0] out0,out1;
 wire signed [7:0] limited=rounded>127?8'sd127:rounded<(relu?0:-127)?(relu?8'sd0:-8'sd127):rounded[7:0];
 always @(posedge clk)begin
  if(valid_pipe[5])accum[lane]<=total;
  if(state==INIT)begin sums[lane]<=0;sums[lane+8]<=0;sums[lane+16]<=0;sums[lane+24]<=0;end
  else if(group_ready && stats_pass)sums[og_pipe[5]*8+lane]<=sums[og_pipe[5]*8+lane]+total;
  if(group_ready)begin centered<=total-(center?mean_lane_value[lane]:24'sd0);
   mul<=active_coeff[lane*77+24+:21];beta0<=active_coeff[lane*77+45+:32];skip_code<=active_skip[lane*8+:8];end
  main_product<=centered*mul;skip_product<=skip_code*skip_mul;beta1<=beta0;
  wide<=main_product+beta1+(has_skip?skip_product:33'sd0);
  code0<=lane<co?limited:8'd0;code1<=code0;code2<=code1;
  out1<=out0;
 end
 if(lane<3)begin:rgb_lane
  wire signed [27:0] RM=model_rgb_mul[lane*28+:28];
  wire signed [31:0] RB=model_rgb_bias[lane*32+:32];
  reg signed [35:0] rp;reg signed [39:0] rw;
  wire signed [39:0] rr=(rw+40'sd8388608)>>>24;
  always @(posedge clk)begin rp<=code0*RM;rw<=rp+RB;out0<=rgb?(rr>255?8'd255:rr<0?8'd0:rr[7:0]):code2;end
 end else begin always @(posedge clk)out0<=rgb?0:code2;end
 assign quant_result[lane*8+:8]=out1;
end endgenerate
// Credits include in-flight quantization, preventing FIFO overflow at stalls.
reg [87:0] fifo[0:31];reg [4:0] wp,rp;reg [5:0] count,credits;
wire push=qvalid[7];wire pop=mem_valid && mem_ready && mem_write;
wire reserve=issue && step==steps-1 && !stats_pass && (!rgb || ys[consume_bank]<EXT_H);
always @(posedge clk)begin
 if(rst)begin wp<=0;rp<=0;count<=0;credits<=0;end
 else begin
  if(push)begin fifo[wp]<={qaddr[7],quant_result};wp<=wp+1'b1;end
  if(pop)rp<=rp+1'b1;
  case({push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:;endcase
  case({reserve,pop})2'b10:credits<=credits+1'b1;2'b01:credits<=credits-1'b1;default:;endcase
 end
end
assign mem_wstrb=8'hff;
always @*begin
 mem_valid=0;mem_write=0;mem_addr=0;mem_wdata=0;
 if(count!=0)begin mem_valid=1;mem_write=1;mem_addr=fifo[rp][87:64];mem_wdata=fifo[rp][63:0];end
 else if(front_read)begin mem_valid=1;mem_addr=load_base+({14'd0,sent}<<3);end
end
wire pipeline_empty=!load_active && !computing && full==0 && valid_pipe==0 && qvalid==0 && count==0 && credits==0;
integer n;
always @(posedge clk)begin
 if(rst)begin
  state<=IDLE;busy<=0;done<=0;layer_done<=0;layer_index<=0;frame_cycles<=0;
  fs<=F_DONE;fx<=0;fy<=0;row_k<=0;tag_valid<=0;full<=0;fill_bank<=0;consume_bank<=0;
  sent<=0;received<=0;load_words<=0;load_base<=0;loading_skip<=0;loading_slot<=0;load_active<=0;load_prefetch<=0;loading_tag<=0;
  tap<=0;sliding<=0;front_offset<=0;computing<=0;og<=0;step<=0;stats_pass<=0;mean_ch<=0;coeff_load<=0;
  // Mean cache is fully loaded before each centered replay.
 end else begin
  done<=0;layer_done<=0;if(busy)frame_cycles<=frame_cycles+1'b1;
  case(state)
   IDLE:if(start)begin busy<=1;frame_cycles<=0;layer_index<=0;state<=CONFIG;end
   CONFIG:begin coeff_load<=0;state<=COEFF_REQ;end
   COEFF_REQ:state<=COEFF_CAP;
   COEFF_CAP:begin
    if({1'b0,coeff_load}=={ogs,3'b0}-1'b1)state<=INIT;
    else begin coeff_load<=coeff_load+1'b1;state<=COEFF_REQ;end
   end
   INIT:begin
    stats_pass<=center;fx<=0;fy<=0;row_k<=0;tag_valid<=0;front_offset<=0;
    full<=0;fill_bank<=0;consume_bank<=0;computing<=0;fs<=F_ADDR0;state<=RUN;
    // Mean cache is fully loaded before each centered replay.
   end
   RUN:begin
    if(load_active)begin
     if(read_accept)sent<=sent+1'b1;
     if(front_response)begin
      received<=received+1'b1;
      if(received==load_words-1)begin
       load_active<=0;
       if(!loading_skip)begin tags[loading_slot]<=loading_tag;tag_valid[loading_slot]<=1;end
       if(!load_prefetch)fs<=loading_skip?F_FREE:F_ROWS;
      end
     end
    end
    case(fs)
     F_ADDR0:fs<=F_ADDR1;
     F_ADDR1:fs<=F_ROWS;
     F_ROWS:if(!load_active)begin
      row_bases[row_k]<=cache_base(needed_slot);
      if(tag_valid[needed_slot] && tags[needed_slot]==needed_row)begin
       if(row_k==kernel-1)begin row_k<=0;fs<=F_SKIP;end else begin row_k<=row_k+1'b1;fs<=F_ADDR0;end
      end else begin
       loading_slot<=needed_slot;loading_tag<=needed_row;load_active<=1;load_prefetch<=0;
       load_base<=needed_base_q;load_words<=row_words;
       sent<=0;received<=0;loading_skip<=0;fs<=F_LOAD;
      end
     end
     F_LOAD:;
     F_SKIP:if(!load_active)begin if(has_skip && !stats_pass)begin
      loading_skip<=1;load_base<={skip_slot,21'd0}+row_offset(fy,out_row_words);load_words<=out_row_words;
      sent<=0;received<=0;load_active<=1;load_prefetch<=0;fs<=F_LOAD;
     end else fs<=F_FREE;end
     F_FREE:if(!full[fill_bank])begin
      if(!load_active && can_prefetch)begin
       loading_slot<=prefetch_slot;loading_tag<=prefetch_row;loading_skip<=0;
       load_base<=prefetch_base_q;load_words<=row_words;
       sent<=0;received<=0;load_active<=1;load_prefetch<=1;
      end
      sliding<=fx!=0 && kernel>1 && !stride2;
      tap<=fx!=0 && kernel>1 && !stride2?kernel-1:0;
      offsets[fill_bank]<=front_offset;ys[fill_bank]<=fy;fs<=F_GATHER;
     end
     F_GATHER:begin
      if(tap==25 || tap==kernel*kernel-1)begin
       if(tap!=25 && has_skip && !stats_pass)tap<=25;else fs<=F_DRAIN;
      end else tap<=tap+(sliding?kernel:1'b1);
     end
     F_DRAIN:begin
      full[fill_bank]<=1;fill_bank<=!fill_bank;
      front_offset<=front_offset+({21'd0,ogs}<<3);
      if(fx==ow-1)begin fx<=0;row_k<=0;if(fy==oh-1)fs<=F_DONE;else begin fy<=fy+1'b1;fs<=F_ADDR0;end end
      else begin fx<=fx+1'b1;fs<=F_FREE;end
     end
     default:;
    endcase
    if(!computing && full[consume_bank] && credits<24)begin computing<=1;og<=0;step<=0;end
    else if(computing)begin
     if(step==steps-1)begin step<=0;
      if(og==ogs-1)begin computing<=0;full[consume_bank]<=0;consume_bank<=!consume_bank;end else og<=og+1'b1;
     end else step<=step+1'b1;
    end
    if(fs==F_DONE && pipeline_empty)begin if(stats_pass)begin mean_ch<=0;state<=MEAN;end else state<=NEXT;end
   end
   MEAN:begin
    if(mean_ch==co-1)state<=REPLAY;else mean_ch<=mean_ch+1'b1;end
   REPLAY:begin
    stats_pass<=0;fx<=0;fy<=0;row_k<=0;tag_valid<=0;front_offset<=0;
    full<=0;fill_bank<=0;consume_bank<=0;computing<=0;fs<=F_ADDR0;state<=RUN;
   end
   NEXT:begin layer_done<=1;
    if(layer_index==21)begin busy<=0;done<=1;state<=IDLE;end
    else begin layer_index<=layer_index+1'b1;state<=CONFIG;end
   end
   default:state<=IDLE;
  endcase
 end
end
// synthesis translate_off
always @(posedge clk)if(!rst)begin
 if(credits>32 || count>32 || (push && count==32 && !pop))$fatal(1,"glass output credit overflow");
 if(front_response && received>=sent)$fatal(1,"Unowned line response");
 if(gathering && !gather_skip && line_addr>=6*W)$fatal(1,"Window address out of range");
 if(computing && !full[consume_bank])$fatal(1,"Window ownership");
end
// synthesis translate_on
// synthesis translate_off
reg [31:0] mean_seen;
always @(posedge clk)begin
 if(rst || state==INIT)mean_seen<=0;
 else if(state==MEAN)mean_seen[mean_ch]<=1'b1;
 if(!rst && state==RUN && center && !stats_pass && group_ready)
  for(integer m=0;m<8;m=m+1)
   if(mean_seen[og_pipe[5]*8+m]!==1'b1)$fatal(1,"Mean read before complete load");
end
// synthesis translate_on
endmodule
