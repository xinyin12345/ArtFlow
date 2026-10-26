// Read-only display observer. A failed/slow link discards a complete epoch.
module afs_stream_tx #(
 parameter OUT_W=160,OUT_H=90,STEP=6,FIFO_LOG2=12,
 parameter CLK_HZ=74250000,HALF_SLOW=38,HALF_FAST=3
)(input clk,rst_n,input frame_tick,frame_bad,pixel_valid,
 input [9:0] source_x,source_y,input [23:0] rgb,input [31:0] epoch,
 input ready,miso,output cs_n,sclk,mosi,
 output reg [31:0] completed=0,dropped=0);
 localparam PIXELS=OUT_W*OUT_H,BYTES=PIXELS*2,DEPTH=1<<FIFO_LOG2;
 function automatic [31:0] crcbyte(input [31:0] c,input [7:0] b);
  reg [31:0] v;integer k;begin v=c^b;for(k=0;k<8;k=k+1)v=(v>>1)^(v[0]?32'hedb88320:0);crcbyte=v;end
 endfunction
 // Pack two pixels per word: 2048x32 maps to seven RAM10 blocks for 8KiB.
 // Only complete pairs are read; DATA admission requires at least 512 pixels.
 reg [31:0] mem[0:DEPTH/2-1];reg [31:0] pair_front;reg [15:0] held_low;
 wire [15:0] front;
 reg [FIFO_LOG2:0] wp=0,rp=0;
 assign front=rp[0]?pair_front[31:16]:pair_front[15:0];
 wire [FIFO_LOG2:0] used=wp-rp;
 wire full=used==DEPTH;
 wire [15:0] pixel565={rgb[23:19],rgb[15:10],rgb[7:3]};
 reg capture=0,captured=0,abort_frame=0;
 reg [15:0] samples=0;reg [9:0] want_x=0,want_y=0;
 reg [31:0] seq=0,session=0,frame_session=0,frame_crc=32'hffffffff;
 reg crc_high_pending=0;reg [7:0] crc_high_byte=0;
 reg enabled=0;reg [7:0] fps=1;
 reg [26:0] throttle=0,poll_wait=0,link_wait=0;
 reg [2:0] phase=0; // 0 idle,1 BEGIN,2 DATA/END
 reg pending=0,start=0;reg [7:0] kind=0;reg [14:0] offset=0,packet_offset=0;
 reg [15:0] packet_len=0;reg payload_high=0;
 wire busy,done,failed,take,status_valid,status_enable;wire [7:0] status_fps;wire [31:0] status_session;
 wire sample_now=capture&&pixel_valid&&source_x==want_x&&source_y==want_y;
 wire first_now=phase==0&&!pending&&enabled&&throttle==0&&pixel_valid&&source_x==0&&source_y==0;
 wire write_pixel=(sample_now||first_now)&&!full&&!abort_frame;
 wire [31:0] pixel_crc_next=crcbyte(first_now?32'hffffffff:frame_crc,crc_high_pending?crc_high_byte:pixel565[7:0]);
 always @(posedge clk)begin
  pair_front<=mem[rp[FIFO_LOG2-1:1]];
  if(write_pixel)begin
   if(wp[0])mem[wp[FIFO_LOG2-1:1]]<={pixel565,held_low};
   else held_low<=pixel565;
  end
 end
 afs_spi_packet #(.HALF_SLOW(HALF_SLOW),.HALF_FAST(HALF_FAST),.WAIT_CYCLES(CLK_HZ/2)) packet(
 .clk(clk),.rst_n(rst_n),.start(start),.fast(enabled),.ready_async(ready),.miso(miso),
 .kind(kind),.session(phase==0?session:frame_session),.sequence_id(seq),.offset({17'd0,packet_offset}),.frame_crc(~frame_crc),.length(packet_len),
 .payload_byte(payload_high?front[15:8]:front[7:0]),.payload_take(take),.busy(busy),.done(done),.failed(failed),.cs_n(cs_n),.sclk(sclk),.mosi(mosi),
 .status_valid(status_valid),.status_enable(status_enable),.status_fps(status_fps),.status_session(status_session));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin crc_high_pending<=0;crc_high_byte<=0;wp<=0;rp<=0;capture<=0;captured<=0;abort_frame<=0;samples<=0;want_x<=0;want_y<=0;seq<=0;session<=0;frame_session<=0;frame_crc<=32'hffffffff;enabled<=0;fps<=1;throttle<=0;poll_wait<=0;link_wait<=0;phase<=0;pending<=0;start<=0;kind<=0;offset<=0;packet_offset<=0;packet_len<=0;payload_high<=0;completed<=0;dropped<=0;end
  else begin
   start<=0;
   if(crc_high_pending)begin frame_crc<=pixel_crc_next;crc_high_pending<=0;end
   if(write_pixel)begin crc_high_pending<=1;crc_high_byte<=pixel565[15:8];end
   if(throttle!=0)throttle<=throttle-1'b1;
   if(poll_wait!=0)poll_wait<=poll_wait-1'b1;
   if(link_wait<CLK_HZ/2)link_wait<=link_wait+1'b1;
   else begin enabled<=0;if(phase!=0)abort_frame<=1;end
   if(status_valid)begin
    link_wait<=0;enabled<=status_enable;fps<=status_fps;session<=status_session;
    if(phase!=0&&(!status_enable||status_session!=frame_session))abort_frame<=1;
   end
   if(take)begin payload_high<=!payload_high;if(payload_high)rp<=rp+1'b1;end
   if(first_now)begin
    capture<=1;captured<=0;phase<=1;samples<=1;want_x<=STEP;want_y<=0;seq<=epoch;frame_session<=session;frame_crc<=pixel_crc_next;wp<=wp+1'b1;offset<=0;
    case(fps)2:throttle<=CLK_HZ/2;3:throttle<=CLK_HZ/3;4:throttle<=CLK_HZ/4;5:throttle<=CLK_HZ/5;default:throttle<=CLK_HZ;endcase
   end else if(sample_now&&!abort_frame)begin
    if(full)begin abort_frame<=1;capture<=0;end
    else begin
     wp<=wp+1'b1;samples<=samples+1'b1;frame_crc<=pixel_crc_next;
     if(want_x==(OUT_W-1)*STEP)begin want_x<=0;want_y<=want_y+STEP;end else want_x<=want_x+STEP;
    end
   end
   if(capture&&(frame_bad||(pixel_valid&&epoch!=seq)))begin abort_frame<=1;capture<=0;end
   if(capture&&frame_tick)begin capture<=0;if(samples==PIXELS&&!frame_bad)captured<=1;else abort_frame<=1;end
   if(done)begin
    pending<=0;payload_high<=0;
    if(failed)begin phase<=0;capture<=0;captured<=0;abort_frame<=0;wp<=0;rp<=0;offset<=0;enabled<=0;if(phase!=0)dropped<=dropped+1'b1;end
    else begin
    if(kind==1)phase<=2;
    if(kind==2)offset<=offset+packet_len;
    if(kind==3||kind==4)begin
     phase<=0;capture<=0;captured<=0;abort_frame<=0;wp<=0;rp<=0;offset<=0;
     if(kind==3&&!abort_frame)completed<=completed+1'b1;else dropped<=dropped+1'b1;
    end
    end
   end
   if(!pending&&!first_now)begin
    if(phase!=0&&abort_frame)begin kind<=4;packet_offset<=offset;packet_len<=0;pending<=1;start<=1;capture<=0;end
    else if(phase==1)begin kind<=1;packet_offset<=0;packet_len<=0;pending<=1;start<=1;end
    else if(phase==2)begin
     if(offset==BYTES&&captured)begin kind<=3;packet_offset<=BYTES;packet_len<=4;pending<=1;start<=1;end
     else if(offset<BYTES&&((BYTES-offset>=1024&&used>=512)||(BYTES-offset<1024&&captured&&used>=(BYTES-offset)/2)))begin
      kind<=2;packet_offset<=offset;packet_len<=BYTES-offset>1024?1024:BYTES-offset;payload_high<=0;pending<=1;start<=1;
     end
    end else if(poll_wait==0)begin kind<=5;packet_offset<=0;packet_len<=16;pending<=1;start<=1;poll_wait<=CLK_HZ/10;end
   end
  end
 end
endmodule
