
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2013-2020 Efinix Inc. All rights reserved.
//
// Description:
// FIFO 
//
// Language:  Verilog 2001
//-----------------------------------------------------
// Design Name : fifo
// File Name   : fifo.v
// Function    : Synchronous (single clock) FIFO
//-----------------------------------------------------
module fifo (
clk      , // Clock input
nrst     , // Active low reset
data_in  , // Data input
we       , // Write Enable
re       , // Read enable
data_out , // Data Output
empty    , // FIFO empty
full     , // FIFO full
status_cnt, // Counter Status
underflow_err,
overflow_err,
wr_pointer,
rd_pointer
);    
 
// FIFO constants
parameter DATA_WIDTH = 8;
parameter ADDR_WIDTH = 8;
parameter RAM_DEPTH = (1 << ADDR_WIDTH);
// Port Declarations
input clk ;
input nrst ;
input we ;
input re ;
input [DATA_WIDTH-1:0] data_in ;
output full ;
output empty ;
output [DATA_WIDTH-1:0] data_out ;
//output [ADDR_WIDTH:0] status_cnt;
//output 	      underflow_err;
//output 	      overflow_err;
output reg [ADDR_WIDTH-1:0] wr_pointer;
output reg [ADDR_WIDTH-1:0] rd_pointer;
output reg [ADDR_WIDTH :0]  status_cnt;
output reg 		    underflow_err;
output reg 		    overflow_err;
   

//-----------Internal variables-------------------
//reg [DATA_WIDTH-1:0] data_out ;
wire [DATA_WIDTH-1:0] data_ram ;
   
//-----------Variable assignments---------------
assign full = (status_cnt == (RAM_DEPTH-1));
assign empty = (status_cnt == 0);

   
//-----------Code Start---------------------------
always @ (posedge clk)
begin : WRITE_POINTER
  if (~nrst) begin
    wr_pointer <= 0;
  end else if (we) begin
    wr_pointer <= wr_pointer + 1;
  end
end

always @ (posedge clk)
begin : READ_POINTER
  if (~nrst) begin
    rd_pointer <= 0;
  end else if (re) begin
    rd_pointer <= rd_pointer + 1;
  end
end

/* always  @ (posedge clk)
begin : READ_DATA
  if (~nrst) begin
    data_out <= 0;
  end else if (re) begin
    data_out <= data_ram;
  end
end
 */
assign data_out = data_ram;

always @ (posedge clk)
begin : STATUS_COUNTER
  if (~nrst) begin
    status_cnt <= 0;
  // Read but no write.
  end else if (re && !we 
                && (status_cnt != 0)) begin
    status_cnt <= status_cnt - 1;
  // Write but no read.
  end else if (we && !re 
               && (status_cnt != RAM_DEPTH)) begin
    status_cnt <= status_cnt + 1;
  end
end 

/* Underflow and Overflow error flags */
always @(posedge clk)
     if (~nrst)
       underflow_err <= 0;
     else
       underflow_err <= empty && re;

always @(posedge clk)
     if (~nrst)
       overflow_err <= 0;
     else
       overflow_err <= full && we;

   
vga_buffer #(.DATA_WIDTH(DATA_WIDTH),
	     .ADDR_WIDTH(ADDR_WIDTH),
	     .RAM_DEPTH(RAM_DEPTH)) vga_buffer_in0 (
.mem_wr_clk (clk),
.mem_rd_clk (clk),
.mem_wr_rst_n (nrst),
.mem_rd_rst_n (nrst),						    
.mem_waddr (wr_pointer) , // address_0 input 
.mem_wdata (data_in)    , // data_0 bi-directional
.mem_wr_en (we)         , // write enable
.mem_rd_en (re)         , // Read enable
.mem_raddr (rd_pointer) , // address_q input
.mem_rdata (data_ram)    // data_1 bi-directional
);     

endmodule
