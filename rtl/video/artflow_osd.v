// Black-bar OSD: one 2048x5 ROM; unchanged two-register latency.
// DUAL image is y=270..809. Fullscreen retains native pixels except compact HUD.
module artflow_osd #(
 parameter H_ACTIVE=1920, parameter [7:0] VERSION_DIGIT="9", parameter PROCESS_FPS=0,
 parameter FONT_FILE="./rtl/video/osd_text_rows.mem"
)(
 input clk,rst_n,input [1:0] mode,input osd_enable,
 input [2:0] style_id,input style_valid,
 input [11:0] capture_bcd,display_bcd,input fps_valid,
 input i_de,i_hs,i_vs,input [23:0] i_rgb,
 output reg o_de,o_hs,o_vs,output reg [23:0] o_rgb
);
localparam [23:0] BG=24'h20242a,TRACK=24'h454b54,WHITE=24'hf4f5f7,
 YELLOW=24'hffd34e,GREEN=24'h50df8a,RED=24'hff6470;
reg [12:0] x,y;reg de_prev;
always @(posedge clk or negedge rst_n)
 if(!rst_n) begin x<=0;y<=0;de_prev<=0;end
 else begin
  de_prev<=i_de;
  if(i_vs) begin x<=0;y<=0;end
  else begin if(i_de)x<=x+13'd1;else x<=0;
   if(de_prev && !i_de)y<=y+13'd1;end
 end
function [23:0] palette;input [1:0] attr;
 begin case(attr)0:palette=WHITE;1:palette=YELLOW;2:palette=GREEN;3:palette=RED;endcase end
endfunction
// Inputs are saturated BCD event counts over an independent one-second window.
// 0..30 maps to 0..480 px. Clamp BEFORE arithmetic; no 999 overflow/wrap.
function [5:0] bar_fps;input [11:0] b;
 begin if(b>=12'h030)bar_fps=30;else bar_fps={2'b0,b[7:4]}*6'd10+{2'b0,b[3:0]};end
