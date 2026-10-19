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
