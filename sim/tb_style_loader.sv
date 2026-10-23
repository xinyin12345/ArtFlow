`timescale 1ns/1ps
module tb_style_loader;
reg clk=0;always #3.5 clk=~clk;
reg rst_n=0,press=0,job=0;wire bank,cv,cb,loading,ready,cs,sck,mosi,miso;
wire [4:0] active,requested,job_style;wire [15:0] errors;
wire [1:0] kind;wire [9:0] addr;wire [575:0] data;
style_bank_controller dut(clk,rst_n,press,job,bank,active,requested,job_style,cv,cb,kind,addr,data,loading,ready,errors,cs,sck,mosi,miso);
spi_model_archive flash(cs,sck,mosi,miso);
integer writes=0;integer offset,size;reg [575:0] expected;reg lastbank;integer commits=0;
always @(posedge clk)if(rst_n)begin
 if(cv)begin
  if(cb==bank)$fatal(1,"active bank write");
  size=kind==0?72:kind==1?10:4;
  offset=dut.loaded_style*16384+32+(kind==0?addr*72:kind==1?9216+addr*10:14336+addr*4);
  expected=0;for(integer b=0;b<size;b=b+1)expected[b*8+:8]=flash.memory[offset+b];
  if(data!==expected)$fatal(1,"loader mismatch kind=%0d addr=%0d got=%h want=%h",kind,addr,data,expected);
  writes=writes+1;
 end
end
task request;begin @(negedge clk);press=1;@(negedge clk);press=0;end endtask
task launch;begin @(negedge clk);job=1;@(negedge clk);job=0;end endtask
initial begin
 repeat(8)@(negedge clk);rst_n=1;request();wait(loading);
 repeat(3)begin repeat(400000)@(negedge clk);launch();if(active!=0)$fatal(1,"premature commit");end
 wait(ready);if(writes!=668 || errors!=0)$fatal(1,"wrong load status");
 if(active!=0 || job_style!=1)$fatal(1,"must wait for boundary");launch();
 if(active!=1 || !bank)$fatal(1,"commit failed");
 $display("LOAD PASS style=1 writes=%0d",writes);$fflush();
 // Corrupt one byte without changing CRC. The next bank must not become live.
 flash.memory[2*16384+48]=flash.memory[2*16384+48]^8'h01;
 writes=0;request();wait(loading);wait(!loading);repeat(4)@(negedge clk);
 if(ready || errors!=1 || active!=1)$fatal(1,"CRC failure handling");launch();
 if(active!=1)$fatal(1,"bad bank committed");$display("CRC REJECTION PASS");$fflush();
 // A fresh key request can recover to another valid model.
 writes=0;request();wait(ready);launch();if(active!=3 || bank!=0 || errors!=1)$fatal(1,"recovery failed");
 $display("RECOVERY PASS style=3");$display("tb_style_loader PASS");$finish;
end
initial begin #100000000;$fatal(1,"timeout byte=%0d",dut.byte_index);end
endmodule
