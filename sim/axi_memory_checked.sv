`timescale 1ns/1ps
// Independent channel stalls, delayed B, byte strobes and four-state checks.
module axi_memory_checked #(parameter DW=128, AW=32, STALL_PCT=20, RD_LAT=12)(
    input clk, rst_n,
    input [AW-1:0] awaddr, input [7:0] awlen, input [2:0] awsize,
    input [1:0] awburst, input awlock, awvalid, output reg awready=0,
    input [DW-1:0] wdata, input [DW/8-1:0] wstrb,
    input wlast,wvalid, output reg wready=0,
    output reg bvalid=0, output reg [1:0] bresp=0, input bready,
    input [AW-1:0] araddr, input [7:0] arlen, input [2:0] arsize,
    input [1:0] arburst, input arlock, arvalid, output reg arready=0,
    output reg [DW-1:0] rdata=0, output reg rlast=0,rvalid=0,
    output reg [1:0] rresp=0, input rready,
    input hold_aw,hold_w,hold_b,hold_ar,hold_r,
    input inject_b_error, inject_r_error
);
localparam BYTES=DW/8, SH=$clog2(BYTES);
logic [DW-1:0] mem[longint];
int n_wr_burst=0,n_rd_burst=0,n_err=0,n_b_error=0,n_r_error=0;
function automatic bit go(); return $urandom_range(99)>=STALL_PCT; endfunction
function automatic logic [DW-1:0] rd_word(longint a);
    return mem.exists(a) ? mem[a] : {DW{1'bx}};
endfunction
int ws=0,rs=0,wb=0,wl=0,rb=0,rl=0,delay_count=0;
longint wa,ra;
always @(posedge clk) begin
    if (!rst_n) begin ws<=0; awready<=0; wready<=0; bvalid<=0; bresp<=0; end
    else case(ws)
        0: begin
            awready<=go()&&!hold_aw;
            if (awvalid&&awready) begin
                if ($isunknown({awaddr,awlen,awsize,awburst,awlock}) || awsize!=SH ||
                    awburst!==2'b01 || awlock!==0 || awaddr[SH-1:0]!=0 ||
                    (awaddr&4095)+(int'(awlen)+1)*BYTES>4096) $fatal(1,"Invalid AW");
                wa<=awaddr>>SH; wl<=awlen; wb<=0; ws<=1; awready<=0;
            end
        end
        1: begin
            wready<=go()&&!hold_w;
            if (wvalid&&wready) begin
                if ($isunknown({wdata,wstrb,wlast}) || wlast!==(wb==wl)) $fatal(1,"Invalid W beat %0d/%0d",wb,wl);
                for(int byte_n=0;byte_n<BYTES;byte_n++)
                    if(wstrb[byte_n]) mem[wa+wb][byte_n*8+:8]=wdata[byte_n*8+:8];
                if(wb==wl) begin ws<=2; wready<=0; n_wr_burst++; end
                else wb<=wb+1;
            end
        end
        2: begin
            if(!bvalid&&!hold_b) begin bvalid<=1; bresp<=inject_b_error?2'b10:0; end
            if(bvalid&&bready) begin
                if(bresp!=0) n_b_error++;
                bvalid<=0; ws<=0;
            end
        end
    endcase
end
always @(posedge clk) begin
    if(!rst_n) begin rs<=0; arready<=0; rvalid<=0; rlast<=0; rresp<=0; end
    else case(rs)
        0: begin
            arready<=go()&&!hold_ar;
            if(arvalid&&arready) begin
                if($isunknown({araddr,arlen,arsize,arburst,arlock}) || arsize!=SH ||
                   arburst!==2'b01 || arlock!==0 || araddr[SH-1:0]!=0 ||
                   (araddr&4095)+(int'(arlen)+1)*BYTES>4096) $fatal(1,"Invalid AR");
                ra<=araddr>>SH; rl<=arlen; rb<=0;
                delay_count<=RD_LAT; rs<=1; arready<=0;
            end
        end
        1: if(delay_count==0) rs<=2; else delay_count<=delay_count-1;
        2: begin
            if(rvalid&&rready) begin
                if(rresp!=0) n_r_error++;
                rvalid<=0;
                if(rlast) begin rs<=0; rlast<=0; n_rd_burst++; end
                else begin
                    rb<=rb+1;
                    if(go()&&!hold_r) begin
                        rdata<=rd_word(ra+rb+1); rvalid<=1; rlast<=(rb+1==rl);
                        rresp<=inject_r_error?2'b10:0;
                    end
                end
            end else if(!rvalid&&go()&&!hold_r) begin
                rdata<=rd_word(ra+rb); rvalid<=1; rlast<=(rb==rl);
                rresp<=inject_r_error?2'b10:0;
            end
        end
    endcase
end
property stable_aw; @(posedge clk) disable iff(!rst_n)
    awvalid&&!awready |=> awvalid&&$stable({awaddr,awlen,awsize,awburst,awlock}); endproperty
property stable_w; @(posedge clk) disable iff(!rst_n)
    wvalid&&!wready |=> wvalid&&$stable({wdata,wstrb,wlast}); endproperty
property stable_ar; @(posedge clk) disable iff(!rst_n)
    arvalid&&!arready |=> arvalid&&$stable({araddr,arlen,arsize,arburst,arlock}); endproperty
property stable_r; @(posedge clk) disable iff(!rst_n)
    rvalid&&!rready |=> rvalid&&$stable({rdata,rlast,rresp}); endproperty
property stable_b; @(posedge clk) disable iff(!rst_n)
    bvalid&&!bready |=> bvalid&&$stable(bresp); endproperty
assert property(stable_aw) else $fatal(1,"AW changed under backpressure");
assert property(stable_w) else $fatal(1,"W changed under backpressure");
assert property(stable_ar) else $fatal(1,"AR changed under backpressure");
assert property(stable_r) else $fatal(1,"R changed under backpressure");
assert property(stable_b) else $fatal(1,"B changed under backpressure");
endmodule
