`timescale 1ns/1ps
module tb_afs_tap;
reg clk=0;always #5 clk=~clk;wire valid;wire [9:0] x,y;wire [23:0] rgb;
rgb_frame_store_v07 dut(.rst_n(1'b0),.i_clk(clk),.axi_clk(clk),.o_clk(clk),
.H_FRONT_PORCH(13'd1),.H_SYNC(13'd0),.H_VALID(13'd1920),.H_BACK_PORCH(13'd0),
.V_FRONT_PORCH(13'd1),.V_SYNC(13'd0),.V_VALID(13'd1080),.V_BACK_PORCH(13'd0),
.stream_valid(valid),.stream_x(x),.stream_y(y),.stream_rgb(rgb));
initial begin
force dut.qcount=1;force dut.pixel=0;force dut.display_epoch=7;force dut.frame_bad=0;
force dut.q0={1'b1,1'b0,32'd7,96'd0,32'h00123456};force dut.active_layout=0;
force dut.hx=960;force dut.vy=270;#1;if(!valid||x!=0||y!=0||rgb!=24'h123456)$fatal(1,"pair origin");
force dut.hx=1914;force dut.vy=804;#1;if(!valid||x!=954||y!=534)$fatal(1,"pair last sample");
force dut.hx=959;#1;if(valid)$fatal(1,"original half leaked");
force dut.active_layout=2;#1;if(valid)$fatal(1,"original fullscreen leaked");
force dut.active_layout=1;force dut.hx=1908;force dut.vy=1068;#1;if(!valid||x!=954||y!=534)$fatal(1,"fullscreen sample");
force dut.hx=1909;#1;if(valid)$fatal(1,"horizontal duplicate");
force dut.hx=1908;force dut.vy=1069;#1;if(valid)$fatal(1,"vertical duplicate");
force dut.vy=1068;force dut.q0={1'b0,1'b0,32'd7,96'd0,32'h00123456};#1;if(valid)$fatal(1,"unavailable style leaked");
force dut.q0={1'b1,1'b0,32'd6,96'd0,32'h00123456};#1;if(valid)$fatal(1,"stale epoch leaked");
force dut.q0={1'b1,1'b1,32'd7,96'd0,32'h00123456};#1;if(valid)$fatal(1,"DDR error leaked");
force dut.q0={1'b1,1'b0,32'd7,96'd0,32'h00123456};force dut.frame_bad=1;#1;if(valid)$fatal(1,"bad frame leaked");
$display("PASS AFS display tap 11 selection/coordinate/tag/error cases");$finish;end
endmodule
