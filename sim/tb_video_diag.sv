`timescale 1ns/1ps
module tb_video_diag;
parameter CORE_HALF=5, PIXEL_HALF=13;
reg pclk=0, pixel_clk=0;
always #(CORE_HALF) pclk=~pclk;
always #(PIXEL_HALF) pixel_clk=~pixel_clk;
reg presetn=0, pixel_resetn=0;
reg [15:0] paddr=0;
reg psel=0, penable=0, pwrite=0;
reg [31:0] pwdata=0;
wire [31:0] prdata;
wire pready, pslverror;
reg pixel_vs=0, pixel_hs=0, pixel_valid=0, cal_done=0;
wire [15:0] gain_r, gain_g, gain_b;
wire camera_reset, camera_ready;
reg [2:0] diag_events=0, diag_axi_fire=0;
reg [31:0] diag_state=32'h002abcde, diag_fifo=32'h01230080;
reg [31:0] diag_written=128, diag_completed=512;
reg [31:0] diag_published=19, diag_rejected=3;
artflow_control dut(.*);
integer checks=0;
task automatic read_check(input [15:0] addr,input [31:0] expected);
begin
    @(negedge pclk); paddr=addr; pwrite=0; psel=1; penable=0;
    @(negedge pclk); penable=1;
    #1;
    if (prdata!==expected || !pready || pslverror)
        $fatal(1,"Diagnostic read %h got %h expected %h",addr,prdata,expected);
    checks++;
    @(negedge pclk); psel=0; penable=0;
end
endtask
task automatic writes_rejected(input [15:0] addr);
begin
    @(negedge pclk); paddr=addr; pwrite=1; pwdata=32'hffffffff; psel=1;
    @(negedge pclk); penable=1;
    #1; if (!pslverror || !pready) $fatal(1,"Diagnostic register writable: %h",addr);
    checks++;
    @(negedge pclk); psel=0; penable=0; pwrite=0;
end
endtask
initial begin #1000000; $fatal(1,"Diagnostic test timeout"); end
initial begin
    repeat(10) @(negedge pclk); presetn=1;
    repeat(10) @(negedge pixel_clk); pixel_resetn=1;
    read_check('h34,32'h44494131);
    for(integer addr='h38; addr<='h4c; addr+=4) read_check(addr,0);
    // Each independent source event is well separated from receiver edges.
    // Stall two sources while the third runs, then stall all three.
    for(integer n=0;n<23;n++) begin
        @(negedge pixel_clk);
        diag_events[0]=~diag_events[0];
        if(n<13) diag_events[1]=~diag_events[1];
        if(n<7) diag_events[2]=~diag_events[2];
        repeat(10) @(negedge pclk);
    end
    read_check('h38,23); read_check('h3c,13); read_check('h40,7);
    for(integer n=0;n<29;n++) begin
        @(negedge pclk); diag_axi_fire={n<3,n<29,n<5};
    end
    @(negedge pclk); diag_axi_fire=0;
    read_check('h44,5); read_check('h48,29); read_check('h4c,3);
    read_check('h50,diag_state); read_check('h54,diag_fifo);
    read_check('h58,128); read_check('h5c,512);
    read_check('h60,19); read_check('h64,3);
    for(integer addr='h34;addr<='h64;addr+=4) writes_rejected(addr);
    // Reads must not clear counters or affect the original control registers.
    repeat(80) @(negedge pclk);
    read_check('h38,23); read_check('h3c,13); read_check('h40,7);
    read_check('h44,5); read_check('h48,29); read_check('h4c,3);
    read_check('h30,1); read_check('h20,280); read_check('h24,255); read_check('h28,350);
    // Common SW0 reset returns counters to zero. No software clear side effect.
    @(negedge pclk); presetn=0; pixel_resetn=0; diag_events=0;
    repeat(10) @(negedge pclk); presetn=1; pixel_resetn=1;
    repeat(10) @(negedge pclk);
    for(integer addr='h38;addr<='h4c;addr+=4) read_check(addr,0);
    $display("tb_video_diag PASS: %0d checks, independent CDC events, AXI handshakes, read-only map, idle/reset",checks);
    $finish;
end
endmodule
