`timescale 1ns/1ps
module tb_style_loader_extended;
reg clk=0;always #3.5 clk=~clk;
reg rst_n=0,press=0,job=0,missing=0;
wire bank,cv,cb,loading,ready,cs,sck,mosi,flash_data;
wire [4:0] active,requested,job_style;wire [15:0] errors;
wire [1:0] kind;wire [9:0] addr;wire [575:0] data;
style_bank_controller dut(clk,rst_n,press,job,bank,active,requested,job_style,cv,cb,kind,addr,data,loading,ready,errors,cs,sck,mosi,missing?1'b1:flash_data);
spi_model_archive flash(cs,sck,mosi,flash_data);
integer writes=0,offset,size,loads=0;reg [575:0] expected;reg [7:0] saved;
reg old_bank;reg [4:0] old_active;reg previous_job=0;
always @(posedge clk)begin
 previous_job<=job;
 if(rst_n && cv)begin
  if(cb==bank)$fatal(1,"active bank write");
  size=kind==0?72:kind==1?10:4;
  offset=dut.loaded_style*16384+32+(kind==0?addr*72:kind==1?9216+addr*10:14336+addr*4);
  expected=0;for(integer b=0;b<size;b=b+1)expected[b*8+:8]=missing?8'hff:flash.memory[offset+b];
  if(data!==expected)$fatal(1,"load payload mismatch style=%0d kind=%0d addr=%0d",dut.loaded_style,kind,addr);
  writes=writes+1;
 end
end
// Sample after nonblocking updates: state cannot change without a job boundary.
always @(negedge clk)begin
 if(rst_n && (bank!==old_bank || active!==old_active) && !previous_job)$fatal(1,"non-boundary commit");
 old_bank=bank;old_active=active;
end
task request;begin @(negedge clk);press=1;@(negedge clk);press=0;end endtask
task launch;begin @(negedge clk);job=1;@(negedge clk);job=0;end endtask
task select_ready(input integer id);begin
 wait(ready);if(job_style!=id || requested!=id)$fatal(1,"wrong ready model");
 launch();if(active!=id)$fatal(1,"wrong committed model");
 loads=loads+1;$display("STYLE CYCLE PASS id=%0d",id);$fflush();
end endtask
initial begin
 repeat(8)@(negedge clk);rst_n=1;
 // Load and commit every slot, including 15->16 and wrap from 18 back to original glass.
 for(integer id=1;id<=19;id=id+1)begin
  writes=0;request();select_ready(id%19);
  if(writes!=668 || errors!=0)$fatal(1,"incomplete parameter package");
 end
 if(active!=0 || requested!=0)$fatal(1,"wrap failed");
 // Request another style during a load. The stale bank must never commit.
 request();wait(loading);repeat(1000)@(negedge clk);request();
 repeat(3)begin repeat(400000)@(negedge clk);launch();if(active!=0)$fatal(1,"stale load committed");end
 wait(dut.loaded_style==2);select_ready(2);
 $display("RAPID REQUEST REPLACEMENT PASS");$fflush();
 // A valid payload with an invalid format header must be rejected.
 saved=flash.memory[3*16384];flash.memory[3*16384]=0;
 request();wait(loading);wait(!loading);repeat(4)@(negedge clk);launch();
 if(active!=2 || ready || errors!=1)$fatal(1,"invalid header handling");
 flash.memory[3*16384]=saved;
 $display("HEADER REJECTION PASS");$fflush();
 // Disconnected/erased Flash reads all ones; it must retain the running model.
 missing=1;request();wait(loading);wait(!loading);repeat(4)@(negedge clk);launch();
 if(active!=2 || ready || errors!=2)$fatal(1,"missing Flash handling");
 missing=0;request();select_ready(5);
 if(errors!=2)$fatal(1,"error counter changed incorrectly");
 $display("MISSING FLASH RECOVERY PASS");
 $display("tb_style_loader_extended PASS loads=%0d",loads);$finish;
end
initial begin #400000000;$fatal(1,"timeout byte=%0d style=%0d",dut.byte_index,requested);end
endmodule
