module ecc_calc_v1(  
    input clk,
input rst_p,
input [55:0] idata,
input valid,
output reg[7:0]  ecc = 'd0
);
reg [55:0] idata_r = 'd0;
reg [7:0] cnt = 'd0;

always @( posedge clk )
begin
cnt <= valid ? 0 : cnt + 1'b1;
end
always @( posedge clk or posedge rst_p )
begin
if( rst_p )
    idata_r <= 'd0;
else if( valid )
    idata_r <= idata;
else 
    idata_r <= idata_r >>1;
end
wire din = idata_r[0];
wire [7:0] parity_next;
always @( posedge clk or posedge rst_p )
begin
if( valid ) begin
    // ecc <= 8'h00;//shift;//8'h1a;//
    ecc <= 'd0;
end else begin
    ecc <= parity_next;
end
end


reg ecc_valid;
always @( posedge clk )
begin
ecc_valid <= ((cnt >= 50) && (ecc == 8'h96));
end




assign parity_next = next_ecc(ecc, din);


function  [7:0] next_ecc;
input [7:0] ecc, next_bch_bit;
begin
    next_ecc = (ecc >> 1) ^ ((ecc[0] ^ next_bch_bit) ? 8'b10000011 : 8'd0);
end
endfunction


endmodule
