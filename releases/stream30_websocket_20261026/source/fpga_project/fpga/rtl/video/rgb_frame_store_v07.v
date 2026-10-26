// ArtFlow v07: fixed-size XRGB8888 triple buffer.
// Only this controller owns bank allocation. A bank is published after the
// entire capture AND every AXI B response. A reader pins its bank through RLAST.
// Camera overload drops a whole frame; frame boundaries never reset AXI/FIFOs.
// Output words carry a 32-bit display epoch. Late data is drained, not displayed.
module rgb_frame_store_v07 #(
    parameter INTERACT = 0, WIDTH = 960, HEIGHT = 540, DUAL_WINDOW = 1,
    parameter ADDR_WIDTH = 32, START_ADDR = 0, BANK_BYTES = 32'h00400000,
    parameter FIFO_DEPTH = 1024, BURST_BEATS = 128
)(
    output stream_tick,stream_bad,stream_valid,
    output [9:0] stream_x,stream_y,output [23:0] stream_rgb,output [31:0] stream_epoch,
    input rst_n, input i_clk, input i_vs, input i_valid,
    input [63:0] i_data,
    input o_clk,
    input [1:0] requested_layout, // 0=native pair, 1=styled 2x, 2=original 2x
    output reg [1:0] active_layout=0,
    input [12:0] H_FRONT_PORCH, H_SYNC, H_VALID, H_BACK_PORCH,
    input [12:0] V_FRONT_PORCH, V_SYNC, V_VALID, V_BACK_PORCH,
    output reg o_de, o_hs, o_vs, output reg [31:0] o_data,
    output wire capture_toggle, // AXI-domain successful publication telemetry
    // Read-only diagnostics, all in axi_clk. No feedback into video control.
    output [31:0] diag_state, diag_fifo, diag_written, diag_completed,
    output [31:0] diag_published, diag_rejected,
    input freeze_valid, input [1:0] freeze_original_bank, output reg retire_ack,
    input source_locked, input [1:0] source_bank,
    output original_valid, output [1:0] original_bank,
    input styled_valid, input [1:0] styled_bank,
    output display_active, output reg [1:0] display_bank,
    input axi_clk,
    output [ADDR_WIDTH-1:0] awaddr, output [7:0] awlen,
    output awvalid, input awready,
    output [127:0] wdata, output [15:0] wstrb,
    output wlast, wvalid, input wready,
    input bvalid, input [1:0] bresp, output bready,
    output [ADDR_WIDTH-1:0] araddr, output [7:0] arlen,
    output arvalid, input arready,
    input [127:0] rdata, input rlast, rvalid,
    input [1:0] rresp, output rready
);
// synthesis translate_off
initial begin
    if (WIDTH < 2 || WIDTH%2 != 0 || HEIGHT < 1 || (WIDTH*HEIGHT)%4 != 0 ||
        BANK_BYTES < WIDTH*HEIGHT*4 || BANK_BYTES%4096 != 0 || START_ADDR%16 != 0 ||
        ADDR_WIDTH < 12 || ADDR_WIDTH > 32 || DUAL_WINDOW != 1 ||
        (DUAL_WINDOW && WIDTH%4 != 0) ||
        BURST_BEATS < 1 || BURST_BEATS > 256 || FIFO_DEPTH < BURST_BEATS+16 ||
        (FIFO_DEPTH & (FIFO_DEPTH-1)) != 0)
        $fatal(1,"Unsupported rgb_frame_store geometry/burst/bank configuration");
end
// synthesis translate_on
localparam WORDS = WIDTH * HEIGHT / 4;
localparam INPUTS = WIDTH * HEIGHT / 2;
localparam CW = $clog2(FIFO_DEPTH)+1;
wire crst, arst, orst;
wire write_grant, read_grant;
video_reset_sync rc (.clk(i_clk), .rst_n(rst_n), .ready(crst));
video_reset_sync ra (.clk(axi_clk), .rst_n(rst_n), .ready(arst));
video_reset_sync ro (.clk(o_clk), .rst_n(rst_n), .ready(orst));

