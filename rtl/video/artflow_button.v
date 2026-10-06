// Active-low button: synchronize, qualify both edges, one pulse per press.
module artflow_button #(parameter DEBOUNCE_CYCLES = 2970000)(
    input clk, input rst_n, input key_n, output reg press
);
localparam CW = DEBOUNCE_CYCLES < 2 ? 1 : $clog2(DEBOUNCE_CYCLES);
(* async_reg = "true" *) reg key_meta, key_sync;
reg stable;
reg [CW-1:0] count;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_meta<=1; key_sync<=1; stable<=1; count<=0; press<=0;
    end else begin
        key_meta<=key_n; key_sync<=key_meta; press<=0;
        if (key_sync == stable) count<=0;
        else if (count == DEBOUNCE_CYCLES-1) begin
            stable<=key_sync; count<=0; press<=!key_sync;
        end else count<=count+1'b1;
    end
end
endmodule
