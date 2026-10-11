// v07 XRGB8888 -> rounded 2x2 box -> identity -> half-pixel bilinear.
// All addresses are byte addresses. One AXI burst outstanding per engine.
// RAM ports have no reset; all valid/count state is reset. No full-frame BRAM.
module artflow_accel_dma #(
    parameter WIDTH=960, HEIGHT=540, BURST=64
)(
    input clk, rst_n, start, input [31:0] src_addr, dst_addr,
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
reg [31:0] src, dst;
reg [15:0] low_y, out_y;
reg raw_bottom, bank, last_copy, pair_second;
reg [WW-1:0] offset, ram_index, down_index, write_index;
reg [8:0] beats, beat;
reg [XW-1:0] up_x;
reg down_valid;
reg [WW-1:0] down_index_q;
reg [127:0] raw_top[0:LW-1], raw_bot[0:LW-1];
reg [127:0] top_q, bot_q;
// Two copies supply two synchronous read ports while the downsampler writes.
reg [47:0] low0a[0:LW-1], low0b[0:LW-1];
reg [47:0] low1a[0:LW-1], low1b[0:LW-1];
reg [47:0] l0a,l0b,l1a,l1b;
reg [127:0] output_line[0:LW-1];
reg [127:0] write_q, pack;
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
wire [47:0] down_pixels={down2x(top_q[127:64],bot_q[127:64]),
                              down2x(top_q[63:0],bot_q[63:0])};
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
integer c;
always @(posedge clk) begin
    if(state==RD && rvalid) begin
        if(raw_bottom) raw_bot[ram_index]<=rdata;
        else raw_top[ram_index]<=rdata;
    end
    top_q<=raw_top[down_index]; bot_q<=raw_bot[down_index];
    if(down_valid) begin
        if(bank) begin low1a[down_index_q]<=down_pixels; low1b[down_index_q]<=down_pixels; end
        else begin low0a[down_index_q]<=down_pixels; low0b[down_index_q]<=down_pixels; end
    end
    l0a<=low0a[xa>>1]; l0b<=low0b[xb>>1];
    l1a<=low1a[xa>>1]; l1b<=low1b[xb>>1];
    if(v3 && x3[1:0]==3) output_line[x3>>2]<={8'd0,up_rgb,pack[95:0]};
    write_q<=output_line[write_index];
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state<=IDLE; busy<=0; done<=0; failed<=0; cycles<=0;
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
        v1<=state==UP && up_x<WIDTH; v2<=v1; v3<=v2;
        x1<=up_x; x2<=x1; x3<=x2; pa<=xa[0];pb<=xb[0];odd_x<=up_x[0];
        for(c=0;c<3;c=c+1) begin
            htop[c]<=horizontal(ta[c*8+:8],tb[c*8+:8],odd_x);
            hbot[c]<=horizontal(curr_a[c*8+:8],curr_b[c*8+:8],odd_x);
            up_rgb[c*8+:8]<=vertical(htop[c],hbot[c],out_y[0]);
        end
        if(v3) pack[x3[1:0]*32+:32]<={8'd0,up_rgb};
        case(state)
            IDLE: if(start) begin
                busy<=1;failed<=0;cycles<=0;src<=src_addr;dst<=dst_addr;
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
                        if(raw_bottom) begin down_index<=0;state<=DP;end
                        else begin raw_bottom<=1;state<=RP;end
                    end else state<=RP;
                end else beat<=beat+1'b1;
            end
            DP: state<=DOWN;
            DOWN: begin
                if(down_index<LW) down_index<=down_index+1'b1;
                else if(!down_valid) begin up_x<=0;state<=UP;end
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
                else begin beat<=beat+1'b1;state<=PREF;end
            end
            BR: if(bvalid) begin
                if(bresp!=0) failed<=1;
                awaddr<=awaddr+(beats<<4);offset<=offset+beats;
                if(offset+beats==LW) state<=NEXT; else state<=WP;
            end
            NEXT: begin
                out_y<=out_y+1'b1;up_x<=0;
                if(out_y==HEIGHT-1) state<=FIN;
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
