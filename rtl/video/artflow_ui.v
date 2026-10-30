// KEY1 emits a three-state layout request; frame_store commits it at VS.
// KEY2 OSD visibility and telemetry commit at positive VS in final screen coordinates.
module artflow_ui #(
    parameter CLOCK_HZ=148500000, DEBOUNCE_CYCLES=2970000
)(
    input clk, rst_n, key_mode_n, key_osd_n, capture_toggle, i_vs,
    output reg [1:0] mode, output reg osd_enable,
    output reg [11:0] capture_bcd, display_bcd, output reg fps_valid
);
wire mode_press, osd_press;
artflow_button #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_mode_key
    (clk,rst_n,key_mode_n,mode_press);
artflow_button #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_osd_key
    (clk,rst_n,key_osd_n,osd_press);
reg vs_prev;
wire frame_tick=i_vs && !vs_prev;
wire [11:0] cap_sample, out_sample;
wire sample_valid;
artflow_fps #(.CLOCK_HZ(CLOCK_HZ)) u_fps
    (clk,rst_n,capture_toggle,frame_tick,cap_sample,out_sample,sample_valid);
reg requested_osd;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vs_prev<=0; requested_osd<=1;
        mode<=0; osd_enable<=1; capture_bcd<=0; display_bcd<=0; fps_valid<=0;
    end else begin
        vs_prev<=i_vs;
        if(mode_press) mode<=mode==2 ? 0 : mode+2'd1;
        if(osd_press) requested_osd<=!requested_osd;
        if(frame_tick) osd_enable<=requested_osd ^ osd_press;
        // A complete event-free second must publish zero even without another VS.
        // The pixel-clock timebase must remain running; a stopped clock cannot
        // measure elapsed time or draw a new on-screen status.
        if(frame_tick || (sample_valid && out_sample==0)) begin
            capture_bcd<=cap_sample; display_bcd<=out_sample; fps_valid<=sample_valid;
        end
    end
end
endmodule
