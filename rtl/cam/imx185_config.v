module imx185_config
#(
	parameter I2C_ID		= 7'h1A,
	parameter INITIAL_CODE	= "imx185_1080p_reg.mem",
	parameter MEM_DEPTH		= 423,
	parameter REGISTER_BYTE	= 3
)
(
	input	i_arst,
	input	i_sysclk,
	input	i_pll_locked,
	output	[2:0]o_state,
	output	o_confdone,
	
	input	i_dbg_we,
	input	[7:0]i_dbg_din,
	input	[9:0]i_dbg_addr,
	output	[7:0]o_dbg_dout,
	input	i_dbg_reconfig,
	
	input	i_sda,
	output	o_sda_oe,
	input	i_scl,
	output	o_scl_oe,
	output	o_rstn
);

localparam	DEVICE_ADDRESS	= 8'h00;
localparam	ADDRESSING		= 7;
localparam	SYSCLK_FREQ		= 25;
localparam	MODE			= "STANDARD";
localparam	SLAVE_ENABLE	= "FALSE";
localparam	tSYSCLK			= 1000/SYSCLK_FREQ;

localparam	s_IDLE		= 3'b001;
localparam	s_CONFIG	= 3'b010;
localparam	s_DONE		= 3'b000;
localparam	s_WAIT		= 3'b011;
localparam	s_LAST		= 3'b101; // debug

reg		r_m_en_1P;
reg		r_m_wr_1P;
wire	[7:0]w_opn008_reg;
reg		r_last_1P;
wire	w_ack;
wire	w_last;
wire	[7:0]w_data;

reg		[2:0]r_i2c_config_state_1P;
reg		[9:0]r_addr_1P;
reg		[1:0]r_byte_cnt_1P;
reg		[8:0]r_reg_cnt_1P;
reg		r_state_1P;
reg		r_confdone_1P;

reg		[5:0]r_timer_1P;
reg		r_rstn_1P;

reg		[15:0]r_clk_div_1P;
reg		r_clk_div_2P;
reg		r_clk_div_3P;
reg		[7:0]r_ms_dly_1P;

reg		r_dbg_reconfig_1P;
reg		r_dbg_reconfig_2P;

i2c_wrapper
#(
	.DEVICE_ADDRESS	(DEVICE_ADDRESS),
	.ADDRESSING		(ADDRESSING),
	.SYSCLK_FREQ	(SYSCLK_FREQ),
	.MODE			(MODE),
	.SLAVE_ENABLE	(SLAVE_ENABLE)
)
inst_i2c
(
	.i_arst		(i_arst),
	.i_sysclk	(i_sysclk),
	.i_m_en		(r_m_en_1P),
	.i_m_wr		(r_m_wr_1P),
	.i_last		(r_last_1P),
	.i_addr		(I2C_ID),		// I2C ID
	.i_data		(w_opn008_reg),
	.o_ack		(w_ack),
	.o_last		(w_last),
	.o_data		(w_data),
	.i_sda		(i_sda),
	.o_sda_oe	(o_sda_oe),
	.i_scl		(i_scl),
	.o_scl_oe	(o_scl_oe)
);

