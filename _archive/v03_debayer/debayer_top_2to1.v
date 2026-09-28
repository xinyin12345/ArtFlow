module debayer_top_2to1
(
	input			in_pclk,
	input			in_rstn,
	
	input			raw_vs_i,
	input			raw_hs_i,
	input			raw_de_i,
	input			raw_valid_i,
	input	[15:0]	raw_datax4_i,
	input [15:0] r_gain,
	input [15:0] g_gain,
	input [15:0] b_gain,
	
	output				rgb_vs_o,
	output				rgb_hs_o,
	output				rgb_de_o,
	output				rgb_valid_o,
	output [15:0] 	rgb_bout,
	output [15:0] 	rgb_gout,
	output [15:0] 	rgb_rout,
	output	[24*2-1:0]	rgb_datax2_o //b,g,r,b,g,r
);
// wire [2:0]w_r_gain,w_g_gain,w_b_gain;
// assign	w_r_gain	= 3'd7;	//3'd7;
// assign	w_g_gain	= 3'd4;	//3'd4;
// assign	w_b_gain	= 3'd4;	//3'd6;

wire	        w_gain_vs;
wire	        w_gain_hs;
wire	        w_gain_ah;
wire	        w_gain_de;
wire	[15:0]	w_gain_data;

rgb_gain_v1
#(
	.P_DEPTH(8	),
	.Q_WIDTH(16	)
)
inst_rgb_gain
(
	.i_pclk		(in_pclk		),
	.i_arstn	(in_rstn		),
	.i_hs		(raw_hs_i		),
	.i_vs		(raw_vs_i		),
	.i_de		(raw_de_i		),
	.i_valid	(raw_valid_i	),
	.i_data		(raw_datax4_i	),

	
	.gain_b (b_gain		),
	.gain_g (g_gain		),
	.gain_r (r_gain		),
	
	.o_hs		(w_gain_hs		),
	.o_vs		(w_gain_vs		),
	.o_de		(w_gain_ah		),
	.o_valid	(w_gain_de	    ),
	.o_data		(w_gain_data	)
);

		
		wire	    	w_debayer_lb_hs;
		wire	    	w_debayer_lb_vs;
		wire	    	w_debayer_lb_ah;
		wire	    	w_debayer_lb_de;
		wire	[15:0]	w_debayer_lb_p_11;
		wire	[15:0]	w_debayer_lb_p_00;
		wire	[15:0]	w_debayer_lb_p_01;

		line_buffer
		#(
			.P_DEPTH	(8),
			.X_CNT_WIDTH(10)
		)
		inst_line_buffer_debayer
		(
			.i_arstn	(in_rstn	),
			.i_pclk		(in_pclk	),
			
			.i_vsync	(w_gain_vs),	//(raw_vs_i		),//					
			.i_hsync	(w_gain_hs),	//(raw_hs_i		),//
			.i_de		(w_gain_de),	//(raw_de_i		),//
			.i_valid	(w_gain_de),	//(raw_valid_i	),//
			.i_p		(w_gain_data),	//(raw_datax4_i	),//
			
			.o_vsync	(w_debayer_lb_vs  ),
			.o_hsync	(w_debayer_lb_hs  ),
			.o_de		(w_debayer_lb_de  ),
			.o_valid	(w_debayer_lb_ah  ),
			.o_p_11		(w_debayer_lb_p_11),
			.o_p_00		(w_debayer_lb_p_00),
			.o_p_01		(w_debayer_lb_p_01)
		);
		wire	w_debayer_hs;
		wire	w_debayer_vs;
		wire	w_debayer_ah;
		wire	w_debayer_de;
		wire	[10:0]	w_debayer_x;
		wire	[10:0]	w_debayer_y;
		wire	[15:0]	w_debayer_r;
		wire	[15:0]	w_debayer_g;
		wire	[15:0]	w_debayer_b;
		raw_to_rgb
		#(
			.P_DEPTH	(8),
			.LEGACY		(1'b1)
		)
		inst_raw_to_rgb
		(
			.i_arstn	(in_rstn	),
			.i_pclk		(in_pclk	),
			
			.i_vsync	(w_debayer_lb_vs),
			.i_hsync	(w_debayer_lb_hs),
			.i_de		(w_debayer_lb_de),
			.i_valid	(w_debayer_lb_ah),
			.i_p_11		(w_debayer_lb_p_11),
			.i_p_00		(w_debayer_lb_p_00),
			.i_p_01		(w_debayer_lb_p_01),
			
			// .o_dbg_valid			(),
			// .o_dbg_bayer_11_01_0P_0	(),
			// .o_dbg_bayer_11_01_0P_1	(),
			// .o_dbg_bayer_00_01_0P_0	(),
			// .o_dbg_bayer_00_01_0P_1	(),
			// .o_dbg_bayer_01_01_0P_0	(),
			// .o_dbg_bayer_01_01_0P_1	(),
			// .o_dbg_bayer_11_00_1P_0	(),
			// .o_dbg_bayer_11_00_1P_1	(),
			// .o_dbg_bayer_00_00_1P_0	(),
			// .o_dbg_bayer_00_00_1P_1	(),
			// .o_dbg_bayer_01_00_1P_0	(),
			// .o_dbg_bayer_01_00_1P_1	(),
			// .o_dbg_bayer_11_11_2P_0	(),
			// .o_dbg_bayer_11_11_2P_1	(),
			// .o_dbg_bayer_00_11_2P_0	(),
			// .o_dbg_bayer_00_11_2P_1	(),
			// .o_dbg_bayer_01_11_2P_0	(),
			// .o_dbg_bayer_01_11_2P_1	(),
			
			.o_vsync	(w_debayer_vs),
			.o_hsync	(w_debayer_hs),
			.o_de		(w_debayer_ah),
			.o_valid	(w_debayer_de),
			.o_x_cnt	(w_debayer_x),
			.o_y_cnt	(w_debayer_y),
			.o_r		(w_debayer_r),
			.o_g		(w_debayer_g),
			.o_b		(w_debayer_b)
		);	
		
	assign		rgb_vs_o 		= w_debayer_vs;	
	assign		rgb_hs_o 		= w_debayer_hs;	
	assign		rgb_de_o 		= w_debayer_ah;	
	assign		rgb_valid_o 	= w_debayer_de;	
	assign 		rgb_bout  		= w_debayer_b;
	assign 		rgb_gout  		= w_debayer_g;
	assign 		rgb_rout  		= w_debayer_r;

	assign		rgb_datax2_o 	= {	w_debayer_b[15:8],w_debayer_g[15:8],w_debayer_r[15:8],
									w_debayer_b[ 7:0],w_debayer_g[ 7:0],w_debayer_r[ 7:0]};	
endmodule
