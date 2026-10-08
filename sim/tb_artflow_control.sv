`timescale 1ns/1ps
module tb_artflow_control;
    parameter integer CORE_HALF = 5;
    parameter integer PIXEL_HALF = 10;
    reg pclk = 0, pixel_clk = 0;
    always #(CORE_HALF) pclk = ~pclk;
    always #(PIXEL_HALF) pixel_clk = ~pixel_clk;
    reg presetn = 0, pixel_resetn = 0;
    reg [15:0] paddr = 0;
    reg psel = 0, penable = 0, pwrite = 0;
    reg [31:0] pwdata = 0;
    wire [31:0] prdata;
    wire pready, pslverror;
    reg pixel_vs = 0, pixel_hs = 0, pixel_valid = 0, cal_done = 0;
    reg [39:0] raw = {4{10'd400}};
    wire [15:0] gain_r, gain_g, gain_b;
    wire camera_reset, camera_ready;
    wire [2:0] diag_events = 0, diag_axi_fire = 0;
    wire [31:0] diag_state = 0, diag_fifo = 0, diag_written = 0, diag_completed = 0;
    wire [31:0] diag_published = 0, diag_rejected = 0;
    artflow_control dut (.*);

    wire bin_vs, bin_hs, bin_valid;
    wire [63:0] bin_data;
    bayer_bin2x2 #(.MAX_IN_WIDTH(8)) bayer (
        .clk(pixel_clk), .rstn(pixel_resetn), .i_bayer(2'd0), .i_pix_rev(1'b0),
        .i_gain_r(gain_r), .i_gain_g(gain_g), .i_gain_b(gain_b),
        .i_vs(pixel_vs), .i_hs(pixel_hs), .i_valid(pixel_valid), .i_data(raw),
        .o_vs(bin_vs), .o_hs(bin_hs), .o_valid(bin_valid), .o_data(bin_data)
    );

    integer checked_pixels = 0, checked_accesses = 0;
    reg [23:0] expected_pixel = 0;
    reg check_pixels = 0;
    // Check the real Bayer pipeline, including the last pixels after VS changes.
    always @(posedge pixel_clk) begin
        #1;
        if (pixel_resetn && check_pixels && bin_valid) begin
            if (bin_data !== {8'd0, expected_pixel, 8'd0, expected_pixel})
                $fatal(1,"Bayer RGB mismatch got=%h expected=%h time=%0t",
                       bin_data, expected_pixel, $time);
            checked_pixels = checked_pixels + 2;
        end
    end

    task automatic apb_access(input bit wr, input [15:0] addr,
        input [31:0] value, input bit expected_error, output reg [31:0] result);
        begin
            @(negedge pclk);
            paddr = addr; pwrite = wr; pwdata = value; psel = 1; penable = 0;
            #1;
            if (pslverror !== 0) $fatal(1,"Error asserted in APB setup");
            @(negedge pclk); penable = 1;
            #1;
            if (pready !== 1 || pslverror !== expected_error)
                $fatal(1,"APB response addr=%h write=%b data=%h err=%b expected=%b",
                       addr, wr, value, pslverror, expected_error);
            result = prdata;
            @(negedge pclk); psel = 0; penable = 0; pwrite = 0;
            checked_accesses = checked_accesses + 1;
        end
    endtask

    task automatic wr(input [15:0] addr, input [31:0] value, input bit err);
        reg [31:0] ignored;
        begin apb_access(1, addr, value, err, ignored); end
    endtask

    task automatic rd(input [15:0] addr, input [31:0] expected, input bit err);
        reg [31:0] value;
        begin
            apb_access(0, addr, 0, err, value);
            if (value !== expected)
                $fatal(1,"APB read addr=%h got=%h expected=%h",addr,value,expected);
        end
    endtask

    task automatic wait_applied(input [15:0] r, input [15:0] g, input [15:0] b);
        reg [31:0] value;
        integer polls;
        begin
            value = 1; polls = 0;
            while (value[0] && polls < 100) begin
                apb_access(0, 16'h001c, 0, 0, value);
                polls = polls + 1;
            end
            if (value[0]) $fatal(1,"Commit failed to complete");
            rd(16'h0020, r, 0); rd(16'h0024, g, 0); rd(16'h0028, b, 0);
            if ({gain_r,gain_g,gain_b} !== {r,g,b})
                $fatal(1,"Pixel gain group differs from acknowledged values");
        end
    endtask

    task automatic set_shadow(input [15:0] r, input [15:0] g, input [15:0] b);
        begin wr('h10,r,0); wr('h14,g,0); wr('h18,b,0); end
    endtask

    task automatic frame_start;
        begin
            @(negedge pixel_clk); pixel_vs = 1; pixel_hs = 0; pixel_valid = 0;
            repeat (7) @(negedge pixel_clk);
            pixel_vs = 0;
            repeat (7) @(negedge pixel_clk);
        end
    endtask

    task automatic row(input bit tail_vs);
        begin
            @(negedge pixel_clk); pixel_hs = 1; pixel_valid = 1;
            @(negedge pixel_clk); pixel_valid = 0; // legal in-line CSI gap
            @(negedge pixel_clk); pixel_valid = 1;
            @(negedge pixel_clk); pixel_hs = 0; pixel_valid = 0;
            if (tail_vs) pixel_vs = ~pixel_vs;
        end
    endtask

    task automatic common_reset;
        begin
            presetn = 0; pixel_resetn = 0;
            pixel_vs = 0; pixel_hs = 0; pixel_valid = 0;
            psel = 0; penable = 0;
            repeat (6) @(negedge pclk);
            presetn = 1;
            repeat (3) @(negedge pixel_clk);
            pixel_resetn = 1;
            repeat (6) @(negedge pixel_clk);
        end
    endtask

    initial begin
        #2000000;
        $fatal(1,"tb_artflow_control timeout");
    end

    initial begin
        common_reset();
        rd('h00,32'h41524605,0);
        rd('h04,8,0); rd('h30,1,0);
        rd('h10,280,0); rd('h14,255,0); rd('h18,350,0);
        wait_applied(280,255,350);
        wr('h00,0,1); wr('h04,0,1); wr('h20,0,1);
        wr('h10,1025,1); wr('h14,32'h10000,1); wr('h18,32'hffffffff,1);
        rd('h10,280,0); rd('h14,255,0); rd('h18,350,0);
        wr('h11,1,1); rd('h11,0,1); wr('hfffc,0,1); rd('hfffc,0,1);
        wr('h1c,0,1); wr('h1c,2,1); wr('h30,3,1); wr('h30,4,1);
        rd('h30,1,0);

        // Abandoned/extended setup phases must never write anything.
        @(negedge pclk);
        psel = 1; penable = 0; pwrite = 1; paddr = 'h10; pwdata = 777;
        repeat (4) @(negedge pclk);
        psel = 0; pwrite = 0;
        rd('h10,280,0);
        cal_done = 1;
        repeat (4) @(negedge pclk);
        rd('h04,10,0);
        wr('h30,0,0); rd('h30,0,0);
        wr('h30,2,0); rd('h30,2,0); rd('h04,6,0);
        if (camera_reset !== 0 || camera_ready !== 1) $fatal(1,"Camera control");

        // Full allowed gain range and startup commit before the first frame.
        set_shadow(0,1024,256); wr('h1c,1,0); wait_applied(0,1024,256);
        set_shadow(256,384,512); wr('h1c,1,0); wait_applied(256,384,512);
        expected_pixel = {8'd100,8'd150,8'd200}; check_pixels = 1;
        frame_start(); row(0);
        repeat (10) @(negedge pixel_clk);

        // Once a frame starts, even a very long horizontal blank is unsafe.
        set_shadow(300,400,500); wr('h1c,1,0);
        repeat (12) @(negedge pixel_clk);
        rd('h1c,1,0);
        rd('h20,256,0); rd('h24,384,0); rd('h28,512,0);
        if ({gain_r,gain_g,gain_b} !== {16'd256,16'd384,16'd512})
            $fatal(1,"Gains changed in mid-frame horizontal blank");

        // Shadow edits while busy must not corrupt the in-flight snapshot.
        set_shadow(600,700,800); wr('h1c,1,1);
        rd('h10,600,0); rd('h14,700,0); rd('h18,800,0); rd('h1c,1,0);
        row(1); // VS changes immediately after the final RAW input beat.
        repeat (12) @(negedge pixel_clk);
        if (checked_pixels != 4) $fatal(1,"Missing first frame pixels: %0d",checked_pixels);
        wait_applied(300,400,500);

        // Next complete frame must use the accepted snapshot, not later shadow.
        expected_pixel = {8'd117,8'd156,8'd195};
        @(negedge pixel_clk); pixel_vs = 0;
        repeat (8) @(negedge pixel_clk);
        row(0);
        repeat (8) @(negedge pixel_clk);
        wr('h1c,1,0);
        row(0);
        repeat (20) @(negedge pixel_clk);
        if (checked_pixels != 8) $fatal(1,"Missing second frame pixels");
        rd('h1c,1,0);
        if ({gain_r,gain_g,gain_b} !== {16'd300,16'd400,16'd500})
            $fatal(1,"Camera stop without boundary must leave commit pending");
        @(negedge pixel_clk); pixel_vs = 1;
        wait_applied(600,700,800);

        // A new request that reaches the receiver after a too-short boundary
        // must wait for another frame, even if later line blanks are long.
        @(negedge pixel_clk); pixel_vs = 0; pixel_hs = 1;
        repeat (3) @(negedge pixel_clk);
        pixel_hs = 0;
        set_shadow(256,256,256); wr('h1c,1,0);
        repeat (20) @(negedge pixel_clk);
        rd('h1c,1,0);
        @(negedge pixel_clk); pixel_vs = 1;
        wait_applied(256,256,256);

        // A common system reset cancels a pending transaction and restores all
        // domains, including camera hold-reset. No stale toggle may replay.
        @(negedge pixel_clk); pixel_hs = 1;
        @(negedge pixel_clk); pixel_hs = 0;
        set_shadow(10,20,30); wr('h1c,1,0); rd('h1c,1,0);
        check_pixels = 0;
        common_reset();
        rd('h30,1,0); rd('h1c,0,0); wait_applied(280,255,350);
        set_shadow(256,256,256); wr('h1c,1,0); wait_applied(256,256,256);

        // Full-frame-high VS, with a falling edge next to the final RAW beat.
        check_pixels = 1; expected_pixel = {8'd100,8'd100,8'd100};
        @(negedge pixel_clk); pixel_vs = 1;
        repeat (8) @(negedge pixel_clk);
        row(0);
        set_shadow(512,256,128); wr('h1c,1,0);
        row(1);
        repeat (12) @(negedge pixel_clk);
        if (checked_pixels != 12) $fatal(1,"Missing full-frame-high VS pixels");
        wait_applied(512,256,128);

        // Keep a request pending until the next VS, then make that VS edge
        // coincide with the FIRST input pixel. Updating now would split frames.
        expected_pixel = {8'd200,8'd100,8'd50};
        @(negedge pixel_clk); pixel_vs = 1;
        repeat (8) @(negedge pixel_clk);
        row(0);
        set_shadow(700,800,900); wr('h1c,1,0);
        row(0);
        repeat (12) @(negedge pixel_clk);
        rd('h1c,1,0);
        @(negedge pixel_clk); pixel_vs = 0; pixel_hs = 1; pixel_valid = 1;
        @(negedge pixel_clk); pixel_valid = 0;
        @(negedge pixel_clk); pixel_valid = 1;
        @(negedge pixel_clk); pixel_hs = 0; pixel_valid = 0;
        repeat (12) @(negedge pixel_clk);
        rd('h1c,1,0);
        if ({gain_r,gain_g,gain_b} !== {16'd512,16'd256,16'd128})
            $fatal(1,"VS coincident with first pixel changed active gains");
        row(0);
        repeat (12) @(negedge pixel_clk);
        if (checked_pixels != 20) $fatal(1,"Missing coincident-VS frame pixels");
        @(negedge pixel_clk); pixel_vs = 1;
        wait_applied(700,800,900);
        $display("=== tb_artflow_control PASS (%0d APB accesses, %0d Bayer pixels) ===",
                 checked_accesses,checked_pixels);
        $finish;
    end
endmodule
