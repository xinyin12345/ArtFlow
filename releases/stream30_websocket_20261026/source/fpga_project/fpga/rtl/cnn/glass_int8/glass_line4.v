// Four interleaved 64-bit BRAM banks: return four consecutive feature words.
// Capacity and word values are unchanged; unused tail reads are clamped.
module glass_line4 #(parameter CAP=3360)(
 input clk,we,input [12:0] wa,input [63:0] wd,
 input [12:0] ra,output reg [255:0] q
);
localparam DEPTH=(CAP+3)/4;
reg [1:0] rotation;
wire [255:0] raw;
genvar b;
generate for(b=0;b<4;b=b+1)begin:bank
 reg [63:0] ram[0:DEPTH-1],rd;
 wire [12:0] a=(ra>>2)+(b<ra[1:0]);
 always @(posedge clk)begin
  if(we && wa[1:0]==b)ram[wa>>2]<=wd;
  rd<=ram[a<DEPTH?a:13'd0];
 end
 assign raw[b*64+:64]=rd;
end endgenerate
always @(posedge clk)rotation<=ra[1:0];
always @*case(rotation)
 0:q=raw;
 1:q={raw[63:0],raw[255:64]};
 2:q={raw[127:0],raw[255:128]};
 3:q={raw[191:0],raw[255:192]};
endcase
endmodule
