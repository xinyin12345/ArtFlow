`timescale 1ns/1ps
module tb_v06_osd;
reg clk=0;always #5 clk=~clk;
reg rst=0,de=0,hs=0,vs=0,enable=1,valid=1;
reg [1:0] mode=0;
reg [23:0] rgb=0;
reg [11:0] cap=12'h030,outfps=12'h060;
wire od,oh,ov;wire [23:0] pixel;
artflow_osd dut(clk,rst,mode,enable,cap,outfps,valid,de,hs,vs,rgb,od,oh,ov,pixel);
integer fd,frame,x,y,cycle=0;
reg prev_de=0,prev_hs=0,prev_vs=0;
task drive(input bit d,h,v,input [23:0] color);
begin
    @(negedge clk);de=d;hs=h;vs=v;rgb=color;
    @(posedge clk);#1;
    if(od!==prev_de || oh!==prev_hs || ov!==prev_vs)$fatal(1,"OSD timing %0d",cycle);
    if(!od && pixel!==0)$fatal(1,"OSD blanking");
    if(od)$fwrite(fd,"%06x\n",pixel);
    prev_de=d;prev_hs=h;prev_vs=v;cycle++;
end endtask
initial begin
    repeat(3)@(negedge clk);rst=1;
    fd=$fopen("osd_pixels.hex","w");if(!fd)$fatal(1,"OSD output missing");
    for(frame=0;frame<9;frame++)begin
        mode=frame%4;enable=frame<4 || frame==8;valid=frame!=8;
        cap=frame==8?12'h999:12'h030;outfps=12'h060;
        drive(0,1,1,0);drive(0,0,1,0);drive(0,0,0,0);
        for(y=0;y<100;y++)begin
            drive(0,1,0,0);drive(0,0,0,0);
            for(x=0;x<1920;x++) drive(1,0,0,{8'(x+frame),8'(y*3),8'(x^y)});
            drive(0,0,0,0);drive(0,0,0,0);
        end
    end
    drive(0,0,0,0);$fclose(fd);
    @(negedge clk);rst=0;@(posedge clk);#1;
    if({od,oh,ov,pixel}!==0)$fatal(1,"OSD reset");
    $display("tb_v06_osd PASS frames=9 pixels=1728000 cycles=%0d",cycle);$finish;
end
initial begin #30000000;$fatal(1,"OSD timeout");end
endmodule
