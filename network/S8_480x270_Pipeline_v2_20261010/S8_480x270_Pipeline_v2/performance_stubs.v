// SIMULATION ONLY. Never included in the synthesis project.
// Same pipeline latencies as verified arithmetic modules; values do not affect control.
module shared_mac(input clk,input rst,input issue,input last,input dw,
 input sign_in,input [287:0] dw_samples,input [95:0] samples,input [767:0] weights,
 input init0,input init1,input [79:0] biases,output reg finished,output [159:0] accum);
 reg v1,v2,l1,l2;
 assign accum=0;
 always @(posedge clk)if(rst)begin v1<=0;v2<=0;l1<=0;l2<=0;finished<=0;end
 else begin v1<=issue;v2<=v1;l1<=issue&&last;l2<=l1;finished<=v2&&l2;end
endmodule
module shared_quant(input clk,input rst,input valid_in,input [1:0] mode_in,
 input [79:0] accum,input [35:0] skip_mul,input [35:0] skip_codes,
 input [143:0] main_mul,output reg valid_out,output [31:0] codes);
 reg v1,v2;assign codes=0;
 always @(posedge clk)if(rst)begin v1<=0;v2<=0;valid_out<=0;end
 else begin v1<=valid_in;v2<=v1;valid_out<=v2;end
endmodule
module shared_line #(parameter W=480)(input clk,input we,input [15:0] waddr,
 input [63:0] wdata,input [15:0] raddr,output [95:0] rdata);
 assign rdata=0;
endmodule
