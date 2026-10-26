// v09 prepare: XRGB8888 -> rounded box -> display gamma -> padded RGB64.
// v09 postprocess: RGB64 -> half-pixel bilinear -> tagged display XRGB8888.
// All addresses are byte addresses. One AXI burst outstanding per engine.
// RAM ports have no reset; all valid/count state is reset. No full-frame BRAM.
module artflow_cnn_resize #(
    parameter WIDTH=960, HEIGHT=540, BURST=64
)(
    input clk, rst_n, start, input upscale, input [31:0] src_addr, dst_addr,
    output reg busy, done, failed, output reg [31:0] cycles,
    output reg [31:0] araddr, output [7:0] arlen,
    output arvalid, input arready, input [127:0] rdata,
    input rvalid, rlast, input [1:0] rresp, output rready,
    output reg [31:0] awaddr, output [7:0] awlen,
    output awvalid, input awready, output [127:0] wdata,
    output [15:0] wstrb, output wvalid, wlast, input wready,
    input bvalid, input [1:0] bresp, output bready
);
localparam LW=WIDTH/4, LH=HEIGHT/2, XW=$clog2(WIDTH+1), WW=$clog2(LW+1);
localparam IDLE=0, RP=1, RA=2, RD=3, DP=4, DOWN=5, UP=6,
           WP=7, WA=8, PREF=9, WD=10, BR=11, NEXT=12, FIN=13;
reg [3:0] state;
reg mode_up;
reg [31:0] src, dst;
reg [15:0] low_y, out_y;
reg raw_bottom, bank, last_copy, pair_second;
reg [WW-1:0] offset, ram_index, down_index, write_index;
reg [8:0] beats, beat;
reg [XW-1:0] up_x;
reg down_valid;
reg [WW-1:0] down_index_q;
reg [95:0] raw_top[0:LW-1], raw_bot[0:LW-1];
reg [127:0] top_q, bot_q;
// Two copies supply two synchronous read ports while the downsampler writes.
reg [47:0] low0a[0:LW-1], low0b[0:LW-1];
reg [47:0] low1a[0:LW-1], low1b[0:LW-1];
reg [47:0] l0a,l0b,l1a,l1b;
reg [95:0] output_line[0:LW-1];
reg [127:0] write_q, pack;
// The model expects display-domain RGB in increasing byte order R,G,B.
// Six synchronous LUT reads; no changes to the frozen CNN quantization.
wire [47:0] gamma_pixels;
reg gamma_valid;
reg [WW-1:0] gamma_index;
integer wanted, boundary;
always @* begin
    wanted=LW-offset;
    boundary=(4096-((state==RP ? araddr : awaddr)&4095))>>4;
    if(wanted>BURST) wanted=BURST;
    if(wanted>boundary) wanted=boundary;
end
assign arlen=beats-1'b1; assign awlen=beats-1'b1;
assign arvalid=state==RA; assign rready=state==RD;
assign awvalid=state==WA; assign wvalid=state==WD;
assign wdata=write_q; assign wstrb=16'hffff;
assign wlast=beat==beats-1'b1; assign bready=state==BR;
function [23:0] down2x;
    input [63:0] a,b;
    integer c; reg [9:0] sum;
    begin
        for(c=0;c<3;c=c+1) begin
            sum={2'b0,a[c*8+:8]}+{2'b0,a[32+c*8+:8]}+
                {2'b0,b[c*8+:8]}+{2'b0,b[32+c*8+:8]}+10'd2;
            down2x[c*8+:8]=sum[9:2];
        end
    end
endfunction
// Compact four XRGB slots to RGB96. Public AXI words remain unchanged.
function [95:0] compact_rgb;
 input [127:0] word_value;
 begin compact_rgb={word_value[119:96],word_value[87:64],word_value[55:32],word_value[23:0]};end
endfunction
function [127:0] expand_rgb;
 input [95:0] packed_rgb;input [7:0] tag;
 begin expand_rgb={tag,packed_rgb[95:72],tag,packed_rgb[71:48],tag,packed_rgb[47:24],tag,packed_rgb[23:0]};end
endfunction
wire [47:0] down_pixels={down2x(top_q[127:64],bot_q[127:64]),
                              down2x(top_q[63:0],bot_q[63:0])};
