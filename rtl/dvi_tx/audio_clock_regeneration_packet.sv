module audio_clock_regeneration_packet #(
    parameter real VIDEO_RATE = 25.2E6,
    parameter TIME_CNT = 148500
)(
    input logic clk,
    input logic clk_audio,
    input logic [19:0] N ,
    input logic [19:0] CTS,
    output logic [23:0] header,
    output logic [55:0] sub0,
    output logic [55:0] sub1,
    output logic [55:0] sub2,
    output logic [55:0] sub3,
    output logic pkt_valid
);
logic [55:0] sub [3:0];
genvar i;
generate
    for (i = 0; i < 4; i++)
    begin: same_packet
        assign sub[i] = {N[7:0], N[15:8], {4'd0, N[19:16]}, CTS[7:0], CTS[15:8], {4'd0, CTS[19:16]}, 8'd0};
    end
endgenerate

assign sub0 = sub[0];
assign sub1 = sub[1];
assign sub2 = sub[2];
assign sub3 = sub[3];


// `ifdef MODEL_TECH
assign header = {8'd0, 8'd0, 8'd1};
// `else
// assign header = {8'dX, 8'dX, 8'd1};
// `endif
reg [23:0] cnt = 'd0;
always @( posedge clk )
begin
    if( cnt == TIME_CNT-1)
        cnt <= 0;
    else 
        cnt <= cnt + 1'b1;
end 
always @( posedge clk )
begin
    pkt_valid <= cnt == TIME_CNT-1;
end 

endmodule
