// Exact glass INT8, 64 shared MACs, five cached rows, two-pass sum/8192.
module glass_int8 #(parameter EXT_W=480,EXT_H=270)(
 input clk,rst,start,output reg busy,done,
 output reg mem_valid,mem_write,output reg [23:0] mem_addr,
 output reg [63:0] mem_wdata,output [7:0] mem_wstrb,
 input mem_ready,mem_rvalid,input [63:0] mem_rdata,
 output reg layer_done,output reg [4:0] layer_index,output reg [31:0] frame_cycles);
 localparam W=EXT_W,H=((EXT_H+3)/4)*4,ROW_WORDS=2*W;
 localparam IDLE=0,CONFIG=1,BEGIN_LAYER=2,ROWS=3,LOAD=5,LOAD_WAIT=6,
 GROUP=7,INIT=8,ISSUE=9,MAC_WAIT=10,ACC_DONE=11,SKIP=12,SKIP_WAIT=13,
 QUANT0=14,QUANT1=15,QUANT2=16,QUANT3=17,QUANT4=18,WRITE=19,
 NEXT_GROUP=20,NEXT_PIXEL=21,END_PASS=22,MEANS=23,NEXT_LAYER=24;
 reg [4:0] state;
 reg [5:0] ci,co;reg [2:0] ng,ogs,kernel,radius;reg [9:0] iw,ih,ow,oh,row_words,out_row_words;
 reg dw,up2,stride2,center,signed_input,has_skip,relu,rgb,stats_pass;
 reg [1:0] src_slot,dst_slot,skip_slot;
 reg [8:0] wbase;reg [5:0] cbase;reg [6:0] steps;reg signed [24:0] skip_mul;
 always @(posedge clk) if(state==CONFIG)begin
 `include "rtl/cnn/glass_int8/layers.vh"
 end
 function [9:0] reflect;
 input signed [12:0] x;input [10:0] n;
 begin if(x<0)reflect=-x;else if(x>=n)reflect=2*n-2-x;else reflect=x;end
 endfunction
 function [23:0] row_offset;
 input [9:0] y;input [9:0] words;reg [23:0] p;
 begin p=y*W;if(words==2*W)row_offset=p<<4;else if(words==W)row_offset=p<<3;
 else if(words==W/2)row_offset=p<<2;else if(words==W/4)row_offset=p<<1;
 else row_offset=0;end endfunction
 function [12:0] cache_base;
 input [2:0] slot;
 begin case(slot)
 0:cache_base=0;1:cache_base=W;2:cache_base=2*W;
 3:cache_base=3*W;default:cache_base=4*W;
 endcase if(row_words==2*W)cache_base=cache_base<<1;end endfunction
 reg [9:0] x,y;reg [1:0] og;reg [2:0] row_k,load_slot;
 reg [9:0] row_tags[0:4];reg [4:0] row_valid;reg [12:0] row_bases[0:4];
 reg [9:0] load_index;reg [23:0] load_addr,out_offset;
 reg [2:0] ky,kx,ig;reg [6:0] issued;reg [8:0] weight_addr;
 wire signed [12:0] yc=stride2?$signed({2'b00,y,1'b0}):$signed({3'b000,y});
 wire signed [12:0] xc=stride2?$signed({2'b00,x,1'b0}):$signed({3'b000,x});
 wire [9:0] needed_row=up2?
 reflect(yc+$signed({10'd0,row_k})-$signed({10'd0,radius}),{ih,1'b0})>>1:
 reflect(yc+$signed({10'd0,row_k})-$signed({10'd0,radius}),{1'b0,ih});
 wire [2:0] needed_slot=kernel==5?needed_row%5:needed_row%3;
 wire [9:0] physical_row=(layer_index==0 && needed_row>=EXT_H)?2*EXT_H-2-needed_row:needed_row;
 wire [9:0] column=up2?
 reflect(xc+$signed({10'd0,kx})-$signed({10'd0,radius}),{iw,1'b0})>>1:
 reflect(xc+$signed({10'd0,kx})-$signed({10'd0,radius}),{1'b0,iw});
 wire [12:0] column_offset=ng==4?({3'd0,column}<<2):ng==2?({3'd0,column}<<1):{3'd0,column};
 wire [12:0] line_addr=row_bases[ky]+column_offset+(dw?{11'd0,og}:{10'd0,ig});
 reg [63:0] lines[0:6*W-1];reg [63:0] line_q;
 reg [511:0] weights[0:255];reg [511:0] weight_q;
 reg [615:0] coeff_q;
(* syn_romstyle="logic" *) reg [76:0] coeff0[0:63];
 initial $readmemh("rtl/cnn/glass_int8/coeff0.mem",coeff0);
 always @(posedge clk)coeff_q[0+:77]<=coeff0[cbase+og];
(* syn_romstyle="logic" *) reg [76:0] coeff1[0:63];
 initial $readmemh("rtl/cnn/glass_int8/coeff1.mem",coeff1);
 always @(posedge clk)coeff_q[77+:77]<=coeff1[cbase+og];
(* syn_romstyle="logic" *) reg [76:0] coeff2[0:63];
 initial $readmemh("rtl/cnn/glass_int8/coeff2.mem",coeff2);
 always @(posedge clk)coeff_q[154+:77]<=coeff2[cbase+og];
(* syn_romstyle="logic" *) reg [76:0] coeff3[0:63];
 initial $readmemh("rtl/cnn/glass_int8/coeff3.mem",coeff3);
 always @(posedge clk)coeff_q[231+:77]<=coeff3[cbase+og];
(* syn_romstyle="logic" *) reg [76:0] coeff4[0:63];
 initial $readmemh("rtl/cnn/glass_int8/coeff4.mem",coeff4);
 always @(posedge clk)coeff_q[308+:77]<=coeff4[cbase+og];
(* syn_romstyle="logic" *) reg [76:0] coeff5[0:63];
 initial $readmemh("rtl/cnn/glass_int8/coeff5.mem",coeff5);
 always @(posedge clk)coeff_q[385+:77]<=coeff5[cbase+og];
(* syn_romstyle="logic" *) reg [76:0] coeff6[0:63];
 initial $readmemh("rtl/cnn/glass_int8/coeff6.mem",coeff6);
 always @(posedge clk)coeff_q[462+:77]<=coeff6[cbase+og];
(* syn_romstyle="logic" *) reg [76:0] coeff7[0:63];
 initial $readmemh("rtl/cnn/glass_int8/coeff7.mem",coeff7);
 always @(posedge clk)coeff_q[539+:77]<=coeff7[cbase+og];
 initial begin
 $readmemh("rtl/cnn/glass_int8/weights.mem",weights);
 end
 always @(posedge clk)begin
 if(state==LOAD_WAIT && mem_rvalid)lines[cache_base(load_slot)+load_index]<=mem_rdata;
 line_q<=lines[line_addr];weight_q<=weights[weight_addr];
 end
 reg [4:0] valid_pipe,last_pipe;
 reg signed [16:0] product[0:63];reg signed [17:0] sum2[0:31];
 reg signed [18:0] sum4[0:15];reg signed [19:0] sum8[0:7];
 reg signed [23:0] accum[0:7];reg signed [39:0] sums[0:31];
 reg signed [23:0] means[0:31];reg [4:0] mean_ch;
 integer a,b;
 always @(posedge clk)begin
 if(rst)begin valid_pipe<=0;last_pipe<=0;end
 else begin valid_pipe<={valid_pipe[3:0],state==ISSUE};
 last_pipe<={last_pipe[3:0],state==ISSUE && issued==steps-1};end
 for(a=0;a<8;a=a+1)begin
 for(b=0;b<8;b=b+1)
 product[a*8+b]<=$signed({signed_input & line_q[b*8+7],line_q[b*8+:8]})*$signed(weight_q[(a*8+b)*8+:8]);
 for(b=0;b<4;b=b+1)sum2[a*4+b]<=$signed(product[a*8+2*b])+$signed(product[a*8+2*b+1]);
 for(b=0;b<2;b=b+1)sum4[a*2+b]<=$signed(sum2[a*4+2*b])+$signed(sum2[a*4+2*b+1]);
 sum8[a]<=$signed(sum4[a*2])+$signed(sum4[a*2+1]);
 if(state==INIT)accum[a]<=$signed(coeff_q[a*77+:24]);
 else if(valid_pipe[4])accum[a]<=accum[a]+sum8[a];
 if(state==ACC_DONE && stats_pass)sums[og*8+a]<=sums[og*8+a]+accum[a];
 end
 if(state==BEGIN_LAYER)for(a=0;a<32;a=a+1)begin sums[a]<=0;means[a]<=0;end
 if(state==MEANS)means[mean_ch]<=(sums[mean_ch]+40'sd4096)>>>13;
 end
 reg [63:0] skip_data,result_codes;reg [2:0] qchannel;
 genvar qi;
 generate for(qi=0;qi<8;qi=qi+1)begin:q_lane
 reg signed [23:0] centered;
 reg signed [20:0] multiplier;
 reg signed [31:0] beta;
 reg signed [44:0] main_product;
 reg signed [32:0] skip_product;
 reg signed [47:0] wide;
 wire signed [47:0] rounded=(wide+48'sd8388608)>>>24;
 wire signed [7:0] int_code=rounded>127?8'sd127:rounded<(relu?0:-127)?(relu?8'sd0:-8'sd127):rounded[7:0];
 reg signed [7:0] code_q;wire [7:0] rgb_code;
 always @(posedge clk)begin
 if(state==QUANT0)begin
 centered<=accum[qi]-(center?means[og*8+qi]:24'sd0);
 multiplier<=$signed(coeff_q[qi*77+24+:21]);beta<=$signed(coeff_q[qi*77+45+:32]);end
 if(state==QUANT1)begin main_product<=centered*multiplier;
 skip_product<=$signed(skip_data[qi*8+:8])*skip_mul;end
 if(state==QUANT2)wide<=main_product+beta+(has_skip?skip_product:33'sd0);
 if(state==QUANT3)begin code_q<=int_code;
 if(!rgb)result_codes[qi*8+:8]<=og*8+qi<co?int_code:8'd0;end
 if(state==28)result_codes[qi*8+:8]<=rgb_code;
 end
 if(qi<3)begin:rgb_lane
 localparam signed [27:0] RM=qi==0?28'sd72863011:qi==1?28'sd71272116:28'sd71590295;
 localparam signed [31:0] RB=qi==0?32'sd2074922189:qi==1?32'sd1950854676:32'sd1736945172;
 reg signed [35:0] product;
 reg signed [39:0] wide_rgb;
 wire signed [39:0] rounded_rgb=(wide_rgb+40'sd8388608)>>>24;
 always @(posedge clk)begin
 if(state==QUANT4)product<=code_q*RM;
 if(state==27)wide_rgb<=product+RB;

 end
 assign rgb_code=rounded_rgb>255?8'd255:rounded_rgb<0?8'd0:rounded_rgb[7:0];
 end else begin:padding
 assign rgb_code=8'd0;
 end
 end endgenerate
 assign mem_wstrb=8'hff;
 always @*begin
 mem_valid=0;mem_write=0;mem_addr=0;mem_wdata=result_codes;
 if(state==LOAD)begin mem_valid=1;mem_addr=load_addr;end
 if(state==SKIP)begin mem_valid=1;mem_addr={skip_slot,21'd0}+out_offset+{19'd0,og,3'd0};end
 if(state==WRITE && (!rgb||y<EXT_H))begin
 mem_valid=1;mem_write=1;mem_addr={dst_slot,21'd0}+out_offset+{19'd0,og,3'd0};end
 end
 always @(posedge clk)begin
 if(rst)begin state<=IDLE;busy<=0;done<=0;layer_done<=0;layer_index<=0;frame_cycles<=0;
 x<=0;y<=0;og<=0;ky<=0;kx<=0;ig<=0;row_k<=0;load_slot<=0;load_index<=0;load_addr<=0;row_valid<=0;
 issued<=0;weight_addr<=0;out_offset<=0;stats_pass<=0;mean_ch<=0;skip_data<=0;qchannel<=0;
 end else begin
 done<=0;layer_done<=0;if(busy)frame_cycles<=frame_cycles+1'b1;
 case(state)
 IDLE:if(start)begin state<=CONFIG;busy<=1;layer_index<=0;frame_cycles<=0;end
 CONFIG:state<=BEGIN_LAYER;
 BEGIN_LAYER:begin stats_pass<=center;x<=0;y<=0;og<=0;out_offset<=0;row_valid<=0;row_k<=0;state<=ROWS;end
 ROWS:begin row_bases[row_k]<=cache_base(needed_slot);
 if(row_valid[needed_slot]&&row_tags[needed_slot]==needed_row)begin
 if(row_k==kernel-1)begin state<=GROUP;row_k<=0;end else row_k<=row_k+1'b1;end
 else begin load_slot<=needed_slot;row_tags[needed_slot]<=needed_row;row_valid[needed_slot]<=1;
 load_addr<={src_slot,21'd0}+row_offset(physical_row,row_words);load_index<=0;state<=LOAD;end end
 LOAD:if(mem_ready)state<=LOAD_WAIT;
 LOAD_WAIT:if(mem_rvalid)begin if(load_index==row_words-1)state<=ROWS;
 else begin load_index<=load_index+1'b1;load_addr<=load_addr+8;state<=LOAD;end end
 GROUP:state<=INIT;
 INIT:begin ky<=0;kx<=0;ig<=0;issued<=0;weight_addr<=wbase+og*steps;state<=ISSUE;end
 ISSUE:begin weight_addr<=weight_addr+1'b1;issued<=issued+1'b1;
 if(issued==steps-1)state<=MAC_WAIT;
 else if(dw||ig==ng-1)begin ig<=0;if(kx==kernel-1)begin kx<=0;ky<=ky+1'b1;end else kx<=kx+1'b1;end
 else ig<=ig+1'b1;end
 MAC_WAIT:if(last_pipe[4])state<=ACC_DONE;
 ACC_DONE:begin qchannel<=0;if(stats_pass)state<=NEXT_GROUP;else if(has_skip)state<=SKIP;else begin skip_data<=0;state<=QUANT0;end end
 SKIP:if(mem_ready)state<=SKIP_WAIT;
 SKIP_WAIT:if(mem_rvalid)begin skip_data<=mem_rdata;state<=QUANT0;end
 QUANT0:state<=QUANT1;QUANT1:state<=QUANT2;QUANT2:state<=QUANT3;
 QUANT3:if(rgb)state<=QUANT4;else state<=WRITE;
 QUANT4:state<=27;27:state<=28;
 28:state<=WRITE;
 WRITE:if(mem_ready||(rgb&&y>=EXT_H))state<=NEXT_GROUP;
 NEXT_GROUP:if(og==ogs-1)begin og<=0;state<=NEXT_PIXEL;end else begin og<=og+1'b1;state<=GROUP;end
 NEXT_PIXEL:begin out_offset<=out_offset+({21'd0,ogs}<<3);
 if(x==ow-1)begin x<=0;row_k<=0;if(y==oh-1)state<=END_PASS;else begin y<=y+1'b1;state<=ROWS;end end
 else begin x<=x+1'b1;state<=GROUP;end end
 END_PASS:if(stats_pass)begin mean_ch<=0;state<=MEANS;end else state<=NEXT_LAYER;
 MEANS:if(mean_ch==co-1)begin stats_pass<=0;x<=0;y<=0;og<=0;out_offset<=0;row_valid<=0;row_k<=0;state<=ROWS;end else mean_ch<=mean_ch+1'b1;
 NEXT_LAYER:begin layer_done<=1;if(layer_index==21)begin busy<=0;done<=1;state<=IDLE;end else begin layer_index<=layer_index+1'b1;state<=CONFIG;end end
 default:state<=IDLE;endcase end end
 // synthesis translate_off
 always @(posedge clk)if(!rst)begin
 if(state==LOAD && load_index>=ROW_WORDS)$fatal(1,"glass row capacity");
 if(state==ISSUE && line_addr>=6*W)$fatal(1,"glass cache address");
 end
 // synthesis translate_on
endmodule



