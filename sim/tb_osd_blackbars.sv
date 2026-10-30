`timescale 1ns/1ps
module tb_osd_blackbars;
reg clk=0;always #5 clk=~clk;
reg rst_n=0;reg [1:0] mode=0;reg en=1;reg [2:0] style=0;reg sv=1;
reg [11:0] cap=12'h030,outfps=12'h030;reg fv=1;
reg de=0,hs=0,vs=0;reg [23:0] rgb=0;
wire ode,ohs,ovs;wire [23:0] orgb;
artflow_osd dut(.clk(clk),.rst_n(rst_n),.mode(mode),.osd_enable(en),.style_id(style),.style_valid(sv),
 .capture_bcd(cap),.display_bcd(outfps),.fps_valid(fv),.i_de(de),.i_hs(hs),.i_vs(vs),.i_rgb(rgb),
 .o_de(ode),.o_hs(ohs),.o_vs(ovs),.o_rgb(orgb));
integer f,frame,px,py,cycles=0,pixels=0;string dir,name;
reg pd=0,ph=0,pv=0;reg [23:0] prgb=0;
task tick;
 begin
  @(posedge clk);#1;
  if({ode,ohs,ovs}!=={pd,ph,pv})$fatal(1,"Timing pipeline mismatch cycle %0d",cycles);
  if(!ode && orgb!==0)$fatal(1,"Blank RGB");
  if(ode)begin
   $fwrite(f,"%c%c%c",orgb[23:16],orgb[15:8],orgb[7:0]);pixels++;
   if(!en && orgb!==prgb)$fatal(1,"Disabled pixel pipeline mismatch");
  end
  pd=de;ph=hs;pv=vs;prgb=rgb;cycles++;
  @(negedge clk);
 end
endtask
initial begin
 if(!$value$plusargs("DIR=%s",dir))$fatal(1,"DIR required");
 repeat(3)@(negedge clk);rst_n=1;
 for(frame=0;frame<13;frame++)begin
  style=frame%8;mode=frame==8?1:frame==9?2:0;en=frame!=10;fv=frame!=11;sv=frame!=12;
  case(frame) 1:outfps=12'h029;2:outfps=12'h031;3:outfps=0;4:outfps=12'h999;default:outfps=12'h030;endcase
  case(frame) 5:cap=12'h029;6:cap=0;7:cap=12'h999;default:cap=12'h030;endcase
  name=$sformatf("%s/frame_%02d.ppm",dir,frame);f=$fopen(name,"wb");
  $fwrite(f,"P6\n1920 1080\n255\n");pixels=0;
  vs=1;hs=1;repeat(5)tick();vs=0;hs=0;repeat(4)tick();
  for(py=0;py<1080;py++)begin
   for(px=0;px<1920;px++)begin
    de=1;rgb={8'(px),8'(py),8'(px^py)};
    tick();
   end
   de=0;rgb=24'haabbcc;hs=1;repeat(3)tick();hs=0;repeat(2)tick();
  end
  repeat(3)tick();
  if(pixels!=1920*1080)$fatal(1,"Pixel count %0d",pixels);
  $fclose(f);$display("FRAME %0d PASS pixels=%0d",frame,pixels);
 end
 $display("PASS OSD frames=13 timing_cycles=%0d",cycles);$finish;
end
endmodule
