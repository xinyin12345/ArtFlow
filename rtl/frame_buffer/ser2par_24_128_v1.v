

module ser2par_24_128_v1 #(
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
reg [143:0] par_pix_data = 'd0;
reg [31:0] ddr_len_cnt = 'd0;
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
            par_pix_data[143:120] <= vin; //data 1
        end
        5'd2 : begin
            if( de | frame_cnt_end ) begin
                pre_state <= pre_state + 1'b1;
                par_pix_data[119:96] <= vin; //data 2
            end 
        end
        5'd3 : begin
            if( de | frame_cnt_end ) begin
                par_pix_data[95:72] <= vin; //data3
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd4 : begin
            if( de | frame_cnt_end ) begin
                par_pix_data[71:48] <= vin; //data 4
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd5 :begin
            if( de | frame_cnt_end ) begin
                par_pix_data[47:24] <= vin;// data 5
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd6 : begin
            par_pix_valid <= 1'b1;
            if( frame_cnt_end ) begin
                pre_state <= 'd0;
                // par_pix_valid <= 1'b1;
            end else if( de ) begin
                par_pix_data[23:0] <= vin;//data 6
                pre_state <= pre_state + 1'b1;
                // par_pix_valid <= 1'b1;
            end
        end
           
        5'd7 :
        begin
            if( de | frame_cnt_end ) begin
                par_pix_data[127:104] <= vin;
                par_pix_data[143:128] <= par_pix_data[15:0];
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd8 :begin
            if( de | frame_cnt_end ) begin
                par_pix_data[103:80] <= vin;
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd9 :
           begin
            if( de | frame_cnt_end ) begin
                par_pix_data[79:56] <= vin;
                pre_state <= pre_state + 1'b1;
            end
           end
        5'd10 :
           begin
            if( de | frame_cnt_end ) begin
                par_pix_data[55:32] <= vin;
                pre_state <= pre_state + 1'b1;
            end
           end
        5'd11:begin
            par_pix_valid <= 1'b1;
            if( frame_cnt_end ) begin
                pre_state <= 'd0;
                // par_pix_valid <= 1'b1;
            end else if( de ) begin
                par_pix_data[31:8] <= vin;
                pre_state <= pre_state + 1'b1;
                // par_pix_valid <= 1'b1;
            end
        end
        5'd12:begin
            if( de| frame_cnt_end  ) begin
                par_pix_data[143:136] <= par_pix_data[15:8];
                par_pix_data[135:112] <= vin;
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd13:begin
            if( de | frame_cnt_end ) begin
                par_pix_data[111:88] <= vin;
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd14:begin
            if( de | frame_cnt_end ) begin
                par_pix_data[87:64] <= vin;
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd15:begin
            
            if( de | frame_cnt_end ) begin
                par_pix_data[63:40] <= vin;
                pre_state <= pre_state + 1'b1;
            end
        end

        5'd16:begin
            par_pix_valid <= 1'b1;
            if( frame_cnt_end ) begin
                pre_state <= 'd0;
                // par_pix_valid <= 1'b1;
            end else if( de ) begin
                par_pix_data[39:16] <= vin;
                pre_state <= 'd1;
                // par_pix_valid <= 1'b1;
            end
        end
        default:;
        endcase
    end          
end



 assign    fifo_wr_data = par_pix_data[143:16];
 assign    fifo_wr_en = par_pix_valid;






endmodule
