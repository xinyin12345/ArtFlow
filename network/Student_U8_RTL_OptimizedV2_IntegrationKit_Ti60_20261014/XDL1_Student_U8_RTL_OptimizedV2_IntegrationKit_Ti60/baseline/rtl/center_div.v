// Exact same-frame signed half-up(S_A*M/N), beta minus result.
module center_div(input clk,input rst,input start,
 input signed [39:0] sum,input signed [20:0] multiplier,
 input signed [31:0] beta,input [19:0] area,
 output reg done,output reg signed [47:0] dynamic_bias);
 reg [2:0] state;reg signed [60:0] product;
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
 0:if(start)begin saved_sum<=sum;saved_multiplier<=multiplier;saved_beta<=beta;n<=area;state<=1;end
 1:begin product<=saved_sum*saved_multiplier;state<=2;end
 2:begin
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