// Same six synchronous reads, exact table bytes and original BGR-to-RGB order.
// Both ports use this module's unchanged clk; no reset on ROM read outputs,
// matching the original free-running gamma_pixels register.
genvar gc;
generate for(gc=0;gc<3;gc=gc+1)begin:gamma_channels
 EFX_DPRAM10 #(.READ_WIDTH_A(8),.WRITE_WIDTH_A(8),.READ_WIDTH_B(8),.WRITE_WIDTH_B(8),
  .OUTPUT_REG_A(1'b0),.OUTPUT_REG_B(1'b0),
  .INIT_0(256'h62605f5d5c5a5957555452504e4c4a48464442403d3b3835322e2b27221c1500),
  .INIT_1(256'h87868584838281807f7e7d7c7b7a78777675747372706f6e6d6b6a6967666563),
  .INIT_2(256'ha3a2a1a0a09f9e9d9c9c9b9a9998979796959493929190908f8e8d8c8b8a8988),
  .INIT_3(256'hbab9b8b8b7b6b6b5b4b4b3b2b2b1b0afafaeadadacabaaaaa9a8a7a7a6a5a4a4),
  .INIT_4(256'hcecdcdcccbcbcacac9c8c8c7c7c6c5c5c4c3c3c2c2c1c0c0bfbebebdbcbcbbba),
  .INIT_5(256'he0dfdfdedddddcdcdbdbdadad9d9d8d7d7d6d6d5d5d4d4d3d2d2d1d1d0cfcfce),
  .INIT_6(256'hf0efefeeeeededececebebeaeae9e9e8e8e7e7e6e6e5e5e4e4e3e3e2e2e1e1e0),
  .INIT_7(256'hfffffefefdfdfcfcfbfbfafaf9f9f9f8f8f7f7f6f6f5f5f4f4f3f3f2f2f1f1f0)
 ) rom(.CLKA(clk),.CLKEA(1'b1),.WEA(1'b0),.RSTA(1'b0),.ADDRENA(1'b1),.WDATAA(8'd0),
       .ADDRA({2'b0,down_pixels[gc*8+:8]}),.RDATAA(gamma_pixels[(2-gc)*8+:8]),
       .CLKB(clk),.CLKEB(1'b1),.WEB(1'b0),.RSTB(1'b0),.ADDRENB(1'b1),.WDATAB(8'd0),
       .ADDRB({2'b0,down_pixels[(gc+3)*8+:8]}),.RDATAB(gamma_pixels[(5-gc)*8+:8]));
end endgenerate
wire [XW-1:0] k=up_x>>1;
wire [XW-1:0] xa=up_x[0] ? k : (k==0 ? 0 : k-1'b1);
wire [XW-1:0] xb=up_x[0] ? (k==WIDTH/2-1 ? k : k+1'b1) : k;
reg v1,v2,v3; reg [XW-1:0] x1,x2,x3;
reg pa,pb,odd_x;
reg [9:0] htop[0:2], hbot[0:2];
reg [23:0] up_rgb;
wire [23:0] a0=pa ? l0a[47:24] : l0a[23:0];
wire [23:0] b0=pb ? l0b[47:24] : l0b[23:0];
wire [23:0] a1=pa ? l1a[47:24] : l1a[23:0];
wire [23:0] b1=pb ? l1b[47:24] : l1b[23:0];
wire [23:0] prev_a=bank ? a0 : a1, prev_b=bank ? b0 : b1;
wire [23:0] curr_a=bank ? a1 : a0, curr_b=bank ? b1 : b0;
wire edge_row=low_y==0 || last_copy;
wire [23:0] ta=edge_row ? curr_a : prev_a, tb=edge_row ? curr_b : prev_b;
function [9:0] horizontal;
    input [7:0] a,b; input odd;
    begin
        horizontal=odd ? ({2'b0,a}<<1)+{2'b0,a}+{2'b0,b} :
                         {2'b0,a}+({2'b0,b}<<1)+{2'b0,b};
    end
endfunction
function [7:0] vertical;
    input [9:0] a,b; input odd;
    reg [11:0] sum;
    begin
        sum=odd ? ({2'b0,a}<<1)+{2'b0,a}+{2'b0,b}+12'd8 :
                  {2'b0,a}+({2'b0,b}<<1)+{2'b0,b}+12'd8;
        vertical=sum[11:4];
    end
endfunction
wire [WW-1:0] write_read_index=(state==WD && wready && !wlast)?write_index+1'b1:write_index;
integer c;
always @(posedge clk) begin
    if(state==RD && rvalid) begin
        if(raw_bottom) raw_bot[ram_index]<=compact_rgb(rdata);
        else raw_top[ram_index]<=compact_rgb(rdata);
    end
    top_q<=expand_rgb(raw_top[down_index],8'd0); bot_q<=expand_rgb(raw_bot[down_index],8'd0);
    if(state==RD && rvalid && mode_up) begin
        if(bank) begin low1a[ram_index]<={rdata[87:64],rdata[23:0]}; low1b[ram_index]<={rdata[87:64],rdata[23:0]}; end
        else begin low0a[ram_index]<={rdata[87:64],rdata[23:0]}; low0b[ram_index]<={rdata[87:64],rdata[23:0]}; end
    end
    l0a<=low0a[xa>>1]; l0b<=low0b[xb>>1];
    l1a<=low1a[xa>>1]; l1b<=low1b[xb>>1];
    // A single explicitly multiplexed write port is essential for BRAM
    // inference; two independent indexed writes infer a register array.
    if((gamma_valid && !mode_up) || (v3 && x3[1:0]==3))
        output_line[mode_up ? (x3>>2) : gamma_index] <= compact_rgb(mode_up ?
            {8'd1,up_rgb[7:0],up_rgb[15:8],up_rgb[23:16],pack[95:0]} :
            {40'd0,gamma_pixels[47:24],40'd0,gamma_pixels[23:0]});
    write_q<=expand_rgb(output_line[write_read_index],{7'd0,mode_up});
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mode_up<=0;gamma_valid<=0;gamma_index<=0;state<=IDLE; busy<=0; done<=0; failed<=0; cycles<=0;
        src<=0; dst<=0; araddr<=0; awaddr<=0; low_y<=0; out_y<=0;
        raw_bottom<=0; bank<=0; last_copy<=0; pair_second<=0;
        offset<=0; ram_index<=0; down_index<=0; down_index_q<=0;
        write_index<=0; beats<=0; beat<=0; up_x<=0; down_valid<=0;
        v1<=0;v2<=0;v3<=0;x1<=0;x2<=0;x3<=0;pa<=0;pb<=0;odd_x<=0;
        pack<=0;up_rgb<=0;
        for(c=0;c<3;c=c+1) begin htop[c]<=0; hbot[c]<=0; end
    end else begin
        done<=0;
        if(busy) cycles<=cycles+1'b1;
        down_valid<=state==DOWN && down_index<LW;
        down_index_q<=down_index;
        gamma_valid<=down_valid;gamma_index<=down_index_q;
        v1<=state==UP && up_x<WIDTH; v2<=v1; v3<=v2;
        x1<=up_x; x2<=x1; x3<=x2; pa<=xa[0];pb<=xb[0];odd_x<=up_x[0];
        for(c=0;c<3;c=c+1) begin
            htop[c]<=horizontal(ta[c*8+:8],tb[c*8+:8],odd_x);
            hbot[c]<=horizontal(curr_a[c*8+:8],curr_b[c*8+:8],odd_x);
            up_rgb[c*8+:8]<=vertical(htop[c],hbot[c],out_y[0]);
        end
        if(v3) pack[x3[1:0]*32+:32]<={8'd1,up_rgb[7:0],up_rgb[15:8],up_rgb[23:16]};
        case(state)
            IDLE: if(start) begin
                mode_up<=upscale;busy<=1;failed<=0;cycles<=0;src<=src_addr;dst<=dst_addr;
                araddr<=src_addr;awaddr<=dst_addr;low_y<=0;out_y<=0;
                raw_bottom<=0;bank<=0;last_copy<=0;pair_second<=0;
                offset<=0;ram_index<=0;state<=RP;
            end
            RP: begin beats<=wanted;beat<=0;state<=RA;end
            RA: if(arready) state<=RD;
            RD: if(rvalid) begin
                if(rresp!=0 || rlast!=(beat==beats-1'b1)) failed<=1;
                ram_index<=ram_index+1'b1;
                if(rlast) begin
                    araddr<=araddr+(beats<<4);offset<=offset+beats;
                    if(offset+beats==LW) begin
                        offset<=0;ram_index<=0;
                        if(mode_up) begin up_x<=0;state<=UP;end
                        else if(raw_bottom) begin down_index<=0;state<=DP;end
                        else begin raw_bottom<=1;state<=RP;end
                    end else state<=RP;
                end else beat<=beat+1'b1;
            end
            DP: state<=DOWN;
            DOWN: begin
                if(down_index<LW) down_index<=down_index+1'b1;
                else if(!down_valid && !gamma_valid) begin offset<=0;write_index<=0;state<=WP;end
            end
            UP: begin
                if(up_x<WIDTH) up_x<=up_x+1'b1;
                if(v3 && x3==WIDTH-1) begin offset<=0;write_index<=0;state<=WP;end
            end
            WP: begin beats<=wanted;beat<=0;state<=WA;end
            WA: if(awready) state<=PREF;
            PREF: state<=WD;
            WD: if(wready) begin
                write_index<=write_index+1'b1;
                if(wlast) state<=BR;
                else beat<=beat+1'b1;
            end
            BR: if(bvalid) begin
                if(bresp!=0) failed<=1;
                awaddr<=awaddr+(beats<<4);offset<=offset+beats;
                if(offset+beats==LW) state<=NEXT; else state<=WP;
            end
            NEXT: begin
                out_y<=out_y+1'b1;up_x<=0;
                if(!mode_up) begin
                    if(low_y==LH-1) state<=FIN;
                    else begin low_y<=low_y+1'b1;raw_bottom<=0;offset<=0;ram_index<=0;state<=RP;end
                end else if(out_y==HEIGHT-1) state<=FIN;
                else if(low_y==LH-1 && pair_second) begin last_copy<=1;state<=UP;end
                else if(low_y!=0 && !pair_second) begin pair_second<=1;state<=UP;end
                else begin
                    low_y<=low_y+1'b1;bank<=!bank;pair_second<=0;
                    raw_bottom<=0;offset<=0;ram_index<=0;state<=RP;
                end
            end
            FIN: begin busy<=0;done<=1;state<=IDLE;end
            default: state<=IDLE;
        endcase
    end
end
// synthesis translate_off
initial if(WIDTH<8 || WIDTH%4 || HEIGHT<4 || HEIGHT%2 || BURST<1 || BURST>256)
    $fatal(1,"Invalid accelerator geometry");
// synthesis translate_on
endmodule
