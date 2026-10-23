// Two complete parameter banks. The loader only writes the inactive bank.
// Narrow coefficient storage feeds a per-layer cache, preserving 8-lane issue.
module glass_model_params(
 input clk,read_bank,input [6:0] weight_addr,output reg [575:0] weight_q,
 input [8:0] coeff_addr,output reg [79:0] coeff_q,
 input [4:0] layer_addr,output reg [24:0] skip_q,
 output [83:0] rgb_mul,output [95:0] rgb_bias,
 input cfg_valid,cfg_bank,input [1:0] cfg_kind,input [9:0] cfg_addr,input [575:0] cfg_data
);
reg [575:0] weights[0:255];
reg [79:0] coeffs[0:1023];
reg [24:0] skips[0:63];
reg [83:0] rgb_m[0:1];reg [95:0] rgb_b[0:1];
initial $readmemh("rtl/cnn/glass_int8/style_weights_init.mem",weights);
initial $readmemh("rtl/cnn/glass_int8/style_coeff_init.mem",coeffs);
initial $readmemh("rtl/cnn/glass_int8/style_skip_init.mem",skips);
`include "rtl/cnn/glass_int8/style_rgb_init.vh"
assign rgb_mul=rgb_m[read_bank];assign rgb_bias=rgb_b[read_bank];
always @(posedge clk)begin
 weight_q<=weights[{read_bank,weight_addr}];
 coeff_q<=coeffs[{read_bank,coeff_addr}];
 skip_q<=skips[{read_bank,layer_addr}];
 if(cfg_valid && cfg_kind==0)weights[{cfg_bank,cfg_addr[6:0]}]<=cfg_data;
 if(cfg_valid && cfg_kind==1)coeffs[{cfg_bank,cfg_addr[8:0]}]<=cfg_data[79:0];
 if(cfg_valid && cfg_kind==2 && cfg_addr<22)skips[{cfg_bank,cfg_addr[4:0]}]<=cfg_data[24:0];
 if(cfg_valid && cfg_kind==2)case(cfg_addr)
  10'd22:rgb_m[cfg_bank][0+:28]<=cfg_data[27:0];
  10'd23:rgb_m[cfg_bank][28+:28]<=cfg_data[27:0];
  10'd24:rgb_m[cfg_bank][56+:28]<=cfg_data[27:0];
  10'd25:rgb_b[cfg_bank][0+:32]<=cfg_data[31:0];
  10'd26:rgb_b[cfg_bank][32+:32]<=cfg_data[31:0];
  10'd27:rgb_b[cfg_bank][64+:32]<=cfg_data[31:0];
  default:;
 endcase
end
// synthesis translate_off
always @(posedge clk)if(cfg_valid)begin
 if(cfg_kind==0 && cfg_addr>=128)$fatal(1,"Weight configuration address");
 if(cfg_kind==1 && cfg_addr>=512)$fatal(1,"Coefficient configuration address");
 if(cfg_kind==2 && cfg_addr>=28)$fatal(1,"Scalar configuration address");
 if(cfg_kind==3)$fatal(1,"Unknown configuration kind");
end
// synthesis translate_on
endmodule