function [31:0] gray_decode;
    input [31:0] gray;
    integer n;
    begin
        gray_decode[31]=gray[31];
        for(n=30;n>=0;n=n-1) gray_decode[n]=gray_decode[n+1]^gray[n];
    end
endfunction

// Capture grant is a toggle handshake: equality grants exactly one frame.
reg grant = 0, capture_begin = 0, capture_done = 0;
(* async_reg = "true" *) reg [1:0] grant_sync = 0;
reg vs_d = 0, frame_pending = 1, capturing = 0, half_valid = 0;
reg [63:0] half_word = 0;
reg [31:0] input_count = 0, capture_words = 0;
reg [31:0] capture_words_gray = 0;
reg capture_bad = 0;
reg [31:0] dropped_frames = 0, overflow_frames = 0;
wire vs_edge = vs_d != i_vs;
wire cf_full, cf_empty;
wire [CW-1:0] cf_count;
wire [127:0] cf_data;
wire cf_write = capturing && i_valid && !vs_edge && half_valid &&
                !capture_bad && !cf_full;
wire cf_read;
DC_FIFO #(.FIFO_MODE("ShowAhead"), .DATA_WIDTH(128), .FIFO_DEPTH(FIFO_DEPTH)) capture_fifo (
    .Reset(!rst_n), .WrClk(i_clk), .WrEn(cf_write), .WrDNum(), .WrFull(cf_full),
    .WrData({i_data,half_word}), .RdClk(axi_clk), .RdEn(cf_read),
    .RdDNum(cf_count), .RdEmpty(cf_empty), .RdData(cf_data), .DataVal());

always @(posedge i_clk or negedge crst) begin
    if (!crst) begin
        grant_sync <= 0; vs_d <= 0; frame_pending <= 1;
        capturing <= 0; half_valid <= 0; input_count <= 0;
        capture_begin <= 0; capture_done <= 0;
        capture_words <= 0; capture_words_gray <= 0; capture_bad <= 0;
        dropped_frames <= 0; overflow_frames <= 0;
    end else begin
        grant_sync <= {grant_sync[0],grant};
        vs_d <= i_vs;
        if (vs_edge) begin
            frame_pending <= 1;
            if (capturing) begin
                // Truncated camera frame: drain accepted words, never publish.
                capturing <= 0; half_valid <= 0; capture_bad <= 1;
                capture_done <= capture_begin;
            end
        end else if (i_valid) begin
            if (frame_pending) begin
                frame_pending <= 0;
                if (!capturing && capture_begin == grant_sync[1]) begin
                    capturing <= 1; capture_begin <= ~capture_begin;
                    input_count <= 1; capture_words <= 0; capture_words_gray <= 0; capture_bad <= 0;
                    half_word <= i_data; half_valid <= 1;
                end else dropped_frames <= dropped_frames + 1;
            end else if (capturing) begin
                input_count <= input_count + 1;
                half_valid <= ~half_valid;
                if (!half_valid) half_word <= i_data;
                else if (!capture_bad) begin
                    if (cf_full) begin
                        capture_bad <= 1;
                        overflow_frames <= overflow_frames + 1;
                    end else begin
                        capture_words <= capture_words + 1;
                        capture_words_gray <= ((capture_words+1)>>1) ^ (capture_words+1);
                    end
                end
                if (input_count == INPUTS-1) begin
                    capturing <= 0; half_valid <= 0;
                    capture_done <= capture_begin;
                end
            end
        end
    end
end

