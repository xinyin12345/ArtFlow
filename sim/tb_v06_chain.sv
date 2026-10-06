`timescale 1ns/1ps
// Real Gamma -> UI/OSD chain at full 1920x1080; key changes during DE.
module tb_v06_chain;
reg clk=0;always #5 clk=~clk;
reg rst=0,km=1,ko=1,cap=0,de=0,hs=0,vs=0;
reg [23:0] rgb=0;
wire gd,gh,gv,od,oh,ov;
wire [23:0] grgb,orgb;
wire [1:0] mode;wire osd,valid;wire [11:0] cf,df;
gamma_lut #(.LUT_FILE("./rtl/gamma_conrrection/gamma_2p2_8b.mem")) gamma (
 .i_pclk(clk),.i_rstn(rst),.i_bypass(1'b0),.i_valid(de),.i_hs(hs),.i_vs(vs),
 .i_red(rgb[23:16]),.i_green(rgb[15:8]),.i_blue(rgb[7:0]),
 .o_red(grgb[23:16]),.o_green(grgb[15:8]),.o_blue(grgb[7:0]),.o_valid(gd),.o_hs(gh),.o_vs(gv));
artflow_ui #(.CLOCK_HZ(100000),.DEBOUNCE_CYCLES(4)) ui
 (clk,rst,km,ko,cap,gv,mode,osd,cf,df,valid);
artflow_osd overlay(clk,rst,mode,osd,cf,df,valid,gd,gh,gv,grgb,od,oh,ov,orgb);
reg [7:0] lut[0:255];
reg [2:0] timing[0:3];reg [23:0] expected[0:3];reg compare_pixel[0:3];
integer frame,x,y,n,checked=0,active=0;
reg [1:0] lastmode=0;reg lastosd=1;reg [24:0] lastfps=0;reg lastvs=0;
reg commit_allowed;
// Visible controls/statistics may change only on the Gamma VS edge.
always @(posedge clk) begin
 commit_allowed=gv && !lastvs;
 lastvs=gv;
 #1;
 if(rst && !commit_allowed && {mode,osd,cf,df,valid}!=={lastmode,lastosd,lastfps})
   $fatal(1,"Visible UI changed outside frame boundary");
 lastmode=mode;lastosd=osd;lastfps={cf,df,valid};
end
function [23:0] bar(input integer px);
 case(px/240)
 0:bar=24'hffffff;1:bar=24'hffff00;2:bar=24'h00ffff;3:bar=24'h00ff00;
 4:bar=24'hff00ff;5:bar=24'hff0000;6:bar=24'h0000ff;default:bar=0;
 endcase
endfunction
task drive(input bit d,h,v,input integer px,py);
reg [23:0] exp,c;
begin
 @(negedge clk);de=d;hs=h;vs=v;c={8'(px+frame),8'(py),8'(px^py)};rgb=c;
 exp={lut[c[23:16]],lut[c[15:8]],lut[c[7:0]]};
 if(frame==1 && px>=960 || frame==2 && px<960)exp=0;
 if(frame==3)exp=bar(px);
 if(!d)exp=0;
 for(n=3;n>0;n--)begin timing[n]=timing[n-1];expected[n]=expected[n-1];compare_pixel[n]=compare_pixel[n-1];end
 timing[0]={d,h,v};expected[0]=exp;
 compare_pixel[0]=!d || frame>=2 || !(px>=32 && px<928 && py>=32 && py<96);
 @(posedge clk);#2;
 if({od,oh,ov}!==timing[3])$fatal(1,"Chain timing mismatch");
 if(compare_pixel[3])begin
  checked++;
  if(orgb!==expected[3])$fatal(1,"Chain pixel mismatch frame=%0d x=%0d y=%0d got=%h expected=%h",frame,px,py,orgb,expected[3]);
 end
 if(od)begin active++;if($isunknown(orgb))$fatal(1,"Unknown output");end
end endtask
initial begin
 $readmemh("./rtl/gamma_conrrection/gamma_2p2_8b.mem",lut);
 for(n=0;n<4;n++)begin timing[n]=0;expected[n]=0;compare_pixel[n]=1;end
 repeat(4)@(negedge clk);rst=1;
 for(frame=0;frame<4;frame++)begin
  repeat(12)drive(0,1,1,0,0);repeat(12)drive(0,0,0,0,0);
  if(mode!==2'(frame) || osd!==(frame<2))$fatal(1,"Frame mode/OSD commit");
  for(y=0;y<1080;y++)begin
   repeat(4)drive(0,1,0,0,y);
   for(x=0;x<1920;x++)begin
    if(y==120 && x==70 && frame<3)km=0;
    if(y==120 && x==110)km=1;
    if(frame==1 && y==300 && x==70)ko=0;
    if(y==300 && x==110)ko=1;
    if(y==500 && x==50)cap=~cap;
    drive(1,0,0,x,y);
   end
   repeat(4)drive(0,0,0,0,y);
  end
 end
 repeat(5)drive(0,0,0,0,0);
 if(active!=4*1920*1080)$fatal(1,"Missing active pixels");
 @(negedge clk);rst=0;@(posedge clk);#2;
 if({od,oh,ov,orgb}!==0)$fatal(1,"Chain reset");
 $display("tb_v06_chain PASS active=%0d checked=%0d",active,checked);$finish;
end
initial begin #100000000;$fatal(1,"Chain timeout");end
endmodule
