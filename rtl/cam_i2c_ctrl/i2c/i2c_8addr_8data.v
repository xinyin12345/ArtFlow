


module i2c_8addr_8data(
	input		wire				clk,
	input		wire				rst_n,
	input		wire	[7:0] din,
	input		wire	[7:0] addr,
	output	wire	[7:0] dout,
	input		wire	[7:0] dev_addr,
	output	reg					init_done,
	input		wire				wr_en,
	input		wire				rd_en,
	output	reg					wr_done,
	output	reg					rd_done,
	output	wire				dout_valid,
	
	output	wire	[2:0]	i2c_address,
  output	wire				i2c_write   ,
  output	wire	[7:0] i2c_writedata, 
  output	wire				i2c_chipselect,
  input		wire				i2c_waitrequest,
  input		wire	[7:0] i2c_readdata	

);
//parameter I2C_ADDR = 8'h72;

parameter INIT_IDLE = 3'b000;
parameter INIT_CNT_H = 3'b001;
parameter INIT_CNT_L = 3'b010;
parameter	INIT_CORE_EN = 3'b011;
parameter INIT_OVER = 3'b100;
reg	[2:0] init_state = INIT_IDLE;
reg	init_cs = 1'b0;
reg	init_wr = 1'b0;
reg	[7:0] init_wrdata = 0;
reg	[2:0] init_addr = 0;
always @( posedge clk or negedge rst_n)
begin
		if( ~rst_n ) begin
				init_state <= INIT_IDLE;
				init_cs <= 1'b0;
				init_wr <= 1'b0;
		end else begin
			case( init_state )
				INIT_IDLE : begin
						if( ~i2c_waitrequest ) begin
								init_cs <= 1'b0;
								init_wr <= 1'b0;
								init_state <= INIT_CNT_L;	
						end
				end
				INIT_CNT_L : begin
							init_addr <= 3'b000;
							init_cs <= 1'b1;
							init_wr <= 1'b1;
							init_wrdata[7:0] <= 8'h05;
							init_state <= INIT_CNT_H;
						
				end
				INIT_CNT_H :begin
							init_addr <= 3'b001;
							init_cs <= 1'b1;
							init_wr <= 1'b1;
							init_wrdata[7:0] <= 8'h00;
							init_state <= INIT_CORE_EN;
				end
				INIT_CORE_EN : begin
							init_addr <= 3'b010;
							init_cs <= 1'b1;
							init_cs <= 1'b1;
							init_wrdata[7:0] <= 8'h80;
							init_state <= INIT_OVER;
				end
				INIT_OVER : begin
						init_addr <= 3'b000;
						init_cs <= 1'b0;
						init_wr <= 1'b0;
						init_wrdata[7:0] <= 8'h00;
				end
				
				default:;
			endcase
				
		
		end
end

always @( posedge clk or negedge rst_n)
begin
		if( ~rst_n ) begin
				init_done <= 1'b0;
		end else if( init_state == INIT_OVER ) begin
				init_done <= 1'b1;
		end
end

parameter S_WR_IDLE 	= 3'b000;
parameter S_WR_RD_TIP 	= 3'b001;
parameter S_WR_TIP_WAIT = 3'b010;
parameter S_WR_TIP_CHK 	= 3'b011;
parameter S_WR_WR_DATA 	= 3'b100;
parameter S_WR_CTRL_SET = 3'b101;
parameter S_WR_SET_WAIT = 3'b110;
parameter S_WR_WR_OVER 	= 3'b111;