true_dual_port_ram
#(
	.DATA_WIDTH(8),
	.ADDR_WIDTH(10),
	.WRITE_MODE_1("WRITE_FIRST"),
	.WRITE_MODE_2("WRITE_FIRST"),
	.OUTPUT_REG_1("TRUE"),
	.OUTPUT_REG_2("TRUE"),
	.RAM_INIT_FILE(INITIAL_CODE)		// Initial code file
)
inst_imx185_reg
(
	.we1(1'b0),
	.we2(i_dbg_we),
	.clka(i_sysclk),
	.clkb(i_sysclk),
	.din1({8{1'b0}}),
	.din2(i_dbg_din),
	.addr1(r_addr_1P[9:0]),
	.addr2(i_dbg_addr),
	.dout1(w_opn008_reg),
	.dout2(o_dbg_dout)
);

always@(posedge i_arst or posedge i_sysclk)
begin
	if (i_arst)
	begin
		r_i2c_config_state_1P	<= s_IDLE;
		r_addr_1P				<= {10{1'b0}};
		r_m_en_1P				<= 1'b0;
		r_m_wr_1P				<= 1'b0;
		r_last_1P				<= 1'b0;
		
		r_byte_cnt_1P			<= {2{1'b0}};
		r_reg_cnt_1P			<= {9{1'b0}};
		
		r_state_1P				<= 1'b0;
		r_confdone_1P			<= 1'b0;
		r_timer_1P				<= {6{1'b0}};
		r_rstn_1P				<= 1'b0;
		
		r_clk_div_1P			<= {16{1'b0}};
		r_ms_dly_1P				<= {8{1'b0}};
		
		r_dbg_reconfig_1P		<= 1'b0;
		r_dbg_reconfig_2P		<= 1'b0;
	end
	else
	begin
		case (r_i2c_config_state_1P)
			s_IDLE:
			begin
				if (i_pll_locked)
				begin
					r_i2c_config_state_1P	<= s_CONFIG;
					r_addr_1P				<= {10{1'b0}};
					r_m_en_1P				<= 1'b1;
					r_m_wr_1P				<= 1'b0;
					r_last_1P				<= 1'b0;
					
					r_byte_cnt_1P			<= {2{1'b0}};
					r_reg_cnt_1P			<= {9{1'b0}};

					r_state_1P				<= 1'b1;
				end
			end
			
			s_CONFIG:
			begin
				r_m_en_1P		<= 1'b1;
				r_last_1P		<= 1'b0;
				if (w_ack)
				begin
					if (r_reg_cnt_1P != MEM_DEPTH)		// MEM depth
					begin
						r_addr_1P		<= r_addr_1P+1'b1;
						r_byte_cnt_1P	<= r_byte_cnt_1P+1'b1;
						if (r_byte_cnt_1P == REGISTER_BYTE)		// Number of byte of register
						begin
							r_m_en_1P		<= 1'b0;
							r_last_1P		<= 1'b1;
							r_byte_cnt_1P	<= {2{1'b0}};
							r_reg_cnt_1P	<= r_reg_cnt_1P+1'b1;
						end						
					end
					else
					begin
						r_i2c_config_state_1P	<= s_DONE;
						r_m_en_1P				<= 1'b0;
						r_confdone_1P			<= 1'b1;
					end
				end
			end
	
			s_WAIT:
			begin
				r_clk_div_1P	<= r_clk_div_1P+1'b1;
				r_clk_div_2P	<= r_clk_div_1P[15];
				r_clk_div_3P	<= r_clk_div_2P;
				if (~r_clk_div_2P & r_clk_div_3P)
				begin
					r_ms_dly_1P		<= r_ms_dly_1P+1'b1;
				
					if (r_ms_dly_1P == 8'd255)
					begin
						r_i2c_config_state_1P	<= s_CONFIG;
						r_m_en_1P				<= 1'b1;
						r_m_wr_1P				<= 1'b0;
						r_last_1P				<= 1'b0;
					end
				end
			end
			
			s_DONE:
			begin				
				r_dbg_reconfig_1P	<= i_dbg_reconfig;
				r_dbg_reconfig_2P	<= r_dbg_reconfig_1P;
				if (r_dbg_reconfig_1P && ~r_dbg_reconfig_2P)
					r_i2c_config_state_1P	<= s_IDLE;
			end
			
			s_LAST:
			begin
				/*r_addr_1P <= 10'h000;
				r_m_en_1P <= 1'b0;
				r_m_wr_1P <= 1'b0;
				r_last_1P <= 1'b1;
				r_i2c_config_state_1P <= s_DONE;*/
			end
			
			default:
			begin
				r_i2c_config_state_1P	<= s_IDLE;
				r_addr_1P				<= {10{1'b0}};
				r_m_en_1P				<= 1'b0;
				r_m_wr_1P				<= 1'b0;
				
				r_byte_cnt_1P			<= {2{1'b0}};
				r_reg_cnt_1P			<= {9{1'b0}};
			end
		endcase
		if (i_pll_locked)
			r_timer_1P	<= r_timer_1P+1'b1;
		if (r_timer_1P == 9'd500/tSYSCLK)
			r_rstn_1P	<= 1'b1;
	end
end

assign	o_state		= r_i2c_config_state_1P;
assign	o_confdone	= r_confdone_1P;
assign	o_rstn		= r_rstn_1P;

endmodule
