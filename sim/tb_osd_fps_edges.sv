`timescale 1ns/1ps
module tb_osd_fps_edges;
reg clk=0; always #5 clk=~clk;
reg rst=0,cap=0,dt=0;
wire [11:0] cf,df;wire valid;
artflow_fps #(.CLOCK_HZ(4096)) dut(clk,rst,cap,dt,cf,df,valid);
integer cycle,expected_cap=0,expected_out=0,checks=0;
reg m=0,s=0,p=0;
function integer decimal(input [11:0] b);decimal=b[11:8]*100+b[7:4]*10+b[3:0];endfunction
initial begin
    repeat(3) @(negedge clk);rst=1;
    // Independent 3-stage CDC/event model, including exact sample boundary.
    for(cycle=0;cycle<4096*8;cycle++) begin
        if(cycle<4096 && cycle%137==17)cap=~cap;
        if(cycle>=8192 && cycle<12288 && cycle%3==0)cap=~cap;
        dt=(cycle<4096 && cycle%67==3) || (cycle>=8192 && cycle<12288);
        if(cycle>=4*4096)begin
          // Offset toggles so CDC-delayed events remain inside each window.
          if((cycle/4096==4 && cycle%4096<29*20 && cycle%20==0) ||
             (cycle/4096==5 && cycle%4096<30*20 && cycle%20==0) ||
             (cycle/4096==6 && cycle%4096<31*20 && cycle%20==0))cap=~cap;
          dt=0;
        end
        if(s!=p)expected_cap++;if(dt)expected_out++;
        p=s;s=m;m=cap;
        @(posedge clk);#1;
        if(cycle%4096==4095) begin
            checks++;
            if(!valid || decimal(cf)!=(expected_cap>999?999:expected_cap) ||
               decimal(df)!=(expected_out>999?999:expected_out))
                $fatal(1,"FPS sample %0d got %h/%h expected %0d/%0d",checks,cf,df,expected_cap,expected_out);
            expected_cap=0;expected_out=0;
        end
        @(negedge clk);
    end
    rst=0;@(posedge clk);#1;if(valid || cf || df)$fatal(1,"FPS reset");
    $display("tb_osd_fps_edges PASS windows=%0d",checks);$finish;
end
endmodule
