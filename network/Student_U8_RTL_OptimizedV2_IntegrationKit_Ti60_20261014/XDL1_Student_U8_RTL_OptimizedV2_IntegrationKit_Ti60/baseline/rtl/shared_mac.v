// 96 shared products. U8/S8/S12 inputs normalized to signed 13 bits; ACC24.
module shared_mac(input clk,input rst,input issue,input last,input dw,
 input [575:0] dw_samples,input [155:0] samples,input [767:0] weights,
 input init0,input init1,input [95:0] biases,
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
     if(init0 && o<4)ac[o]<=$signed(biases[(o%4)*24+:24]);
     else if(init1 && o>=4)ac[o]<=$signed(biases[(o%4)*24+:24]);
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
