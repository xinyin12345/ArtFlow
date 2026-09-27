// (C) 2001-2016 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


module oc_i2c_master (
//    inout scl_pad_io ,
//    inout sda_pad_io ,
    
	input  scl_pad_i,       // SCL-line input
	output scl_pad_o,       // SCL-line output (always 1'b0)
	output scl_padoen_o,    // SCL-line output enable (active low)

	input  sda_pad_i,       // SDA-line input
	output sda_pad_o,       // SDA-line output (always 1'b0)
	output sda_padoen_o,    // SDA-line output enable (active low)
    
    
    
    output wb_ack_o ,
    input [2:0] wb_adr_i  ,
    input wb_clk_i ,
    //input wb_cyc_i ,
    input [31:0] wb_dat_i ,
    output [31:0] wb_dat_o ,
    //wb_err_o ,
    input wb_rst_i ,
    input wb_stb_i,
    input wb_we_i,
    output wb_inta_o
  );

  i2c_master_top i2c_top_inst (
                .wb_clk_i  (wb_clk_i),  
                .wb_rst_i  (wb_rst_i),  
                .arst_i    (1'b1),    
                .wb_adr_i  (wb_adr_i),  
                .wb_dat_i  (wb_dat_i),  
                .wb_dat_o  (wb_dat_o),  
                .wb_we_i   (wb_we_i),   
                .wb_stb_i  (wb_stb_i),  
                .wb_cyc_i  (1),  
                .wb_ack_o  (wb_ack_o),  
                .wb_inta_o (wb_inta_o), 
                // i2c lines
                .scl_pad_i     (scl_pad_i		),   
                .scl_pad_o     (scl_pad_o		),   
                .scl_padoen_o  (scl_padoen_o),
                .sda_pad_i     (sda_pad_i		),   
                .sda_pad_o     (sda_pad_o		),   
                .sda_padoen_o  (sda_padoen_o)
  );


  
endmodule


