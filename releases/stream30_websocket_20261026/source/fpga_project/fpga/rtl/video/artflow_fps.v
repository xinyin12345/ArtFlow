// One-second event counts in the HDMI clock domain, saturating at 999.
// Capture toggle changes only after a complete, successful DDR publication.
module artflow_fps #(parameter CLOCK_HZ = 148500000)(
    input clk, input rst_n, input capture_toggle, input display_tick,
    output reg [11:0] capture_bcd, output reg [11:0] display_bcd,
    output reg sample_valid
);
localparam CW = CLOCK_HZ < 2 ? 1 : $clog2(CLOCK_HZ);
(* async_reg = "true" *) reg cap_meta, cap_sync;
reg cap_prev;
reg [CW-1:0] second_count;
reg [11:0] cap_count, out_count;
wire cap_event = cap_sync ^ cap_prev;
function [11:0] increment;
    input [11:0] n;
    begin
        if (n == 12'h999) increment=n;
        else if (n[3:0] != 9) increment=n+12'h001;
        else if (n[7:4] != 9) increment={n[11:4]+8'h01,4'h0};
        else increment={n[11:8]+4'h1,8'h00};
    end
endfunction
wire [11:0] cap_next = cap_event ? increment(cap_count) : cap_count;
wire [11:0] out_next = display_tick ? increment(out_count) : out_count;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cap_meta<=0; cap_sync<=0; cap_prev<=0; second_count<=0;
        cap_count<=0; out_count<=0; capture_bcd<=0; display_bcd<=0; sample_valid<=0;
    end else begin
        cap_meta<=capture_toggle; cap_sync<=cap_meta; cap_prev<=cap_sync;
        if (second_count == CLOCK_HZ-1) begin
            second_count<=0; capture_bcd<=cap_next; display_bcd<=out_next;
            cap_count<=0; out_count<=0; sample_valid<=1;
        end else begin
            second_count<=second_count+1'b1; cap_count<=cap_next; out_count<=out_next;
        end
    end
end
endmodule
