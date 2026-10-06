`timescale 1ns/1ps
module tb_v06_ui;
reg clk=0; always #5 clk=~clk;
reg rst=0,km=1,ko=1,cap=0,vs=0;
wire [1:0] mode; wire osd,valid; wire [11:0] cf,df;
artflow_ui #(.CLOCK_HZ(100),.DEBOUNCE_CYCLES(4)) dut
    (clk,rst,km,ko,cap,vs,mode,osd,cf,df,valid);
integer checks=0;
task tick(input integer n); repeat(n) begin @(posedge clk); #1; end endtask
task check(input bit ok); begin checks++; if(!ok) $fatal(1,"UI check %0d",checks); end endtask
task frame; begin @(negedge clk);vs=1;tick(2);@(negedge clk);vs=0;tick(2);end endtask
initial begin
    tick(3);@(negedge clk);rst=1;tick(5); check(mode==0 && osd && !valid);
    // Reject short bounce, both press and release must qualify.
    @(negedge clk);km=0;tick(2);@(negedge clk);km=1;tick(8);frame();check(mode==0);
    @(negedge clk);km=0;tick(12);check(mode==0);frame();check(mode==1);
    tick(20);frame();check(mode==1); // held button does not repeat
    @(negedge clk);km=1;tick(2);@(negedge clk);km=0;tick(10);frame();check(mode==1);
    @(negedge clk);km=1;tick(10);
    repeat(3) begin @(negedge clk);km=0;tick(10);frame();@(negedge clk);km=1;tick(10);end
    check(mode==0); // modulo-four wrap
    @(negedge clk);ko=0;tick(10);check(osd);frame();check(!osd);
    tick(20);frame();check(!osd);
    @(negedge clk);ko=1;tick(10);@(negedge clk);ko=0;tick(10);frame();check(osd);
    // Reset while held clears visible and pending state.
    @(negedge clk);rst=0;tick(3);check(mode==0 && osd && !valid);
    $display("tb_v06_ui PASS checks=%0d",checks);$finish;
end
initial begin #100000;$fatal(1,"UI timeout");end
endmodule
