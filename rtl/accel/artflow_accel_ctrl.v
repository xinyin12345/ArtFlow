// APB C5 scheduler and styled triple-buffer ownership, all in core_clk.
// Software arms once; hardware waits for a new completed original. Completion
// holds a level interrupt until W1C; firmware acknowledges and arms the next job.
module artflow_accel_ctrl #(
    parameter ORIGINAL_BASE=0, BANK_BYTES=32'h00400000, STYLED_BASE=32'h00c00000
)(
    input clk,rst_n, input [15:0] paddr, input psel,penable,pwrite,
    input [31:0] pwdata, output reg [31:0] prdata, output pready,pslverror,
    input original_valid, input [1:0] original_bank, input [31:0] original_seq,
    output reg source_locked, output reg [1:0] source_bank,
    input display_active, input [1:0] display_bank,
    output reg styled_valid, output reg [1:0] styled_bank,
    output reg start, output reg [31:0] src_addr,dst_addr,
    input busy,done,failed, input [31:0] cycles,
    output irq, output process_toggle,
    output reg [31:0] completed,skipped,errors
);
reg armed,irq_enable,pending;
reg [1:0] job_bank;
reg [31:0] last_seq,styled_seq,launched;
reg [1:0] free_bank;
reg free_valid,valid_addr,valid_write;
integer n;
always @* begin
    free_bank=0;free_valid=0;
    for(n=0;n<3;n=n+1)
        if((!styled_valid || n!=styled_bank) && (!display_active || n!=display_bank)) begin
            free_bank=n;free_valid=1;
        end
end
assign irq=pending && irq_enable;
assign process_toggle=completed[0];
// The video domain is held reset during the board startup delay. Stall APB
// until local reset release: an early CPU arm must not be silently discarded.
assign pready=rst_n;
assign pslverror=psel && penable && (!valid_addr || (pwrite && !valid_write));
always @* begin
    prdata=0;valid_addr=1;valid_write=0;
    case(paddr)
        16'h0080: prdata=32'h41524607;
        16'h0084: begin prdata={30'd0,irq_enable,armed};valid_write=pwdata<=3;end
        16'h0088: prdata={27'd0,styled_valid,source_locked,pending,armed,busy};
        16'h008c: begin prdata={31'd0,pending};valid_write=pwdata==1;end
        16'h0090: prdata=completed;
        16'h0094: prdata=skipped;
        16'h0098: prdata=errors;
        16'h009c: prdata=cycles;
        16'h00a0: prdata=last_seq;
        16'h00a4: prdata=styled_seq;
        16'h00a8: prdata=launched;
        default: valid_addr=0;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        armed<=0;irq_enable<=0;pending<=0;source_locked<=0;source_bank<=0;
        styled_valid<=0;styled_bank<=0;start<=0;src_addr<=0;dst_addr<=0;
        job_bank<=0;last_seq<=0;styled_seq<=0;launched<=0;
        completed<=0;skipped<=0;errors<=0;
    end else begin
        start<=0;
        if(psel && penable && pwrite && !pslverror) begin
            if(paddr==16'h0084) begin armed<=pwdata[0];irq_enable<=pwdata[1];end
            if(paddr==16'h008c) pending<=0;
        end
        if(armed && !pending && !source_locked && !busy && original_valid &&
           original_seq!=last_seq && free_valid) begin
            armed<=0;source_locked<=1;source_bank<=original_bank;
            job_bank<=free_bank;last_seq<=original_seq;launched<=launched+1'b1;
            skipped<=skipped+(original_seq-last_seq-1'b1);
            src_addr<=ORIGINAL_BASE+original_bank*BANK_BYTES;
            dst_addr<=STYLED_BASE+free_bank*BANK_BYTES;
            start<=1;
        end
        if(done && source_locked) begin
            source_locked<=0;pending<=1;
            if(failed) errors<=errors+1'b1;
            else begin
                styled_bank<=job_bank;styled_valid<=1;styled_seq<=last_seq;
                completed<=completed+1'b1;
            end
        end
    end
end
endmodule
