

module i2c_master_reg_set #(
	parameter DATA_LENGTH = 61,
	parameter I2C_REG_ADDR_WIDTH = 16,
	parameter I2C_DATA_WIDTH = 8,
	parameter I2C_DEVICE_ADDR = 8'h20
)(
	input		wire		clk,
	input		wire		rst_n,
	
	input		wire		init_done,  //keep high all the time
	input		wire		rd_done,		//one clock pulse
	input		wire		wr_done,		//one clock pulse
	output	reg			wr_en,			//one clock pulse
	output	reg			rd_en,			//one clock pulse
	output	wire	[I2C_REG_ADDR_WIDTH-1:0] addr,		//i2c register address
	output	wire	[I2C_DATA_WIDTH-1:0] dout,		//i2c configure data to the register
	output	reg		[7:0] dev_addr
	
);
localparam ROM_ADDR_WIDTH = $clog2(DATA_LENGTH);

wire	[ROM_ADDR_WIDTH-1:0] rom_addr;
wire	[I2C_REG_ADDR_WIDTH+I2C_DATA_WIDTH:0] rom_dout;

reg	[ROM_ADDR_WIDTH-1:0] cnt =0;
parameter	S0 = 3'd0;  
parameter	S1 = 3'd1;
parameter	S2 = 3'd2;
parameter	S3 = 3'd3;
parameter	S4 = 3'd4;
reg	[2:0] state = S0;

	i2c_master_reg_rom #(
		.ROM_SIZE              (25 ),   
		.TOTAL_ROM_DEPTH       (DATA_LENGTH), // 6*7
		.ADDR_WIDTH            (8  ) // alt_clogb2(42) 
	)u_user_rom(
    .clock(clk),
    .addr_ptr(rom_addr),
    .rdata_out(rom_dout)
);

assign rom_addr = cnt;
assign addr = rom_dout[24:9];
assign dout = rom_dout[8:1];
wire rw_flag = rom_dout[0];

always @( posedge clk or negedge rst_n )
begin
	if( ~rst_n ) begin
			cnt <= 0;
			state <= S0;
			rd_en <= 1'b0;
			wr_en <= 1'b0; 

	end else begin
			if( init_done ) begin
					case( state ) 
					S0: begin
						if( cnt < DATA_LENGTH ) //address from 0~60
								state <= S1;
					end
					S1:	begin
								state <= S2;
					end
					S2: begin
							state <= S3;
							if( rw_flag )
									rd_en <= 1'b1; 
							else 	
									wr_en <= 1'b1;
					end		
					S3: begin 
							rd_en <= 1'b0;
							wr_en <= 1'b0;
							state <= S4;
					end
					S4: begin
							if( rd_done | wr_done ) begin
									state <= S0;
									cnt <= cnt + 1'b1;
							end
								
					end
					default:;
					endcase
			end
	end
end

always @( posedge clk  )
		dev_addr <= I2C_DEVICE_ADDR;//8bit address(include w/r bit)



endmodule
