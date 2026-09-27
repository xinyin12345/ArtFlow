/////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2013-2021 Efinix Inc. All rights reserved.
//
// Description:
// AXI Stream Out  
// From AXI Stream outuput Signal which output from DMA Controller and it will convert the streaming signal to Video output.
// Language:  Verilog 2001
//
// ------------------------------------------------------------------------------
///////////////////////////////////////////////////////////////////////////////// 

module axi_streamout
#(
    parameter VIDEOOUT_WIDTH = 32
)
(
input 			axi_clk,
input 			out_clk,
input 			rstn,

//Frame Size
input 		[10:0]	x_size,	//h
input 		[10:0]	y_size,	//v

input 		stream_en,

input              in_tvalid,
output             out_tready,
input     [VIDEOOUT_WIDTH-1:0]   in_tdata,
input     [3:0]    in_tkeep,
input     [3:0]    in_tdest,
input              in_tlast,


input 			in_valid,
input 			in_de,
input 			in_hs,
input 			in_vs,
			
output  wire    out_de,
output	wire    out_valid,
output  wire    out_hsync,
output  wire    out_vsync,
output	[7:0]	out_rd_00,
output	[7:0]   out_rd_01,
output	[7:0]   out_rd_10,
output	[7:0]   out_rd_11,


output  [5:0]   in_tlast_count,
output  [5:0]   in_tvalid_count

);

   

//Main states
localparam  IDLE 		 = 3'b000;
localparam  WAIT_STREAM  = 3'b001;
localparam  START_STREAM = 3'b010;
localparam  START_FRAME  = 3'b011;
localparam  START_LINE   = 3'b100;
localparam  START_READ	 = 3'b101;
	

reg 	[10:0]	r_x_count;
reg 	[10:0]	r_y_count;
reg 	[20:0]	r_d_count;
reg 	[2:0] 	r_axi_state;

reg		r_tready;
reg 	r_de;
reg     r_tlast;
reg		[31:0] r_vdata;

reg r_rd_load;


reg r_in_tvalid;
reg [4:0] r_in_tvalid_count;

reg r_in_tlast;
reg [4:0] r_in_tlast_count;

reg [7:0] r_ready_count;
wire		w_de_2L;
wire		w_valid_2L;
wire		w_hsync_2L;
wire		w_vsync_2L;

assign out_tready = r_tready;

assign in_tlast_count = r_in_tlast_count;
assign in_tvalid_count = r_in_tvalid_count;

wire allkeep;

