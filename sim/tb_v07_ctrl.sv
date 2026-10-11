`timescale 1ns/1ps
module tb_v07_ctrl;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,psel=0,penable=0,pwrite=0;
reg [15:0] paddr=0;reg [31:0] pwdata=0;wire [31:0] prdata;wire pready,pslverror;
reg original_valid=1;reg [1:0] original_bank=0;reg [31:0] original_seq=1;
wire source_locked;wire [1:0] source_bank;reg display_active=0;reg [1:0] display_bank=0;
wire styled_valid;wire [1:0] styled_bank;wire start;wire [31:0] src_addr,dst_addr;
reg busy=0,done=0,failed=0;wire irq,process_toggle;wire [31:0] completed,skipped,errors;
artflow_accel_ctrl dut(.*,.cycles(32'd123));
task write_reg(input [15:0] a,input [31:0] d,input bit error_expected);
 @(negedge clk);paddr=a;pwdata=d;psel=1;pwrite=1;
 @(negedge clk);penable=1;
 @(negedge clk);if(!pready || pslverror!==error_expected) $fatal(1,"APB decode %x",a);
 psel=0;penable=0;pwrite=0;
endtask
task finish_job(input bit bad);
 @(negedge clk);busy=1;
 repeat(12) @(negedge clk);
 if(!source_locked || styled_valid && dut.job_bank==styled_bank) $fatal(1,"Lost ownership");
 failed=bad;busy=0;done=1;
 @(negedge clk);done=0;
 if(!irq || source_locked) $fatal(1,"Completion IRQ/lock");
endtask
initial begin
 repeat(10) @(negedge clk);
 if(pready!==0) $fatal(1,"APB must wait while video is in startup reset");
 rst_n=1;
 write_reg(16'h90,1,1);write_reg(16'h84,4,1);write_reg(16'hac,0,1);
 if(start || completed!=0) $fatal(1,"Invalid APB side effect");
 write_reg(16'h84,3,0);wait(start);#1;
 if(src_addr!=0 || !source_locked || source_bank!=0) $fatal(1,"Source claim");
 finish_job(0);
 if(completed!=1 || !styled_valid || errors!=0 || skipped!=0) $fatal(1,"First publish");
 display_active=1;display_bank=styled_bank;original_seq=4;original_bank=1;
 repeat(30) @(negedge clk);
 if(start || !irq || completed!=1) $fatal(1,"IRQ must hold until W1C");
 write_reg(16'h8c,1,0);write_reg(16'h84,3,0);wait(start);#1;
 if(skipped!=2 || source_bank!=1 || dut.job_bank==display_bank) $fatal(1,"Skip/lock allocation");
 finish_job(1);
 if(completed!=1 || errors!=1 || styled_bank!=display_bank) $fatal(1,"Failed frame published");
 original_seq=5;original_bank=2;
 write_reg(16'h8c,1,0);write_reg(16'h84,3,0);wait(start);finish_job(0);
 if(completed!=2 || errors!=1 || skipped!=2 || styled_bank==display_bank) $fatal(1,"Recovery publish");
 $display("tb_v07_ctrl PASS: APB errors, source lock, styled lock, IRQ W1C, skip count, failed-frame rejection/recovery");$finish;
end
initial begin #100000;$fatal(1,"control timeout");end
endmodule
