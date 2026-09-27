
	module data_tx #(
			parameter VID_WIDTH 	= 16,
			parameter FIFO_DIPTH 	= 512,
			parameter FIFO_ALMOST_FULL = 240//fifo_almost_full
			
			
	)(
	input		wire									clk,
	input		wire									rst_n,
	input		wire									frame_en,
	input		wire	[VID_WIDTH-1:0] 				fifo_wr_data,
	input		wire									fifo_wr_en,
	output		reg										fifo_wr_almost_full, 
	output		reg										fifo_rd_period,     
	output		reg										fifo_rd_underflow,
	
	input		wire 	[12:0]							H_FRONT_PORCH 	,
	input		wire 	[12:0]							H_SYNC 				,
	input		wire 	[12:0]							H_VALID 			,
	input		wire 	[12:0]							H_BACK_PORCH 	,
	input		wire 	[12:0]							V_FRONT_PORCH 	,
	input		wire 	[12:0]							V_SYNC 				,
	input		wire 	[12:0]							V_VALID 			,
	input		wire 	[12:0]							V_BACK_PORCH 	,
	
	
	output		reg 	[VID_WIDTH-1:0] 				vout,
	output		reg										o_hs,
	output		reg										o_vs,
	output		reg										o_de
	
	);
//==========================================================
//
//==========================================================
	
	localparam S_H_SYNC 		= 2'd0;
	localparam S_H_BACK_PORCH 	= 2'd1;
	localparam S_H_VALID 		= 2'd2;
	localparam S_H_FRONT_PORCH 	= 2'd3;
	localparam S_V_SYNC 		= 2'd0;
	localparam S_V_BACK_PORCH 	= 2'd1;
	localparam S_V_VALID 		= 2'd2;
	localparam S_V_FRONT_PORCH 	= 2'd3;
	localparam FIFO_ADDR_WIDTH   = $clog2(FIFO_DIPTH) ;
	
	wire									fifo_wr_rst ;
	wire	[FIFO_ADDR_WIDTH-1:0] 					wrusedw;
	//wire 
	wire	[VID_WIDTH-1:0] fifo_rd_data;
	reg										fifo_rd_en = 1'b0;
	wire									fifo_rd_empty;
	reg	[1:0] 						h_state = S_H_FRONT_PORCH;
	reg	[1:0] 						v_state = S_V_FRONT_PORCH;
	reg	[12:0] 						h_cnt = 0;
	reg	[12:0] 						v_cnt = 0;
	reg										hs_r1 = 1'b0;
	reg										hs_r2 = 1'b0;
	reg 									vs_r1 = 1'b0;
	reg										vs_r2 = 1'b0;
	reg										de_r1 = 1'b0;
	reg										de_r2 = 1'b0;
	reg										frame_start_d0 = 1'b0;
	reg										frame_start_d1 = 1'b0;
	wire									pos_frame_start;
	reg										frame_ena			 = 1'b0;
	reg										h_front_porch_flag 	= 1'b0;
	reg										h_sync_flag				= 1'b0;
	reg										h_valid_flag			= 1'b0;
	reg										h_back_porch_flag = 1'b0;
	    									
	reg										v_front_porch_flag 	= 1'b0;
	reg										v_sync_flag				= 1'b0;
	reg										v_valid_flag			= 1'b0;
	reg										v_back_porch_flag = 1'b0;
	wire									fifo_rst					;
	wire									neg_fifo_rd_period;
//==========================================================
//
//==========================================================
	
	always @( posedge clk )
	begin
			if( wrusedw >= FIFO_ALMOST_FULL ) begin
					fifo_wr_almost_full <= 1'b1;
			end else begin
					fifo_wr_almost_full <= 1'b0;
			end
	end
	
	always @( posedge clk or negedge rst_n )
	begin
			if( !rst_n ) begin
					frame_start_d0 <= 1'b0;
					frame_start_d1 <= 1'b0;
			end else begin
					frame_start_d0 <= frame_en;
					frame_start_d1 <= frame_start_d0;
			end
	end
	// assign pos_frame_start = frame_start_d0 & ~frame_start_d1;
	assign pos_frame_start = frame_en & ~frame_start_d0;
	assign fifo_wr_rst = pos_frame_start | fifo_rst;//fifo_rst_p //
	
	always @( posedge clk or negedge rst_n	)
	begin
			if( ~rst_n )
					frame_ena <= 1'b0;
			else
					frame_ena <= frame_start_d1;
			
	end
	
