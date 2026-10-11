// Two-cycle registered RGB/timing pipeline. 8x8 ROM glyphs at 4x scale.
// Panel: (32,32)..(927,95), 28 columns, two rows. Outside is transparent.
module artflow_osd #(
    parameter H_ACTIVE=1920, parameter [7:0] VERSION_DIGIT="6", parameter PROCESS_FPS=0,
    parameter FONT_FILE="./rtl/video/osd_font.mem"
)(
    input clk, rst_n, input [1:0] mode, input osd_enable,
    input [11:0] capture_bcd, display_bcd, input fps_valid,
    input i_de, i_hs, i_vs, input [23:0] i_rgb,
    output reg o_de, o_hs, o_vs, output reg [23:0] o_rgb
);
reg [12:0] x,y;
reg de_prev;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin x<=0; y<=0; de_prev<=0; end
    else begin
        de_prev<=i_de;
        if(i_vs) begin x<=0; y<=0; end
        else begin
            if(i_de) x<=x+13'd1; else x<=0;
            if(de_prev && !i_de) y<=y+13'd1;
        end
    end
end
wire [12:0] rx=x-13'd32, ry=y-13'd32;
wire panel=osd_enable && i_de && x>=32 && x<928 && y>=32 && y<96;
reg [7:0] character;
always @* begin
    character=8'h20;
    if(!ry[5]) begin
        case(rx[9:5])
             0:character="A"; 1:character="R"; 2:character="T"; 3:character="F";
             4:character="L"; 5:character="O"; 6:character="W";
             8:character="V"; 9:character="0"; 10:character=VERSION_DIGIT;
             12:character="M"; 13:character="O"; 14:character="D";
             15:character="E"; 16:character=":";
             18:case(mode) 0:character="D";1:character="L";2:character="R";3:character="B";endcase
             19:case(mode) 0:character="U";1:character="E";2:character="I";3:character="A";endcase
             20:case(mode) 0:character="A";1:character="F";2:character="G";3:character="R";endcase
             21:case(mode) 0:character="L";1:character="T";2:character="H";3:character="S";endcase
             22:if(mode==2) character="T";
             default:character=" ";
        endcase
    end else begin
        case(rx[9:5])
             0:character="C"; 1:character="A"; 2:character="P";
             4:character="F"; 5:character="P"; 6:character="S"; 7:character=":";
             8:character=fps_valid ? 8'h30+{4'd0,capture_bcd[11:8]} : "-";
             9:character=fps_valid ? 8'h30+{4'd0,capture_bcd[7:4]} : "-";
             10:character=fps_valid ? 8'h30+{4'd0,capture_bcd[3:0]} : "-";
             13:character=PROCESS_FPS ? "P" : "O"; 14:character=PROCESS_FPS ? "R" : "U"; 15:character=PROCESS_FPS ? "C" : "T";
             17:character="F"; 18:character="P"; 19:character="S"; 20:character=":";
             21:character=fps_valid ? 8'h30+{4'd0,display_bcd[11:8]} : "-";
             22:character=fps_valid ? 8'h30+{4'd0,display_bcd[7:4]} : "-";
             23:character=fps_valid ? 8'h30+{4'd0,display_bcd[3:0]} : "-";
             default:character=" ";
        endcase
    end
end
(* syn_ramstyle="block_ram" *) reg [7:0] font [0:1023];
reg [7:0] font_row;
initial $readmemh(FONT_FILE,font);
always @(posedge clk) font_row<=font[{character[6:0],ry[4:2]}];
reg [23:0] base_rgb;
always @* begin
    base_rgb=i_rgb;
    case(mode)
        1: if(x>=H_ACTIVE/2) base_rgb=0;
        2: if(x<H_ACTIVE/2) base_rgb=0;
        3: begin
            if(x<H_ACTIVE/8) base_rgb=24'hffffff;
            else if(x<H_ACTIVE*2/8) base_rgb=24'hffff00;
            else if(x<H_ACTIVE*3/8) base_rgb=24'h00ffff;
            else if(x<H_ACTIVE*4/8) base_rgb=24'h00ff00;
            else if(x<H_ACTIVE*5/8) base_rgb=24'hff00ff;
            else if(x<H_ACTIVE*6/8) base_rgb=24'hff0000;
            else if(x<H_ACTIVE*7/8) base_rgb=24'h0000ff;
            else base_rgb=0;
        end
        default: ;
    endcase
end
reg de1,hs1,vs1,panel1,title1;
reg [2:0] column1;
reg [23:0] rgb1;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        de1<=0;hs1<=0;vs1<=0;panel1<=0;title1<=0;column1<=0;rgb1<=0;
        o_de<=0;o_hs<=0;o_vs<=0;o_rgb<=0;
    end else begin
        de1<=i_de;hs1<=i_hs;vs1<=i_vs;rgb1<=base_rgb;
        panel1<=panel;column1<=rx[4:2];title1<=!ry[5];
        o_de<=de1;o_hs<=hs1;o_vs<=vs1;
        if(!de1) o_rgb<=0;
        else if(panel1) o_rgb<=font_row[7-column1] ?
            (title1 ? 24'h40e0ff : 24'hffffff) : 24'h081828;
        else o_rgb<=rgb1;
    end
end
endmodule
