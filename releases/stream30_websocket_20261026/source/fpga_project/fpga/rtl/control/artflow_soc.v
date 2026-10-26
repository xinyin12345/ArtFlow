`timescale 1ns/1ps
// ArtFlow v05 control-plane integration of the demo10 Sapphire SoC.
// Firmware executes from the SoC's 8 KiB initialized RAM at 0xf9000000.
// APB0 is at 0xf8100000; the pixel DDR remains exclusively owned by v04 logic.
module artflow_soc (
    input wire accel_irq,
    input  wire        clk,
    input  wire        reset_n,
    output wire        system_reset_n,
    input  wire        uart_rx,
    output wire        uart_tx,
    input  wire        i2c_scl_i,
    output wire        i2c_scl_o,
    output wire        i2c_scl_oe,
    input  wire        i2c_sda_i,
    output wire        i2c_sda_o,
    output wire        i2c_sda_oe,
    output wire [15:0] paddr16,
    output wire        psel,
    output wire        penable,
    output wire        pwrite,
    output wire [31:0] pwdata,
    input  wire [31:0] prdata,
    input  wire        pready,
    input  wire        pslverror
);
    wire cpu_reset;
    wire scl_release, sda_release;
    // Sapphire I2C write=1 means release. Efinity GPIO OE=1 drives the pad.
    // Drive only a zero; the board pull-ups establish the high level.
    assign i2c_scl_o = 1'b0;
    assign i2c_sda_o = 1'b0;
    assign i2c_scl_oe = system_reset_n && !scl_release;
    assign i2c_sda_oe = system_reset_n && !sda_release;

    wire common_reset_n = reset_n && !cpu_reset;
    (* async_reg = "true" *) reg [1:0] reset_release;
    always @(posedge clk or negedge common_reset_n) begin
        if (!common_reset_n) reset_release <= 2'b00;
        else reset_release <= {reset_release[0], 1'b1};
    end
    assign system_reset_n = reset_release[1];

    wire awvalid, awready, wvalid, wready, wlast, bvalid, bready;
    wire arvalid, arready, rvalid, rready, rlast;
    wire [7:0] awid, arid, bid, rid, awlen, arlen;

    sapphire_soc u_sapphire_soc (
        .io_systemClk(clk), .io_asyncReset(!reset_n), .io_systemReset(cpu_reset),
        .system_uart_0_io_txd(uart_tx), .system_uart_0_io_rxd(uart_rx),
        .system_i2c_0_io_scl_read(i2c_scl_i),
        .system_i2c_0_io_scl_write(scl_release),
        .system_i2c_0_io_sda_read(i2c_sda_i),
        .system_i2c_0_io_sda_write(sda_release),
        .io_apbSlave_0_PADDR(paddr16), .io_apbSlave_0_PSEL(psel),
        .io_apbSlave_0_PENABLE(penable), .io_apbSlave_0_PWRITE(pwrite),
        .io_apbSlave_0_PWDATA(pwdata), .io_apbSlave_0_PRDATA(prdata),
        .io_apbSlave_0_PREADY(pready), .io_apbSlave_0_PSLVERROR(pslverror),
        .userInterruptA(accel_irq), .axiAInterrupt(1'b0),
        // v05 starts from BRAM and exposes no external debug/flash pins.
        .jtagCtrl_tck(1'b0), .jtagCtrl_tdi(1'b0), .jtagCtrl_enable(1'b0),
        .jtagCtrl_capture(1'b0), .jtagCtrl_shift(1'b0),
        .jtagCtrl_update(1'b0), .jtagCtrl_reset(1'b0), .jtagCtrl_tdo(),
        .system_spi_0_io_data_0_read(1'b1), .system_spi_0_io_data_0_write(),
        .system_spi_0_io_data_0_writeEnable(),
        .system_spi_0_io_data_1_read(1'b1), .system_spi_0_io_data_1_write(),
        .system_spi_0_io_data_1_writeEnable(),
        .system_spi_0_io_data_2_read(1'b1), .system_spi_0_io_data_2_write(),
        .system_spi_0_io_data_2_writeEnable(),
        .system_spi_0_io_data_3_read(1'b1), .system_spi_0_io_data_3_write(),
        .system_spi_0_io_data_3_writeEnable(),
        .system_spi_0_io_sclk_write(), .system_spi_0_io_ss(),
        .system_gpio_0_io_read(4'b0000),
        .system_gpio_0_io_write(), .system_gpio_0_io_writeEnable(),
        .axiA_awvalid(awvalid), .axiA_awready(awready), .axiA_awid(awid),
        .axiA_awlen(awlen), .axiA_awaddr(), .axiA_awsize(), .axiA_awburst(),
        .axiA_awlock(), .axiA_awcache(), .axiA_awqos(), .axiA_awprot(), .axiA_awregion(),
        .axiA_wvalid(wvalid), .axiA_wready(wready), .axiA_wlast(wlast),
        .axiA_wdata(), .axiA_wstrb(), .axiA_bvalid(bvalid), .axiA_bready(bready),
        .axiA_bid(bid), .axiA_bresp(2'b11),
        .axiA_arvalid(arvalid), .axiA_arready(arready), .axiA_arid(arid),
        .axiA_arlen(arlen), .axiA_araddr(), .axiA_arsize(), .axiA_arburst(),
        .axiA_arlock(), .axiA_arcache(), .axiA_arqos(), .axiA_arprot(), .axiA_arregion(),
        .axiA_rvalid(rvalid), .axiA_rready(rready), .axiA_rlast(rlast),
        .axiA_rid(rid), .axiA_rdata(32'b0), .axiA_rresp(2'b11)
    );

    // Complete accidental accesses to AXI-A (0x01000000) with DECERR instead
    // of leaving the CPU waiting forever. AW and W may arrive independently.
    artflow_axi_error_slave u_axi_error (
        .clk(clk), .reset_n(system_reset_n),
        .awvalid(awvalid), .awready(awready), .awid(awid), .awlen(awlen),
        .wvalid(wvalid), .wready(wready), .wlast(wlast),
        .bvalid(bvalid), .bready(bready), .bid(bid),
        .arvalid(arvalid), .arready(arready), .arid(arid), .arlen(arlen),
        .rvalid(rvalid), .rready(rready), .rid(rid), .rlast(rlast)
    );
endmodule

module artflow_axi_error_slave (
    input wire clk, input wire reset_n,
    input wire awvalid, output wire awready,
    input wire [7:0] awid, input wire [7:0] awlen,
    input wire wvalid, output wire wready, input wire wlast,
    output reg bvalid, input wire bready, output reg [7:0] bid,
    input wire arvalid, output wire arready,
    input wire [7:0] arid, input wire [7:0] arlen,
    output reg rvalid, input wire rready, output reg [7:0] rid,
    output wire rlast
);
    reg write_active;
    reg [7:0] write_remaining;
    reg [7:0] read_remaining;
    assign awready = reset_n && !write_active && !bvalid;
    assign wready = reset_n && write_active;
    assign arready = reset_n && !rvalid;
    assign rlast = (read_remaining == 0);
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_active <= 1'b0;
            write_remaining <= 0;
            bvalid <= 1'b0;
            bid <= 0;
            rvalid <= 1'b0;
            rid <= 0;
            read_remaining <= 0;
        end else begin
            if (bvalid && bready) bvalid <= 1'b0;
            if (awvalid && awready) begin
                write_active <= 1'b1;
                write_remaining <= awlen;
                bid <= awid;
            end
            if (wvalid && wready) begin
                if (write_remaining == 0) begin
                    write_active <= 1'b0;
                    bvalid <= 1'b1;
                end else write_remaining <= write_remaining - 1'b1;
            end
            if (arvalid && arready) begin
                rvalid <= 1'b1;
                rid <= arid;
                read_remaining <= arlen;
            end else if (rvalid && rready) begin
                if (read_remaining == 0) rvalid <= 1'b0;
                else read_remaining <= read_remaining - 1'b1;
            end
        end
    end
    // WLAST is checked by the master protocol. AWLEN determines the number
    // of accepted beats, including when WVALID precedes AWVALID.
    wire unused_wlast = wlast;
endmodule
