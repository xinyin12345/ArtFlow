// Burst admission for the single video DDR master. A grant owns the port until
// B or RLAST; address/data VALID is never withdrawn to change priority.
// Urgency may win twice, then a continuously pending peer MUST be served.
// Fairness is measured in completed transactions, not cycles of a stalled slave.
module video_axi_scheduler (
    input clk, rst_n,
    input write_request, read_request, write_urgent, read_urgent,
    input write_done, read_done,
    output write_grant, read_grant
);
localparam IDLE=2'd0, WRITE=2'd1, READ=2'd2;
reg [1:0] owner=IDLE;
reg last_read=0;
reg [1:0] streak=0;
reg choose_read;
always @* begin
    choose_read=read_request;
    if (write_request && read_request) begin
        if (streak==2) choose_read=!last_read;
        else if (write_urgent != read_urgent) choose_read=read_urgent;
        else choose_read=!last_read;
    end
end
assign write_grant=rst_n && owner==IDLE && write_request && !choose_read;
assign read_grant=rst_n && owner==IDLE && read_request && choose_read;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin owner<=IDLE;last_read<=0;streak<=0;end
    else if (owner==IDLE) begin
        if (write_grant || read_grant) begin
            owner<=read_grant?READ:WRITE;
            last_read<=read_grant;
            if (last_read==read_grant && streak!=0) begin
                if (streak<2) streak<=streak+1'b1;
            end else streak<=1;
        end
    end else if ((owner==WRITE && write_done) || (owner==READ && read_done))
        owner<=IDLE;
end
endmodule
