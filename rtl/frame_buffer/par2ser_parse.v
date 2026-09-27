
module par2ser_parse#(
    parameter VID_WIDTH = 24,
    parameter AXI_DATA_WIDTH	= 512
)(
    input clk,
    input rst_n,
 
    input frame_period,
    input rd_fifo_rdvalid,
    input [AXI_DATA_WIDTH-1:0]rd_fifo_rddata ,
    input rd_fifo_rdempty,
    output rd_fifo_rden,
    input [31:0] ddr_frame_len,

    output [VID_WIDTH-1:0] tx_fifo_wrdata,
    output tx_fifo_valid,
    input  tx_fifo_full

);

    generate
        
   if( VID_WIDTH == 24 ) begin
    
  
    par2ser_128_24_v1 #(
        .VID_WIDTH (VID_WIDTH),
        .AXI_DATA_WIDTH	(AXI_DATA_WIDTH) 

    )u_par2ser_128_24(
    /*i*/.clk               (clk              ),
    /*i*/.rst_n             (rst_n            ),
    /*i*/.frame_period      (frame_period     ),
    /*i*/.frame_lenth       (ddr_frame_len    ),

    /*i*/.rd_fifo_rdvalid   (rd_fifo_rdvalid  ),
    /*i*/.rd_fifo_rddata    (rd_fifo_rddata   ),
    /*i*/.rd_fifo_rdempty   (rd_fifo_rdempty  ),
    /*o*/.rd_fifo_rden      ( rd_fifo_rden    ),
    /*o*/.tx_fifo_valid     ( tx_fifo_valid   ),
    /*i*/.wr_fifo_full      (tx_fifo_full     ),
    /*i*/.tx_fifo_wrdata    (tx_fifo_wrdata   )
);
   end else if(VID_WIDTH == 16 ) begin
    par2ser_128_16_v1 #(
        .VID_WIDTH (VID_WIDTH),
        .AXI_DATA_WIDTH	(AXI_DATA_WIDTH) 

    )u_par2ser_128_16(
    /*i*/.clk               (clk              ),
    /*i*/.rst_n             (rst_n            ),
    /*i*/.frame_period      (frame_period     ),
    /*i*/.frame_lenth       (ddr_frame_len    ),

    /*i*/.rd_fifo_rdvalid   (rd_fifo_rdvalid  ),
    /*i*/.rd_fifo_rddata    (rd_fifo_rddata   ),
    /*i*/.rd_fifo_rdempty   (rd_fifo_rdempty  ),
    /*o*/.rd_fifo_rden      ( rd_fifo_rden    ),
    /*o*/.tx_fifo_valid     ( tx_fifo_valid   ),
    /*i*/.wr_fifo_full      (tx_fifo_full     ),
    /*i*/.tx_fifo_wrdata    (tx_fifo_wrdata   )
);

   end else if(VID_WIDTH == 32 ) begin
    par2ser_128_32_v1 #(
        .VID_WIDTH (VID_WIDTH),
        .AXI_DATA_WIDTH	(AXI_DATA_WIDTH) 

    )u_par2ser_128_16(
    /*i*/.clk               (clk              ),
    /*i*/.rst_n             (rst_n            ),
    /*i*/.frame_period      (frame_period     ),
    /*i*/.frame_lenth       (ddr_frame_len    ),

    /*i*/.rd_fifo_rdvalid   (rd_fifo_rdvalid  ),
    /*i*/.rd_fifo_rddata    (rd_fifo_rddata   ),
    /*i*/.rd_fifo_rdempty   (rd_fifo_rdempty  ),
    /*o*/.rd_fifo_rden      ( rd_fifo_rden    ),
    /*o*/.tx_fifo_valid     ( tx_fifo_valid   ),
    /*i*/.wr_fifo_full      (tx_fifo_full     ),
    /*i*/.tx_fifo_wrdata    (tx_fifo_wrdata   )
);
    end
endgenerate

endmodule

