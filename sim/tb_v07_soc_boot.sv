`timescale 1ns/1ps
// Production firmware executes on the vendor Sapphire RISC-V implementation.
// Compile ip/sapphire_soc/sim/sapphire_soc.v, NOT the synthesis variant.
// Run with the v05 directory as cwd so the production BRAM files are found.
module tb_v07_soc_boot;
    reg clk = 0, pixel_clk = 0, reset_n = 0;
    always #5 clk = !clk;
    always #7 pixel_clk = !pixel_clk;
    wire system_reset_n;
    reg uart_rx = 1;
    wire uart_tx;
    wire scl_o, scl_oe, sda_o, sda_oe, sensor_low;
    wire scl = scl_oe ? scl_o : 1'b1;
    wire sda = (sda_oe && !sda_o) || sensor_low ? 1'b0 : 1'b1;
    wire [15:0] paddr, gain_r, gain_g, gain_b;
    wire [31:0] pwdata, prdata;
    wire psel, penable, pwrite, pready, pslverror;
    wire camera_reset, camera_ready;
    reg pixel_vs = 0, pixel_hs = 0, pixel_valid = 0;

    artflow_soc dut (
        .accel_irq(accel_irq),
        .clk(clk), .reset_n(reset_n), .system_reset_n(system_reset_n),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .i2c_scl_i(scl), .i2c_scl_o(scl_o), .i2c_scl_oe(scl_oe),
        .i2c_sda_i(sda), .i2c_sda_o(sda_o), .i2c_sda_oe(sda_oe),
        .paddr16(paddr), .psel(psel), .penable(penable), .pwrite(pwrite),
        .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverror(pslverror)
    );
    wire [31:0] ctrl_data,accel_data;
    wire ctrl_ready,ctrl_error,accel_ready,accel_error,accel_irq;
    assign prdata=paddr[7] ? accel_data : ctrl_data;
    assign pready=paddr[7] ? accel_ready : ctrl_ready;
    assign pslverror=paddr[7] ? accel_error : ctrl_error;
    reg [31:0] seq=1;reg job_busy=0,job_done=0;
    wire job_start,locked,styled_valid;wire [31:0] completed,skipped,errors;
    reg [15:0] job_count=0;
    int interrupt_claims=0,interrupt_completions=0;
    always @(posedge clk) begin
      job_done<=0;
      if(!system_reset_n) begin job_busy<=0;job_count<=0;seq<=1;end
      else if(job_start) begin job_busy<=1;job_count<=50000;end
      else if(job_busy) begin
        if(job_count==0) begin job_busy<=0;job_done<=1;seq<=seq+1;end
        else job_count<=job_count-1;
      end
      if(dut.u_sapphire_soc.u_EfxSapphireSoc.system_plic_logic_bridge_claim_valid &&
         dut.u_sapphire_soc.u_EfxSapphireSoc.system_plic_logic_bridge_claim_payload==16)
        interrupt_claims++;
      if(psel && penable && pwrite && paddr==16'h8c && completed!=0) interrupt_completions++;
    end
    artflow_accel_ctrl accel(
      .clk(clk),.rst_n(system_reset_n),.paddr(paddr),.psel(psel && paddr[7]),
      .penable(penable),.pwrite(pwrite),.pwdata(pwdata),.prdata(accel_data),
      .pready(accel_ready),.pslverror(accel_error),
      .original_valid(camera_ready),.original_bank(2'd0),.original_seq(seq),
      .source_locked(locked),.source_bank(),.display_active(1'b0),.display_bank(2'd0),
      .styled_valid(styled_valid),.styled_bank(),.start(job_start),.src_addr(),.dst_addr(),
      .busy(job_busy),.done(job_done),.failed(1'b0),.cycles(32'd123),
      .irq(accel_irq),.process_toggle(),.completed(completed),.skipped(skipped),.errors(errors));
    artflow_control control (
        .diag_events(3'd0), .diag_axi_fire(3'd0), .diag_state(32'd0),
        .diag_fifo(32'd0), .diag_written(32'd0), .diag_completed(32'd0),
        .diag_published(32'd0), .diag_rejected(32'd0),
        .pclk(clk), .presetn(system_reset_n), .paddr(paddr), .psel(psel && !paddr[7]),
        .penable(penable), .pwrite(pwrite), .pwdata(pwdata), .prdata(ctrl_data),
        .pready(ctrl_ready), .pslverror(ctrl_error), .pixel_clk(pixel_clk),
        .pixel_resetn(system_reset_n), .pixel_vs(pixel_vs), .pixel_hs(pixel_hs),
        .pixel_valid(pixel_valid), .cal_done(1'b1),
        .gain_r(gain_r), .gain_g(gain_g), .gain_b(gain_b),
        .camera_reset(camera_reset), .camera_ready(camera_ready)
    );
    artflow_sensor_model sensor (
        .scl(scl), .sda(sda), .reset(camera_reset), .sda_low(sensor_low)
    );

    localparam real UART_BIT_NS = 1000000000.0 / 115200.0;
    task automatic send_byte(input byte value);
        uart_rx = 0;
        #(UART_BIT_NS);
        for (int bit_index = 0; bit_index < 8; bit_index++) begin
            uart_rx = value[bit_index];
            #(UART_BIT_NS);
        end
        uart_rx = 1;
        #(UART_BIT_NS);
    endtask
    task automatic send_line(input string text);
        for (int i = 0; i < text.len(); i++) send_byte(text[i]);
    endtask

    int uart_bytes = 0;
    string uart_text = "";
    string uart_line = "";
    bit startup_ready = 0, camera_message_ok = 0, camera_message_nack = 0;
    bit wb_message_ok = 0, help_message_ok = 0, timing_message_ok = 0, baseline_message_ok = 0;
    bit nack_scenario;
    initial nack_scenario = $test$plusargs("SENSOR_NACK");
    function automatic bit contains(input string text, input string needle);
        for (int i = 0; i + needle.len() <= text.len(); i++)
            if (text.substr(i, i + needle.len() - 1) == needle) return 1;
        return 0;
    endfunction
    byte received;
    initial forever begin
        @(negedge uart_tx);
        #(UART_BIT_NS / 2.0);
        if (uart_tx === 1'b0) begin
            for (int i = 0; i < 8; i++) begin
                #(UART_BIT_NS);
                received[i] = uart_tx;
            end
            #(UART_BIT_NS);
            if (uart_tx !== 1'b1) $fatal(1, "UART stop bit is not high");
            uart_bytes++;
            uart_text = {uart_text, received};
            // Verilog does not define the C-style \r escape. Normalize CRLF
            // explicitly so line matching is portable across simulators.
            if (received != 13) uart_line = {uart_line, received};
            $write("%c", received);
            if (received == 10) begin
                if (uart_line == "READY; type help\n") startup_ready = 1;
                if (uart_line == "OK camera P1 VTS1500 EXP2989\n")
                    camera_message_ok = 1;
                if (uart_line == "OK camera BASELINE\n") baseline_message_ok = 1;
                if (uart_line == "cam_timing hts=3000 vts=1500 exposure_half_lines=2989\n") timing_message_ok = 1;
                if (contains(uart_line, "ERR camera NACK index=0")) camera_message_nack = 1;
                if (uart_line == "OK wb applied\n") wb_message_ok = 1;
                if (contains(uart_line, "help | status | wb R G B | defaults | cam init/off/baseline/timing"))
                    help_message_ok = 1;
                if (contains(uart_line, "FATAL trap")) $fatal(1, "%s", uart_line);
                uart_line = "";
            end
        end
    end

    // Short synthetic frames only exercise the gain mailbox. No video data
    // replaces CPU/I2C/UART transactions in this integration test.
    int frame_cycle = 0;
    always @(posedge pixel_clk) begin
        if (!system_reset_n || !camera_ready) begin
            frame_cycle <= 0;
            pixel_vs <= 0;
            pixel_hs <= 0;
            pixel_valid <= 0;
        end else begin
            frame_cycle <= frame_cycle == 999 ? 0 : frame_cycle + 1;
            pixel_vs <= frame_cycle < 10;
            pixel_hs <= frame_cycle >= 100 && frame_cycle < 800;
            pixel_valid <= frame_cycle >= 100 && frame_cycle < 800;
        end
    end
    reg [47:0] previous_gains;
    always @(negedge pixel_clk) begin
        if (system_reset_n && camera_ready && pixel_valid &&
            previous_gains !== {gain_r, gain_g, gain_b})
            $fatal(1, "gain changed during active image pixels");
        previous_gains = {gain_r, gain_g, gain_b};
    end
    always @(posedge clk) begin
        if (system_reset_n && psel && penable && pready && pslverror)
            $fatal(1, "firmware issued invalid APB transaction at %h", paddr);
    end

    initial begin
        #1000 reset_n = 1;
        wait (startup_ready);
        if (nack_scenario) begin
            if (!camera_message_nack || camera_message_ok || camera_ready || !camera_reset ||
                sensor.write_count != 0 || sensor.read_count != 0)
                $fatal(1, "NACK did not report failure and keep the camera held reset");
            #(UART_BIT_NS);
            send_line("help\n");
            wait (help_message_ok);
            if (gain_r != 280 || gain_g != 255 || gain_b != 350 || !camera_reset || camera_ready)
                $fatal(1, "failed camera initialization changed safe defaults");
            $display("\ntb_v07_soc_boot PASS: production CPU handled sensor NACK, held reset, emitted READY and answered UART help");
        end else begin
            if (!camera_message_ok || !camera_ready || camera_reset ||
                sensor.write_count != 166 || sensor.read_count != 17 || !timing_message_ok)
                $fatal(1, "READY without verified camera: writes=%0d reads=%0d",
                       sensor.write_count, sensor.read_count);
            if (sensor.memory[16'h3208] != 8'h07 || sensor.memory[16'h3209] != 8'h80 ||
                sensor.memory[16'h320a] != 8'h04 || sensor.memory[16'h320b] != 8'h38 ||
                sensor.memory[16'h0100] != 8'h01 || sensor.memory[16'h320e] != 5 ||
                sensor.memory[16'h320f] != 220 || sensor.memory[16'h3e00] != 0 ||
                sensor.memory[16'h3e01] != 186 || sensor.memory[16'h3e02] != 208)
                $fatal(1, "camera configuration readback mismatch");
            #(UART_BIT_NS);
            send_line("wb 512 256 384\n");
            wait (gain_r == 512 && gain_g == 256 && gain_b == 384);
            wait (wb_message_ok);
            if (!camera_ready || camera_reset) $fatal(1, "white balance disturbed camera gate");
            wait(interrupt_claims>=3 && interrupt_completions>=3);
            if(errors!=0 || !styled_valid || completed<3) $fatal(1,"C5 interrupt scheduling failed");
            $display("tb_v07_soc_boot PASS: production firmware, P1 camera, gain commit; PLIC claims=%0d ACK=%0d done=%0d",interrupt_claims,interrupt_completions,completed);
        end
        $finish;
    end
    initial begin
        #800000000;
        $fatal(1, "SoC boot timeout: camera_ready=%b reset=%b writes=%0d reads=%0d UART=%s",
               camera_ready, camera_reset, sensor.write_count, sensor.read_count, uart_text);
    end
endmodule

// Minimal SC431HAI register transport model. It implements 7-bit address 0x30,
// 16-bit register addressing, ACK, repeated START, and single/multibyte reads.
// Register values are read from prior I2C writes; verification is not hardcoded.
module artflow_sensor_model (
    input wire scl, input wire sda, input wire reset, output reg sda_low = 0
);
    localparam IDLE=0, RX=1, ACK=2, TX=3, MASTER_ACK=4, AFTER_MASTER_ACK=5;
    int state = IDLE;
    int bit_count = 0;
    int byte_phase = 0;
    int write_count = 0;
    int read_count = 0;
    reg [7:0] memory [0:65535];
    reg [23:0] original [0:163];
    reg [23:0] expected [0:165];
    bit p1_profile;
    reg [7:0] shift = 0, transmit_byte = 0;
    reg [15:0] address = 0;
    reg acknowledge = 0, ack_clock_seen = 0, read_mode = 0, master_acked = 0;
    bit inject_nack;
    initial begin
        int golden_file, destination;
        inject_nack = $test$plusargs("SENSOR_NACK");
        p1_profile = $test$plusargs("P1_BOOT");
        for (int i=0; i<65536; i++) memory[i] = 0;
        golden_file = $fopen("camera_golden.memh", "r");
        if (!golden_file) $fatal(1, "runner must export camera_golden.memh from preserved v04 ROM");
        $fclose(golden_file);
        $readmemh("camera_golden.memh", original);
        destination = 0;
        for (int i=0;i<164;i++) begin
            if (original[i] == 24'h010001) continue;
            expected[destination] = original[i];
            case (original[i][23:8])
                16'h3e00: expected[destination][7:0] = 0;
                16'h3e01: expected[destination][7:0] = 8'hba;
                16'h3e02: expected[destination][7:0] = 8'hd0;
            endcase
            destination++;
        end
        if(destination != 163) $fatal(1,"unexpected baseline stream-on count");
        expected[163] = 24'h320e05;
        expected[164] = 24'h320fdc;
        expected[165] = 24'h010001;
    end

    always @(posedge reset) begin
        state = IDLE;
        sda_low = 0;
        write_count = 0;
        read_count = 0;
        for (int i=0;i<65536;i++) memory[i] = 0;
        memory[16'h320c] = 8'h0b; memory[16'h320d] = 8'hb8;
        memory[16'h320e] = 5; memory[16'h320f] = 220;
    end
    always @(negedge sda) begin
        if (scl === 1'b1 && !reset) begin
            state = RX;
            bit_count = 0;
            byte_phase = 0;
            shift = 0;
            read_mode = 0;
            sda_low = 0;
        end
    end
    always @(posedge sda) begin
        if (scl === 1'b1) begin
            state = IDLE;
            sda_low = 0;
        end
    end
    always @(posedge scl) begin
        if (!reset) case (state)
            RX: begin
                shift = {shift[6:0], sda};
                if (bit_count == 7) begin
                    acknowledge = 1;
                    if (byte_phase == 0) begin
                        acknowledge = shift[7:1] == 7'h30 && !inject_nack;
                        read_mode = shift[0];
                    end else if (byte_phase == 1) address[15:8] = shift;
                    else if (byte_phase == 2) address[7:0] = shift;
                    else begin
                        if (write_count >= (p1_profile ? 166 : 164)) $fatal(1, "unexpected extra camera I2C write");
                        if ({address, shift} !== (p1_profile ? expected[write_count] : original[write_count]))
                            $fatal(1, "camera write %0d address/value/order mismatch: actual=%h",
                                   write_count, {address, shift});
                        if (p1_profile && address == 16'h0100 && shift == 1 && read_count != 5)
                            $fatal(1,"P1 stream-on preceded timing readback verification");
                        memory[address] = shift;
                        address = address + 1'b1;
                        write_count++;
                    end
                    byte_phase++;
                    ack_clock_seen = 0;
                    state = ACK;
                    bit_count = 0;
                end else bit_count++;
            end
            ACK: ack_clock_seen = 1;
            TX: begin
                if (bit_count == 7) begin
                    read_count++;
                    state = MASTER_ACK;
                end else bit_count++;
            end
            MASTER_ACK: begin
                master_acked = !sda;
                state = AFTER_MASTER_ACK;
            end
            default: begin end
        endcase
    end
    always @(negedge scl) begin
        if (!reset) case (state)
            ACK: begin
                if (!ack_clock_seen) sda_low = acknowledge;
                else begin
                    sda_low = 0;
                    if (!acknowledge) state = IDLE;
                    else if (read_mode) begin
                        state = TX;
                        bit_count = 0;
                        transmit_byte = memory[address];
                        sda_low = !transmit_byte[7];
                    end else state = RX;
                end
            end
            TX: sda_low = !transmit_byte[7-bit_count];
            MASTER_ACK: sda_low = 0;
            AFTER_MASTER_ACK: begin
                if (master_acked) begin
                    address = address + 1'b1;
                    transmit_byte = memory[address];
                    bit_count = 0;
                    state = TX;
                    sda_low = !transmit_byte[7];
                end else begin
                    state = IDLE;
                    sda_low = 0;
                end
            end
            default: begin end
        endcase
    end
endmodule
