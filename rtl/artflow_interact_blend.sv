// Inputs are already in display RGB space. One-cycle, fixed-latency raster pipeline.
module artflow_interact_blend(
 input logic clk,rst_n,de,hs,vs, input logic [10:0] x,y,
 input logic [23:0] original_rgb,style_rgb,
 input logic [2:0] mode,level, input logic mask,
 input logic [10:0] x0,y0,x1,y1,split_x,
 output logic ode,ohs,ovs, output logic [10:0] ox,oy, output logic [23:0] rgb);
function automatic [7:0] mix(input [7:0] a,b,input [2:0] l);
 reg [8:0] sum;
 reg [9:0] extra,v;
 begin
 sum={1'b0,a}+{1'b0,b};
 extra=(l==2)?{1'b0,sum}:((l==3)?{1'b0,b,1'b0}:{1'b0,a,1'b0});
 v={1'b0,sum}+extra+10'd2;
 case(l)
 0:mix=a;
 1,2,3:mix=v[9:2];
 4:mix=b;
 default:mix=a;
 endcase
 end
endfunction
logic selected;
always_comb begin
 case(mode)
 1:selected=(x>=x0 && x<x1 && y>=y0 && y<y1);
 2:selected=x<split_x;
 3:selected=mask;
 4:selected=1'b1;
 default:selected=1'b0;
 endcase
end
always_ff @(posedge clk or negedge rst_n)
 if(!rst_n) begin ode<=0;ohs<=0;ovs<=0;ox<=0;oy<=0;rgb<=0;end
 else begin
 ode<=de;ohs<=hs;ovs<=vs;ox<=x;oy<=y;
 if(!de) rgb<=0;
 else if(!selected) rgb<=original_rgb;
 else rgb<={mix(original_rgb[23:16],style_rgb[23:16],level),
             mix(original_rgb[15:8],style_rgb[15:8],level),
             mix(original_rgb[7:0],style_rgb[7:0],level)};
 end
endmodule

