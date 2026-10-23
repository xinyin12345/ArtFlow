// All events are in cnn_clk. A loaded bank can become active ONLY at job_start.
// Missing/invalid Flash never blocks video: keep computing the previous model.
module style_bank_controller #(parameter STYLE_COUNT=19, parameter [23:0] FLASH_BASE=24'h400000)(
 input clk,rst_n,key_press,job_start,
 output reg active_bank,output reg [4:0] active_style,requested_style,
 output wire [4:0] job_style,
 output reg cfg_valid,cfg_bank,output reg [1:0] cfg_kind,
 output reg [9:0] cfg_addr,output wire [575:0] cfg_data,
 output loading,output reg ready,output reg [15:0] errors,
 output flash_cs_n,flash_sck,flash_mosi,input flash_miso
);
wire spi_busy,spi_done,byte_valid;wire [7:0] data;
reg spi_start,load_active,loaded_bank,blocked,header_bad;
reg [4:0] loaded_style;reg [14:0] byte_index;
reg [31:0] crc,expected_crc;
reg [575:0] word_buffer;reg [6:0] word_byte;reg [9:0] word_addr;reg [1:0] word_kind;
wire commit=ready && loaded_style==requested_style;
assign job_style=commit?loaded_style:active_style;
assign loading=load_active;
style_spi_reader reader(.clk(clk),.rst_n(rst_n),.start(spi_start),
 .address(FLASH_BASE+{5'd0,loaded_style,14'd0}),.length(15'd14480),
 .busy(spi_busy),.done(spi_done),.byte_valid(byte_valid),.byte_data(data),
 .flash_cs_n(flash_cs_n),.flash_sck(flash_sck),.flash_mosi(flash_mosi),.flash_miso(flash_miso));
function [31:0] crc_byte;input [31:0] c;input [7:0] d;reg [31:0] v;integer j;
 begin v=c^{24'd0,d};for(j=0;j<8;j=j+1)v=v[0]?(v>>1)^32'hedb88320:v>>1;crc_byte=v;end
endfunction
wire [6:0] last_byte=word_kind==0?71:word_kind==1?9:3;
wire [575:0] complete_word={data,word_buffer[575:8]};
assign cfg_data=cfg_kind==0?word_buffer:cfg_kind==1?{496'd0,word_buffer[575:496]}:{544'd0,word_buffer[575:544]};
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  active_bank<=0;active_style<=0;requested_style<=0;ready<=0;errors<=0;
  spi_start<=0;load_active<=0;loaded_bank<=1;loaded_style<=0;blocked<=0;
  cfg_valid<=0;cfg_bank<=1;cfg_kind<=0;cfg_addr<=0;
  byte_index<=0;crc<=32'hffffffff;expected_crc<=0;header_bad<=0;
  word_buffer<=0;word_byte<=0;word_addr<=0;word_kind<=0;
 end else begin
  spi_start<=0;cfg_valid<=0;
  if(key_press)begin requested_style<=requested_style==STYLE_COUNT-1?0:requested_style+1'b1;blocked<=0;end
  if(ready && loaded_style!=requested_style)ready<=0;
  if(job_start && commit)begin active_bank<=loaded_bank;active_style<=loaded_style;ready<=0;end
  if(!load_active && !ready && !blocked && requested_style!=active_style)begin
   loaded_style<=requested_style;loaded_bank<=~active_bank;cfg_bank<=~active_bank;
   spi_start<=1;load_active<=1;byte_index<=0;header_bad<=0;crc<=32'hffffffff;expected_crc<=0;
   word_buffer<=0;word_byte<=0;word_addr<=0;word_kind<=0;
  end
  if(load_active && byte_valid)begin
   byte_index<=byte_index+1'b1;
   if(byte_index<32)begin
    case(byte_index)
     0:if(data!=8'h41)header_bad<=1;
     1:if(data!=8'h46)header_bad<=1;
     2:if(data!=8'h53)header_bad<=1;
     3:if(data!=8'h4d)header_bad<=1;
     4:if(data!=1)header_bad<=1;
     5,6,7,9,10,11,14,15:if(data!=0)header_bad<=1;
     8:if(data!={3'd0,loaded_style})header_bad<=1;
     12:if(data!=8'h70)header_bad<=1; // 14448 = 0x3870
     13:if(data!=8'h38)header_bad<=1;
     16,17,18,19:expected_crc[(byte_index-16)*8+:8]<=data;
     default:;
    endcase
   end else begin
    crc<=crc_byte(crc,data);
    if(word_byte==last_byte)begin
     cfg_valid<=1;cfg_kind<=word_kind;cfg_addr<=word_addr;
     word_buffer<=complete_word;word_byte<=0;word_addr<=word_addr+1'b1;
     if((word_kind==0 && word_addr==127) || (word_kind==1 && word_addr==511))begin
      word_kind<=word_kind+1'b1;word_addr<=0;
     end
    end else begin word_buffer<=complete_word;word_byte<=word_byte+1'b1;end
   end
  end
  if(load_active && spi_done)begin
   load_active<=0;
   if(header_bad || byte_index!=14480 || (crc^32'hffffffff)!=expected_crc)begin
    errors<=errors+1'b1;blocked<=1;ready<=0;
   end else ready<=loaded_style==requested_style;
  end
 end
end
// synthesis translate_off
always @(posedge clk)if(rst_n && cfg_valid && cfg_bank==active_bank)$fatal(1,"loader wrote active bank");
initial if(STYLE_COUNT<1 || STYLE_COUNT>32)$fatal(1,"style count");
// synthesis translate_on
endmodule
