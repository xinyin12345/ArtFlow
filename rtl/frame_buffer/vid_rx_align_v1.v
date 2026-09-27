

module vid_rx_align_v1 #(
	parameter I_VID_WIDTH = 16,
	parameter AXI_DDR_WIDTH = 256
	 
)(
input		wire										clk		,    
input		wire										rst_n	,
input		wire										i_vs	, //active hgih
input       wire                                        i_hs    ,
input		wire										i_de	, //active high
input		wire	[I_VID_WIDTH-1:0] 					vin     ,

output		wire										fifo_wr_en,
output		wire		[AXI_DDR_WIDTH-1:0]				fifo_wr_data ,
output		reg											frame_start = 1'b0,
output		reg											fifo_rst = 1'b0,
output		wire				[23:0]					frame_cnt,
output      wire									    frame_stable,
output      wire    [31:0]                              ddr_frame_len		


);

	localparam SHIFT_WIDTH = AXI_DDR_WIDTH/I_VID_WIDTH;
	localparam AXI_DATA_SIZE   = $clog2(SHIFT_WIDTH) ;
  reg	[I_VID_WIDTH-1:0] 								din_r0 =16'd0;
  
  reg													vs_r0 = 1'b0;
  reg													de_r0 = 1'b0;
  wire 													neg_vs;
  wire													pos_vs;
  reg 													fifo_reset_en = 1'b0;
  
  wire 													negtive_sync;							
  always @( posedge clk )
  begin
  		vs_r0 	<= i_vs;  		
  		de_r0 	<= i_de; 
  		din_r0  <= vin;
  end
  assign neg_vs = {vs_r0,i_vs} == 2'b10;   
  assign pos_vs = {vs_r0,i_vs} == 2'b01;
wire w_frame_start = (neg_vs && ~negtive_sync)||(pos_vs && negtive_sync);
wire w_frame_end   = (pos_vs && ~negtive_sync)||(neg_vs && negtive_sync);
  
     always@( posedge clk )
    begin
  		if(w_frame_start)
            fifo_reset_en <= 1'b1;
  		else if( de_r0 )
            fifo_reset_en <= 1'b0;
    end
  //before every frame,reset the fifo first
    always @( posedge clk )
        fifo_rst <= w_frame_start;//fifo_reset_en & de_r0 & frame_stable;  
  

 	always @( posedge clk )
 	begin
        if( fifo_rst )
            frame_start <= 1'b1;
        else if(fifo_wr_en)//( wr_en )
            frame_start <= 1'b0;
 	end
  					

generate 
    if( I_VID_WIDTH == 24 ) begin
        ser2par_24_128_v1 # (
            .I_VID_WIDTH(I_VID_WIDTH),
            .AXI_DDR_WIDTH(AXI_DDR_WIDTH)
        )ser2par_24_128_inst (
            .clk            (clk            ),
            .rst_n          (rst_n          ),
            .de             (de_r0          ),
            .frame_start    (w_frame_start  ),//( (neg_vs && ~negtive_sync)||(pos_vs && negtive_sync)),
            .frame_end      (w_frame_end    ),//((neg_vs && ~negtive_sync)||(pos_vs && negtive_sync)),
            .frame_stable   (frame_stable   ),
            // .ddr_frame_len  (ddr_frame_len  ),
            .frame_pix_num  (frame_cnt      ),
            .vin            (din_r0         ),
            .fifo_wr_en     (fifo_wr_en     ),
            .fifo_wr_data   (fifo_wr_data   )
        );
    end else if( I_VID_WIDTH == 16) begin

        ser2par_16_128_v1 # (
            .I_VID_WIDTH(I_VID_WIDTH),
            .AXI_DDR_WIDTH(AXI_DDR_WIDTH)
        )ser2par_16_128_inst (
            .clk            (clk            ),
            .rst_n          (rst_n          ),
            .de             (de_r0          ),
            .frame_start    (w_frame_start  ),//(neg_vs         ),
            .frame_end      (w_frame_end    ),//(pos_vs         ),
            .frame_stable   (frame_stable   ),
            .frame_pix_num  (frame_cnt      ),
            .vin            (din_r0         ),
            .fifo_wr_en     (fifo_wr_en     ),
            .fifo_wr_data   (fifo_wr_data   )
        );
    end else if( I_VID_WIDTH == 32) begin

        ser2par_32_128_v1 # (
            .I_VID_WIDTH(I_VID_WIDTH),
            .AXI_DDR_WIDTH(AXI_DDR_WIDTH)
        )ser2par_32_128_inst (
            .clk            (clk            ),
            .rst_n          (rst_n          ),
            .de             (de_r0          ),
            .frame_start    (w_frame_start  ),//(neg_vs         ),
            .frame_end      (w_frame_end    ),//(pos_vs         ),
            .frame_stable   (frame_stable   ),
            .frame_pix_num  (frame_cnt      ),
            .vin            (din_r0         ),
            .fifo_wr_en     (fifo_wr_en     ),
            .fifo_wr_data   (fifo_wr_data   )
        );
    end
endgenerate



  
  
frame_info_det #(
    .I_VID_WIDTH(I_VID_WIDTH),
    .AXI_DDR_WIDTH(AXI_DDR_WIDTH)
)u_frame_info_det(
/*i*/.clk			(clk		),    
/*i*/.rst_n			(rst_n	    ),
/*i*/.i_vs			(i_vs	    ), //active hgih
/*i*/.i_hs          (i_hs       ),
/*i*/.i_de			(i_de	    ), //active high
                    
/*o*/.frame_cnt_o	(frame_cnt),
/*o*/.frame_stable  (frame_stable	),
/*O*/.negtive_sync  (negtive_sync   ),
/*O*/.ddr_frame_len (ddr_frame_len)
);             



endmodule
