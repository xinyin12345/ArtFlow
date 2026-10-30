`timescale 1ns/1ps
module tb_osd_output_telemetry;
reg clk=0;always #5 clk=~clk;
reg rst=0,cap=0,vs=0,de=0;reg [23:0] rgb=0;
wire ode,ohs,ovs;wire [23:0] orgb;wire [1:0] mode;
wire en,valid;wire [11:0] cf,ofps;
artflow_ui #(.CLOCK_HZ(1000),.DEBOUNCE_CYCLES(4)) ui
 (clk,rst,1'b1,1'b1,cap,ovs,mode,en,cf,ofps,valid);
artflow_osd osd(.clk(clk),.rst_n(rst),.mode(mode),.osd_enable(en),
 .style_id(3'd0),.style_valid(1'b1),.capture_bcd(cf),.display_bcd(ofps),.fps_valid(valid),
 .i_de(de),.i_hs(1'b0),.i_vs(vs),.i_rgb(rgb),.o_de(ode),.o_hs(ohs),.o_vs(ovs),.o_rgb(orgb));
integer window,i,nout,ncap,observed=0,checks=0;reg prev_vs=0;reg [11:0] expected_out,expected_cap;
function [11:0] bcd(input integer v);bcd=((v/100)<<8)|(((v/10)%10)<<4)|(v%10);endfunction
task check(input bit good,input string why);begin checks++;if(!good)$fatal(1,"%s window=%0d cycle=%0d",why,window,i);end endtask
always @(posedge clk) if(rst)begin
 if(ovs && !prev_vs)observed++;
 prev_vs=ovs;
end
initial begin
 repeat(3)@(negedge clk);rst=1;
 for(window=0;window<8;window++)begin
  case(window)0:nout=29;1:nout=30;2:nout=31;3:nout=30;4,5,7:nout=0;6:nout=30;endcase
  case(window)0:ncap=30;1:ncap=29;2:ncap=31;3,4,6:ncap=30;5,7:ncap=0;endcase
  observed=0;
  for(i=0;i<1000;i++)begin
   // VS is deliberately three cycles wide: count a real edge only once.
   vs=i>=10 && ((i-10)/20)<nout && ((i-10)%20)<3;
   if(i>=10 && ((i-10)/20)<ncap && ((i-10)%20)==0)cap=~cap;
   de=!vs;
   // Frozen image data in window 3; physical output timing continues unchanged.
   rgb=window==3?24'h123456:{12'(window),12'(i)};
   @(posedge clk);#1;
   if(window>0 && i==50 && nout>0)begin
    check(valid && ofps==expected_out && cf==expected_cap,"frame-committed measured telemetry");
   end
   if(window==5 && i==2)check(ofps==0 && valid,"stopped VS publishes zero without a new frame");
   @(negedge clk);
  end
  expected_out=bcd(nout);expected_cap=bcd(ncap);
  check(ui.out_sample==expected_out,"independent one-second OUT sample");
  check(ui.cap_sample==expected_cap,"independent one-second CAP sample");
  check(observed==nout,"actual OSD-to-TMDS VS edges");
 end
 // End a complete stopped window and allow the public UI snapshot to update.
 vs=0;de=0;repeat(3)begin @(posedge clk);#1;@(negedge clk);end
 check(ofps==0 && cf==0 && valid,"public counters zero while output stopped");
 $display("PASS output_telemetry windows=8 checks=%0d frozen_OUT=30 stopped_OUT=0 targets=29/30/31",checks);$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
