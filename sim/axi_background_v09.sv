`timescale 1ns/1ps
// Sustained competing 128-bit/64-beat video bursts on the ORIGINAL 100 MHz
// AXI clock: up to 256 MB/s reads + 64 MB/s writes. Video keeps burst priority.
// Traffic touches only bank 2, outside the test input/result/CNN scratch.
module axi_background_v09 #(parameter ENABLE=0)(
 input clk,rst_n,
 output [31:0] awaddr,output [7:0] awlen,output awvalid,input awready,
 output [127:0] wdata,output [15:0] wstrb,output wvalid,wlast,input wready,
 input bvalid,input [1:0] bresp,output bready,
 output [31:0] araddr,output [7:0] arlen,output arvalid,input arready,
 input [127:0] rdata,input rvalid,rlast,input [1:0] rresp,output rready
);
integer rt=0,wt=0,rs=0,ws=0,beat=0;
integer read_beats=0,write_beats=0;
assign awaddr=32'h00800000;assign araddr=32'h00800000;
assign awlen=63;assign arlen=63;
assign awvalid=ENABLE && ws==1;assign arvalid=ENABLE && rs==1;
assign wvalid=ENABLE && ws==2;assign wlast=beat==63;
assign wstrb=16'hffff;assign wdata={4{32'h20406080}};
assign bready=ENABLE && ws==3;assign rready=ENABLE && rs==2;
always @(posedge clk) begin
 if(!rst_n) begin rt<=0;wt<=0;rs<=0;ws<=0;beat<=0;read_beats<=0;write_beats<=0;end
 else if(ENABLE) begin
  if(rt>0)rt<=rt-1;if(wt>0)wt<=wt-1;
  case(rs)
   0:if(rt==0)begin rs<=1;rt<=399;end
   1:if(arready)rs<=2;
   2:if(rvalid)begin read_beats<=read_beats+1;if(rresp!=0)$fatal(1,"Background R error");if(rlast)rs<=0;end
  endcase
  case(ws)
   0:if(wt==0)begin ws<=1;wt<=1599;beat<=0;end
   1:if(awready)ws<=2;
   2:if(wready)begin write_beats<=write_beats+1;if(wlast)ws<=3;else beat<=beat+1;end
   3:if(bvalid)begin if(bresp!=0)$fatal(1,"Background B error");ws<=0;end
  endcase
 end
end
endmodule
