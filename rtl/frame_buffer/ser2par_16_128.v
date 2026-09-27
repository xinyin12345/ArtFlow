module ser2par_16_128 #(
	parameter I_VID_WIDTH = 16,
	parameter AXI_DDR_WIDTH = 256
	 
)(
input		wire										clk		,    
input		wire										rst_n	,
input       wire                                        de,
input		wire										frame_start	, //active hgih
input		wire										frame_end	, //active high
input       wire                                        frame_stable,
input		wire				[23:0]					frame_pix_num,
input		wire	[I_VID_WIDTH-1:0] 					vin,

output		reg											fifo_wr_en,
output		reg		[AXI_DDR_WIDTH-1:0]					fifo_wr_data = 'd0


);
localparam SHIFT_WIDTH = AXI_DDR_WIDTH/I_VID_WIDTH;
reg	[SHIFT_WIDTH-1:0] 								shift_cnt = 0;

reg													wr_en	= 1'b0;
reg	[AXI_DDR_WIDTH-1:0]								wr_data = 'd0;
reg frame_cnt_end = 'd0;
reg [23:0] frame_cnt = 'd0;

always @( posedge clk or negedge rst_n )
begin
    if( !rst_n )
        shift_cnt <= 'd0;
    else if( frame_start )
        shift_cnt <= 'd1;
    else if( (de | frame_cnt_end) && frame_stable )
        shift_cnt <= {shift_cnt[SHIFT_WIDTH-2:0],shift_cnt[SHIFT_WIDTH-1]};
end

always @( posedge clk )
begin
    if( shift_cnt[SHIFT_WIDTH-1] && (de | frame_cnt_end) && frame_stable) //
            wr_en <= 1'b1;
    else
            wr_en <= 1'b0;
end	  

  //write data Control
always @( posedge clk )
begin
        if( de | frame_cnt_end) begin  				
                wr_data <= {wr_data[AXI_DDR_WIDTH-I_VID_WIDTH-1:0],vin};
        end
end


always @( posedge clk )  
    fifo_wr_data <= wr_data;

always @( posedge clk )
begin
    if(  frame_stable ) begin
        fifo_wr_en <= wr_en ;
    end else 
        fifo_wr_en <= 1'b0;
end   


always @( posedge clk or negedge rst_n )
begin
    if( !rst_n )
        frame_cnt <= 'd0;
    else if( frame_start && frame_stable )
        frame_cnt <= 'd0;
    else if( de )
            frame_cnt <= frame_cnt + 1'b1;
end

always @( posedge clk or negedge rst_n )
begin
    if( !rst_n )
        frame_cnt_end <= 'd0;
    else if( (frame_start | shift_cnt[SHIFT_WIDTH-1] ) && frame_stable )
        frame_cnt_end <= 'd0;
    else if( frame_cnt + 1 == frame_pix_num && de )
        frame_cnt_end <= 1'b1;
end


endmodule
