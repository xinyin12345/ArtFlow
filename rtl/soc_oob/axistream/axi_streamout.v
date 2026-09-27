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

input              in_tvalid,
output             out_tready,
input     [VIDEOOUT_WIDTH-1:0]   in_tdata,
input     [3:0]    in_tkeep,
input     [3:0]    in_tdest,
input              in_tlast,
                
//input			in_0_ar_ready,
//input			in_0_r_valid,
//input [127:0]	in_0_r_payload_data,
//input           in_0_r_payload_last,
// 	
//output reg     	out_0_ar_valid,
//output [31:0]	out_0_ar_addr,
//output reg		out_0_r_ready,

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


//assign out_de 	 = r_de;
//assign out_rd_00 = r_vdata[7:0];
//assign out_rd_01 = r_vdata[15:8];
//assign out_rd_10 = r_vdata[23:16];
//assign out_rd_11 = r_vdata[31:24];

assign in_tlast_count = r_in_tlast_count;
assign in_tvalid_count = r_in_tvalid_count;



/*
always @(posedge axi_clk)
begin
	if (~rstn) 
	begin
		r_tready	<= 1'b0;
		
		r_axi_state <= IDLE;
		r_rd_load	<= 1'b0;
		r_x_count 	<= 11'd0;
		r_y_count	<= 11'd0;
				
		r_de		<= 1'b0;
		r_vdata		<= 32'd0;
        r_d_count   <= 20'd0;
		r_tlast     <= 1'b1;
        
        
        r_in_tvalid <= 1'b0;
        r_in_tvalid_count <= 6'd0;

        r_in_tlast <= 1'b0;
        r_in_tlast_count <= 6'd0;
        
        r_ready_count <= 7'd0;

	end
	else
	begin
        r_in_tvalid <= in_tvalid;
        r_in_tlast <= in_tlast;
        r_tready <= 1'b1;
        
       // if(r_ready_count[3:0] ==4'b1000)
       // begin
       //     r_tready	<= ~r_tready;
       // end
        r_ready_count <= r_ready_count+1'b1;
    
    
        if( ~r_in_tvalid & in_tvalid)
        begin
            r_in_tvalid_count <= r_in_tvalid_count + 1'b1;
        end
 
        if( ~r_in_tlast & in_tlast)
        begin
            r_in_tlast_count <= r_in_tlast_count + 1'b1;
        end
    
		case (r_axi_state)						
			IDLE:
			begin
				if (!r_rd_load)
				begin
					
					r_rd_load	<= 1'b1;
					r_axi_state	<= READ;
					r_x_count 	<= 11'd0;
					r_y_count	<= 11'd0;
					r_de		<= 1'b0;
					r_vdata		<= 32'd0;
					
				end
                
                r_tlast<= 1'b0;
                r_axi_state	<= READ;
			end
	
			READ:
			begin
			//	r_tready	<= 1'b1;
				if (in_tvalid & allkeep)
				begin
					r_vdata <= in_tdata;
					r_de	<= 1'b1;
					
					if(r_x_count == (x_size-1'b1))
					begin
						r_x_count	<= 11'd0;
						if(r_y_count == (y_size-1'b1))
						begin
							r_y_count	<= 11'd0;
						end
						begin
							r_y_count	<= r_y_count + 1'b1;
						end
						
					end
					else 
					begin
						r_x_count	<= r_x_count + 1'b1;
					end
                    
                    if(r_tready)
                    begin
                        r_d_count <= r_d_count +1'b1;
                    end 
				end
				else 
				begin
					r_vdata		<= 32'd0;
					r_de		<= 1'b0;   
				end
				
				if (in_tlast)
				begin
                    r_tlast<=1'b1;
                    
//                    r_rd_load	<= 1'b0;
//					r_axi_state	<= IDLE;
                   
				end
                
                if(r_tlast==1'b1)
                begin
                    r_tlast<=1'b0;
                    r_axi_state	<= IDLE;
                    r_d_count   <=  20'd0;
                end
                
           
				
			end	

			default:
			begin
		//		r_tready	<= 1'b0;
				
				r_axi_state <= IDLE;
				r_rd_load	<= 1'b0;
				r_x_count 	<= 11'd0;
				r_y_count	<= 11'd0;
			
				r_de		<= 1'b0;
				r_vdata		<= 32'd0;
				
			end
        endcase
	
	end

end
*/