DC_FIFO
# (
  	.FIFO_MODE  ( "Normal"        	), //"Normal"; //"ShowAhead"
    .DATA_WIDTH ( VID_WIDTH        ),
    .FIFO_DEPTH ( FIFO_DIPTH        )//,

  ) u_rd_fifo(   
  //System Signal
  /*i*/.Reset   (fifo_wr_rst), //System Reset
  //Write Signal                             
  /*i*/.WrClk   (clk), //(I)Wirte Clock
  /*i*/.WrEn    (fifo_wr_en), //(I)Write Enable
  /*o*/.WrDNum  (wrusedw), //(O)Write Data Number In Fifo
  /*o*/.WrFull  (), //(I)Write Full 
  /*i*/.WrData  (fifo_wr_data), //(I)Write Data
  //Read Signal                            
  /*i*/.RdClk   (clk), //(I)Read Clock
  /*i*/.RdEn    (fifo_rd_en), //(I)Read Enable
  /*o*/.RdDNum  (), //(O)Radd Data Number In Fifo
  /*o*/.RdEmpty (fifo_rd_empty), //(O)Read FifoEmpty
  /*o*/.RdData  (fifo_rd_data)  //(O)Read Data
);               

always @( posedge clk or negedge rst_n )
begin
		if( !rst_n )
				fifo_rd_underflow <= 1'b0;    
		else if( pos_frame_start )
				fifo_rd_underflow <= 1'b0;
		else if( fifo_rd_empty & fifo_rd_en )
				fifo_rd_underflow <= 1'b1;
		else 
				fifo_rd_underflow <= 1'b0;
end


