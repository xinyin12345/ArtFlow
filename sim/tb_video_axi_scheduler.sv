`timescale 1ns/1ps
module tb_video_axi_scheduler;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,wr=0,rd=0,wu=0,ru=0,wd=0,dd=0;
wire wg,dg;
video_axi_scheduler dut(clk,rst_n,wr,rd,wu,ru,wd,dd,wg,dg);
int writes=0,reads=0,owner=0,remaining=0,wait_w=0,wait_r=0;
int urgent_w=0,urgent_r=0,forced_w=0,forced_r=0;
always @(posedge clk) if(rst_n) begin
 if(wg&&dg)$fatal(1,"Double grant");
 if(owner!=0 && (wg||dg))$fatal(1,"Preempted live burst");
 if(wg||dg)begin
  if(wg&&!wr || dg&&!rd)$fatal(1,"Unrequested grant");
  if(wg)begin
   owner=1;writes++;wait_w=0;if(rd)wait_r++;else wait_r=0;
   if(wu&&!ru)urgent_w++;if(ru&&!wu)forced_w++;
  end else begin
   owner=2;reads++;wait_r=0;if(wr)wait_w++;else wait_w=0;
   if(ru&&!wu)urgent_r++;if(wu&&!ru)forced_r++;
  end
  if(wait_w>2 || wait_r>2)$fatal(1,"Peer starved for more than two grants");
  remaining=$urandom_range(1,40);
 end else if(owner!=0)begin
  if(wd||dd)owner=0;else remaining--;
 end
end
always @(negedge clk)begin
 wd=owner==1 && remaining==0;dd=owner==2 && remaining==0;
end
initial begin
 repeat(5)@(negedge clk);rst_n=1;wr=1;rd=1;ru=1;
 repeat(4000)@(negedge clk);
 ru=0;wu=1;repeat(4000)@(negedge clk);
 wu=0;repeat(2000)@(negedge clk);
 // Withdraw idle requests without changing in-flight ownership.
 repeat(3000)begin @(negedge clk);wr=$urandom_range(0,1);rd=$urandom_range(0,1);end
 @(negedge clk);rst_n=0;owner=0;wait_w=0;wait_r=0;
 repeat(4)@(negedge clk);rst_n=1;wr=1;rd=1;
 repeat(1000)@(negedge clk);
 if(writes<100 || reads<100 || urgent_w==0 || urgent_r==0 || forced_w==0 || forced_r==0)
  $fatal(1,"Scheduler coverage incomplete");
 $display("SCHEDULER writes=%0d reads=%0d urgent_w=%0d urgent_r=%0d forced_w=%0d forced_r=%0d",writes,reads,urgent_w,urgent_r,forced_w,forced_r);
 $display("=== tb_video_axi_scheduler PASS ===");$finish;
end
initial begin #2000000;$fatal(1,"Scheduler watchdog");end
endmodule