assign allkeep = (in_tkeep == 4'b1111);



reg         r_in_hs_1P;
reg         r_in_Vs_1P;
reg         r_in_de_1P;

reg         r_frame_Start;
reg         r_line_Start;

reg	[1:0]	r_line_cnt;
reg			r_line_in_1L;
reg			r_line_in_2L;

reg [31:0]  r_de_in_count;
reg [31:0]  r_de_out_count;
reg [31:0]  r_de_buffer_count;


reg [31:0]  r_de_data;
reg         r_de_buffer;
reg         r_reset_buffer;


wire w_fifo_data_empty;
wire w_fifo_data_full;

(* async_reg = "true" *) reg 	r_stream_en;

always @(posedge out_clk or negedge rstn )
begin
    if (~rstn) 
	begin
          
        r_in_de_1P <= 1'b0;
        r_in_hs_1P <= 1'b0;
        r_in_Vs_1P <= 1'b0;
        
        r_line_cnt   <= 1'b0;
        r_line_in_1L <= 1'b0;
        r_line_in_2L <= 1'b0;
		
		r_stream_en <= 1'b0;
      
        
    end
    else
    begin
               
        r_in_hs_1P <= in_hs;
        r_in_Vs_1P <= in_vs;
        r_in_de_1P <= in_de;
		r_stream_en <= stream_en;
        
        if(~r_in_de_1P & in_de)
        begin
            r_line_cnt	<= r_line_cnt + 1'b1;
        end
    	if (r_line_cnt[0])
			r_line_in_1L	<= 1'b1;
		
		if (r_line_cnt[1])
			r_line_in_2L	<= 1'b1;
        
    end

end

always @(posedge out_clk or negedge rstn)
begin
	if(~rstn)
	begin
		r_axi_state<= IDLE;
		r_tready   <= 1'b0;
		r_de_in_count <= 32'd0;
        r_de_out_count <= 32'd0;
		r_de_data	   <= 32'd0;	
		r_de_buffer    <= 1'b0;
        r_reset_buffer <= 1'b0;
		r_x_count 	   <= 11'd0;
	end
	else
	begin
		case (r_axi_state)		
		
		IDLE:
			begin
				r_tready <= 0;
				r_axi_state<= WAIT_STREAM;
				r_de_buffer    <= 1'b0;
                r_reset_buffer <= 1'b0;
				r_x_count 	   <= 11'd0;
			end 
		
		WAIT_STREAM:
			begin
				r_tready <= 1'b0;
                r_reset_buffer <= 1'b1;
				if(~r_in_Vs_1P &  in_vs)
				begin
					if(in_tvalid & r_stream_en)
					begin
						r_axi_state<= START_FRAME;
						r_de_in_count <= 32'd0;
						r_de_out_count <= 32'd0;
						r_reset_buffer <= 1'b0;
						r_x_count 	<= 11'd0;
					end
				end
				
			end 
		START_STREAM:
			begin
				r_tready <= 1'b0;
                r_reset_buffer <= 1'b1;
				if(~r_in_Vs_1P &  in_vs)
				begin
					r_axi_state<= START_FRAME;
                   	r_de_in_count <= 32'd0;
                    r_de_out_count <= 32'd0;
                    r_reset_buffer <= 1'b0;
				end
			end
		START_FRAME:
			begin
				if(~r_in_de_1P &  in_de)
				begin
					r_axi_state<= START_LINE;
			        r_de_in_count <= r_de_in_count + 1'b1;
					r_x_count 	<= 11'd0;
                end
			end 		
		START_LINE:
			begin
				if(~(r_de_in_count == r_de_out_count))
				begin
					r_tready <= 1'b1;
					
					if(in_tvalid&allkeep)
					begin
						
						r_de_data	<= in_tdata;		
						if(r_tready)
						begin
							r_de_buffer <= 1'b1;  
							r_de_out_count <= r_de_out_count +1'b1;   
							if(r_de_in_count == r_de_out_count +1'b1)
							begin
								r_tready <= 1'b0;
						
							end
						end 
					end
				end 
				else 
				begin
					r_tready <= 1'b0;
					r_de_buffer <= 1'b0;    
				end 

					
			    if(in_de&in_valid)
                begin
                     r_de_in_count <= r_de_in_count + 1'b1;
                end
						   
        		
				if(r_in_Vs_1P &  ~in_vs)
				begin
					//r_axi_state<= START_STREAM;
					
					if(r_stream_en)
					begin
						r_axi_state<= START_STREAM;
					end 
					else 
					begin
						r_axi_state<= WAIT_STREAM;
					end 
				end
								

			end 
		START_READ:
			begin
			end 
		default:
			begin
			end
		endcase
	end
end

reg [10:0]  r_hsync_count;
reg [10:0]  r_vsync_count;
reg [10:0]  r_vsync_in_count;
reg [10:0]  r_de_count;

reg         r_out_hs_1P;
reg         r_out_Vs_1P;
reg         r_out_de_1P;
reg         r_in_de_ck_1P;

reg			r_dummy_flag;
reg [31:0]	r_data_dummy;
always @(posedge out_clk or negedge rstn )
begin
    if (~rstn) 
	begin
        r_out_hs_1P <= 1'b0;
        r_out_Vs_1P <= 1'b0;
        r_out_de_1P <= 1'b0;
        
        r_hsync_count <= 11'd0;
        r_vsync_count <= 11'd0;
        r_vsync_in_count<= 11'd0;
        r_de_count <= 11'd0;
        r_in_de_ck_1P <= 1'b0;
		r_dummy_flag <= 1'b0;
		r_data_dummy <= 32'd0;			
    end
    else
    begin
        r_out_hs_1P <= out_hsync;
        r_out_Vs_1P <= out_vsync;
        r_out_de_1P <= out_de;
        r_in_de_ck_1P<= in_de;
        
        if(~r_out_Vs_1P & out_vsync) 
        begin
            r_vsync_count<= 11'b0;
            r_vsync_in_count<= 11'b0;
            r_hsync_count<= 11'b0;
			
        end

        if(~r_out_hs_1P & out_hsync) 
        begin
            r_hsync_count <= r_hsync_count +1'b1;
        end

        if(~r_out_de_1P & out_de) 
        begin
            r_vsync_count <= r_vsync_count +1'b1;
            r_de_count   <= 11'd0;
			if(r_vsync_count[0]==1'b0)
			begin
				r_data_dummy <= 32'h00ff00ff;
			end
			else
			begin
				r_data_dummy <= 32'h00000000;
			end
        end
        else if (out_de)
        begin
            r_de_count <= r_de_count +1'b1;
        
        end
        
        
         if(~r_in_de_ck_1P & in_de) 
        begin
            r_vsync_in_count <= r_vsync_in_count +1'b1;
        end
    
    
    end
end

wire [VIDEOOUT_WIDTH-1:0] w_out_tdata;

// 1 line buffer
fifo 
#(
	.DATA_WIDTH(VIDEOOUT_WIDTH),
    .ADDR_WIDTH(10)
)	   
inst_fifo_data 
(
  .clk 		(out_clk	),
  .nrst     (~r_reset_buffer	),
  .we 		(r_de_buffer),
  .re 		(w_de_2L & w_valid_2L)   ,//(w_de_2L&(~w_fifo_data_empty)),
  
  .empty    (w_fifo_data_empty)    , // FIFO empty
  .full     (w_fifo_data_full)     , // FIFO full
  
  .data_in 	(r_de_data),
 // .data_out ({out_rd_11,out_rd_10,out_rd_01,out_rd_00}	)
    .data_out (w_out_tdata)
 );
 
 assign {out_rd_11,out_rd_10,out_rd_01,out_rd_00} = w_out_tdata[31:0]; //r_data_dummy;//


// 1 line delay for RGB sync signals
fifo 
#(
	.DATA_WIDTH(4),
    .ADDR_WIDTH(13)
)	   
inst_fifo_sync 
(
  .clk 		(out_clk	),
  .nrst 	(rstn	),
  .we 		(r_line_in_1L),
  .re 		(r_line_in_2L),
  .data_in 	({in_de, in_valid, in_hs, in_vs}			),
  .data_out ({w_de_2L, w_valid_2L, w_hsync_2L, w_vsync_2L}	)
 );

 
 
//* FIFO delay for RGB sync signals */
/*shift_reg
#(
	.D_WIDTH(4),
	.TAPE(1)
)
inst_shift_reg_02
(                                                                    
	.i_arst(~rstn	),
	.i_clk(p_clk	),
	.i_en(1'b1),

	.i_d({w_de_2L, w_valid_2L, w_hsync_2L, w_vsync_2L}	),
	.o_q({out_de, out_valid, out_hsync, out_vsync}		)
);
 */

reg r_de_2L;
reg r_valid_2L;
reg r_hsync_2L;
reg r_vsync_2L;

always @(posedge out_clk or negedge rstn )
begin
    if (~rstn) 
	begin
		r_de_2L <= 1'b0;
		r_valid_2L <= 1'b0;
		r_hsync_2L <= 1'b0;
		r_vsync_2L <= 1'b0;
                
    end
    else
    begin
		r_de_2L    <= w_de_2L;
		r_valid_2L <= w_valid_2L;
		r_hsync_2L <= w_hsync_2L;
		r_vsync_2L <= w_vsync_2L;
    end
end

assign out_de = r_de_2L;
assign out_valid = r_valid_2L;
assign out_hsync = r_hsync_2L;
assign out_vsync = r_vsync_2L;
 
wire [31:0] w_debug_in_tdata;
wire [31:0] w_debug_out_tdata;

assign w_debug_in_tdata = in_tdata[31:0];
assign w_debug_out_tdata = w_out_tdata[31:0]; 


endmodule
