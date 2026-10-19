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
