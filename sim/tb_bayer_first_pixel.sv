`timescale 1ns/1ps
// Spatially varying RAW detects a dropped/overwritten first line word, unlike
// flat-field tests. Back-to-back frames leave the old odd-row tail in flight.
module tb_bayer_first_pixel;
localparam W=16,H=8,OW=W/2,OH=H/2;
reg clk=0; always #10 clk=~clk;
reg rstn=0,vs=0,hs=0,valid=0,pix_rev=0;
reg [1:0] bayer=0;
reg [39:0] data=0;
wire o_vs,o_hs,o_valid;
wire [63:0] o_data;
bayer_bin2x2 #(.MAX_IN_WIDTH(W)) dut (
    .clk(clk),.rstn(rstn),.i_bayer(bayer),.i_pix_rev(pix_rev),
    .i_gain_r(16'd256),.i_gain_g(16'd256),.i_gain_b(16'd256),
    .i_vs(vs),.i_hs(hs),.i_valid(valid),.i_data(data),
    .o_vs(o_vs),.o_hs(o_hs),.o_valid(o_valid),.o_data(o_data));
reg [23:0] expected [0:1023];
integer queued=0,checked=0,frames=0;
function automatic integer sample(input integer frame_no,input integer y,input integer x);
    sample=80+(frame_no%4)*100+y*20+x*4;
endfunction
function automatic [23:0] rgb(input integer frame_no,input integer y,input integer x,
                              input integer phase);
    integer px,py,r,g,b;
    begin
        px=phase&1;py=(phase>>1)&1;
        r=sample(frame_no,y*2+py,x*2+px)>>2;
        b=sample(frame_no,y*2+1-py,x*2+1-px)>>2;
        g=(sample(frame_no,y*2+py,x*2+1-px)+
           sample(frame_no,y*2+1-py,x*2+px))>>3;
        rgb={r[7:0],g[7:0],b[7:0]};
    end
endfunction
always @(posedge clk) begin
    #1;
    if(rstn && o_valid) begin
        for(integer p=0;p<2;p++) begin
            if(checked>=queued || o_data[p*32+:32] !== {8'd0,expected[checked]})
                $fatal(1,"First-word/tail mismatch at pixel=%0d got=%h expected=%h",
                       checked,o_data[p*32+:32],expected[checked]);
            checked++;
        end
    end
end
task automatic send_frame(input integer frame_no,input bit coincident_vs);
    integer value;
    begin
        for(integer y=0;y<OH;y++)
            for(integer x=0;x<OW;x++) begin
                expected[queued]=rgb(frame_no,y,x,bayer);queued++;
            end
        for(integer y=0;y<H;y++) begin
            for(integer x=0;x<W;x+=4) begin
                @(negedge clk);hs=1;valid=1;
                if(coincident_vs && y==0 && x==0) vs=~vs;
                for(integer k=0;k<4;k++) begin
                    value=sample(frame_no,y,x+k);
                    data[(pix_rev?3-k:k)*10+:10]=value[9:0];
                end
            end
            @(negedge clk);hs=0;valid=0;
            if(y<H-1) repeat(2) @(negedge clk);
        end
        frames++;
    end
endtask
initial begin
    #1000000;$fatal(1,"tb_bayer_first_pixel timeout");
end
initial begin
    repeat(6) @(negedge clk);rstn=1;
    repeat(6) @(negedge clk);
    for(integer phase=0;phase<4;phase++)
        for(integer reverse=0;reverse<2;reverse++) begin
            bayer=phase;pix_rev=reverse;
            // Adjacent frame boundary while the old odd-row tail is in flight.
            send_frame(frames,1);
            send_frame(frames,1);
            repeat(8) @(negedge clk);
            // Also retain the ordinary VS-before-RAW path.
            vs=~vs;repeat(6) @(negedge clk);
            send_frame(frames,0);
            repeat(8) @(negedge clk);
            if(checked!=queued) $fatal(1,"Missing Bayer output at phase/reverse boundary");
        end
    if(frames!=24 || checked!=768) $fatal(1,"Incorrect directed test coverage");
    $display("tb_bayer_first_pixel PASS: %0d varying frames, %0d pixels, 4 phases x 2 orders, same-cycle FS and tail",frames,checked);
    $finish;
end
endmodule
