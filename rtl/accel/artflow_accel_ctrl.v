// APB C5 scheduler and styled triple-buffer ownership, all in core_clk.
// Software arms once; hardware waits for a new completed original. Completion
// holds a level interrupt until W1C; firmware acknowledges and arms the next job.
module artflow_accel_ctrl #(
    parameter INTERACT=0, SNAPSHOT_TIMEOUT=2000000000, VERSION_ID=32'h41524607, EARLY_RELEASE=0, ORIGINAL_BASE=0, BANK_BYTES=32'h00400000, STYLED_BASE=32'h00c00000
)(
    input clk,rst_n, input [15:0] paddr, input psel,penable,pwrite,
    input [31:0] pwdata, output reg [31:0] prdata, output pready,pslverror,
    input original_valid, input [1:0] original_bank, input [31:0] original_seq,
    output reg source_locked, output reg [1:0] source_bank,
    input display_active, input [1:0] display_bank,
    output reg styled_valid, output reg [1:0] styled_bank,
    output reg start, output reg [31:0] src_addr,dst_addr,
    input busy,done,failed, input [31:0] cycles,
    input source_consumed,
    input retire_ack, input [4:0] requested_style,completed_style,
    output wire freeze_valid, output wire [1:0] freeze_original_bank,
    output wire freeze_busy,

    output irq, output process_toggle,
    output reg [31:0] completed,skipped,errors
);
localparam LIVE=0,WAIT_PAIR=1,PAIR_JOB=2,FROZEN=3,RETIRE=4,DRAIN=5;
reg [2:0] interaction_state;
reg [31:0] freeze_timer,pair_seq;
reg [4:0] pair_style,previous_request;
reg [2:0] exit_reason;
wire write_cmd=INTERACT && psel && penable && pwrite && !pslverror && paddr==16'h00c0;
wire exit_cmd=write_cmd && pwdata==2;
wire style_changed=INTERACT && requested_style!=previous_request;
wire timed_out=INTERACT && interaction_state!=LIVE && interaction_state!=FROZEN && freeze_timer==SNAPSHOT_TIMEOUT-1;
wire cancel_pair=exit_cmd || style_changed || timed_out;
assign freeze_valid=INTERACT && interaction_state==FROZEN;
assign freeze_original_bank=source_bank;
assign freeze_busy=INTERACT && interaction_state!=LIVE;
reg armed,irq_enable,pending;
reg job_active;
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
        16'h0080: prdata=VERSION_ID;
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
        16'h00c0: begin valid_addr=INTERACT;valid_write=pwdata==1 || pwdata==2;end
        16'h00c4: begin valid_addr=INTERACT;prdata={21'd0,exit_reason,3'd0,freeze_busy,1'b0,interaction_state};end
        16'h00c8: begin valid_addr=INTERACT;prdata=pair_seq;end
        16'h00cc: begin valid_addr=INTERACT;prdata={27'd0,pair_style};end
        default: valid_addr=0;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        interaction_state<=LIVE;freeze_timer<=0;pair_seq<=0;pair_style<=0;previous_request<=0;exit_reason<=0;
        armed<=0;irq_enable<=0;pending<=0;source_locked<=0;source_bank<=0;job_active<=0;
        styled_valid<=0;styled_bank<=0;start<=0;src_addr<=0;dst_addr<=0;
        job_bank<=0;last_seq<=0;styled_seq<=0;launched<=0;
        completed<=0;skipped<=0;errors<=0;
    end else begin
        start<=0;
        previous_request<=requested_style;
        if(interaction_state==LIVE || interaction_state==FROZEN) freeze_timer<=0;
        else if(!timed_out) freeze_timer<=freeze_timer+1'b1;
        if(write_cmd && pwdata==1 && interaction_state==LIVE) begin interaction_state<=WAIT_PAIR;exit_reason<=0;end
        if(cancel_pair && interaction_state!=LIVE) begin
            exit_reason<=timed_out?3'd3:(style_changed?3'd2:3'd1);
            case(interaction_state)
            WAIT_PAIR: interaction_state<=LIVE;
            PAIR_JOB: interaction_state<=DRAIN;
            FROZEN: interaction_state<=RETIRE;
            default: begin end
            endcase
        end
        // The display reader acknowledges only after previous AXI reads drain.
        // FIFO pixels are copies, not DDR references, and retain their epoch.
        if(interaction_state==RETIRE && retire_ack) begin interaction_state<=LIVE;source_locked<=0;end
        if(psel && penable && pwrite && !pslverror) begin
            if(paddr==16'h0084) begin armed<=pwdata[0];irq_enable<=pwdata[1];end
            if(paddr==16'h008c) pending<=0;
        end
        if((!INTERACT || interaction_state==LIVE || interaction_state==WAIT_PAIR) && !cancel_pair && armed && !pending && !job_active && !source_locked && !busy && original_valid &&
           original_seq!=last_seq && free_valid) begin
            armed<=0;source_locked<=1;source_bank<=original_bank;job_active<=1;
            job_bank<=free_bank;last_seq<=original_seq;launched<=launched+1'b1;
            skipped<=skipped+(original_seq-last_seq-1'b1);
            src_addr<=ORIGINAL_BASE+original_bank*BANK_BYTES;
            dst_addr<=STYLED_BASE+free_bank*BANK_BYTES;
            start<=1;
            if(INTERACT && interaction_state==WAIT_PAIR) begin interaction_state<=PAIR_JOB;pair_seq<=original_seq;end
        end
        if(EARLY_RELEASE && source_consumed && job_active && (!INTERACT || (interaction_state!=PAIR_JOB && interaction_state!=DRAIN))) source_locked<=0;
        if(done && job_active) begin
            source_locked<=0;pending<=1;job_active<=0;
            if(INTERACT && (interaction_state==PAIR_JOB || interaction_state==DRAIN)) begin
                if(!failed && interaction_state==PAIR_JOB && !cancel_pair) begin
                    interaction_state<=FROZEN;source_locked<=1;pair_style<=completed_style;
                end else begin interaction_state<=LIVE;if(failed) exit_reason<=4;end
            end
            if(failed) errors<=errors+1'b1;
            else begin
                styled_bank<=job_bank;styled_valid<=1;styled_seq<=last_seq;
                completed<=completed+1'b1;
            end
        end
    end
end
endmodule
