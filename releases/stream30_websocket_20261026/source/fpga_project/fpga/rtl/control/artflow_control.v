// ArtFlow v05 APB3 control plane. APB and camera pixel clocks are asynchronous.
// Both reset inputs MUST assert together for a system reset; camera reset is a
// separate peripheral control and must not reset one side of this mailbox.
module artflow_control #(
    parameter [15:0] DEFAULT_R = 16'd280,
    parameter [15:0] DEFAULT_G = 16'd255,
    parameter [15:0] DEFAULT_B = 16'd350
) (
    input              pclk,
    input              presetn,
    input      [15:0]  paddr,
    input              psel,
    input              penable,
    input              pwrite,
    input      [31:0]  pwdata,
    output reg [31:0]  prdata,
    output             pready,
    output             pslverror,

    input              pixel_clk,
    input              pixel_resetn,
    input              pixel_vs,
    input              pixel_hs,
    input              pixel_valid,
    input [2:0]        diag_events, // independent pixel-domain toggles
    input [2:0]        diag_axi_fire, // AW, W, B handshakes in pclk
    input [31:0]       diag_state, diag_fifo, diag_written, diag_completed,
    input [31:0]       diag_published, diag_rejected,
    input              cal_done,
    output reg [15:0]  gain_r,
    output reg [15:0]  gain_g,
    output reg [15:0]  gain_b,
    output reg         camera_reset,
    output reg         camera_ready
);

localparam [31:0] IDENTIFICATION = 32'h41524605;

reg [15:0] shadow_r, shadow_g, shadow_b;
// This payload is written before the request crosses two synchronizer stages,
// and remains constant until the acknowledgement has crossed back and retired.
reg [15:0] mailbox_r, mailbox_g, mailbox_b;
reg [15:0] applied_r, applied_g, applied_b;
reg request_toggle, busy;
reg acknowledge_toggle;
(* async_reg = "true" *) reg [1:0] acknowledge_sync;
(* async_reg = "true" *) reg [1:0] request_sync;
(* async_reg = "true" *) reg [1:0] calibration_sync;

// Diagnostic registers only observe the data path. No read or write here
// changes capture, frame ownership, AXI scheduling or any reset.
(* async_reg = "true" *) reg [2:0] diag_meta, diag_sync;
reg [2:0] diag_previous;
reg [31:0] diag_vs_count, diag_raw_blocks, diag_bin_blocks;
reg [31:0] diag_aw_count, diag_w_count, diag_b_count;
always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        diag_meta <= 0; diag_sync <= 0; diag_previous <= 0;
        diag_vs_count <= 0; diag_raw_blocks <= 0; diag_bin_blocks <= 0;
        diag_aw_count <= 0; diag_w_count <= 0; diag_b_count <= 0;
    end else begin
        diag_meta <= diag_events; diag_sync <= diag_meta; diag_previous <= diag_sync;
        if (diag_sync[0] != diag_previous[0]) diag_vs_count <= diag_vs_count + 1'b1;
        if (diag_sync[1] != diag_previous[1]) diag_raw_blocks <= diag_raw_blocks + 1'b1;
        if (diag_sync[2] != diag_previous[2]) diag_bin_blocks <= diag_bin_blocks + 1'b1;
        if (diag_axi_fire[0]) diag_aw_count <= diag_aw_count + 1'b1;
        if (diag_axi_fire[1]) diag_w_count <= diag_w_count + 1'b1;
        if (diag_axi_fire[2]) diag_b_count <= diag_b_count + 1'b1;
    end
end

reg address_valid, write_valid;
wire transfer = psel && penable;
assign pready = 1'b1;
assign pslverror = transfer && (!address_valid || (pwrite && !write_valid));

