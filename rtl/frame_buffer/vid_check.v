
module vid_check(
input wire clk,
input wire rst_n,
input wire i_hs,
input wire i_vs,
input wire i_de,
input wire [23:0] vin,
output reg check_fail

);

reg vs_r0 = 1'b0;
reg vs_r1 = 1'b0;
reg [23:0] check_data = 'd0;
always @( posedge clk )
begin
    vs_r0 <= i_vs;
    vs_r1 <= vs_r0;
end

wire frame_start = {vs_r1,vs_r0 }  == 2'b10;

always @( posedge clk )
    if( frame_start )
        check_data <= 'd1;
    else if( i_de )
        check_data <= check_data + 1'b1; 


always @( posedge clk )
begin
     if( check_data != vin && i_de )
            check_fail <= 1'b1;
    else 
            check_fail <= 1'b0;
end







endmodule