// Registered Gray buses replace direct asynchronous binary-bus sampling.
// Capture count is used only after the 3-stage completion toggle; the count and
// bad flag have 2 stages and remain stable until the writer returns its grant.
reg [31:0] display_epoch = 0;
reg [31:0] display_epoch_gray = 0;
(* async_reg = "true" *) reg [31:0] epoch_meta=0, epoch_sync=0;
(* async_reg = "true" *) reg [31:0] count_meta=0, count_sync=0;
(* async_reg = "true" *) reg [1:0] begin_sync=0, bad_sync=0;
(* async_reg = "true" *) reg [2:0] done_sync=0;
reg [31:0] requested_epoch = 0;
// Bundled mailbox: layout is stable for the epoch; two stages plus the
// existing extra epoch-decode cycle precede the AXI snapshot.
(* async_reg = "true" *) reg [1:0] layout_meta=0, layout_sync=0;
reg [1:0] read_layout=0;
reg begin_seen = 0;
wire [31:0] completed_words = gray_decode(count_sync);
always @(posedge axi_clk or negedge arst) begin
    if (!arst) begin
        begin_sync <= 0; done_sync <= 0; bad_sync<=0;
        epoch_meta<=0; epoch_sync<=0; count_meta<=0; count_sync<=0;
        requested_epoch <= 0; layout_meta<=0;layout_sync<=0;
    end else begin
        epoch_meta<=display_epoch_gray; epoch_sync<=epoch_meta;
        layout_meta<=active_layout;layout_sync<=layout_meta;
        count_meta<=capture_words_gray; count_sync<=count_meta;
        bad_sync<={bad_sync[0],capture_bad};
        begin_sync <= {begin_sync[0],capture_begin};
        done_sync <= {done_sync[1:0],capture_done};
        requested_epoch <= gray_decode(epoch_sync);
    end
end

