`timescale 1ns/1ps
// Focused test of the actual imported Sapphire I2C peripheral. No RISC-V CPU
// timing is shortened; this complements the production CPU boot regression.
module tb_sapphire_i2c;
    reg clk=0, reset=1;
    always #5 clk=!clk;
    reg valid=0, write=0;
    reg [7:0] address=0;
    reg [31:0] data=0;
    wire ready, rsp_valid;
    wire [31:0] rsp_data;
    wire scl_release, sda_release, sensor_low;
    wire scl=scl_release;
    wire sda=sda_release && !sensor_low;
    BmbI2cCtrl dut (
        .io_ctrl_cmd_valid(valid), .io_ctrl_cmd_ready(ready),
        .io_ctrl_cmd_payload_last(1'b1), .io_ctrl_cmd_payload_fragment_opcode(write),
        .io_ctrl_cmd_payload_fragment_address(address), .io_ctrl_cmd_payload_fragment_length(2'b11),
        .io_ctrl_cmd_payload_fragment_data(data), .io_ctrl_cmd_payload_fragment_context(4'b0),
        .io_ctrl_rsp_valid(rsp_valid), .io_ctrl_rsp_ready(1'b1),
        .io_ctrl_rsp_payload_last(), .io_ctrl_rsp_payload_fragment_opcode(),
        .io_ctrl_rsp_payload_fragment_data(rsp_data), .io_ctrl_rsp_payload_fragment_context(),
        .io_i2c_sda_write(sda_release), .io_i2c_sda_read(sda),
        .io_i2c_scl_write(scl_release), .io_i2c_scl_read(scl), .io_interrupt(),
        .io_systemClk(clk), .systemCd_logic_outputReset(reset)
    );
    artflow_sensor_model sensor(.scl(scl),.sda(sda),.reset(reset),.sda_low(sensor_low));
    task automatic transaction(input bit wr, input byte addr, input int wd, output int rd);
        @(negedge clk);
        valid=1; write=wr; address=addr; data=wd;
        do @(posedge clk); while(!ready);
        @(negedge clk); valid=0;
        while(!rsp_valid) @(negedge clk);
        rd=rsp_data;
    endtask
    task automatic put(input byte addr,input int wd);
        int unused_data;
        transaction(1,addr,wd,unused_data);
    endtask
    task automatic get(input byte addr,output int rd);
        transaction(0,addr,0,rd);
    endtask
    task automatic wait_clear(input byte addr,input int mask);
        int value;
        for(int i=0;i<20000;i++) begin
            get(addr,value);
            if (!(value & mask)) return;
        end
        $fatal(1,"wait_clear timeout addr=%h mask=%h value=%h",addr,mask,value);
    endtask
    task automatic initialize;
        put(8'h20,0); put(8'h28,3); put(8'h2c,999999); put(8'h30,49);
        put(8'h50,500); put(8'h54,500); put(8'h58,1000);
        put(8'h0c,32'h200); put(8'h08,32'h200);
    endtask
    task automatic start_bus(input bit rearm);
        int status;
        put(8'h40,32'he10);
        wait_clear(8'h40,32'h10);
        get(8'h40,status);
        if ((status & 32'he01)!=1) $fatal(1,"START status=%h",status);
        if(rearm) begin put(8'h0c,32'h200); put(8'h08,32'h200); end
    endtask
    task automatic stop_bus;
        int status;
        put(8'h40,32'he20);
        wait_clear(8'h40,32'h21);
        get(8'h40,status);
        if(status & 32'he00) $fatal(1,"STOP status=%h",status);
    endtask
    task automatic send_byte(input byte value);
        int ack,unused_data;
        get(8'h0c,unused_data); get(8'h08,unused_data);
        put(8'h00,32'hb00 | {24'b0,value}); put(8'h04,32'h301);
        for(int i=0;i<20000;i++) begin
            get(8'h0c,ack);
            if(ack & 32'h100) begin
                if(ack & 1) $fatal(1,"unexpected NACK for byte %h",value);
                return;
            end
        end
        $fatal(1,"RX_ACK never valid for byte %h",value);
    endtask
    task automatic write_reg(input bit rearm,input bit [15:0] reg_address,input byte value);
        start_bus(rearm); send_byte(8'h60);
        send_byte(reg_address[15:8]); send_byte(reg_address[7:0]); send_byte(value);
        stop_bus();
    endtask
    int status, received_data, unused_data;
    initial begin
        #200 reset=0;
        initialize();
        write_reg(0,16'h0100,8'h00);
        get(8'h0c,status);
        if(status & 32'h200) $fatal(1,"expected hardware STOP to clear ACK listener");
        start_bus(0);
        put(8'h00,32'hb60); put(8'h04,32'h301);
        #120000;
        get(8'h0c,status);
        if(status & 32'h100) $fatal(1,"legacy missing-listener regression did not reproduce");
        $display("confirmed legacy failure: first STOP clears LISTEN, second address ACK is not captured");

        @(negedge clk); reset=1;
        #200 reset=0;
        initialize();
        write_reg(1,16'h0100,8'h00);
        write_reg(1,16'h36e9,8'h80);
        start_bus(1); send_byte(8'h60); send_byte(8'h36); send_byte(8'he9);
        start_bus(1); send_byte(8'h61);
        get(8'h08,unused_data); get(8'h0c,unused_data);
        put(8'h00,32'h3ff); put(8'h04,32'h301);
        received_data=0;
        for(int i=0;i<20000;i++) begin
            get(8'h08,received_data);
            if(received_data & 32'h100) break;
        end
        if((received_data & 32'h1ff)!=32'h180)
            $fatal(1,"repeated START readback expected 0x80; received=%h",received_data);
        wait_clear(8'h04,32'h100);
        stop_bus();
        if(sensor.write_count!=2 || sensor.read_count!=1)
            $fatal(1,"sensor transactions mismatched");
        $display("tb_sapphire_i2c PASS: real core reproduces old LISTEN bug; rearmed consecutive writes and repeated START read succeed");
        $finish;
    end
    initial begin #5000000; $fatal(1,"focused I2C test timeout"); end
endmodule
