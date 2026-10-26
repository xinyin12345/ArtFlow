`timescale 1ns/1ps
module tb_p1_control;
reg clk=0,rst_n=0;always #5 clk=~clk;
reg [15:0] paddr=0;reg psel=0,penable=0,pwrite=0;reg [31:0] pwdata=0;wire [31:0] prdata;wire pready,pslverror;
reg original_valid=1;reg [1:0] original_bank=1,display_bank=0;reg [31:0] original_seq=1;reg display_active=0,busy=0,done=0,failed=0,source_consumed=0,retire_ack=0;reg [4:0] requested_style=0,completed_style=0;
wire source_locked,styled_valid,start,irq,process_toggle,freeze_valid,freeze_busy;wire [1:0] source_bank,styled_bank,freeze_original_bank;wire [31:0] src_addr,dst_addr,completed,skipped,errors;
artflow_accel_ctrl #(.INTERACT(1),.EARLY_RELEASE(1),.SNAPSHOT_TIMEOUT(100)) dut(.*,.cycles(32'd123));
task tick(input integer n);repeat(n) @(negedge clk);endtask
task wr(input [15:0] a,input [31:0] d);@(negedge clk);paddr=a;pwdata=d;psel=1;pwrite=1;@(negedge clk);penable=1;@(posedge clk);if(pslverror)$fatal(1,"APB error");@(negedge clk);psel=0;penable=0;pwrite=0;endtask
task arm;wr('h8c,1);wr('h84,3);endtask
task finish_job(input bit err);@(negedge clk);done=1;failed=err;busy=0;tick(1);done=0;tick(1);endtask
task launch_pair;original_valid=0;wr('hc0,1);arm();original_seq=original_seq+1;original_valid=1;wait(start);@(negedge clk);busy=1;source_consumed=1;tick(1);source_consumed=0;if(!source_locked || !freeze_busy || freeze_valid)$fatal(1,"pair PRE released source");endtask
integer scenarios=0;
initial begin
 tick(4);rst_n=1;tick(2);
 // Live mode retains original early release and completion accounting.
 arm();wait(start);tick(1);busy=1;source_consumed=1;tick(1);source_consumed=0;if(source_locked)$fatal(1,"live early release lost");finish_job(0);scenarios++;
 for(integer k=0;k<30;k++) begin
  launch_pair();completed_style=k%15;tick(8);if(freeze_valid)$fatal(1,"published before done");finish_job(0);
  if(!freeze_valid || !source_locked || dut.pair_seq!=original_seq || dut.pair_style!=completed_style)$fatal(1,"pair metadata");
  arm();tick(110);if(start || !freeze_valid || !source_locked)$fatal(1,"frozen relaunch or timeout");
  if(k%2)begin requested_style=requested_style==14?0:requested_style+1;tick(2);end else wr('hc0,2);
  tick(3);if(freeze_valid || !source_locked || !freeze_busy)$fatal(1,"retire released before display ACK");
  retire_ack=1;tick(1);retire_ack=0;tick(1);if(source_locked || freeze_busy)$fatal(1,"retire ACK");scenarios++;
 end
 // Cancel after PRE, keep source until actual final completion.
 launch_pair();wr('hc0,2);tick(12);if(!source_locked || freeze_valid)$fatal(1,"cancel lost pin");finish_job(0);if(freeze_busy || source_locked)$fatal(1,"cancel drain");scenarios++;
 launch_pair();tick(110);if(dut.interaction_state!=5 || !source_locked)$fatal(1,"timeout drain");finish_job(0);if(freeze_busy || source_locked)$fatal(1,"timeout complete");scenarios++;
 launch_pair();finish_job(1);if(freeze_valid || source_locked || errors!=1)$fatal(1,"failed job publication");scenarios++;
 original_valid=0;wr('hc0,1);wr('hc0,2);tick(2);if(freeze_busy)$fatal(1,"wait cancel");scenarios++;
 wr('hc0,1);tick(110);if(freeze_busy || dut.exit_reason!=3)$fatal(1,"wait timeout");scenarios++;
 $display("TEST PASS p1_control scenarios=%0d completed=%0d errors=%0d",scenarios,completed,errors);$finish;
end
initial begin #1000000;$fatal(1,"watchdog");end
endmodule