endfunction
wire [9:0] cap_width=fps_valid?{bar_fps(capture_bcd),4'b0}:10'd0;
wire [9:0] out_width=fps_valid?{bar_fps(display_bcd),4'b0}:10'd0;
wire [1:0] cap_attr=!fps_valid?0:(capture_bcd>=12'h030 ? 2 : 3);
wire [1:0] out_attr=!fps_valid?0:(display_bcd>=12'h030 ? 2 : 3);
// All used 8x8 glyphs have three constant-zero columns. A 2048x5 ROM
// stores the five live columns without changing any displayed glyph pixels.
// Sixteen-character aligned text groups eliminate character-address adders.
function [7:0] text_slot;
 input [3:0] row; input [4:0] index; input [2:0] style; input [1:0] layout;
 begin
  text_slot=8'h0f; // padded space
  case(row)
   0:text_slot={4'h0,index[3:0]};
   1:case(layout)
      0:if(index<4)text_slot={4'h2,index[3:0]};
      1:text_slot={4'h3,index[3:0]};
      2:if(index<4)text_slot={4'h1,index[3:0]};
      default:text_slot=8'h0f;
     endcase
   2:text_slot={4'h1,index[3:0]};
   3:text_slot={1'b1,style,index[3:0]};
   4:text_slot={4'h4,index[3:0]};
   5:text_slot={4'h5,index[3:0]};
   8:text_slot={4'h3,index[3:0]};
   9:text_slot=index==0?8'h73:8'h70;
   11:text_slot={4'h6,index[3:0]};
   default:text_slot=8'h0f;
  endcase
 end
endfunction

reg [12:0] style_x;reg [4:0] style_len;
always @* begin
 case(style_id)
 3'd0:begin style_x=13'd1232;style_len=5'd13;end
 3'd1:begin style_x=13'd1344;style_len=5'd6;end
 3'd2:begin style_x=13'd1248;style_len=5'd12;end
 3'd3:begin style_x=13'd1248;style_len=5'd12;end
 3'd4:begin style_x=13'd1216;style_len=5'd14;end
 3'd5:begin style_x=13'd1312;style_len=5'd8;end
 3'd6:begin style_x=13'd1392;style_len=5'd3;end
 3'd7:begin style_x=13'd1248;style_len=5'd12;end
 endcase
 if(!style_valid)begin style_x=13'd1328;style_len=7;end
end
reg [3:0] row;reg [4:0] index;reg [2:0] gx,gy;
reg text_hit,paint;reg [2:0] bg_code;reg [1:0] attr;
reg [12:0] dx,dy;reg [2:0] cell_id;reg dark_text;
reg [7:0] character;
always @* begin
 row=15;index=0;gx=0;gy=0;text_hit=0;paint=0;bg_code=0;attr=0;
 dx=0;dy=0;cell_id=0;dark_text=0;
 if(osd_enable && i_de)begin
  if(mode==0)begin
   if(y<270 || y>=810)begin paint=1;bg_code=0;end
   // Horizontal borders live outside the image. Vertical borders explicitly use
   // x=0,1919 and the four central pixels x=958..961; all other image pixels pass.
   if(y==269 || y==810 || (y>=270 && y<810 &&
      (x==0 || x==1919 || (x>=958 && x<962))))begin paint=1;bg_code=1;end
   if(x>=64 && x<512 && y>=48 && y<112)begin
    text_hit=1;row=0;dx=x-13'd64;dy=y-13'd48;
    index=dx[8:6];gx=dx[5:3];gy=dy[5:3];attr=1;
   end
   if(x>=1696 && x<1824 && y>=64 && y<96)begin
    text_hit=1;row=1;dx=x-13'd1696;dy=y-13'd64;
    index=dx[6:5];gx=dx[4:2];gy=dy[4:2];
   end
   if(x>=352 && x<608 && y>=192 && y<224)begin
    text_hit=1;row=2;dx=x-13'd352;dy=y-13'd192;
    index=dx[7:5];gx=dx[4:2];gy=dy[4:2];
   end
   if(x>=style_x && x<style_x+{style_len,5'b0} && y>=192 && y<224)begin
    text_hit=1;row=style_valid?3:11;dx=x-style_x;dy=y-13'd192;
    index=dx[9:5];gx=dx[4:2];gy=dy[4:2];attr=1;
   end
   if(y>=864 && y<896)begin
    dy=y-13'd864;gy=dy[4:2];
    if(x>=96 && x<192)begin text_hit=1;row=4;dx=x-13'd96;end
    if(x>=1056 && x<1152)begin text_hit=1;row=5;dx=x-13'd1056;end
    if(x>=768 && x<864)begin text_hit=1;row=6;dx=x-13'd768;attr=cap_attr;end
    if(x>=1728 && x<1824)begin text_hit=1;row=7;dx=x-13'd1728;attr=out_attr;end
    index=dx[6:5];gx=dx[4:2];
    if(x>=256 && x<736)begin bg_code=x<13'd256+cap_width?{1'b1,cap_attr}:3'd1;end
    if(x>=1216 && x<1696)begin bg_code=x<13'd1216+out_width?{1'b1,out_attr}:3'd1;end
   end
   if(y>=856 && y<904 && ((x>=734 && x<736)||(x>=1694 && x<1696)))bg_code=4;
   if(y>=912 && y<944)begin
    if(x>=704 && x<768)begin text_hit=1;row=9;dx=x-13'd704;end
    if(x>=1664 && x<1728)begin text_hit=1;row=9;dx=x-13'd1664;end
    dy=y-13'd912;index=dx[5];gx=dx[4:2];gy=dy[4:2];
   end
   if(x>=96 && x<256 && y>=992 && y<1024)begin
    text_hit=1;row=8;dx=x-13'd96;dy=y-13'd992;
    index=dx[7:5];gx=dx[4:2];gy=dy[4:2];
   end
   if(x>=352 && x<1376 && y>=984 && y<1032)begin
    dx=x-13'd352;dy=y-13'd984;cell_id=dx[9:7];
    if(dx[6:0]<64)begin
     if(style_valid && cell_id==style_id)bg_code=5;
     else if(dx[6:0]<2 || dx[6:0]>=62 || dy<2 || dy>=46)bg_code=1;
     if(dx[6:0]>=16 && dx[6:0]<48 && dy>=8 && dy<40)begin
      text_hit=1;row=10;gx=(dx-13'd16)>>2;gy=(dy-13'd8)>>2;
      dark_text=style_valid && cell_id==style_id;
     end
    end
   end
  end else begin
   // Fullscreen: compact 768x96 HUD only, no scaling or artificial black bars.
   if(x>=32 && x<800 && y>=32 && y<128)begin paint=1;bg_code=0;end
   if(y>=40 && y<72)begin
    if(x>=48 && x<272)begin text_hit=1;row=0;dx=x-13'd48;attr=1;end
    if(x>=544 && x<704)begin text_hit=1;row=1;dx=x-13'd544;end
    dy=y-13'd40;index=dx[7:5];gx=dx[4:2];gy=dy[4:2];
   end
   if(y>=88 && y<120)begin
    if(x>=48 && x<144)begin text_hit=1;row=4;dx=x-13'd48;end
    if(x>=176 && x<272)begin text_hit=1;row=6;dx=x-13'd176;attr=cap_attr;end
    if(x>=400 && x<496)begin text_hit=1;row=5;dx=x-13'd400;end
    if(x>=528 && x<624)begin text_hit=1;row=7;dx=x-13'd528;attr=out_attr;end
    dy=y-13'd88;index=dx[6:5];gx=dx[4:2];gy=dy[4:2];
   end
  end
 end
 character=text_slot(row,index,style_id,mode);
 if(row==6 || row==7)begin
  if(!fps_valid)character=8'h7a;
  else case(index)
   0:character={4'h7,(row==6?capture_bcd[11:8]:display_bcd[11:8])};
   1:character={4'h7,(row==6?capture_bcd[7:4]:display_bcd[7:4])};
   2:character={4'h7,(row==6?capture_bcd[3:0]:display_bcd[3:0])};
   default:character=8'h0f;endcase
 end
 if(row==10)character={4'h7,1'b0,cell_id};
end
(* syn_ramstyle="block_ram" *) reg [4:0] font[0:2047];reg [4:0] font_row;
initial $readmemh(FONT_FILE,font);
always @(posedge clk)font_row<=font[{character,gy}];
reg de1,hs1,vs1,text1,paint1,dark1;reg [2:0] column1;reg [1:0] attr1;
reg [23:0] rgb1;reg [2:0] bg1;
wire [7:0] glyph_row={1'b0,font_row,2'b00};
wire glyph1=text1 && glyph_row[7-column1];
wire [2:0] solid_code=glyph1?(dark1?3'd0:{1'b1,attr1}):bg1;
wire [23:0] solid_rgb=solid_code[2]?palette(solid_code[1:0]):(solid_code[0]?TRACK:BG);
always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  de1<=0;hs1<=0;vs1<=0;text1<=0;paint1<=0;dark1<=0;column1<=0;attr1<=0;rgb1<=0;bg1<=0;
  o_de<=0;o_hs<=0;o_vs<=0;o_rgb<=0;
 end else begin
  de1<=i_de;hs1<=i_hs;vs1<=i_vs;rgb1<=i_rgb;bg1<=bg_code;
  text1<=text_hit;paint1<=paint;dark1<=dark_text;column1<=gx;attr1<=attr;
  o_de<=de1;o_hs<=hs1;o_vs<=vs1;
  if(!de1)o_rgb<=0;
  else if(glyph1 || paint1)o_rgb<=solid_rgb;
  else o_rgb<=rgb1;
 end
endmodule