reg [1:0] write_bank = 0, latest_bank = 0, read_bank = 0;
wire [1:0] selected_original=(INTERACT && freeze_valid) ? freeze_original_bank : latest_bank;
reg latest_valid = 0;
assign original_valid=latest_valid;
assign original_bank=latest_bank;
reg display_styled=0;
reg read_active = 0;
assign display_active=read_active && display_styled;
reg [31:0] published_frames = 0, rejected_frames = 0;
assign capture_toggle = published_frames[0];
reg [2:0] ws = 0;
localparam W_IDLE=0, W_WAIT=1, W_ADDR=2, W_DATA=3, W_RESP=4, W_ALLOC=5;
reg [31:0] words_written = 0;
reg [8:0] write_beats = 0, write_beat = 0;
reg [ADDR_WIDTH-1:0] write_addr = 0;
reg write_bad = 0;
wire capture_finished = done_sync[2] == begin_seen;
integer candidate, wanted, boundary;
reg [1:0] free_bank;
reg free_valid;
always @* begin
    free_bank = 0; free_valid=0;
    for (candidate=0; candidate<3; candidate=candidate+1)
        if ((!latest_valid || candidate != latest_bank) &&
            (!read_active || candidate != read_bank) &&
            (!source_locked || candidate != source_bank)) begin
                free_bank = candidate[1:0]; free_valid=1;
            end
    wanted = capture_finished ? completed_words - words_written : WORDS - words_written;
    boundary = (4096 - {1'b0,write_addr[11:0]}) >> 4;
    if (wanted > BURST_BEATS) wanted = BURST_BEATS;
    if (wanted > boundary) wanted = boundary;
end
assign awaddr = write_addr;
assign awlen = write_beats[7:0] - 8'd1;
assign awvalid = ws == W_ADDR;
assign wdata = cf_data;
assign wstrb = 16'hffff;
assign wvalid = ws == W_DATA && !cf_empty;
assign wlast = write_beat == write_beats-1;
assign cf_read = wvalid && wready;
assign bready = ws == W_RESP;
always @(posedge axi_clk or negedge arst) begin
    if (!arst) begin
        ws <= W_IDLE; write_bank <= 0; latest_bank <= 0; latest_valid <= 0;
        begin_seen <= 0; grant <= 0; words_written <= 0;
        write_addr <= START_ADDR; write_beat <= 0; write_beats <= 0; write_bad <= 0;
        published_frames <= 0; rejected_frames <= 0;
    end else case (ws)
        W_IDLE: if (begin_sync[1] != begin_seen) begin
            begin_seen <= begin_sync[1]; words_written <= 0; write_bad <= 0;
            write_addr <= START_ADDR + write_bank * BANK_BYTES;
            ws <= W_WAIT;
        end
        W_WAIT: begin
            if (capture_finished && words_written == completed_words) begin
                if (!bad_sync[1] && !write_bad && words_written == WORDS) begin
                    latest_bank <= write_bank; latest_valid <= 1;
                    published_frames <= published_frames + 1;
                end else rejected_frames <= rejected_frames + 1;
                ws <= W_ALLOC;
            end else if (write_grant) begin
                // All W beats are buffered BEFORE AW; sensor loss cannot strand AXI.
                write_beats <= wanted[8:0]; write_beat <= 0; ws <= W_ADDR;
            end
        end
        W_ADDR: if (awready) ws <= W_DATA;
        W_DATA: if (wvalid && wready) begin
            if (wlast) ws <= W_RESP;
            else write_beat <= write_beat + 9'd1;
        end
        W_RESP: if (bvalid) begin
            write_bad <= write_bad | (bresp != 0);
            words_written <= words_written + write_beats;
            write_addr <= write_addr + (write_beats << 4);
            ws <= W_WAIT;
        end
        W_ALLOC: if (free_valid) begin
            write_bank <= free_bank;
            grant <= begin_seen;
            ws <= W_IDLE;
        end
        default: ws <= W_IDLE;
    endcase
end

// AXI reader. A new display epoch cancels unsent work, but never retracts ARVALID
// or abandons an accepted burst. Its bank remains pinned until the last R beat.
reg [1:0] rs = 0;
localparam R_IDLE=0, R_WAIT=1, R_ADDR=2, R_DATA=3;
reg [31:0] read_epoch = 0, handled_epoch = 0;
reg [31:0] words_read = 0;
localparam DISPLAY_WORDS=WORDS*2, ROW_WORDS=WIDTH/4;
reg [15:0] display_row=0;
reg display_right=0;
reg [15:0] row_words=0;
reg [31:0] original_base=0, result_base=0;
reg [8:0] read_beats = 0, read_beat = 0;
reg [ADDR_WIDTH-1:0] read_addr = 0;
wire rf_full, rf_empty;
wire [CW-1:0] rf_used;
wire [161:0] rf_data;
wire rf_read, rf_valid;
wire read_stale = read_epoch != requested_epoch;
wire rf_write = rvalid && rready && !read_stale;
assign rready = rs == R_DATA && (read_stale || !rf_full);
assign araddr = read_addr;
assign arlen = read_beats[7:0] - 8'd1;
assign arvalid = rs == R_ADDR;
DC_FIFO #(.FIFO_MODE("Normal"), .DATA_WIDTH(162), .FIFO_DEPTH(FIFO_DEPTH)) display_fifo (
    .Reset(!rst_n), .WrClk(axi_clk), .WrEn(rf_write), .WrDNum(rf_used), .WrFull(rf_full),
    .WrData({display_styled,(rresp != 0),read_epoch,rdata}), .RdClk(o_clk), .RdEn(rf_read),
    .RdDNum(), .RdEmpty(rf_empty), .RdData(rf_data), .DataVal(rf_valid));
integer read_wanted, read_boundary;
always_comb begin
    read_wanted = ROW_WORDS - row_words;
    read_boundary = (4096 - (read_addr & 32'hfff)) >> 4;
    if (read_wanted > BURST_BEATS) read_wanted = BURST_BEATS;
    if (read_wanted > read_boundary) read_wanted = read_boundary;
end
always @(posedge axi_clk or negedge arst) begin
    if (!arst) begin
        retire_ack<=0;
        rs <= R_IDLE; read_active <= 0; read_bank <= 0;read_layout<=0;
        display_bank<=0;display_styled<=0;display_row<=0;display_right<=0;
        row_words<=0;original_base<=0;result_base<=0;
        read_epoch <= 0; handled_epoch <= 0; words_read <= 0;
        read_beats <= 0; read_beat <= 0; read_addr <= START_ADDR;
    end else begin
    retire_ack<=0;
    case (rs)
        R_IDLE: if (requested_epoch != handled_epoch) begin
            handled_epoch <= requested_epoch;
            retire_ack<=!freeze_valid || !INTERACT;
            if (latest_valid) begin
                read_epoch <= requested_epoch; read_bank <= selected_original; read_active <= 1;
                read_layout<=layout_sync;
                read_addr <= layout_sync==1 && styled_valid ? START_ADDR+(3+styled_bank)*BANK_BYTES : START_ADDR+selected_original*BANK_BYTES;
                words_read <= 0; rs <= R_WAIT;
                display_bank<=styled_bank;display_styled<=styled_valid && layout_sync!=2;
                display_row<=0;display_right<=0;row_words<=0;
                original_base<=START_ADDR+selected_original*BANK_BYTES;
                result_base<=styled_valid ? START_ADDR+3*BANK_BYTES+styled_bank*BANK_BYTES :
                                           START_ADDR+selected_original*BANK_BYTES;
            end
        end
        R_WAIT: begin
            if (read_stale || words_read == DISPLAY_WORDS) begin
                read_active <= 0; rs <= R_IDLE;
            end else if (read_grant) begin
                read_beats <= read_wanted[8:0]; read_beat <= 0; rs <= R_ADDR;
            end
        end
        R_ADDR: if (arready) rs <= R_DATA;
        R_DATA: if (rvalid && rready) begin
            if (rlast) begin
                words_read <= words_read + read_beats;
                if(row_words+read_beats==ROW_WORDS) begin
                    row_words<=0;
                    if(read_layout==0) begin
                        display_right<=!display_right;
                        if(!display_right) read_addr<=result_base+display_row*(WIDTH*4);
                        else begin
                            display_row<=display_row+1'b1;
                            read_addr<=original_base+(display_row+1'b1)*(WIDTH*4);
                        end
                    end else begin
                        // Read each source row twice for vertical 2x; horizontal
                        // duplication happens after the display FIFO. Same byte
                        // count per frame as the native pair, no extra frame RAM.
                        display_row<=display_row+1'b1;
                        read_addr<=(read_layout==1?result_base:original_base)+
                                   ((display_row+1'b1)>>1)*(WIDTH*4);
                    end
                end else begin
                    row_words<=row_words+read_beats;
                    read_addr <= read_addr + (read_beats << 4);
                end
                rs <= R_WAIT;
            end else read_beat <= read_beat + 9'd1;
        end
    endcase
    end
end

// Requests reserve a complete write burst or sufficient read FIFO capacity.
// Low display fill / high capture fill get bounded priority at burst boundaries.
wire write_request = ws==W_WAIT && wanted>0 && cf_count>=wanted && !cf_empty;
wire read_request = rs==R_WAIT && !read_stale && words_read<DISPLAY_WORDS &&
                    rf_used+read_wanted+8<FIFO_DEPTH;
video_axi_scheduler u_scheduler (
    .clk(axi_clk), .rst_n(arst),
    .write_request(write_request), .read_request(read_request),
    .write_urgent(cf_count >= FIFO_DEPTH*3/4), .read_urgent(rf_used < FIFO_DEPTH/4),
    .write_done(bvalid && bready), .read_done(rvalid && rready && rlast),
    .write_grant(write_grant), .read_grant(read_grant));

// Two-word elastic queue hides the synchronous FIFO read latency.
reg [161:0] q0 = 0, q1 = 0;
reg [1:0] qcount = 0;
reg pending_read = 0;
reg [1:0] pixel = 0;
reg [12:0] hx = 0, vy = 0;
wire [12:0] htotal = H_SYNC + H_BACK_PORCH + H_VALID + H_FRONT_PORCH;
wire [12:0] vtotal = V_SYNC + V_BACK_PORCH + V_VALID + V_FRONT_PORCH;
wire active = hx >= H_SYNC+H_BACK_PORCH && hx < H_SYNC+H_BACK_PORCH+H_VALID &&
              vy >= V_SYNC+V_BACK_PORCH && vy < V_SYNC+V_BACK_PORCH+V_VALID;
wire [12:0] px = hx - H_SYNC - H_BACK_PORCH;
wire [12:0] py = vy - V_SYNC - V_BACK_PORCH;
wire frame_tick = hx == 0 && vy == 0;
reg frame_bad = 0;
reg [31:0] underflow_frames = 0;
wire word_ok = qcount != 0 && q0[159:128] == display_epoch && !q0[160];
// Dual view: native-size left/right copies, centered in the active raster.
// Read each source row once; replay it from BRAM in the right window.
wire image_row = active_layout!=0 || (py >= HEIGHT/2 && py < HEIGHT/2+HEIGHT);
wire source_slot = active_layout==0 || px[0]; // second copy advances a fullscreen pixel
wire consume = active && image_row && source_slot && !frame_bad && word_ok;
wire discard = qcount != 0 && (q0[159:128] != display_epoch || frame_bad);
wire pop = discard || (consume && pixel == 3);
assign rf_read = orst && !rf_empty && !pending_read && qcount < 2;
wire [31:0] next_pixel = q0[pixel*32 +: 32];
// Read-only epoch-tagged style tap. Never feeds video/AXI ownership or timing.
assign stream_tick=frame_tick;
assign stream_bad=frame_bad;
assign stream_epoch=display_epoch;
assign stream_rgb=next_pixel[23:0];
assign stream_x=active_layout==0 ? px-WIDTH : px>>1;
assign stream_y=active_layout==0 ? py-HEIGHT/2 : py>>1;
assign stream_valid=active && image_row && !frame_bad && word_ok && q0[161] &&
 ((active_layout==0 && px>=WIDTH && px<WIDTH*2) ||
  (active_layout==1 && !px[0] && !py[0]));
always @(posedge o_clk or negedge orst) begin
    if (!orst) begin
        qcount <= 0; pending_read <= 0; q0 <= 0; q1 <= 0;
    end else begin
        pending_read <= rf_read;
        case ({rf_valid,pop})
            2'b10: begin
                if (qcount == 0) q0 <= rf_data; else q1 <= rf_data;
                qcount <= qcount + 2'd1;
            end
            2'b01: begin q0 <= q1; qcount <= qcount - 2'd1; end
            2'b11: begin
                if (qcount == 1) q0 <= rf_data;
                else begin q0 <= q1; q1 <= rf_data; end
            end
            default: ;
        endcase
    end
end
always @(posedge o_clk or negedge orst) begin
    if (!orst) begin
        hx <= 0; vy <= 0; pixel <= 0; display_epoch <= 0; display_epoch_gray <= 0;active_layout<=0;
        o_de <= 0; o_hs <= 0; o_vs <= 0; o_data <= 0;
        frame_bad <= 0; underflow_frames <= 0;
    end else begin
        if (hx == htotal-1) begin
            hx <= 0;
            vy <= vy == vtotal-1 ? 0 : vy+13'd1;
        end else hx <= hx+13'd1;
        if (frame_tick) begin
            active_layout<=requested_layout==1 ? 1 : requested_layout==2 ? 2 : 0;
            display_epoch <= display_epoch + 1;
            display_epoch_gray <= ((display_epoch+1)>>1) ^ (display_epoch+1);
            pixel <= 0; frame_bad <= 0;
        end
        o_de <= active;
        o_hs <= hx < H_SYNC;
        o_vs <= vy < V_SYNC;
        o_data <= 0;
        if (active && image_row && !frame_bad) begin
            if (word_ok) begin
                o_data <= next_pixel;
                if(source_slot) pixel <= pixel+2'd1;
            end else begin
                frame_bad <= 1;
                underflow_frames <= underflow_frames + 1;
            end
        end
    end
end
// Each field is a live AXI-domain value. A UART status line is not an atomic
// multi-register snapshot; compare successive readings to locate stalled work.
assign diag_state = {9'd0,rlast,rready,rvalid,arready,arvalid,bready,bvalid,
                     wready,wvalid,awready,awvalid,rf_full,cf_empty,
                     write_bad,bad_sync[1],capture_finished,read_active,latest_valid,rs,ws};
wire [15:0] diag_cf_count = cf_count;
wire [15:0] diag_beats = write_beats;
assign diag_fifo = {diag_cf_count,diag_beats};
assign diag_written = words_written;
assign diag_completed = completed_words;
assign diag_published = published_frames;
assign diag_rejected = rejected_frames;
endmodule

