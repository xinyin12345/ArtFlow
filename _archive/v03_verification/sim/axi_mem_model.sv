// =============================================================================
// axi_mem_model.sv  --  仿真用 AXI4 从机内存（代替 DDR3 控制器）
//   * 稀疏存储（关联数组），按 128bit 字寻址
//   * 随机反压：awready / wready / arready / rvalid 按 STALL_PCT% 概率插入空拍
//   * 读延迟 RD_LAT 拍
//   * 协议检查：突发跨 4KB、wlast 位置错、INCR 以外的突发类型 -> $error
//   * 同一时刻各方向只接受 1 个未完成事务（frame_buffer 本身就是这样发的）
// =============================================================================
`timescale 1ns/1ps
module axi_mem_model #(
    parameter DW        = 128,
    parameter AW        = 32,
    parameter STALL_PCT = 20,
    parameter RD_LAT    = 12
)(
    input                 clk,
    input                 rst_n,
    // write
    input      [AW-1:0]   awaddr,
    input      [7:0]      awlen,
    input      [1:0]      awburst,
    input                 awvalid,
    output reg            awready = 0,
    input      [DW-1:0]   wdata,
    input                 wlast,
    input                 wvalid,
    output reg            wready = 0,
    output reg            bvalid = 0,
    input                 bready,
    // read
    input      [AW-1:0]   araddr,
    input      [7:0]      arlen,
    input      [1:0]      arburst,
    input                 arvalid,
    output reg            arready = 0,
    output reg [DW-1:0]   rdata = 0,
    output reg            rlast = 0,
    output reg            rvalid = 0,
    input                 rready
);
localparam BYTES = DW / 8;
localparam SH    = $clog2(BYTES);

bit [DW-1:0] mem [longint];

int unsigned n_wr_burst = 0, n_rd_burst = 0, n_wr_beat = 0, n_rd_beat = 0, n_err = 0;

function automatic bit go();
    return ($urandom_range(99) >= STALL_PCT);
endfunction

function automatic bit [DW-1:0] rd_word(longint a);
    if (mem.exists(a)) return mem[a];
    return {BYTES/4{32'hDEAD_BEEF}};
endfunction

// ---------------------------------------------------------------- 写通道
typedef enum {W_IDLE, W_DATA, W_RESP} wst_t;
wst_t        wst = W_IDLE;
longint      w_addr;
int          w_len, w_beat;
int          w_idle = 0;          // W_DATA 状态下连续无数据拍数（检测主机中途放弃突发）

always @(posedge clk) begin
    if (!rst_n) begin
        wst <= W_IDLE; awready <= 0; wready <= 0; bvalid <= 0;
    end else begin
        case (wst)
        W_IDLE: begin
            wready <= 0;
            if (awvalid && awready) begin
                awready <= 0;
                w_addr  <= awaddr >> SH;
                w_len   <= awlen;
                w_beat  <= 0;
                if ($test$plusargs("axi_log")) $display("[%0t] AW addr=%h len=%0d", $time, awaddr, awlen);
                if (awburst != 2'b01) begin n_err++; $error("AXI AW: burst type %0d", awburst); end
                if ((awaddr & 12'hFFF) + (awlen + 1) * BYTES > 4096) begin
                    n_err++; $error("AXI AW: burst crosses 4KB  addr=%h len=%0d", awaddr, awlen);
                end
                if (awaddr[SH-1:0] != 0) begin n_err++; $error("AXI AW: unaligned addr %h", awaddr); end
                wst    <= W_DATA;
                wready <= go();
            end else
                awready <= go();
        end
        W_DATA: begin
            w_idle <= (wvalid && wready) ? 0 : w_idle + 1;
            if (w_idle == 5000) begin
                n_err++;
                $error("AXI W: master abandoned write burst (addr=%h, %0d of %0d beats received)",
                       w_addr << SH, w_beat, w_len + 1);
            end
            if (wvalid && wready) begin
                mem[w_addr + w_beat] = wdata;
                n_wr_beat++;
                if (wlast != (w_beat == w_len)) begin
                    n_err++; $error("AXI W: wlast=%0d at beat %0d of %0d", wlast, w_beat, w_len);
                end
                if (w_beat == w_len) begin
                    wst    <= W_RESP;
                    wready <= 0;
                    bvalid <= 1;
                    n_wr_burst++;
                end else begin
                    w_beat <= w_beat + 1;
                    wready <= go();
                end
            end else
                wready <= go();
        end
        W_RESP: if (bvalid && bready) begin
            bvalid <= 0;
            wst    <= W_IDLE;
        end
        endcase
    end
end

// ---------------------------------------------------------------- 读通道
typedef enum {R_IDLE, R_WAIT, R_DATA} rst_t;
rst_t        rst = R_IDLE;
longint      r_addr;
int          r_len, r_beat, r_wait;

always @(posedge clk) begin
    if (!rst_n) begin
        rst <= R_IDLE; arready <= 0; rvalid <= 0; rlast <= 0;
    end else begin
        case (rst)
        R_IDLE: begin
            if (arvalid && arready) begin
                arready <= 0;
                r_addr  <= araddr >> SH;
                r_len   <= arlen;
                r_beat  <= 0;
                r_wait  <= RD_LAT;
                if ($test$plusargs("axi_log")) $display("[%0t] AR addr=%h len=%0d", $time, araddr, arlen);
                if (arburst != 2'b01) begin n_err++; $error("AXI AR: burst type %0d", arburst); end
                if ((araddr & 12'hFFF) + (arlen + 1) * BYTES > 4096) begin
                    n_err++; $error("AXI AR: burst crosses 4KB  addr=%h len=%0d", araddr, arlen);
                end
                rst <= R_WAIT;
            end else
                arready <= go();
        end
        R_WAIT: begin
            if (r_wait == 0) rst <= R_DATA;
            else             r_wait <= r_wait - 1;
        end
        R_DATA: begin
            if (rvalid && rready) begin
                n_rd_beat++;
                if (rlast) begin
                    rvalid <= 0; rlast <= 0;
                    rst    <= R_IDLE;
                    n_rd_burst++;
                end else begin
                    r_beat <= r_beat + 1;
                    if (go()) begin
                        rvalid <= 1;
                        rdata  <= rd_word(r_addr + r_beat + 1);
                        rlast  <= (r_beat + 1 == r_len);
                    end else
                        rvalid <= 0;
                end
            end else if (!rvalid && go()) begin
                rvalid <= 1;
                rdata  <= rd_word(r_addr + r_beat);
                rlast  <= (r_beat == r_len);
            end
        end
        endcase
    end
end

endmodule
