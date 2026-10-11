`timescale 1ns/1ps
// Numeric checks use arithmetic, not the implementation LUT or Python model.
module tb_reference_color;
parameter [9:0] BLACK_LEVEL = 68;
parameter [15:0] DEFAULT_GAIN = 102;
localparam W=16, H=8, NPIX=W*H/4;
reg clk=0; always #10 clk=~clk;
reg rstn=0,vs=0,hs=0,valid=0,rev=0;
reg [1:0] phase=0;
reg [39:0] data=0;
reg [15:0] gr=DEFAULT_GAIN,gg=DEFAULT_GAIN,gb=DEFAULT_GAIN;
wire bv,bh,bs,lv,lh,ls;
wire [63:0] bd;
bayer_bin2x2 #(.MAX_IN_WIDTH(W),.BLACK_LEVEL(BLACK_LEVEL)) dut (
    .clk(clk),.rstn(rstn),.i_bayer(phase),.i_pix_rev(rev),
    .i_gain_r(gr),.i_gain_g(gg),.i_gain_b(gb),
    .i_vs(vs),.i_hs(hs),.i_valid(valid),.i_data(data),
    .o_vs(bs),.o_hs(bh),.o_valid(bv),.o_data(bd));
// A disabled BLC instance proves the added arithmetic does not shift flags.
bayer_bin2x2 #(.MAX_IN_WIDTH(W)) legacy (
    .clk(clk),.rstn(rstn),.i_bayer(phase),.i_pix_rev(rev),
    .i_gain_r(gr),.i_gain_g(gg),.i_gain_b(gb),
    .i_vs(vs),.i_hs(hs),.i_valid(valid),.i_data(data),
    .o_vs(ls),.o_hs(lh),.o_valid(lv),.o_data());
wire [47:0] display_rgb;
wire [1:0] gv,gh,gs;
for(genvar p=0;p<2;p=p+1) begin: display_stage
    gamma_lut #(.LUT_FILE("./rtl/gamma_conrrection/gamma_inv2p2_8b.mem")) gamma (
        .i_pclk(clk),.i_rstn(rstn),.i_bypass(1'b0),
        .i_valid(bv),.i_hs(bh),.i_vs(bs),
        .i_red(bd[p*32+16+:8]),.i_green(bd[p*32+8+:8]),.i_blue(bd[p*32+:8]),
        .o_red(display_rgb[p*24+16+:8]),.o_green(display_rgb[p*24+8+:8]),
        .o_blue(display_rgb[p*24+:8]),.o_valid(gv[p]),.o_hs(gh[p]),.o_vs(gs[p]));
end
function integer sample(input integer f,y,x);
    case(f)
        0:sample=0;
        1:sample=67;
        2:sample=68;
        3:sample=69;
        4:sample=72;
        5:sample=512;
        6:sample=1023;
        7:sample=((x+y)%2)?100:36; // Gr/Gb straddle pedestal after phase selection.
        8:sample=(y%2)?100:36;
        default:sample=(y*237+x*73+11)%1024;
    endcase
endfunction
function integer corrected(input integer f,y,x);
    integer n;
    begin n=sample(f,y,x)-BLACK_LEVEL;corrected=n<0?0:n;end
endfunction
function [23:0] expected_pixel(input integer f,y,x,ph);
    integer rx,ry,r,g,b;
    begin
        rx=ph%2;ry=ph/2;
        r=corrected(f,y*2+ry,x*2+rx)*gr/1024;
        b=corrected(f,y*2+1-ry,x*2+1-rx)*gb/1024;
        g=(corrected(f,y*2+ry,x*2+1-rx)+corrected(f,y*2+1-ry,x*2+rx))*gg/2048;
        if(r>255)r=255;if(g>255)g=255;if(b>255)b=255;
        expected_pixel={r[7:0],g[7:0],b[7:0]};
    end
endfunction
function [7:0] display_value(input [7:0] n);
    display_value=$rtoi($floor(255.0*$pow(n/255.0,1.0/2.2)+0.5));
endfunction
function [23:0] expected_gamma(input [23:0] rgb);
    expected_gamma={display_value(rgb[23:16]),display_value(rgb[15:8]),display_value(rgb[7:0])};
endfunction
reg [23:0] expected[0:16383];
integer queued=0,checked=0,gamma_checked=0,frames=0;
reg [2:0] flags1=0,flags2=0;
always @(posedge clk) begin
    if(!rstn) begin flags1<=0;flags2<=0;end
    else begin flags1<={bv,bh,bs};flags2<=flags1;end
    #1;
    if(rstn) begin
        if({bv,bh,bs} !== {lv,lh,ls}) $fatal(1,"BLC changed data/flag latency");
        for(integer p=0;p<2;p=p+1) begin
            if({gv[p],gh[p],gs[p]} !== flags2) $fatal(1,"Gamma flags not delayed with RGB");
            if(bv) begin
                if(checked>=queued || bd[p*32+:32] !== {8'd0,expected[checked]})
                    $fatal(1,"BLC/WB mismatch pixel=%0d got=%h expected=%h",checked,bd[p*32+:32],expected[checked]);
                checked=checked+1;
            end
            if(gv[p]) begin
                if(gamma_checked>=queued || display_rgb[p*24+:24] !== expected_gamma(expected[gamma_checked]))
                    $fatal(1,"Display gamma mismatch pixel=%0d",gamma_checked);
                gamma_checked=gamma_checked+1;
            end else if(display_rgb[p*24+:24] !== 24'd0) $fatal(1,"Invalid pixels must be black");
        end
    end
end
task send_frame(input integer f);
    integer value;
    begin
        for(integer y=0;y<H/2;y=y+1)
            for(integer x=0;x<W/2;x=x+1) begin
                expected[queued]=expected_pixel(f,y,x,phase);queued=queued+1;
            end
        for(integer y=0;y<H;y=y+1) begin
            for(integer x=0;x<W;x=x+4) begin
                @(negedge clk);hs=1;valid=1;
                if(y==0 && x==0) vs=~vs; // Same-cycle FS plus first word.
                for(integer k=0;k<4;k=k+1) begin
                    value=sample(f,y,x+k);data[(rev?3-k:k)*10+:10]=value[9:0];
                end
                if((x/4+y)%3==0) begin @(negedge clk);valid=0;data=40'hdeadbeef01;end
            end
            @(negedge clk);valid=0;hs=0;
            if(y<H-1)repeat(2)@(negedge clk);
        end
        frames=frames+1;
    end
endtask
initial begin
    #10000000;$fatal(1,"Reference color timeout");
end
initial begin
    repeat(8)@(negedge clk);rstn=1;repeat(8)@(negedge clk);
    for(integer gains=0;gains<5;gains=gains+1) begin
        case(gains)
            0:begin gr=DEFAULT_GAIN;gg=DEFAULT_GAIN;gb=DEFAULT_GAIN;end
            1:begin gr=256;gg=256;gb=256;end
            2:begin gr=280;gg=230;gb=350;end
            3:begin gr=1024;gg=1024;gb=1024;end
            4:begin gr=0;gg=0;gb=0;end
        endcase
        for(integer ph=0;ph<4;ph=ph+1)
            for(integer rv=0;rv<2;rv=rv+1) begin
                phase=ph;rev=rv;
                for(integer f=0;f<10;f=f+1)send_frame(f);
                repeat(12)@(negedge clk);
                if(checked!=queued || gamma_checked!=queued)$fatal(1,"Missing frame tail");
            end
    end
    if(frames!=400 || checked!=12800 || gamma_checked!=12800)$fatal(1,"Coverage incomplete");
    $display("tb_reference_color PASS: 400 frames, 12800 BLC/WB + 12800 gamma pixels; 4 phases, 2 orders, 5 gain sets; black clamp, green average, saturation, gaps, FS/tails, flags");
    $finish;
end
endmodule
