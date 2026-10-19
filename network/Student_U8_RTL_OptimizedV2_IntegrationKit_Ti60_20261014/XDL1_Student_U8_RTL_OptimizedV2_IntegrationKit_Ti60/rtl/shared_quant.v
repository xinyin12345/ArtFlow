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
