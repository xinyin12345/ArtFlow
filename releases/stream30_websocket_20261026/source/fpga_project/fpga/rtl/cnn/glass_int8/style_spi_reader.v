// Read-only SPI mode 0: command 03h, 24-bit address, no write/erase commands.
// SCK = clk / 16. Input is captured on the rising edge, 8 clocks after falling.
module style_spi_reader(
 input clk,rst_n,start,input [23:0] address,input [14:0] length,
 output reg busy,done,byte_valid,output reg [7:0] byte_data,
 output reg flash_cs_n,flash_sck,flash_mosi,input flash_miso
);
reg [3:0] phase;reg [31:0] command;reg [5:0] command_bits;
reg [2:0] bit_count;reg [7:0] shift;reg [14:0] remaining;
reg finishing;
reg pending;reg [3:0] cooldown;
// Synchronize the return signal; at the sample strobe it has been stable for
// more than two cnn clocks. A post-route round-trip budget audits this margin.
(* async_reg="true" *) reg miso_meta,miso_sync;
always @(posedge clk or negedge rst_n)
 if(!rst_n)begin miso_meta<=1; miso_sync<=1; end
 else begin miso_meta<=flash_miso; miso_sync<=miso_meta; end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  busy<=0;done<=0;byte_valid<=0;byte_data<=0;flash_cs_n<=1;flash_sck<=0;flash_mosi<=0;
  phase<=0;command<=0;command_bits<=0;bit_count<=0;shift<=0;remaining<=0;finishing<=0;pending<=0;cooldown<=15;
 end else begin
  done<=0;byte_valid<=0;
  if(!busy)begin
   flash_cs_n<=1;flash_sck<=0;phase<=0;
   if(cooldown!=0)cooldown<=cooldown-1'b1;
   if(start)pending<=1;
   if(pending && cooldown==0)begin
    pending<=0;
    busy<=1;flash_cs_n<=0;command<={8'h03,address};command_bits<=32;
    flash_mosi<=0;remaining<=length;bit_count<=0;shift<=0;finishing<=0;
   end
  end else begin
   phase<=phase+1'b1;
   if(phase==7)begin
    flash_sck<=1;
    if(command_bits!=0)command_bits<=command_bits-1'b1;
    else begin
     shift<={shift[6:0],miso_sync};bit_count<=bit_count+1'b1;
     if(bit_count==7)begin
      byte_data<={shift[6:0],miso_sync};byte_valid<=1;remaining<=remaining-1'b1;
      if(remaining==1)finishing<=1;
     end
    end
   end
   if(phase==15)begin
    flash_sck<=0;
    if(finishing)begin busy<=0;done<=1;flash_cs_n<=1;flash_mosi<=0;cooldown<=15;end
    else if(command_bits!=0)begin command<={command[30:0],1'b0};flash_mosi<=command[30];end
    else flash_mosi<=0;
   end
  end
 end
end
endmodule
