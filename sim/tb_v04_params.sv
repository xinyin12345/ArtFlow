`timescale 1ns/1ps
module tb_v04_params;
// Deliberately inconsistent input/output geometry must fail before simulation.
cam_fb_pipe #(.MAX_IN_WIDTH(64),.MAX_IN_HEIGHT(16),.MAX_OUT_WIDTH(31)) invalid_config();
initial begin #100;$fatal(1,"Parameter guard did not fire");end
endmodule
