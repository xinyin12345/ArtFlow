// CSI restart admission, entirely in the camera pixel clock domain.
// CAMERA.ready is already synchronized by the top level. This gate never
// resets DDR/FIFOs or cancels an accepted AXI transaction. Every output has
// one register stage; boundary polarity is intentionally independent of CSI.
module artflow_camera_gate (
    input             clk,
    input             rstn,
    input             camera_ready,
    input             raw_vs,
    input             raw_hs,
    input             raw_valid,
    input      [39:0] raw_data,
    output reg        video_vs,
    output reg        video_hs,
    output reg        video_valid,
    output reg [39:0] video_data
);
reg previous_vs, ready_d, streaming;
wire raw_edge = raw_vs != previous_vs;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        previous_vs <= 1'b0;
        ready_d <= 1'b0;
        streaming <= 1'b0;
        video_vs <= 1'b0;
        video_hs <= 1'b0;
        video_valid <= 1'b0;
        video_data <= 40'd0;
    end else begin
        // Track CSI even while disabled, so a static-high VS cannot be
        // mistaken for a fresh boundary merely because ready becomes high.
        previous_vs <= raw_vs;
        ready_d <= camera_ready;
        video_data <= raw_data;
        video_hs <= 1'b0;
        video_valid <= 1'b0;
        if (!camera_ready) begin
            streaming <= 1'b0;
            // A sensor reset may suppress its final FE/VS edge. Insert one
            // explicit abort after the last admitted beat and exactly once.
            if (ready_d) video_vs <= ~video_vs;
        end else if (streaming || raw_edge) begin
            streaming <= 1'b1;
            if (raw_edge) video_vs <= ~video_vs;
            video_hs <= raw_hs;
            video_valid <= raw_valid;
        end
    end
end
endmodule