//for sync last at start


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
      
        
    end
    else
    begin
               
        r_in_hs_1P <= in_hs;
        r_in_Vs_1P <= in_vs;
        r_in_de_1P <= in_de;
    
        
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
			end 
		
		WAIT_STREAM:
			begin
			//	r_tready <= 1'b1;
		//		if(in_tvalid)
			//	begin
				//	r_axi_state<= START_STREAM;
			//	end
				
				
				r_tready <= 1'b0;
                r_reset_buffer <= 1'b1;
				if(~r_in_Vs_1P &  in_vs)
				begin
					if(in_tvalid)
					begin
						r_axi_state<= START_FRAME;
						r_de_in_count <= 32'd0;
						r_de_out_count <= 32'd0;
						r_reset_buffer <= 1'b0;
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

					
			    if(in_de)
                begin
                     r_de_in_count <= r_de_in_count + 1'b1;
                end
						   
        		
				if(r_in_Vs_1P &  ~in_vs)
				begin
					r_axi_state<= START_STREAM;
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
/*


always @(posedge out_clk or negedge rstn )
begin
    if (~rstn) 
	begin
        r_tready   <= 1'b0;
    
        r_in_de_1P <= 1'b0;
        r_in_hs_1P <= 1'b0;
        r_in_Vs_1P <= 1'b0;
        r_frame_Start <= 1'b0;
        
        r_de_in_count <= 11'd0;
        r_de_out_count <= 11'd0;
        r_de_buffer     <= 1'b0;
        r_line_cnt      <= 1'b0;
        r_line_in_1L <= 1'b0;
        r_line_in_2L <= 1'b0;
        
   end
    else
    begin
               
        r_in_hs_1P <= in_hs;
        r_in_Vs_1P <= in_vs;
        r_in_de_1P <= in_de;
    
        
        if(~r_in_hs_1P & in_hs)
        begin
            r_line_cnt	<= r_line_cnt + 1'b1;
        end
    	if (r_line_cnt[0])
			r_line_in_1L	<= 1'b1;
		
		if (r_line_cnt[1])
			r_line_in_2L	<= 1'b1;
        
    
        if(~r_in_Vs_1P &  in_vs)
        begin
          // if(in_tvalid&allkeep)
          // begin
            r_frame_Start <= 1'b1;
            r_de_in_count <= 11'd0;
            r_de_out_count <= 11'd0;
			r_line_Start   <= 1'b0;	
         //  end
        end
        
        if(r_in_Vs_1P &  ~in_vs)
        begin
           r_frame_Start <= 1'b0;
        end
        
        if(r_frame_Start)
        begin
            if(in_de)
            begin
				r_line_Start <= 1'b1;
                //r_hsync_count <= r_hsync_count+1'b1;     
                r_de_in_count <= r_de_in_count +1'b1;
                r_tready      <= 1'b1;
            end
        end 
        
        if(in_tvalid&allkeep&r_tready)
        begin
			if(r_line_Start == 1'b1)
			begin
				r_de_out_count <= r_de_out_count +1'b1;
				r_de_buffer    <= 1'b1;
			end
        end
        else
        begin
           r_de_buffer      <= 1'b0;
        end
        
        if(r_de_in_count==r_de_out_count)
        begin
            r_tready        <= 1'b0;
        end
        
        if(in_tlast & in_tvalid)
        begin
            r_line_Start <= 1'b0; 
            r_frame_Start <= 1'b0;
            r_tready    <= 1'b0;
        
        end
        
    end

end*/

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
    .ADDR_WIDTH(12)
)	   
inst_fifo_data 
(
  .clk 		(out_clk	),
  .nrst     (~r_reset_buffer	),
  .we 		(r_de_buffer),
  .re 		(w_de_2L)   ,//(w_de_2L&(~w_fifo_data_empty)),
  
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


 /*
 
// FIFO delay for RGB sync signals
shift_reg
#(
	.D_WIDTH(4),
	.TAPE(4)
)
inst_shift_reg_sync
(                                                                    
	.i_arst(~rstn	),
	.i_clk(out_clk	),
	.i_en(1'b1),

	.i_d({w_de_2L, w_valid_2L, w_hsync_2L, w_vsync_2L}	),
	.o_q({out_de, out_valid, out_hsync, out_vsync}		)
);

*/
////Main states
//localparam
//	IDLE 		= 2'b00, 	
//	READ_ADDR 	= 2'b01,
//	READ 		= 2'b10;
//
///* Remap video XY to DDR address */
//reg	[10:0]	r_y_cnt;
//reg	[2:0]	ba;
//reg 		r_hs_1P;
//reg 		r_vs_1P;
//reg [10:0]	r_rd_addr;
//reg [10:0]	r_rd_addr_1P;
//reg [10:0]	r_rd_addr_2P;
//reg [10:0]	r_rd_addr_3P;
//reg	[1:0]	r_line_cnt;
//reg	[1:0]	r_frame_cnt;
//reg			r_line_in_1L;
//reg			r_line_in_2L;
//reg	[7:0]	r_rd_00;
//reg	[7:0]	r_rd_01;
//reg	[7:0]	r_rd_10;
//reg	[7:0]	r_rd_11;
//reg			r_de_2L_1P;
//reg			r_de_2L_2P;
//reg			r_de_2L_3P;
//reg	[10:0]	r_y_cnt_2L_1P;
//reg	[10:0]	r_y_cnt_2L_2P;
//reg	[10:0]	r_y_cnt_2L_3P;
//reg			r_in_de_0L_1P;
//reg			r_in_de_0L_2P;
//reg	[1:0]	states;
//reg	[10:0]	r_rd_ycnt;
//reg	[10:0]	r_axi_xcnt;
//reg	[10:0]	r_axi_ycnt;
//reg	[10:0]	r_rd_xcnt;
//reg			r_axi_new_line;
//reg			r_rd_load;
//reg			r_axi_hsync_1P;
//reg			r_axi_de;
//reg			r_axi_valid;
//reg			r_axi_hsync;
//reg			r_axi_vsync;
//reg [7:0]	r_out_rd_00;
//reg [7:0]	r_out_rd_01;
//reg [7:0]	r_out_rd_10;
//reg [7:0]	r_out_rd_11;
//
//wire		w_de_2L;
//wire		w_valid_2L;
//wire		w_hsync_2L;
//wire		w_vsync_2L;
//
//wire[127:0]	w_in_rd_data;
//wire[127:0]	w_rd_data;
//
////assign	out_0_ar_addr	= {6'b0, r_rd_ycnt, r_rd_xcnt[6:3], 1'b0, in_frame_cnt, r_rd_xcnt[7], r_rd_xcnt[2:0], 5'b0};
////assign	out_0_ar_addr	= {7'b0, r_rd_ycnt, r_rd_xcnt[6:3], in_frame_cnt, r_rd_xcnt[7], r_rd_xcnt[2:0], 5'b0};
////assign	out_0_ar_addr	= {7'b0, in_frame_cnt, r_rd_ycnt, r_rd_xcnt[8:0], 4'b0};
//assign	out_0_ar_addr	= {9'b0, in_frame_cnt, r_rd_ycnt, r_rd_xcnt[10:9], 9'b0};
//			
///* Rd count from DDR data valid */
//always @(posedge axi_clk)
//begin
//    if (~rstn) 
//	begin
//		ba				<= 3'b0;		
//		r_in_de_0L_1P	<= 1'b0;
//		r_in_de_0L_2P	<= 1'b0;
//		r_axi_hsync_1P	<= 1'b0;
//		states			<= IDLE;
//		r_rd_ycnt		<= 11'b0;
//		r_axi_xcnt		<= 11'b0;
//		r_axi_ycnt		<= 11'b0;
//		r_rd_xcnt		<= 11'b0;
//		out_0_ar_valid	<= 1'b0;
//		out_0_r_ready	<= 1'b0;
//		r_axi_new_line	<= 1'b0;
//		r_rd_load		<= 1'b0;
//		r_axi_de		<= 1'b0;
//		r_axi_valid		<= 1'b0;
//		r_axi_hsync		<= 1'b0;
//		r_axi_vsync		<= 1'b0;
//	end
//	else
//	begin
//		r_axi_de		<= in_de;
//		r_axi_valid		<= in_valid;
//		r_axi_hsync		<= in_hsync;
//		r_axi_vsync		<= in_vsync;
//	
//		r_in_de_0L_1P	<= r_axi_de;
//		r_in_de_0L_2P	<= r_in_de_0L_1P;		
//		
//		if (r_in_de_0L_1P && !r_in_de_0L_2P)
//		begin
//			r_axi_new_line 	<= 1'b1;
//			r_rd_ycnt		<= r_axi_ycnt;
//		end
//			
//		if (!r_in_de_0L_1P && r_in_de_0L_2P)
//		begin
//			if (r_axi_ycnt == y_start + y_win)
//				r_axi_ycnt	<= y_start;
//			else
//				r_axi_ycnt	<= r_axi_ycnt + 1'b1;
//		end	
//		
//		if (!r_axi_vsync)
//			r_axi_ycnt	<= y_start;
//					
//		////////////////////////////////////////////////////////////				
//		case (states)						
//			IDLE:
//			begin
//				if (!r_rd_load)
//				begin
//					if (r_axi_new_line)
//					begin					
//						out_0_ar_valid	<= 1'b1;
//						r_rd_load		<= 1'b1;
//						r_axi_new_line	<= 1'b0;
//						states			<= READ_ADDR;
//					end
//				end
//			end
//			
//			READ_ADDR:
//			begin
//				if (in_0_ar_ready)
//				begin
//					out_0_ar_valid	<= 1'b0;
//					out_0_r_ready	<= 1'b1;
//					states			<= READ;
//				end
//			end
//			
//			READ:
//			begin
//				if (in_0_r_valid)
//				begin
//					r_rd_xcnt	<= r_rd_xcnt + 1'b1;
//					
//					if (in_0_r_payload_last)
//					begin
//						if (r_rd_xcnt[10:9] == (x_win >> 9))
//						begin
//							r_rd_load		<= 1'b0;					
//							r_rd_xcnt		<= 11'b0;
//							out_0_r_ready	<= 1'b0;
//							out_0_ar_valid	<= 1'b0;
//							states			<= IDLE;
//						end
//						else
//						begin
//							out_0_r_ready	<= 1'b0;
//							out_0_ar_valid	<= 1'b1;
//							states			<= READ_ADDR;
//						end
//					end
//				end
//			end	
//
//			default:
//			begin
//				r_rd_load		<= 1'b0;					
//				r_rd_xcnt		<= 11'b0;
//				out_0_r_ready	<= 1'b0;
//				out_0_ar_valid	<= 1'b0;
//				
//				states			<= IDLE;
//			end
//		endcase
//	end
//end
//
///* Resync RAM data to RGB video */
//always @(posedge p_clk)
//begin
//    if (~rstn) 
//	begin	
//		r_y_cnt			<= 11'b0;
//		r_hs_1P			<= 1'b0;
//		r_vs_1P			<= 1'b0;
//		r_rd_addr		<= x_start;
//		r_rd_addr_1P	<= 11'b0;
//		r_rd_addr_2P	<= 11'b0;
//		r_rd_addr_3P	<= 11'b0;
//		r_rd_00         <= 8'b0;
//		r_rd_01         <= 8'b0;
//		r_rd_10         <= 8'b0;
//		r_rd_11         <= 8'b0;
//		r_de_2L_1P		<= 1'b0;
//		r_de_2L_2P		<= 1'b0;
//		r_de_2L_3P		<= 1'b0;
//		r_y_cnt_2L_1P	<= y_start;
//		r_y_cnt_2L_2P	<= 11'b0;
//		r_y_cnt_2L_3P	<= 11'b0;
//		r_line_in_1L	<= 1'b0;
//		r_line_in_2L	<= 1'b0;
//		r_line_cnt		<= 2'b0;
//		r_frame_cnt		<= 2'b0;
//	end
//	else
//	begin		
//		r_hs_1P			<= in_hsync;
//		r_vs_1P			<= in_vsync;
//		r_rd_addr_1P	<= r_rd_addr;
//		r_rd_addr_2P	<= r_rd_addr_1P;
//		r_rd_addr_3P	<= r_rd_addr_2P;
//		r_de_2L_1P		<= w_de_2L;
//		r_de_2L_2P		<= r_de_2L_1P;
//		r_de_2L_3P		<= r_de_2L_2P;
//		r_y_cnt_2L_2P	<= r_y_cnt_2L_1P;
//		r_y_cnt_2L_3P	<= r_y_cnt_2L_2P;
//		
//		if (!w_de_2L && r_de_2L_1P)
//		begin
//			if (r_y_cnt_2L_1P == y_start + y_win)
//				r_y_cnt_2L_1P	<= y_start;
//			else
//				r_y_cnt_2L_1P	<= r_y_cnt_2L_1P + 1'b1;
//		end
//		
//		if (!w_vsync_2L)
//			r_y_cnt_2L_1P	<= y_start;
//				
//		if (w_de_2L)
//		begin		
//			if (w_valid_2L)
//				r_rd_addr	<= r_rd_addr + 1'b1;
//		end
//		else
//			r_rd_addr	<= x_start;
//				
//		if (in_hsync && !r_hs_1P)
//			r_line_cnt	<= r_line_cnt + 1'b1;
//		
//		if (r_line_cnt[0])
//			r_line_in_1L	<= 1'b1;
//		
//		if (r_line_cnt[1])
//			r_line_in_2L	<= 1'b1;
//		
//		if (r_rd_addr_3P[1:0] == 2'd3)
//		begin
//			r_out_rd_00 <= w_rd_data[127:120];
//			r_out_rd_01 <= w_rd_data[119:112];
//			r_out_rd_10 <= w_rd_data[111:104];
//			r_out_rd_11 <= w_rd_data[103:96];
//		end
//		else if (r_rd_addr_3P[1:0] == 2'd2)
//		begin
//			r_out_rd_00 <= w_rd_data[95:88];
//			r_out_rd_01 <= w_rd_data[87:80];
//			r_out_rd_10 <= w_rd_data[79:72];
//			r_out_rd_11 <= w_rd_data[71:64];
//		end
//		else if (r_rd_addr_3P[1:0] == 2'd1)
//		begin
//			r_out_rd_00 <= w_rd_data[63:56];
//			r_out_rd_01 <= w_rd_data[55:48];
//			r_out_rd_10 <= w_rd_data[47:40];
//			r_out_rd_11 <= w_rd_data[39:32];
//		end
//		else if (r_rd_addr_3P[1:0] == 2'd0)
//		begin
//			r_out_rd_00 <= w_rd_data[31:24];
//			r_out_rd_01 <= w_rd_data[23:16];
//			r_out_rd_10 <= w_rd_data[15:8];
//			r_out_rd_11 <= w_rd_data[7:0];
//		end
//	end
//end
//
//assign	out_rd_00	= r_out_rd_00;
//assign	out_rd_01	= r_out_rd_01;
//assign	out_rd_10	= r_out_rd_10;
//assign	out_rd_11	= r_out_rd_11;
//
///* Resync RED data from axi_clk to p_clk */
//simple_dual_port_ram
//#(
//	. DATA_WIDTH   	(128),
//	. ADDR_WIDTH	(10)
//)
//inst_simple_dual_port_ram_00
//(
//	.wclk	(axi_clk					),
//	.we		(in_0_r_valid				),
//	.waddr	({r_rd_ycnt[0], r_rd_xcnt[8:0]}),
//	.wdata	(in_0_r_payload_data		),
//		
//	.rclk	(p_clk										),
//	.re		(r_de_2L_1P									),
//	.raddr	({r_y_cnt_2L_1P[0], r_rd_addr_1P[10:2]}	),	
//	.rdata	(w_rd_data									)
//);
//
///* FIFO delay for RGB sync signals */
//shift_reg
//#(
//	.D_WIDTH(4),
//	.TAPE(4)
//)
//inst_shift_reg_02
//(                                                                    
//	.i_arst(~rstn	),
//	.i_clk(p_clk	),
//	.i_en(1'b1),
//
//	.i_d({w_de_2L, w_valid_2L, w_hsync_2L, w_vsync_2L}	),
//	.o_q({out_de, out_valid, out_hsync, out_vsync}		)
//);
//
///* 1 line delay for RGB sync signals */
//fifo 
//#(
//	.DATA_WIDTH(4),
//    .ADDR_WIDTH(13)
//)	   
//fifo_01 
//(
//  .clk 		(p_clk	),
//  .nrst 	(rstn	),
//  .we 		(r_line_in_1L),
//  .re 		(r_line_in_2L),
//  .data_in 	({in_de, in_valid, in_hsync, in_vsync}			),
//  .data_out ({w_de_2L, w_valid_2L, w_hsync_2L, w_vsync_2L}	)
//  );
//
endmodule
