// 16 independently addressed byte banks, three line slots. No frame RAM on chip.
module shared_line #(parameter W=480)(input clk,input we,input [15:0] waddr,
 input [63:0] wdata,input [15:0] raddr,output [95:0] rdata);
 localparam DEPTH=(3*8*W+15)/16;
 wire [127:0] q;
 reg [3:0] rotate;
 always @(posedge clk)rotate<=raddr[3:0];
 genvar b,l;
 generate for(b=0;b<16;b=b+1)begin:bank
   reg [7:0] ram[0:DEPTH-1];reg [7:0] qr;
   wire [3:0] delta=b-raddr[3:0];
   wire [15:0] ra=raddr+delta;
   always @(posedge clk)begin
     if(we && waddr[3]==(b>=8))ram[waddr[15:4]]<=wdata[(b%8)*8+:8];
     qr<=ram[ra[15:4]];
   end
   assign q[b*8+:8]=qr;
 end
 for(l=0;l<12;l=l+1)begin:rot
   wire [3:0] sel=rotate+l;
   assign rdata[l*8+:8]=q[sel*8+:8];
 end endgenerate
endmodule