reg [2:0] wr_state;
reg	[2:0] wr_addr = 3'b000;
reg				wr_cs = 1'b0;
reg				wr_wr = 1'b0;
reg	[7:0]wr_wrdata = 0;
reg	[1:0] wr_cnt = 0;
reg	[2:0] wait_cnt = 0;
always @( posedge clk or negedge rst_n )
begin
		if( ~rst_n ) begin
				wr_addr <= 0;
				wr_cs <= 1'b0;
				wr_wr <= 1'b0;
				wr_wrdata <= 0;
				wr_state <= S_WR_IDLE;
		end else begin
				case( wr_state ) 
				S_WR_IDLE : begin
						wr_addr <= 0;
						wr_cs <= 1'b0;
						wr_wr <= 1'b0;
						wr_wrdata <= 0;
						if( init_done & (wr_en || wr_cnt != 0)) begin
							wr_state <= S_WR_RD_TIP;
						end
				end
				S_WR_RD_TIP : begin
						wr_addr <= 3'd4;
						wr_cs <=1'b1;
						wr_state <= S_WR_TIP_WAIT;
				end
				S_WR_TIP_WAIT : begin
						wr_addr <= 3'd4;
						wr_cs <= 1'b0;
						if( wait_cnt[2] ) begin
								wait_cnt <= 0;
								wr_state <= S_WR_TIP_CHK;
						end else begin
								wait_cnt <= wait_cnt + 1'b1;
						end
				end
				S_WR_TIP_CHK: begin
						wr_cs <= 1'b0;
						if( i2c_readdata[1] == 1'b0 ) begin
								wr_state <= S_WR_WR_DATA;
						end 
				end
				S_WR_WR_DATA : begin
						wr_addr <= 3'd3;//write data address
						wr_cs <= 1'b1;
						wr_wr <= 1'b1;
						if( wr_cnt == 0 ) begin
							wr_wrdata <= dev_addr;
						end else if( wr_cnt == 1 ) begin
							wr_wrdata <= addr;
						end else begin
							wr_wrdata <= din;
						end
						wr_state <= S_WR_CTRL_SET;
				end
				S_WR_CTRL_SET : begin
						wr_addr <= 3'd4;//write data address
						wr_cs <= 1'b1;
						wr_wr <= 1'b1;
						if( wr_cnt == 0 ) begin
								wr_wrdata <= 8'h98;
						end else if( wr_cnt == 1 ) begin
								wr_wrdata <= 8'h18;
						end else begin
								wr_wrdata <= 8'h51;
						end
						
						wr_state <= S_WR_WR_OVER;
				end
				S_WR_WR_OVER : begin
						wr_addr <= 0;
						wr_cs <= 1'b0;
						wr_wr <= 1'b0;
						wr_wrdata <= 0;
						if( wr_cnt == 2'd2 ) begin
								wr_cnt <= 0;
								wr_state <= S_WR_SET_WAIT;
						end else begin
								wr_cnt <= wr_cnt + 1'b1;
								wr_state <= S_WR_RD_TIP;
						end
						
				end
				S_WR_SET_WAIT: begin
						wr_state <= S_WR_IDLE;
				end
				
				default:;
			endcase
				
		end
end            

always @( posedge clk or negedge rst_n )
begin
		if( ~rst_n ) begin
				wr_done <= 1'b0;
		end else if(wr_state == S_WR_SET_WAIT )begin
				wr_done <= 1'b1;
		end else begin
				wr_done <= 1'b0;
		end
end

//================================================================
//
//================================================================
parameter S_RD_IDLE 		= 4'b0000;
parameter S_RD_RD_TIP 	= 4'b0001;
parameter S_RD_TIP_WAIT = 4'b0010;
parameter S_RD_TIP_CHK 	= 4'b0011;
parameter S_RD_WR_DATA 	= 4'b0100;
parameter S_RD_CTRL_SET = 4'b0101;
parameter S_RD_SET_WAIT = 4'b0110;
parameter S_RD_WR_OVER 	= 4'b0111;
parameter	S_RD_CFG_SET  = 4'b1000;
parameter	S_RD_RD_DATA	= 4'b1001;
reg	[2:0] rd_addr;
reg				rd_cs;
reg				rd_wr;
reg[7:0]	rd_wrdata;
reg [3:0] rd_state = S_RD_IDLE;
reg	[2:0]	rd_cnt = 0;   
reg	[2:0] rd_wait_cnt = 0;
always @( posedge clk or negedge rst_n )
begin
		if( ~rst_n ) begin
				rd_addr <= 0;
				rd_cs <= 1'b0;
				rd_wr <= 1'b0;
				rd_wrdata <= 0;
				rd_state <= S_RD_IDLE;    
				rd_cnt <= 'd0;
		end else begin
				case( rd_state ) 
				S_RD_IDLE : begin
						rd_addr <= 0;
						rd_cs <= 1'b0;
						rd_wr <= 1'b0;
						rd_wrdata <= 0;
						if( init_done & (rd_en || rd_cnt != 0)) begin
							rd_state <= S_RD_RD_TIP;
						end
				end
				S_RD_RD_TIP : begin
						rd_addr <= 3'd4;
						rd_cs <=1'b1;
						rd_state <= S_RD_TIP_WAIT;
				end
				S_RD_TIP_WAIT : begin
						rd_addr <= 3'd4;
						rd_cs <= 1'b0;
						if( rd_wait_cnt[2] ) begin
								rd_wait_cnt <= 0;
								rd_state <= S_RD_TIP_CHK;    
						end else begin
								rd_wait_cnt <= rd_wait_cnt + 1'b1;
						end
				end
				S_RD_TIP_CHK: begin     //3 
						rd_cs <= 1'b0;
						if( i2c_readdata[1] == 1'b0 ) begin
								if( rd_cnt == 4 ) begin
										rd_state <= S_RD_WR_OVER;
								end else if( rd_cnt == 3 ) begin
										rd_state <= S_RD_CTRL_SET;
								end else begin
										rd_state <= S_RD_WR_DATA;
								end
						end 
				end
				S_RD_WR_DATA : begin     //state == 4
						rd_addr <= 3'd3;//write data address
						rd_cs <= 1'b1;
						rd_wr <= 1'b1;
						if( rd_cnt == 0 ) begin
							rd_wrdata <= dev_addr ;
						end else if( rd_cnt == 1 ) begin
							rd_wrdata <= addr;
						end else begin
							rd_wrdata <= dev_addr | 8'h01;
						end
						rd_state <= S_RD_CTRL_SET;  
				end
				S_RD_CTRL_SET : begin    //state == 5 
						rd_addr <= 3'd4;//write data address
						rd_cs <= 1'b1;
						rd_wr <= 1'b1;
						if( rd_cnt == 0 ) begin
								rd_wrdata <= 8'h90;
						end else if( rd_cnt == 1 ) begin
								rd_wrdata <= 8'h10;
						end else if( rd_cnt == 2 ) begin
								rd_wrdata <= 8'h90;
						end else begin
								rd_wrdata <= 8'h68;
						end
						
						rd_state <= S_RD_WR_OVER;
				end
				S_RD_WR_OVER : begin
						rd_addr <= 0;
						rd_cs <= 1'b0;
						rd_wr <= 1'b0;
						rd_wrdata <= 0;
						if( rd_cnt == 3'd4 ) begin
								rd_cnt <= 3'd0;
								rd_state <= S_RD_RD_DATA;
						end else begin
								rd_cnt <= rd_cnt + 1'b1;
								rd_state <= S_RD_RD_TIP;
						end
						
				end
				
				S_RD_RD_DATA : begin
						rd_state <= S_RD_CFG_SET ;
						rd_addr <= 3;
						rd_cs <= 1'b1;
				end
				S_RD_CFG_SET: begin
						rd_cs <= 1'b0;
						rd_wr <= 1'b0;
						rd_wrdata <= 8'h00;
						rd_state <= S_RD_IDLE;
				end
				default:;
			endcase
				
		end
end

always @( posedge clk or negedge rst_n )
begin
		if( ~rst_n ) begin
				rd_done <= 1'b0;
		end else if( rd_state == S_RD_CFG_SET ) begin
				rd_done <= 1'b1;
		end else begin
				rd_done <= 1'b0;
		end
end
assign dout_valid = rd_done;

assign 	i2c_address 		= init_addr | wr_addr |rd_addr;
assign	i2c_chipselect 	= init_cs | wr_cs |rd_cs;
assign	i2c_write 			= init_wr | wr_wr | rd_wr;
assign	i2c_writedata 	= init_wrdata | wr_wrdata | rd_wrdata;


endmodule

