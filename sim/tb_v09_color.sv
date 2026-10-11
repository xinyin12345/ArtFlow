`timescale 1ns/1ps
module tb_v09_color;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,de=0,tag=0;reg [23:0] rgb=0;
wire pat_active,pde,phs,pvs;wire [7:0] pr,pg,pb;
wire ode,ohs,ovs;wire [7:0] r,g,b;
// COLOR_TAG_BLOCK is extracted from the current production top by the runner.
`include "color_tag_block.vh"
test_pattern #(.BOOT_FRAMES(0)) pattern(
 .i_clk(clk),.i_rstn(rst_n),.i_mode(2'd0),.i_de(de),.i_hs(1'b0),.i_vs(1'b0),
 .i_r(rgb[23:16]),.i_g(rgb[15:8]),.i_b(rgb[7:0]),.o_de(pde),.o_hs(phs),.o_vs(pvs),
 .o_r(pr),.o_g(pg),.o_b(pb),.o_active(pat_active));
gamma_lut #(.LUT_FILE("rtl/gamma_conrrection/gamma_inv2p2_8b.mem")) gamma(
 .i_pclk(clk),.i_rstn(rst_n),.i_bypass(gamma_display_rgb),
 .i_valid(pde),.i_hs(phs),.i_vs(pvs),.i_red(pr),.i_green(pg),.i_blue(pb),
 .o_valid(ode),.o_hs(ohs),.o_vs(ovs),.o_red(r),.o_green(g),.o_blue(b));
reg [7:0] lut[0:255];reg [23:0] golden[0:2];reg [2:0] valid=0;
integer checked=0;
always @(posedge clk) begin
 if(!rst_n) begin valid=0;golden[0]=0;golden[1]=0;golden[2]=0;end
 else begin
  golden[2]=golden[1];golden[1]=golden[0];
  golden[0]=!de?0:(tag?rgb:{lut[rgb[23:16]],lut[rgb[15:8]],lut[rgb[7:0]]});
  valid={valid[1:0],de};
  #1;
  if(ode!==valid[2] || {r,g,b}!==golden[2]) $fatal(1,"Gamma/tag latency got=%h expected=%h",{r,g,b},golden[2]);
  checked=checked+1;
 end
end
initial begin
 $readmemh("rtl/gamma_conrrection/gamma_inv2p2_8b.mem",lut);
 repeat(5) @(negedge clk);rst_n=1;
 for(integer i=0;i<1024;i=i+1) begin
  de=i%17!=0;tag=i[0];rgb={8'(i),8'(i*7),8'(i*31)};@(negedge clk);
 end
 de=0;repeat(4) @(negedge clk);
 $display("tb_v09_color PASS checked=%0d",checked);$finish;
end
endmodule