//=========================================================
//
//=========================================================
	
	
	always @( posedge clk or negedge rst_n)
	begin
			if( !rst_n )
					  h_front_porch_flag <= 1'b0;
			else if( !frame_ena)
						h_front_porch_flag <= 1'b0;
			else if( h_cnt == H_FRONT_PORCH -2 )
						h_front_porch_flag <= 1'b1;
			else
						h_front_porch_flag <= 1'b0;
	end
	
	always @( posedge clk or negedge rst_n )
	begin
			if( !rst_n )
						h_sync_flag <= 1'b0;
			else if( !frame_ena )
						h_sync_flag <= 1'b0;
			else if( h_cnt == H_SYNC -2 )
						h_sync_flag <= 1'b1;
			else
						h_sync_flag <= 1'b0;
	end
	
	always @( posedge clk or negedge rst_n )
	begin
			if( !rst_n )
						h_valid_flag <= 1'b0;
			else if( !frame_ena )
						h_valid_flag <= 1'b0;
			else if( h_cnt == H_VALID -2 )
						h_valid_flag <= 1'b1;
			else
						h_valid_flag <= 1'b0;
	end
	
	always @( posedge clk or negedge rst_n )
	begin
			if( !rst_n )
						h_back_porch_flag <= 1'b0;
			else if( !frame_ena )
						h_back_porch_flag <= 1'b0;
			else if( h_cnt == H_BACK_PORCH -2 )
						h_back_porch_flag <= 1'b1;
			else
						h_back_porch_flag <= 1'b0;
	end
	
	

	always @( posedge clk or negedge rst_n )
	begin
			if( ~rst_n ) begin
					h_cnt <= 'd0;
					h_state <= S_H_SYNC;
			end else if( frame_ena ) begin
					case(h_state )
					S_H_SYNC : begin
							if( h_sync_flag ) begin
									h_cnt <= 0;
									h_state <= S_H_BACK_PORCH;
							end else begin
									h_cnt <= h_cnt + 1'b1;
							end
					end
					S_H_BACK_PORCH : begin
							if( h_back_porch_flag ) begin
									h_cnt <= 0;
									h_state <= S_H_VALID;
							end else begin
									h_cnt <= h_cnt + 1'b1;
							end
					end
					
					
					S_H_VALID : begin
							if( h_valid_flag ) begin
									h_cnt <= 0;
									h_state <= S_H_FRONT_PORCH;
							end else begin
									h_cnt <= h_cnt + 1'b1;
							end
					end
					S_H_FRONT_PORCH : begin
									if( h_front_porch_flag ) begin
											h_cnt <= 0;
											h_state <= S_H_SYNC;
									end else begin
											h_cnt <= h_cnt + 1'b1;
									end
					end
					
					default: begin
							h_state <= S_H_SYNC;
							h_cnt <= 'd0;
					end
					endcase
			end else begin
					h_cnt <= 'd0;
					h_state <= S_H_SYNC;
			end
	end            
	
	always @( posedge clk or negedge rst_n )
	begin
			if( !rst_n )
					v_front_porch_flag <= 1'b0;
			else if(!frame_ena )
					v_front_porch_flag <= 1'b0;
			else if( v_cnt == V_FRONT_PORCH - 1  )
					v_front_porch_flag <= 1'b1;
			else
					v_front_porch_flag <= 1'b0;		
	end
	
	always @( posedge clk or negedge rst_n )
	begin
			if( !rst_n )
					v_sync_flag <= 1'b0;
			else if(!frame_ena )
					v_sync_flag <= 1'b0;
			else if( v_cnt == V_SYNC - 1  )
					v_sync_flag <= 1'b1;
			else
					v_sync_flag <= 1'b0;		
	end
	
	always @( posedge clk or negedge rst_n )
	begin
			if( !rst_n )
						v_valid_flag <=  1'b0;
			else if(!frame_ena )
						v_valid_flag <=  1'b0;			
			else if( v_cnt == V_VALID -1  )
						v_valid_flag <= 1'b1;
			else
						v_valid_flag <= 1'b0;
	end
	
	always @( posedge clk or negedge rst_n)
	begin
			if( !rst_n )
						v_back_porch_flag <= 1'b0;
			else if(!frame_ena )
						v_back_porch_flag <= 1'b0;	
			else if( v_cnt == V_BACK_PORCH -1  )
						v_back_porch_flag <= 1'b1;
			else
						v_back_porch_flag <= 1'b0;
	end
	
	always @( posedge clk or negedge rst_n )
	begin
			if( ~rst_n ) begin
					v_cnt <= 'd0;
					v_state <= S_V_SYNC;	
			end else if( frame_ena ) begin
						case(v_state )
						S_V_SYNC : begin
								if( h_front_porch_flag && h_state == S_H_FRONT_PORCH ) begin
										if( v_sync_flag ) begin
												v_cnt <= 0;
												v_state <= S_V_BACK_PORCH;
										end else begin
												v_cnt <= v_cnt + 1'b1;
										end
								end
						end
						S_V_BACK_PORCH : begin
								if( h_front_porch_flag && h_state == S_H_FRONT_PORCH ) begin
										if( v_back_porch_flag ) begin
												v_cnt <= 0;
												v_state <= S_V_VALID;
										end else begin
												v_cnt <= v_cnt + 1'b1;
										end
								end
						end
						
						
						S_V_VALID : begin
								if( h_front_porch_flag && h_state == S_H_FRONT_PORCH ) begin
										if( v_valid_flag ) begin
												v_cnt <= 0;
												v_state <= S_V_FRONT_PORCH;
										end else begin
												v_cnt <= v_cnt + 1'b1;
										end
								end
						end
						S_V_FRONT_PORCH : begin
								if( h_front_porch_flag && h_state == S_H_FRONT_PORCH ) begin   
										if(v_front_porch_flag ) begin
												v_cnt <= 0;
												v_state <= S_V_SYNC;
										end else begin
												v_cnt <= v_cnt + 1'b1;
										end
								end
						end
						default: begin
								v_state <= S_V_SYNC;
								v_cnt <= 'd0;
						end
						endcase
			end else begin
					v_cnt <= 'd0;
					v_state <= S_V_SYNC;	
			end
	end

	always @( posedge clk )
	begin
			if( h_state == S_H_VALID && v_state == S_V_VALID ) begin
					fifo_rd_en <= 1'b1;
			end else begin
					fifo_rd_en <= 1'b0;
			end
	end
	
	always @( posedge clk )
	begin
			vout <= de_r2 ? fifo_rd_data : 0;
	end
	
	always @( posedge clk )
	begin
			de_r1 <= (h_state == S_H_VALID && v_state == S_V_VALID );
			de_r2 <= de_r1;
			o_de  <= de_r2;
	end
	always @( posedge clk or negedge rst_n)
	begin
			if( ~rst_n ) begin
					vs_r1 <= 'd0;
					vs_r2 <= 'd0;
					o_vs  <= 'd0;
					
			end else if( frame_ena ) begin
					vs_r1 <= (v_state == S_V_SYNC);
					vs_r2 <= vs_r1;
					o_vs  <= vs_r2;
			end else begin
					vs_r1 <= 'd0;
					vs_r2 <= 'd0;
					o_vs  <= 'd0;
			end
	end
	
	always @( posedge clk or negedge rst_n )
	begin
			if( ~rst_n ) begin
					hs_r1 <= 'd0;
					hs_r2 <= 'd0;
					o_hs  <= 'd0;
					
			end else if( frame_ena )begin
					hs_r1 <= (h_state == S_H_SYNC);
					hs_r2 <= hs_r1;
					o_hs  <= hs_r2;
			end else begin
					hs_r1 <= 'd0;
					hs_r2 <= 'd0;
					o_hs  <= 'd0;
			end
	end         
	
	always @( posedge clk )
	begin
			fifo_rd_period <=  ~(v_state == S_V_SYNC && v_cnt == 0) ;
	end
	reg	fifo_rd_period_d0 = 1'b0;
	always @( posedge clk )
			fifo_rd_period_d0 <= fifo_rd_period;
	
	assign neg_fifo_rd_period = fifo_rd_period_d0 & (~fifo_rd_period);   
	assign fifo_rst = neg_fifo_rd_period;
	
	endmodule
	
	

