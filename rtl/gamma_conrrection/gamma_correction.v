module gamma_correction
#(
	parameter	DATA_WIDTH	= 10,
	parameter 	GAMMA_CURVE	= "2P2.mem"
)
(
	input						i_pclk,
	input						i_rstn,
			
	input 						i_valid,
	input 						i_hs,
	input 						i_vs,
	input 	[DATA_WIDTH-1:0]	i_red,
	input 	[DATA_WIDTH-1:0]	i_green,
	input 	[DATA_WIDTH-1:0]	i_blue,
		
	output	reg[DATA_WIDTH-1:0]	o_red,
	output	reg[DATA_WIDTH-1:0]	o_green,
	output	reg[DATA_WIDTH-1:0]	o_blue,
	output	reg					o_valid,
	output  reg  				o_hs,
	output 	reg 				o_vs
);

wire	[9:0]w_gamma;

reg		[9:0]r_addr;
reg		[9:0]r_addr_1P;
reg		[9:0]r_addr_2P;
reg		[9:0]r_gamma_2P	[0:1023];

true_dual_port_ram
#(
	.DATA_WIDTH(10),
	.ADDR_WIDTH(10),
	.WRITE_MODE_1("WRITE_FIRST"),
	.WRITE_MODE_2("WRITE_FIRST"),
	.OUTPUT_REG_1("TRUE"),
	.OUTPUT_REG_2("TRUE"),
	.RAM_INIT_FILE(GAMMA_CURVE)		// Initial code file
)
inst_gamma
(
	.we1(1'b0),
	.we2(1'b0),
	.clka(i_pclk),
	.clkb(1'b0),
	.din1({10{1'b0}}),
	.din2({10{1'b0}}),
	.addr1(r_addr[9:0]),
	.addr2({10{1'b0}}),
	.dout1(w_gamma),
	.dout2()
);

always @(posedge i_pclk)
begin
	if (~i_rstn) 
	begin
		r_addr		<= 10'b0;
		r_addr_1P	<= 10'b0;
		r_addr_2P	<= 10'b0;
	end
	else 
	begin
		r_addr		<= r_addr + 1'b1;
		r_addr_1P	<= r_addr;
		r_addr_2P	<= r_addr_1P;
		
		r_gamma_2P[r_addr_2P]	<= w_gamma;
	end
end

//Curve Fitting
always @(posedge i_pclk)
begin
	if (~i_rstn) 
	begin
		o_red	<= {DATA_WIDTH{1'b0}};
		o_green	<= {DATA_WIDTH{1'b0}};
		o_blue	<= {DATA_WIDTH{1'b0}};
		o_valid	<= 1'b0;
		o_hs <= 'd0;
		o_vs <= 'd0;
	end
	else 
	begin
		o_valid	<= i_valid;
		o_hs <= i_hs;
		o_vs <= i_vs;
		
		if (i_valid)
		begin
			if (DATA_WIDTH == 10)
			begin
				o_red	<= r_gamma_2P[i_red];
				o_green	<= r_gamma_2P[i_green];		
				o_blue	<= r_gamma_2P[i_blue];
			end
			else
			begin
				o_red	<= r_gamma_2P[{i_red, i_red[7:6]}][9:2];
				o_green	<= r_gamma_2P[{i_green, i_green[7:6]}][9:2];		
				o_blue	<= r_gamma_2P[{i_blue, i_blue[7:6]}][9:2];
			end	
		end
		else
		begin
			o_red	<= {DATA_WIDTH{1'b0}};
			o_green	<= {DATA_WIDTH{1'b0}};
			o_blue	<= {DATA_WIDTH{1'b0}};
		end
	end
end
endmodule
