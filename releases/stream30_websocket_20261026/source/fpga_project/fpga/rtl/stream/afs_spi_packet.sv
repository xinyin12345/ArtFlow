// AFS1 fixed-size mode-0 SPI packet engine. No hardware access from build scripts.
module afs_spi_packet #(parameter HALF_SLOW=38,HALF_FAST=3,WAIT_CYCLES=37125000)(
 input clk,rst_n,start,fast,input ready_async,miso,
 input [7:0] kind,input [31:0] session,sequence_id,offset,frame_crc,
 input [15:0] length,input [7:0] payload_byte,output payload_take,
 output reg busy=0,done=0,failed=0,output reg cs_n=1,sclk=0,mosi=0,
 output reg status_valid=0,status_enable=0,output reg [7:0] status_fps=1,
 output reg [31:0] status_session=0
);
 function automatic [31:0] crcbyte(input [31:0] c,input [7:0] b);
  reg [31:0] v;integer k;begin v=c^b;for(k=0;k<8;k=k+1)v=(v>>1)^(v[0]?32'hedb88320:0);crcbyte=v;end
 endfunction
 (* async_reg="true" *) reg ready_meta=0,ready_sync=0;
 (* async_reg="true" *) reg miso_meta=0,miso_sync=0;
 reg [26:0] wait_count=0;
 reg low_seen=1;reg [6:0] gap=0;
 reg [1:0] st=0;localparam IDLE=0,LOAD=1,SHIFT=2;
 reg [10:0] index=0;reg [2:0] bitno=7;reg [7:0] shift_tx=0,shift_rx=0;
 wire [7:0] rxbyte={shift_rx[6:0],miso_sync};
 reg [5:0] half=HALF_SLOW,divider=0;
 reg [31:0] txcrc=32'hffffffff,rxcrc=32'hffffffff;
 reg header_bad=0,pending_enable=0;reg [2:0] pending_fps=1;reg [31:0] pending_session=0;
 reg [7:0] value;
 always @* begin
  value=0;
  case(index)
   0:value=8'h41;1:value=8'h46;2:value=8'h53;3:value=8'h31;4:value=1;5:value=kind;
   8:value=session[7:0]; 9:value=session[15:8]; 10:value=session[23:16]; 11:value=session[31:24];
   12:value=sequence_id[7:0]; 13:value=sequence_id[15:8]; 14:value=sequence_id[23:16]; 15:value=sequence_id[31:24];
   16:value=offset[7:0]; 17:value=offset[15:8]; 18:value=offset[23:16]; 19:value=offset[31:24];
   20:value=length[7:0];21:value=length[15:8];22:value=160;24:value=90;
   1052:value=~txcrc[7:0]; 1053:value=~txcrc[15:8]; 1054:value=~txcrc[23:16]; 1055:value=~txcrc[31:24];
   default:if(index>=28&&index<28+length)begin
    if(kind==2)value=payload_byte;
    else if(kind==3)case(index)
     28:value=frame_crc[7:0];29:value=frame_crc[15:8];30:value=frame_crc[23:16];31:value=frame_crc[31:24];default:value=0;
    endcase
    else if(kind==5)value=index[7:0]-8'd28;
   end
  endcase
 end
 wire [31:0] crc_next=crcbyte(st==LOAD?txcrc:rxcrc,st==LOAD?value:rxbyte);
 assign payload_take=st==LOAD&&kind==2&&index>=28&&index<28+length;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin miso_meta<=0;miso_sync<=0;wait_count<=0;failed<=0;ready_meta<=0;ready_sync<=0;low_seen<=1;gap<=0;st<=IDLE;busy<=0;done<=0;cs_n<=1;sclk<=0;mosi<=0;index<=0;bitno<=7;divider<=0;;;;header_bad<=0;;;;;;status_valid<=0;;;;end
  else begin
   ready_meta<=ready_async;ready_sync<=ready_meta;miso_meta<=miso;miso_sync<=miso_meta;done<=0;failed<=0;status_valid<=0;
   if(!ready_sync)low_seen<=1;
   if(gap!=0)gap<=gap-1'b1;
   case(st)
    IDLE:if(start)begin wait_count<=0;busy<=1;index<=0;;;header_bad<=0;;;;;st<=LOAD;end
    LOAD:if(cs_n&&wait_count==WAIT_CYCLES-1)begin busy<=0;done<=1;failed<=1;st<=IDLE;end
    else if(!cs_n||(ready_sync&&low_seen&&gap==0))begin
     cs_n<=0;low_seen<=0;;mosi<=value[7];;bitno<=7;divider<=half-1'b1;
     if(index<1052);st<=SHIFT;
    end else wait_count<=wait_count+1'b1;
    SHIFT:if(divider!=0)divider<=divider-1'b1;
     else begin divider<=half-1'b1;sclk<=!sclk;
      // Delayed sampling compensates two synchronizer stages. At this falling
      // edge miso_sync represents the preceding high half-cycle.
      if(sclk && bitno!=0)begin ;bitno<=bitno-1'b1;;mosi<=shift_tx[6];end
      else if(sclk)begin
       ;
       case(index)
        0:if(rxbyte!=8'h41)header_bad<=1;1:if(rxbyte!=8'h46)header_bad<=1;
        2:if(rxbyte!=8'h53)header_bad<=1;3:if(rxbyte!=8'h31)header_bad<=1;
        4:if(rxbyte!=1)header_bad<=1;5:if(rxbyte!=128)header_bad<=1;
        6:begin ;if(rxbyte>1)header_bad<=1;end
        7:begin ;if(rxbyte<1||rxbyte>5)header_bad<=1;end
        8:;9:;
        10:;11:;
        12,13,14,15:;
        22:if(rxbyte!=160)header_bad<=1;24:if(rxbyte!=90)header_bad<=1;
        default:if(index<1052&&rxbyte!=0)header_bad<=1;
       endcase
       if(index==1055)begin
        cs_n<=1;mosi<=0;busy<=0;done<=1;gap<=64;st<=IDLE;
        if(crc_next==32'hdebb20e3 && !header_bad && pending_session!=0)begin
         status_valid<=1;;;;
        end
       end else begin index<=index+1'b1;st<=LOAD;end
      end
     end
   endcase
  end
 end

 // Data-only registers deliberately have no reset-tree sink. CRC and pending
 // fields initialize at every accepted start; shift registers at every LOAD;
 // status data is observable only when reset-controlled status_valid is high.
 // State, chip select, clock, valid strobes and synchronizers retain reset.
 always @(posedge clk) begin
  if(st==IDLE && start)begin
   txcrc<=32'hffffffff;rxcrc<=32'hffffffff;
   pending_enable<=0;pending_fps<=1;pending_session<=0;
   half<=fast?HALF_FAST:HALF_SLOW;
  end
  if(st==LOAD && !(cs_n&&wait_count==WAIT_CYCLES-1) &&
     (!cs_n||(ready_sync&&low_seen&&gap==0)))begin
   shift_tx<=value;shift_rx<=0;
   if(index<1052)txcrc<=crc_next;
  end
  if(st==SHIFT && divider==0 && sclk)begin
   if(bitno!=0)begin shift_rx<=rxbyte;shift_tx<={shift_tx[6:0],1'b0};end
   else begin
    rxcrc<=crc_next;
    case(index)
     6:pending_enable<=rxbyte[0];7:pending_fps<=rxbyte[2:0];
     8:pending_session[7:0]<=rxbyte;9:pending_session[15:8]<=rxbyte;
     10:pending_session[23:16]<=rxbyte;11:pending_session[31:24]<=rxbyte;
    endcase
    if(index==1055 && crc_next==32'hdebb20e3 && !header_bad && pending_session!=0)begin
     status_enable<=pending_enable;status_fps<={5'd0,pending_fps};status_session<=pending_session;
    end
   end
  end
 end
endmodule
