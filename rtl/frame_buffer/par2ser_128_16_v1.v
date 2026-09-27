

module par2ser_128_16_v1 #(
    parameter VID_WIDTH = 24,
    parameter AXI_DATA_WIDTH	= 512

)(
    input clk,
    input rst_n,

    input frame_period,
    input [25:0] frame_lenth,
    input rd_fifo_rdvalid,
    input [AXI_DATA_WIDTH-1:0]rd_fifo_rddata ,
    input rd_fifo_rdempty,
    output reg rd_fifo_rden = 'd0,

    output reg tx_fifo_valid = 'd0,
    input wr_fifo_full,
    output wire [VID_WIDTH-1:0] tx_fifo_wrdata
);
reg frame_period_r0 = 1'b0;
reg frame_period_r1 = 1'b0;
reg [4:0] pre_state = 'd0;
reg [128-1:0] rx_data = 'd0;
reg [25:0] frame_cnt = 'd0;
reg rd_frame_end = 'd0;
reg [3:0] last_shift_cnt = 'd0;
always @( posedge clk or negedge rst_n )
begin
    if( !rst_n ) begin
        frame_period_r0 <= 1'b0;
        frame_period_r1 <= 1'b0;
    end else begin
        frame_period_r0 <= frame_period;
        frame_period_r1 <= frame_period_r0;
    end
end
wire frame_start_w = {frame_period_r0,frame_period} == 2'b01;
wire frame_start = {frame_period_r1,frame_period_r0} == 2'b01;
    
assign tx_fifo_wrdata = rx_data[127:112];
always @( posedge clk or negedge rst_n )
begin
    if( !rst_n ) begin
        
        pre_state <= 0;
        rd_fifo_rden <= 1'b0;
        tx_fifo_valid <= 1'b0;
    end else if(frame_start_w) begin
        pre_state <= 0;
        rd_fifo_rden <= 1'b0;
        tx_fifo_valid <= 1'b0;
    end else begin
        
   
        rd_fifo_rden <= 1'b0;
        tx_fifo_valid <= 1'b0;
        case( pre_state )
        5'd0 : begin
           if( frame_start) 
            pre_state <= pre_state + 1'b1;
        end
        5'd1 : if( ~rd_fifo_rdempty ) begin
                pre_state <= pre_state + 1'b1;
                rd_fifo_rden <= 1'b1;
        end
        5'd2 : begin
            pre_state <= 5'd3;
        end
        5'd3 : begin
            if( ~wr_fifo_full ) begin
                rx_data <= rd_fifo_rddata;//data 1
                tx_fifo_valid <= 1'b1;
                pre_state <= pre_state + 1'b1;
            end
        end
        5'd4 : begin
            if( ~wr_fifo_full ) begin
                tx_fifo_valid <= 1'b1;
                rx_data <= rx_data << 16  ; //data2 
                pre_state <= pre_state + 1'b1 ;
            end 
        end
        5'd5 :begin
            if( ~wr_fifo_full ) begin
                tx_fifo_valid <= ~wr_fifo_full;
                rx_data <= rx_data << 16  ;//data 3
                pre_state <= pre_state + 1'b1 ;
            end 
        end
          
        5'd6 : begin
            if( ~wr_fifo_full ) begin
                tx_fifo_valid <= 1'b1;
                rx_data <=  rx_data << 16  ; //data 4
                pre_state <= pre_state + 1'b1 ;
            end
        end
           
        5'd7 :
        begin
            if( ~wr_fifo_full ) begin
                tx_fifo_valid <= 1'b1;
                rx_data <= rx_data << 16 ;
                pre_state <= pre_state + 1'b1 ;
            end 
        end
           
        5'd8 :begin
            // rx_data <= rx_data << 24 ;
            if( ~wr_fifo_full ) begin
                tx_fifo_valid <= 1'b1;
                rx_data <= rx_data << 16 ;
                pre_state <= pre_state + 1'b1 ;
            end 
        end

        5'd9 :
           begin
            if( ~wr_fifo_full && ~rd_fifo_rdempty ) begin
                rx_data <= rx_data << 16  ;
                tx_fifo_valid <= 1'b1;
                pre_state <= pre_state + 1'b1 ;
                rd_fifo_rden <= 1'b1;
            end
           end
        5'd10 :
           begin
            if( ~wr_fifo_full ) begin
                rx_data <= rx_data << 16  ;
                tx_fifo_valid <= 1'b1;
                pre_state <= 3 ;
            end 
           end
       

        default:;
        endcase

    end          

end

always @( posedge clk or negedge rst_n )
begin
    if( !rst_n )
        rd_frame_end <= 'd0;
    else if( last_shift_cnt[3] )
        rd_frame_end <= 1'b0;
    else if(frame_cnt+1 == frame_lenth  && rd_fifo_rden)
        rd_frame_end <= 1'b1;
end

always @( posedge clk or negedge rst_n )
begin
    if( !rst_n )
        frame_cnt <= 'd0;
    else if( frame_start )
        frame_cnt <= 'd0;
    else if( rd_fifo_rden )
        frame_cnt <= frame_cnt + 1'b1;
end 

always @( posedge clk or negedge rst_n )
begin
    if( !rst_n )
    last_shift_cnt <= 'd0;
    else if( last_shift_cnt[3])
        last_shift_cnt <= 'd0;
    else if( rd_frame_end ) 
        last_shift_cnt <= last_shift_cnt + 1'b1;
end





endmodule
