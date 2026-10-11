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
