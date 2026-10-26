`timescale 1ns/1ps
// Independent channel stalls, delayed B, byte strobes and four-state checks.
module axi_memory_v07 #(parameter DW=128, AW=32, STALL_PCT=20, RD_LAT=12, WORDS_PER_BANK=131072)(
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
logic [DW-1:0] mem[0:6*WORDS_PER_BANK-1];
function automatic integer index_word(input longint a);
    if((a&262143)>=WORDS_PER_BANK || (a>>18)>=6) $fatal(1,"DDR model bounds %x",a);
    return (a>>18)*WORDS_PER_BANK+(a&262143);
endfunction
 task automatic set_word(input longint a,input [DW-1:0] d); mem[index_word(a)]=d;endtask
int n_wr_burst=0,n_rd_burst=0,n_err=0,n_b_error=0,n_r_error=0;
function automatic bit go(); return $urandom_range(99)>=STALL_PCT; endfunction
function automatic logic [DW-1:0] rd_word(longint a);
    return mem[index_word(a)];
endfunction
int ws=0,rs=0,wb=0,wl=0,rb=0,rl=0,delay_count=0;
longint wa,ra;
always @(posedge clk) begin
    if (!rst_n) begin ws<=0; awready<=0; wready<=0; bvalid<=0; bresp<=0; end
    else case(ws)
        0: begin
            awready<=go()&&!hold_aw;
            if (awvalid&&awready) begin
                if (((^{awaddr,awlen,awsize,awburst,awlock}) === 1'bx) || awsize!=SH ||
                    awburst!==2'b01 || awlock!==0 || awaddr[SH-1:0]!=0 ||
                    (awaddr&4095)+(int'(awlen)+1)*BYTES>4096) $fatal(1,"Invalid AW");
                wa<=awaddr>>SH; wl<=awlen; wb<=0; ws<=1; awready<=0;
            end
        end
        1: begin
            wready<=go()&&!hold_w;
            if (wvalid&&wready) begin
                if (((^{wdata,wstrb,wlast}) === 1'bx) || wlast!==(wb==wl)) $fatal(1,"Invalid W beat %0d/%0d addr=%x data=%x strb=%h last=%b un=%b/%b/%b",wb,wl,wa,wdata,wstrb,wlast,$isunknown(wdata),$isunknown(wstrb),$isunknown(wlast));
                for(int byte_n=0;byte_n<BYTES;byte_n++)
                    if(wstrb[byte_n]) mem[index_word(wa+wb)][byte_n*8+:8]=wdata[byte_n*8+:8];
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
                if(((^{araddr,arlen,arsize,arburst,arlock}) === 1'bx) || arsize!=SH ||
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
// Cycle-to-cycle stability checks, compatible with both Icarus and Questa.
reg stall_aw=0,stall_w=0,stall_ar=0,stall_r=0,stall_b=0;
reg [AW+7:0] prev_aw,prev_ar;
reg [DW+DW/8:0] prev_w;
reg [DW+2:0] prev_r;reg [1:0] prev_b;
always @(posedge clk) begin
 if(rst_n) begin
  if(stall_aw && (!awvalid || {awaddr,awlen}!==prev_aw)) $fatal(1,"AW backpressure");
  if(stall_ar && (!arvalid || {araddr,arlen}!==prev_ar)) $fatal(1,"AR backpressure");
  if(stall_w && (!wvalid || {wdata,wstrb,wlast}!==prev_w)) $fatal(1,"W backpressure");
  if(stall_r && (!rvalid || {rdata,rresp,rlast}!==prev_r)) $fatal(1,"R backpressure");
  if(stall_b && (!bvalid || bresp!==prev_b)) $fatal(1,"B backpressure");
 end
 stall_aw<=rst_n && awvalid && !awready;prev_aw<={awaddr,awlen};
 stall_ar<=rst_n && arvalid && !arready;prev_ar<={araddr,arlen};
 stall_w<=rst_n && wvalid && !wready;prev_w<={wdata,wstrb,wlast};
 stall_r<=rst_n && rvalid && !rready;prev_r<={rdata,rresp,rlast};
 stall_b<=rst_n && bvalid && !bready;prev_b<=bresp;
end
endmodule
