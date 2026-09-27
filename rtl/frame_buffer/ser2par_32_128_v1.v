

module ser2par_32_128_v1 #(
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

output		wire										fifo_wr_en,
output		wire	[AXI_DDR_WIDTH-1:0]					fifo_wr_data 


);

//==================================================================================
reg [4:0] pre_state = 'd0;
reg [127:0] par_pix_data = 'd0;
reg  par_pix_valid = 'd0;
reg frame_cnt_end = 'd0;
reg [23:0] frame_cnt = 'd0;
always @( posedge clk or negedge rst_n )
begin
    if( !rst_n )
        frame_cnt <= 'd0;
    else if( frame_start  )
        frame_cnt <= 'd0;
    else if( de && frame_stable)
        frame_cnt <= frame_cnt + 1'b1;
end

always @( posedge clk or negedge rst_n )
begin
    if( !rst_n )
        frame_cnt_end <= 'd0;
    else if(par_pix_valid)//( (frame_start | frame_end) && frame_stable )
        frame_cnt_end <= 'd0;
    else if( frame_cnt + 1 == frame_pix_num && de )
        frame_cnt_end <= 1'b1;
end

always @( posedge clk or negedge rst_n )
begin
    if( !rst_n ) begin
        pre_state <= 'd0;
        par_pix_valid <= 1'b0;
    end else if(frame_end  ) begin
        pre_state <= 'd0;
        par_pix_valid <= 1'b0;
    end else if(frame_stable )begin
        par_pix_valid <= 1'b0;
        case( pre_state )
        5'd0 : begin
           if( frame_start ) 
            pre_state <= pre_state + 1'b1;
        end
        5'd1 : if( de | frame_cnt_end  ) begin
            pre_state <= pre_state + 1'b1;
            par_pix_data[127:96] <= vin; //data 1
        end
        5'd2 : begin
            if( de | frame_cnt_end ) begin
                pre_state <= pre_state + 1'b1;
                par_pix_data[95:64] <= vin; //data 2
            end 
        end
        5'd3 : begin
            if( de | frame_cnt_end ) begin
                par_pix_data[63:32] <= vin; //data3
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd4 : begin
            
            if( frame_cnt_end )begin
                pre_state <= 'b0;
                par_pix_valid <= 1'b1;
                par_pix_data[31:0] <= vin; //data 4
            end else if( de  ) begin
                pre_state <= 'b1;
                par_pix_valid <= 1'b1;
                par_pix_data[31:0] <= vin; //data 4
            end
        end

        default:;
        endcase
    end          
end



 assign    fifo_wr_data = par_pix_data[127:0];
 assign    fifo_wr_en = par_pix_valid;






endmodule
