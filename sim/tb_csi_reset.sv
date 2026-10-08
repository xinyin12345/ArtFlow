`timescale 1ns/1ps
module tb_csi_reset;
parameter integer CORE_HALF=5, BYTE_HALF=7, PIXEL_HALF=10;
reg core_clk=0, byte_clk=0, pixel_clk=0;
reg core_run=1, byte_run=0, pixel_run=1;
reg request_n=0;
wire core_reset_n, byte_reset_n, pixel_reset_n, phy_reset;
artflow_csi_reset dut(.*);
always #CORE_HALF if(core_run) core_clk=~core_clk; else core_clk=0;
// Model the HS clock becoming available only AFTER the core can enable it.
always #BYTE_HALF if(byte_run && core_reset_n) byte_clk=~byte_clk; else byte_clk=0;
always #PIXEL_HALF if(pixel_run) pixel_clk=~pixel_clk; else pixel_clk=0;
integer core_edges=0, byte_edges=0, pixel_edges=0, checks=0, resets=0;
time core_edge_time=0,byte_edge_time=0,pixel_edge_time=0;
always @(posedge core_clk or negedge request_n) begin
    if(!request_n) core_edges=0;
    else begin core_edges++; core_edge_time=$time; end
    #0.01;
    if(core_reset_n !== (request_n && core_edges>=3)) $fatal(1,"core release edge count request=%b edges=%0d out=%b shift=%b",request_n,core_edges,core_reset_n,dut.core_release);
    checks++;
end
always @(posedge byte_clk or negedge core_reset_n) begin
    if(!core_reset_n) byte_edges=0;
    else begin byte_edges++; byte_edge_time=$time; end
    #0.01;
    if(byte_reset_n !== (core_reset_n && byte_edges>=3)) $fatal(1,"byte release edge count");
    checks++;
end
always @(posedge pixel_clk or negedge byte_reset_n) begin
    if(!byte_reset_n) pixel_edges=0;
    else begin pixel_edges++; pixel_edge_time=$time; end
    #0.01;
    if(pixel_reset_n !== (byte_reset_n && pixel_edges>=3)) $fatal(1,"pixel release edge count");
    checks++;
end
always @(posedge core_reset_n) if($time!=core_edge_time) $fatal(1,"asynchronous core release");
always @(posedge byte_reset_n) if($time!=byte_edge_time) $fatal(1,"asynchronous byte release");
always @(posedge pixel_reset_n) if($time!=pixel_edge_time) $fatal(1,"asynchronous pixel release");
always @(negedge request_n) begin
    #1;
    if({core_reset_n,byte_reset_n,pixel_reset_n,phy_reset}!==4'b0001)
        $fatal(1,"reset assertion depended on a running clock");
    resets++;
end
task automatic await_ready;
    integer t;
    begin
        t=0;
        while(!pixel_reset_n && t<400) begin #1; t++; end
        if(!pixel_reset_n || !byte_reset_n || !core_reset_n || phy_reset)
            $fatal(1,"reset release deadlock");
    end
endtask
initial begin #200000; $fatal(1,"timeout"); end
initial begin
    // Boot with absent HS clock: core/PHY must release independently.
    #93; #0.123; request_n=1;
    #200;
    if(!core_reset_n || phy_reset || byte_reset_n || pixel_reset_n)
        $fatal(1,"stopped-byte startup order");
    byte_run=1; await_ready();
    // Discontinuous operation must not reassert reset between HS bursts.
    #71; byte_run=0; #199;
    if(!byte_reset_n || !pixel_reset_n) $fatal(1,"clock pause reset active video");
    // Software camera reset, with byte clock stopped.
    #0.137; request_n=0; #57; #0.123; request_n=1; #161;
    if(!core_reset_n || byte_reset_n || pixel_reset_n) $fatal(1,"camera init reset");
    byte_run=1; await_ready();
    // SW0/PLL loss with ALL clocks stopped. Reset must still assert.
    core_run=0;byte_run=0;pixel_run=0;#61;#0.137; request_n=0;#13;
    #0.123; request_n=1;#61;
    if({core_reset_n,byte_reset_n,pixel_reset_n,phy_reset}!==4'b0001)
        $fatal(1,"release with no clocks");
    core_run=1;byte_run=1;pixel_run=1;await_ready();
    // 64 varied reset phases and short release/bounce intervals.
    for(integer n=0;n<64;n++) begin
        #(11+(n*17)%59); #0.137; request_n=0;
        #(3+(n*7)%47); #0.123; request_n=1;
        if(n%3==0) begin #2; #0.137; request_n=0;#5;#0.123; request_n=1;end
        await_ready();
    end
    if(resets<66 || checks<500) $fatal(1,"insufficient exercised reset/clock cases");
    $display("tb_csi_reset PASS: checks=%0d reset_assertions=%0d",checks,resets);
    $finish;
end
endmodule