// Deterministic APB3 decode: unknown/misaligned addresses return zero+error,
// RO writes and illegal values return error, and every error is side-effect free.
always @* begin
    prdata = 32'd0;
    address_valid = 1'b1;
    write_valid = 1'b0;
    case (paddr)
        16'h0000: prdata = IDENTIFICATION;
        16'h0004: prdata = {28'd0, camera_reset, camera_ready,
                            calibration_sync[1], busy};
        16'h0010: begin
            prdata = {16'd0, shadow_r};
            write_valid = pwdata <= 32'd1024;
        end
        16'h0014: begin
            prdata = {16'd0, shadow_g};
            write_valid = pwdata <= 32'd1024;
        end
        16'h0018: begin
            prdata = {16'd0, shadow_b};
            write_valid = pwdata <= 32'd1024;
        end
        16'h001c: begin
            prdata = {31'd0, busy};
            write_valid = !busy && pwdata == 32'd1;
        end
        16'h0020: prdata = {16'd0, applied_r};
        16'h0024: prdata = {16'd0, applied_g};
        16'h0028: prdata = {16'd0, applied_b};
        16'h0030: begin
            prdata = {30'd0, camera_ready, camera_reset};
            write_valid = pwdata <= 32'd2;
        end
        16'h0034: prdata = 32'h44494131; // "DIA1", firmware compatibility marker
        16'h0038: prdata = diag_vs_count;
        16'h003c: prdata = diag_raw_blocks;
        16'h0040: prdata = diag_bin_blocks;
        16'h0044: prdata = diag_aw_count;
        16'h0048: prdata = diag_w_count;
        16'h004c: prdata = diag_b_count;
        16'h0050: prdata = diag_state;
        16'h0054: prdata = diag_fifo;
        16'h0058: prdata = diag_written;
        16'h005c: prdata = diag_completed;
        16'h0060: prdata = diag_published;
        16'h0064: prdata = diag_rejected;
        default: address_valid = 1'b0;
    endcase
end

always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        acknowledge_sync <= 2'b00;
        calibration_sync <= 2'b00;
        shadow_r <= DEFAULT_R; shadow_g <= DEFAULT_G; shadow_b <= DEFAULT_B;
        mailbox_r <= DEFAULT_R; mailbox_g <= DEFAULT_G; mailbox_b <= DEFAULT_B;
        applied_r <= DEFAULT_R; applied_g <= DEFAULT_G; applied_b <= DEFAULT_B;
        request_toggle <= 1'b0;
        busy <= 1'b0;
        camera_reset <= 1'b1;
        camera_ready <= 1'b0;
    end else begin
        acknowledge_sync <= {acknowledge_sync[0], acknowledge_toggle};
        calibration_sync <= {calibration_sync[0], cal_done};
        // Retire busy and update all readback fields in the SAME source edge.
        // Software never observes !busy with stale active-gain readback.
        if (busy && acknowledge_sync[1] == request_toggle) begin
            busy <= 1'b0;
            applied_r <= mailbox_r; applied_g <= mailbox_g; applied_b <= mailbox_b;
        end
        if (transfer && pwrite && !pslverror) begin
            case (paddr)
                16'h0010: shadow_r <= pwdata[15:0];
                16'h0014: shadow_g <= pwdata[15:0];
                16'h0018: shadow_b <= pwdata[15:0];
                16'h001c: begin
                    mailbox_r <= shadow_r;
                    mailbox_g <= shadow_g;
                    mailbox_b <= shadow_b;
                    request_toggle <= ~request_toggle;
                    busy <= 1'b1;
                end
                16'h0030: begin
                    camera_reset <= pwdata[0];
                    camera_ready <= pwdata[1];
                end
                default: begin end
            endcase
        end
    end
end

reg previous_vs, boundary_window;
reg [4:0] recent_pixels;
wire frame_edge = pixel_vs != previous_vs;
wire input_activity = pixel_hs || pixel_valid;
// bayer_bin2x2 uses the gains in stage D, three pixel clocks after input.
// Wait for five empty pixel clocks to conservatively drain its full pipeline.
// A VS edge (either polarity) opens a blanking window; the FIRST HS/valid closes
// it, so a long horizontal blank or stalled camera cannot cause a mid-frame
// update. Startup is one safe window before the first camera input activity.
wire safe_boundary = (boundary_window || frame_edge) && !input_activity &&
                     recent_pixels == 5'b00000;
always @(posedge pixel_clk or negedge pixel_resetn) begin
    if (!pixel_resetn) begin
        request_sync <= 2'b00;
        acknowledge_toggle <= 1'b0;
        previous_vs <= 1'b0;
        boundary_window <= 1'b1;
        recent_pixels <= 5'b00000;
        gain_r <= DEFAULT_R; gain_g <= DEFAULT_G; gain_b <= DEFAULT_B;
    end else begin
        request_sync <= {request_sync[0], request_toggle};
        previous_vs <= pixel_vs;
        recent_pixels <= {recent_pixels[3:0], pixel_valid && pixel_hs};
        if (input_activity)
            boundary_window <= 1'b0;
        else if (frame_edge)
            boundary_window <= 1'b1;
        if (request_sync[1] != acknowledge_toggle && safe_boundary) begin
            gain_r <= mailbox_r;
            gain_g <= mailbox_g;
            gain_b <= mailbox_b;
            acknowledge_toggle <= request_sync[1];
        end
    end
end

endmodule
