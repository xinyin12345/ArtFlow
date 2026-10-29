`timescale 1ns/1ps
module spi_model_archive(input cs_n,sck,mosi,output miso);
reg [7:0] memory[0:131071];
integer command_bits=0,read_bit=0;reg [31:0] command=0;reg [23:0] address=0;
initial $readmemh("network/styles8/models8_parameters.hex",memory);
assign #(7) miso=(!cs_n && command_bits==32 && address>=24'h400000 && address<24'h420000)?memory[address-24'h400000][7-read_bit]:1'b1;
always @(posedge cs_n)begin command_bits=0;read_bit=0;command=0;end
always @(posedge sck)if(!cs_n)begin
 if(command_bits<32)begin
  command={command[30:0],mosi};command_bits=command_bits+1;
  if(command_bits==32)begin
   if(command[31:24]!==8'h03)$fatal(1,"Flash command must be read only, got %h",command[31:24]);
   address=command[23:0];read_bit=0;
  end
 end else begin
  // Flash changes DO after the falling edge; defer internal pointer to it.
 end
end
reg read_started=0;
always @(posedge cs_n)read_started=0;
always @(negedge sck)if(!cs_n && command_bits==32)begin
 if(!read_started)read_started=1;
 else if(read_bit==7)begin read_bit=0;address=address+1'b1;end
 else read_bit=read_bit+1;
end
endmodule
