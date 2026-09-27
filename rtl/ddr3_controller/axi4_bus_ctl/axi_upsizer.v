//***************************************************************/
//   ______   _   _   _                  _            _
//  |  ____| | | (_) | |                | |          | |
//  | |__    | |  _  | |_    ___   ___  | |_    ___  | | __
//  |  __|   | | | | | __|  / _ \ / __| | __|  / _ \ | |/ /
//  | |____  | | | | | |_  |  __/ \__ \ | |_  |  __/ |   <  
//  |______| |_| |_|  \__|  \___| |___/  \__|  \___| |_|\_\
//
// Moudel Name    : axi_upsizer.v
// Version        : 1.0
// Date Created   : 2023-02-23 10:37:59
// Last Modified  : 2023-02-24 15:27:41
// Abstract       : ---
//
//Copyright (c) 2020-2023 Elitestek,Inc. All Rights Reserved.
//
//***************************************************************/
//Modification History
//1.initial
//***************************************************************/

`timescale 1ps/1ps
`default_nettype none

module axi_upsizer #
  (
   parameter         C_FAMILY                         = "rtl", 
                       // FPGA Family. Current version: virtex6 or spartan6.
   parameter integer C_AXI_ID_WIDTH                 = 4, 
                       // Width of all ID signals on SI and MI side of converter.
                       // Range: >= 1.
   parameter integer C_AXI_ADDR_WIDTH                 = 32, 
                       // Width of all ADDR signals on SI and MI side of converter.
                       // Range: 32.
   parameter         C_S_AXI_DATA_WIDTH               = 32'h00000020, 
                       // Width of S_AXI_WDATA and S_AXI_RDATA.
                       // Format: Bit32; 
                       // Range: 'h00000020, 'h00000040, 'h00000080, 'h00000100.
   parameter         C_M_AXI_DATA_WIDTH               = 32'h00000040, 
                       // Width of M_AXI_WDATA and M_AXI_RDATA.
                       // Assume greater than or equal to C_S_AXI_DATA_WIDTH.
                       // Format: Bit32;
                       // Range: 'h00000020, 'h00000040, 'h00000080, 'h00000100.
   parameter integer C_M_AXI_AW_REGISTER              = 0,
                       // Simple register AW output.
                       // Range: 0, 1
   parameter integer C_M_AXI_W_REGISTER               = 1,  // Parameter not used; W reg always implemented.
   parameter integer C_M_AXI_AR_REGISTER              = 0,
                       // Simple register AR output.
                       // Range: 0, 1
   parameter integer C_S_AXI_R_REGISTER               = 0,
                       // Simple register R output (SI).
                       // Range: 0, 1
   parameter integer C_M_AXI_R_REGISTER               = 1,
                       // Register slice on R input (MI) side.
                       // 0 = Bypass (not recommended due to combinatorial M_RVALID -> M_RREADY path)
                       // 1 = Fully-registered (needed only when upsizer propagates bursts at 1:1 width ratio)
                       // 7 = Light-weight (safe when upsizer always packs at 1:n width ratio, as in interconnect)
   parameter integer C_AXI_SUPPORTS_USER_SIGNALS      = 0,
                       // 1 = Propagate all USER signals, 0 = Don抰 propagate.
   parameter integer C_AXI_AWUSER_WIDTH               = 1,
                       // Width of AWUSER signals. 
                       // Range: >= 1.
   parameter integer C_AXI_ARUSER_WIDTH               = 1,
                       // Width of ARUSER signals. 
                       // Range: >= 1.
   parameter integer C_AXI_WUSER_WIDTH                = 1,
                       // Width of WUSER signals. 
                       // Range: >= 1.
   parameter integer C_AXI_RUSER_WIDTH                = 1,
                       // Width of RUSER signals. 
                       // Range: >= 1.
   parameter integer C_AXI_BUSER_WIDTH                = 1,
                       // Width of BUSER signals. 
                       // Range: >= 1.
   parameter integer C_AXI_SUPPORTS_WRITE             = 1,
   parameter integer C_AXI_SUPPORTS_READ              = 1,
   parameter integer C_PACKING_LEVEL                    = 1,
                       // 0 = Never pack (expander only); packing logic is omitted.
                       // 1 = Pack only when CACHE[1] (Modifiable) is high.
                       // 2 = Always pack, regardless of sub-size transaction or Modifiable bit.
                       //     (Required when used as helper-core by mem-con. Same size AXI interfaces
                       //      should only be used when always packing)
   parameter integer C_SUPPORT_BURSTS                 = 1,
                       // Disabled when all connected masters and slaves are AxiLite,
                       //   allowing logic to be simplified.
   parameter integer C_SINGLE_THREAD                  = 1
                       // 0 = Ignore ID when propagating transactions (assume all responses are in order).
                       // 1 = Allow multiple outstanding transactions only if the IDs are the same
                       //   to prevent response reordering.
                       //   (If ID mismatches, stall until outstanding transaction counter = 0.)
   )
  (
   // Global Signals
   input  wire                                                    ARESETN,
   input  wire                                                    ACLK,

   // Slave Interface Write Address Ports
   input  wire [C_AXI_ID_WIDTH-1:0]             S_AXI_AWID,
   input  wire [C_AXI_ADDR_WIDTH-1:0]           S_AXI_AWADDR,
   input  wire [8-1:0]                          S_AXI_AWLEN,
   input  wire [3-1:0]                          S_AXI_AWSIZE,
   input  wire [2-1:0]                          S_AXI_AWBURST,
   input  wire [2-1:0]                          S_AXI_AWLOCK,
   input  wire [4-1:0]                          S_AXI_AWCACHE,
   input  wire [3-1:0]                          S_AXI_AWPROT,
   input  wire [4-1:0]                          S_AXI_AWREGION,
   input  wire [4-1:0]                          S_AXI_AWQOS,
   input  wire [C_AXI_AWUSER_WIDTH-1:0]         S_AXI_AWUSER,
   input  wire                                  S_AXI_AWVALID,
   output wire                                  S_AXI_AWREADY,
   // Slave Interface Write Data Ports
   input  wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_WDATA,
   input  wire [C_S_AXI_DATA_WIDTH/8-1:0]       S_AXI_WSTRB,
   input  wire                                  S_AXI_WLAST,
   input  wire [C_AXI_WUSER_WIDTH-1:0]          S_AXI_WUSER,
   input  wire                                  S_AXI_WVALID,
   output wire                                  S_AXI_WREADY,
   // Slave Interface Write Response Ports
   output wire [C_AXI_ID_WIDTH-1:0]             S_AXI_BID,
   output wire [2-1:0]                          S_AXI_BRESP,
   output wire [C_AXI_BUSER_WIDTH-1:0]          S_AXI_BUSER,
   output wire                                  S_AXI_BVALID,
   input  wire                                  S_AXI_BREADY,
   // Slave Interface Read Address Ports
   input  wire [C_AXI_ID_WIDTH-1:0]             S_AXI_ARID,
   input  wire [C_AXI_ADDR_WIDTH-1:0]           S_AXI_ARADDR,
   input  wire [8-1:0]                          S_AXI_ARLEN,
   input  wire [3-1:0]                          S_AXI_ARSIZE,
   input  wire [2-1:0]                          S_AXI_ARBURST,
   input  wire [2-1:0]                          S_AXI_ARLOCK,
   input  wire [4-1:0]                          S_AXI_ARCACHE,
   input  wire [3-1:0]                          S_AXI_ARPROT,
   input  wire [4-1:0]                          S_AXI_ARREGION,
   input  wire [4-1:0]                          S_AXI_ARQOS,
   input  wire [C_AXI_ARUSER_WIDTH-1:0]         S_AXI_ARUSER,
   input  wire                                  S_AXI_ARVALID,
   output wire                                  S_AXI_ARREADY,
   // Slave Interface Read Data Ports
   output wire [C_AXI_ID_WIDTH-1:0]             S_AXI_RID,
   output wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_RDATA,
   output wire [2-1:0]                          S_AXI_RRESP,
   output wire                                  S_AXI_RLAST,
   output wire [C_AXI_RUSER_WIDTH-1:0]          S_AXI_RUSER,
   output wire                                  S_AXI_RVALID,
   input  wire                                  S_AXI_RREADY,

   // Master Interface Write Address Port
   output wire [C_AXI_ID_WIDTH-1:0]          M_AXI_AWID,
   output wire [C_AXI_ADDR_WIDTH-1:0]          M_AXI_AWADDR,
   output wire [8-1:0]                         M_AXI_AWLEN,
   output wire [3-1:0]                         M_AXI_AWSIZE,
   output wire [2-1:0]                         M_AXI_AWBURST,
   output wire [2-1:0]                         M_AXI_AWLOCK,
   output wire [4-1:0]                         M_AXI_AWCACHE,
   output wire [3-1:0]                         M_AXI_AWPROT,
   output wire [4-1:0]                         M_AXI_AWREGION,
   output wire [4-1:0]                         M_AXI_AWQOS,
   output wire [C_AXI_AWUSER_WIDTH-1:0]        M_AXI_AWUSER,
   output wire                                                   M_AXI_AWVALID,
   input  wire                                                   M_AXI_AWREADY,
   // Master Interface Write Data Ports
   output wire [C_M_AXI_DATA_WIDTH-1:0]    M_AXI_WDATA,
   output wire [C_M_AXI_DATA_WIDTH/8-1:0]  M_AXI_WSTRB,
   output wire                                                   M_AXI_WLAST,
   output wire [C_AXI_WUSER_WIDTH-1:0]         M_AXI_WUSER,
   output wire                                                   M_AXI_WVALID,
   input  wire                                                   M_AXI_WREADY,
   // Master Interface Write Response Ports
   input  wire [C_AXI_ID_WIDTH-1:0]          M_AXI_BID,
   input  wire [2-1:0]                         M_AXI_BRESP,
   input  wire [C_AXI_BUSER_WIDTH-1:0]         M_AXI_BUSER,
   input  wire                                                   M_AXI_BVALID,
   output wire                                                   M_AXI_BREADY,
   // Master Interface Read Address Port
   output wire [C_AXI_ID_WIDTH-1:0]          M_AXI_ARID,
   output wire [C_AXI_ADDR_WIDTH-1:0]          M_AXI_ARADDR,
   output wire [8-1:0]                         M_AXI_ARLEN,
   output wire [3-1:0]                         M_AXI_ARSIZE,
   output wire [2-1:0]                         M_AXI_ARBURST,
   output wire [2-1:0]                         M_AXI_ARLOCK,
   output wire [4-1:0]                         M_AXI_ARCACHE,
   output wire [3-1:0]                         M_AXI_ARPROT,
   output wire [4-1:0]                         M_AXI_ARREGION,
   output wire [4-1:0]                         M_AXI_ARQOS,
   output wire [C_AXI_ARUSER_WIDTH-1:0]        M_AXI_ARUSER,
   output wire                                                   M_AXI_ARVALID,
   input  wire                                                   M_AXI_ARREADY,
   // Master Interface Read Data Ports
   input  wire [C_AXI_ID_WIDTH-1:0]          M_AXI_RID,
   input  wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_RDATA,
   input  wire [2-1:0]                       M_AXI_RRESP,
   input  wire                               M_AXI_RLAST,
   input  wire [C_AXI_RUSER_WIDTH-1:0]       M_AXI_RUSER,
   input  wire                               M_AXI_RVALID,
   output wire                               M_AXI_RREADY
   );

   
  /////////////////////////////////////////////////////////////////////////////
  // Functions
  /////////////////////////////////////////////////////////////////////////////
  
  // Log2.
  function integer log2;
    input integer value;
  begin
    for (log2=0; value>1; log2=log2+1) begin
      value = value >> 1;
    end
  end
  endfunction
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Local params
  /////////////////////////////////////////////////////////////////////////////
  
  // Log2 of number of 32bit word on SI-side.
  localparam integer C_S_AXI_BYTES_LOG                = log2(C_S_AXI_DATA_WIDTH/8);
  
  // Log2 of number of 32bit word on MI-side.
  localparam integer C_M_AXI_BYTES_LOG                = log2(C_M_AXI_DATA_WIDTH/8);
  
  // Log2 of Up-Sizing ratio for data.
  localparam integer C_RATIO                          = C_M_AXI_DATA_WIDTH / C_S_AXI_DATA_WIDTH;
  localparam integer C_RATIO_LOG                      = log2(C_RATIO);
  localparam P_BYPASS = 32'h0;
  localparam P_LIGHTWT = 32'h7;
  localparam P_FWD_REV = 32'h1;
  
  /////////////////////////////////////////////////////////////////////////////
  // Internal signals
  /////////////////////////////////////////////////////////////////////////////
  
  wire [C_AXI_ID_WIDTH-1:0]          sr_AWID      ;   
  wire [C_AXI_ADDR_WIDTH-1:0]        sr_AWADDR    ;   
  wire [8-1:0]                       sr_AWLEN     ;   
  wire [3-1:0]                       sr_AWSIZE    ;   
  wire [2-1:0]                       sr_AWBURST   ;   
  wire [2-1:0]                       sr_AWLOCK    ;   
  wire [4-1:0]                       sr_AWCACHE   ;   
  wire [3-1:0]                       sr_AWPROT    ;   
  wire [4-1:0]                       sr_AWREGION  ;   
  wire [4-1:0]                       sr_AWQOS     ;   
  wire [C_AXI_AWUSER_WIDTH-1:0]      sr_AWUSER    ;   
  wire                               sr_AWVALID   ;   
  wire                               sr_AWREADY   ;   
  wire [C_AXI_ID_WIDTH-1:0]          sr_ARID      ;    
  wire [C_AXI_ADDR_WIDTH-1:0]        sr_ARADDR    ;    
  wire [8-1:0]                       sr_ARLEN     ;    
  wire [3-1:0]                       sr_ARSIZE    ;    
  wire [2-1:0]                       sr_ARBURST   ;    
  wire [2-1:0]                       sr_ARLOCK    ;    
  wire [4-1:0]                       sr_ARCACHE   ;    
  wire [3-1:0]                       sr_ARPROT    ;    
  wire [4-1:0]                       sr_ARREGION  ;    
  wire [4-1:0]                       sr_ARQOS     ;    
  wire [C_AXI_ARUSER_WIDTH-1:0]      sr_ARUSER    ;    
  wire                               sr_ARVALID   ;    
  wire                               sr_ARREADY   ;    
  
  wire [C_S_AXI_DATA_WIDTH-1:0]      sr_WDATA     ;
  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]  sr_WSTRB     ;
  wire                               sr_WLAST     ;
  wire                               sr_WVALID    ;
  wire                               sr_WREADY    ;
  
  wire [C_AXI_ID_WIDTH-1:0]          mr_RID       ;  
  wire [C_M_AXI_DATA_WIDTH-1:0]      mr_RDATA     ;  
  wire [2-1:0]                       mr_RRESP     ;  
  wire                               mr_RLAST     ;  
  wire [C_AXI_RUSER_WIDTH-1:0]       mr_RUSER     ;  
  wire                               mr_RVALID    ;  
  wire                               mr_RREADY    ;   
  (* max_fanout = 100 *) reg ARESET ;
  
  assign M_AXI_WUSER   = {C_AXI_WUSER_WIDTH{1'b0}};
  assign S_AXI_RUSER   = {C_AXI_RUSER_WIDTH{1'b0}};

    axi_register_slice #
      (
        .C_FAMILY                         (C_FAMILY),
        .C_AXI_ID_WIDTH                   (C_AXI_ID_WIDTH),
        .C_AXI_ADDR_WIDTH                 (C_AXI_ADDR_WIDTH),
        .C_AXI_DATA_WIDTH                 (C_S_AXI_DATA_WIDTH),
        .C_AXI_SUPPORTS_USER_SIGNALS      (C_AXI_SUPPORTS_USER_SIGNALS),
        .C_AXI_AWUSER_WIDTH               (C_AXI_AWUSER_WIDTH),
        .C_AXI_ARUSER_WIDTH               (C_AXI_ARUSER_WIDTH),
        .C_REG_CONFIG_AW                  (C_AXI_SUPPORTS_WRITE ? P_LIGHTWT : P_BYPASS),
        .C_REG_CONFIG_AR                  (C_AXI_SUPPORTS_READ ? P_LIGHTWT : P_BYPASS)
      )
      si_register_slice_inst 
      (
        .ARESETN                          (ARESETN),
        .ACLK                             (ACLK),
        .S_AXI_AWID                       (S_AXI_AWID     ),
        .S_AXI_AWADDR                     (S_AXI_AWADDR   ),
        .S_AXI_AWLEN                      (S_AXI_AWLEN    ),
        .S_AXI_AWSIZE                     (S_AXI_AWSIZE   ),
        .S_AXI_AWBURST                    (S_AXI_AWBURST  ),
        .S_AXI_AWLOCK                     (S_AXI_AWLOCK   ),
        .S_AXI_AWCACHE                    (S_AXI_AWCACHE  ),
        .S_AXI_AWPROT                     (S_AXI_AWPROT   ),
        .S_AXI_AWREGION                   (S_AXI_AWREGION ),
        .S_AXI_AWQOS                      (S_AXI_AWQOS    ),
        .S_AXI_AWUSER                     (S_AXI_AWUSER   ),
        .S_AXI_AWVALID                    (S_AXI_AWVALID  ),
        .S_AXI_AWREADY                    (S_AXI_AWREADY  ),
        .S_AXI_WID                        ( {C_AXI_ID_WIDTH{1'b0}}),
        .S_AXI_WDATA                      ( {C_S_AXI_DATA_WIDTH{1'b0}}    ),
        .S_AXI_WSTRB                      ( {C_S_AXI_DATA_WIDTH/8{1'b0}}  ),
        .S_AXI_WLAST                      ( 1'b0 ),
        .S_AXI_WUSER                      ( 1'b0  ),
        .S_AXI_WVALID                     ( 1'b0 ),
        .S_AXI_WREADY                     ( ),
        .S_AXI_BID                        ( ),
        .S_AXI_BRESP                      ( ),
        .S_AXI_BUSER                      ( ),
        .S_AXI_BVALID                     ( ),
        .S_AXI_BREADY                     ( 1'b0 ),
        .S_AXI_ARID                       (S_AXI_ARID     ),
        .S_AXI_ARADDR                     (S_AXI_ARADDR   ),
        .S_AXI_ARLEN                      (S_AXI_ARLEN    ),
        .S_AXI_ARSIZE                     (S_AXI_ARSIZE   ),
        .S_AXI_ARBURST                    (S_AXI_ARBURST  ),
        .S_AXI_ARLOCK                     (S_AXI_ARLOCK   ),
        .S_AXI_ARCACHE                    (S_AXI_ARCACHE  ),
        .S_AXI_ARPROT                     (S_AXI_ARPROT   ),
        .S_AXI_ARREGION                   (S_AXI_ARREGION ),
        .S_AXI_ARQOS                      (S_AXI_ARQOS    ),
        .S_AXI_ARUSER                     (S_AXI_ARUSER   ),
        .S_AXI_ARVALID                    (S_AXI_ARVALID  ),
        .S_AXI_ARREADY                    (S_AXI_ARREADY  ),
        .S_AXI_RID                        ( ) ,
        .S_AXI_RDATA                      ( ) ,
        .S_AXI_RRESP                      ( ) ,
        .S_AXI_RLAST                      ( ) ,
        .S_AXI_RUSER                      ( ) ,
        .S_AXI_RVALID                     ( ) ,
        .S_AXI_RREADY                     ( 1'b0 ) ,
        .M_AXI_AWID                       (sr_AWID     ),
        .M_AXI_AWADDR                     (sr_AWADDR   ),
        .M_AXI_AWLEN                      (sr_AWLEN    ),
        .M_AXI_AWSIZE                     (sr_AWSIZE   ),
        .M_AXI_AWBURST                    (sr_AWBURST  ),
        .M_AXI_AWLOCK                     (sr_AWLOCK   ),
        .M_AXI_AWCACHE                    (sr_AWCACHE  ),
        .M_AXI_AWPROT                     (sr_AWPROT   ),
        .M_AXI_AWREGION                   (sr_AWREGION ),
        .M_AXI_AWQOS                      (sr_AWQOS    ),
        .M_AXI_AWUSER                     (sr_AWUSER   ),
        .M_AXI_AWVALID                    (sr_AWVALID  ),
        .M_AXI_AWREADY                    (sr_AWREADY  ),
        .M_AXI_WID                        () ,
        .M_AXI_WDATA                      (),
        .M_AXI_WSTRB                      (),
        .M_AXI_WLAST                      (),
        .M_AXI_WUSER                      (),
        .M_AXI_WVALID                     (),
        .M_AXI_WREADY                     (1'b0),
        .M_AXI_BID                        ( {C_AXI_ID_WIDTH{1'b0}} ) ,
        .M_AXI_BRESP                      ( 2'b0 ) ,
        .M_AXI_BUSER                      ( 1'b0 ) ,
        .M_AXI_BVALID                     ( 1'b0 ) ,
        .M_AXI_BREADY                     ( ) ,
        .M_AXI_ARID                       (sr_ARID     ),
        .M_AXI_ARADDR                     (sr_ARADDR   ),
        .M_AXI_ARLEN                      (sr_ARLEN    ),
        .M_AXI_ARSIZE                     (sr_ARSIZE   ),
        .M_AXI_ARBURST                    (sr_ARBURST  ),
        .M_AXI_ARLOCK                     (sr_ARLOCK   ),
        .M_AXI_ARCACHE                    (sr_ARCACHE  ),
        .M_AXI_ARPROT                     (sr_ARPROT   ),
        .M_AXI_ARREGION                   (sr_ARREGION ),
        .M_AXI_ARQOS                      (sr_ARQOS    ),
        .M_AXI_ARUSER                     (sr_ARUSER   ),
        .M_AXI_ARVALID                    (sr_ARVALID  ),
        .M_AXI_ARREADY                    (sr_ARREADY  ),
        .M_AXI_RID                        ( {C_AXI_ID_WIDTH{1'b0}}),
        .M_AXI_RDATA                      ( {C_S_AXI_DATA_WIDTH{1'b0}}    ),
        .M_AXI_RRESP                      ( 2'b00 ),
        .M_AXI_RLAST                      ( 1'b0  ),
        .M_AXI_RUSER                      ( 1'b0  ),
        .M_AXI_RVALID                     ( 1'b0  ),
        .M_AXI_RREADY                     (  )
      );
  
    axi_register_slice #
      (
        .C_FAMILY                         (C_FAMILY),
        .C_AXI_ID_WIDTH                   (C_AXI_ID_WIDTH),
        .C_AXI_ADDR_WIDTH                 (C_AXI_ADDR_WIDTH),
        .C_AXI_DATA_WIDTH                 (C_M_AXI_DATA_WIDTH),
        .C_AXI_SUPPORTS_USER_SIGNALS      (C_AXI_SUPPORTS_USER_SIGNALS),
        .C_AXI_RUSER_WIDTH                (C_AXI_RUSER_WIDTH),
        .C_REG_CONFIG_R                   (C_AXI_SUPPORTS_READ ? C_M_AXI_R_REGISTER : P_BYPASS)
      )
      mi_register_slice_inst 
      (
        .ARESETN                          (ARESETN),
        .ACLK                             (ACLK),
        .S_AXI_AWID                       ({C_AXI_ID_WIDTH{1'b0}}     ),
        .S_AXI_AWADDR                     ( {C_AXI_ADDR_WIDTH{1'b0}} ),
        .S_AXI_AWLEN                      ( 8'b0 ),
        .S_AXI_AWSIZE                     ( 3'b0 ),
        .S_AXI_AWBURST                    ( 2'b0 ),
        .S_AXI_AWLOCK                     ( 2'b0 ),
        .S_AXI_AWCACHE                    ( 4'b0 ),
        .S_AXI_AWPROT                     ( 3'b0 ),
        .S_AXI_AWREGION                   ( 4'b0 ),
        .S_AXI_AWQOS                      ( 4'b0 ),
        .S_AXI_AWUSER                     ( 1'b0 ),
        .S_AXI_AWVALID                    ( 1'b0 ),
        .S_AXI_AWREADY                    (     ),
        .S_AXI_WID                        ( {C_AXI_ID_WIDTH{1'b0}}),
        .S_AXI_WDATA                      ( {C_M_AXI_DATA_WIDTH{1'b0}}  ),
        .S_AXI_WSTRB                      ( {C_M_AXI_DATA_WIDTH/8{1'b0}}  ),
        .S_AXI_WLAST                      ( 1'b0 ),
        .S_AXI_WUSER                      ( 1'b0  ),
        .S_AXI_WVALID                     ( 1'b0 ),
        .S_AXI_WREADY                     ( ),
        .S_AXI_BID                        ( ),
        .S_AXI_BRESP                      ( ),
        .S_AXI_BUSER                      ( ),
        .S_AXI_BVALID                     ( ),
        .S_AXI_BREADY                     ( 1'b0 ),
        .S_AXI_ARID                       ({C_AXI_ID_WIDTH{1'b0}}     ),
        .S_AXI_ARADDR                     ( {C_AXI_ADDR_WIDTH{1'b0}} ),
        .S_AXI_ARLEN                      ( 8'b0 ),
        .S_AXI_ARSIZE                     ( 3'b0 ),
        .S_AXI_ARBURST                    ( 2'b0 ),
        .S_AXI_ARLOCK                     ( 2'b0 ),
        .S_AXI_ARCACHE                    ( 4'b0 ),
        .S_AXI_ARPROT                     ( 3'b0 ),
        .S_AXI_ARREGION                   ( 4'b0 ),
        .S_AXI_ARQOS                      ( 4'b0 ),
        .S_AXI_ARUSER                     ( 1'b0 ),
        .S_AXI_ARVALID                    ( 1'b0 ),
        .S_AXI_ARREADY                    (     ),
        .S_AXI_RID                        (mr_RID       ),
        .S_AXI_RDATA                      (mr_RDATA     ),
        .S_AXI_RRESP                      (mr_RRESP     ),
        .S_AXI_RLAST                      (mr_RLAST     ),
        .S_AXI_RUSER                      (mr_RUSER     ),
        .S_AXI_RVALID                     (mr_RVALID    ),
        .S_AXI_RREADY                     (mr_RREADY    ),
        .M_AXI_AWID                       (),
        .M_AXI_AWADDR                     (),
        .M_AXI_AWLEN                      (),
        .M_AXI_AWSIZE                     (),
        .M_AXI_AWBURST                    (),
        .M_AXI_AWLOCK                     (),
        .M_AXI_AWCACHE                    (),
        .M_AXI_AWPROT                     (),
        .M_AXI_AWREGION                   (),
        .M_AXI_AWQOS                      (),
        .M_AXI_AWUSER                     (),
        .M_AXI_AWVALID                    (),
        .M_AXI_AWREADY                    (1'b0),
        .M_AXI_WID                        () ,
        .M_AXI_WDATA                      (),
        .M_AXI_WSTRB                      (),
        .M_AXI_WLAST                      (),
        .M_AXI_WUSER                      (),
        .M_AXI_WVALID                     (),
        .M_AXI_WREADY                     (1'b0),
        .M_AXI_BID                        ( {C_AXI_ID_WIDTH{1'b0}} ) ,
        .M_AXI_BRESP                      ( 2'b0 ) ,
        .M_AXI_BUSER                      ( 1'b0 ) ,
        .M_AXI_BVALID                     ( 1'b0 ) ,
        .M_AXI_BREADY                     ( ) ,
        .M_AXI_ARID                       (),
        .M_AXI_ARADDR                     (),
        .M_AXI_ARLEN                      (),
        .M_AXI_ARSIZE                     (),
        .M_AXI_ARBURST                    (),
        .M_AXI_ARLOCK                     (),
        .M_AXI_ARCACHE                    (),
        .M_AXI_ARPROT                     (),
        .M_AXI_ARREGION                   (),
        .M_AXI_ARQOS                      (),
        .M_AXI_ARUSER                     (),
        .M_AXI_ARVALID                    (),
        .M_AXI_ARREADY                    (1'b0),
        .M_AXI_RID                        (M_AXI_RID    ),
        .M_AXI_RDATA                      (M_AXI_RDATA  ),
        .M_AXI_RRESP                      (M_AXI_RRESP  ),
        .M_AXI_RLAST                      (M_AXI_RLAST  ),
        .M_AXI_RUSER                      (M_AXI_RUSER  ),
        .M_AXI_RVALID                     (M_AXI_RVALID ),
        .M_AXI_RREADY                     (M_AXI_RREADY )
      );
  
  /////////////////////////////////////////////////////////////////////////////
  // Handle Internal Reset
  /////////////////////////////////////////////////////////////////////////////
  always @ (posedge ACLK) begin
    ARESET <= !ARESETN;
  end
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Handle Write Channels (AW/W/B)
  /////////////////////////////////////////////////////////////////////////////
  generate
    if (C_AXI_SUPPORTS_WRITE == 1) begin : USE_WRITE
    
      // Write Channel Signals for Commands Queue Interface.
      wire                              wr_cmd_valid;
      wire                              wr_cmd_fix;
      wire                              wr_cmd_modified;
      wire                              wr_cmd_complete_wrap;
      wire                              wr_cmd_packed_wrap;
      wire [C_M_AXI_BYTES_LOG-1:0]      wr_cmd_first_word;
      wire [C_M_AXI_BYTES_LOG-1:0]      wr_cmd_next_word;
      wire [C_M_AXI_BYTES_LOG-1:0]      wr_cmd_last_word;
      wire [C_M_AXI_BYTES_LOG-1:0]      wr_cmd_offset;
      wire [C_M_AXI_BYTES_LOG-1:0]      wr_cmd_mask;
      wire [C_S_AXI_BYTES_LOG:0]        wr_cmd_step;
      wire [8-1:0]                      wr_cmd_length;
      wire                              wr_cmd_ready;
      
      // Write Address Channel.
      a_upsizer #
      (
       .C_FAMILY                    (C_FAMILY),
       .C_AXI_ID_WIDTH              (C_AXI_ID_WIDTH),
       .C_AXI_ADDR_WIDTH            (C_AXI_ADDR_WIDTH),
       .C_S_AXI_DATA_WIDTH          (C_S_AXI_DATA_WIDTH),
       .C_M_AXI_DATA_WIDTH          (C_M_AXI_DATA_WIDTH),
       .C_M_AXI_REGISTER            (C_M_AXI_AW_REGISTER),
       .C_AXI_SUPPORTS_USER_SIGNALS (C_AXI_SUPPORTS_USER_SIGNALS),
       .C_AXI_AUSER_WIDTH           (C_AXI_AWUSER_WIDTH),
       .C_AXI_CHANNEL               (0),
       .C_PACKING_LEVEL             (C_PACKING_LEVEL),
       .C_SUPPORT_BURSTS            (C_SUPPORT_BURSTS),
       .C_SINGLE_THREAD             (C_SINGLE_THREAD),
       .C_S_AXI_BYTES_LOG           (C_S_AXI_BYTES_LOG),
       .C_M_AXI_BYTES_LOG           (C_M_AXI_BYTES_LOG)
        ) write_addr_inst
       (
        // Global Signals
        .ARESET                     (ARESET),
        .ACLK                       (ACLK),
    
        // Command Interface
        .cmd_valid                  (wr_cmd_valid),
        .cmd_fix                    (wr_cmd_fix),
        .cmd_modified               (wr_cmd_modified),
        .cmd_complete_wrap          (wr_cmd_complete_wrap),
        .cmd_packed_wrap            (wr_cmd_packed_wrap),
        .cmd_first_word             (wr_cmd_first_word),
        .cmd_next_word              (wr_cmd_next_word),
        .cmd_last_word              (wr_cmd_last_word),
        .cmd_offset                 (wr_cmd_offset),
        .cmd_mask                   (wr_cmd_mask),
        .cmd_step                   (wr_cmd_step),
        .cmd_length                 (wr_cmd_length),
        .cmd_ready                  (wr_cmd_ready),
       
        // Slave Interface Write Address Ports
        .S_AXI_AID                  (sr_AWID),
        .S_AXI_AADDR                (sr_AWADDR),
        .S_AXI_ALEN                 (sr_AWLEN),
        .S_AXI_ASIZE                (sr_AWSIZE),
        .S_AXI_ABURST               (sr_AWBURST),
        .S_AXI_ALOCK                (sr_AWLOCK),
        .S_AXI_ACACHE               (sr_AWCACHE),
        .S_AXI_APROT                (sr_AWPROT),
        .S_AXI_AREGION              (sr_AWREGION),
        .S_AXI_AQOS                 (sr_AWQOS),
        .S_AXI_AUSER                (sr_AWUSER),
        .S_AXI_AVALID               (sr_AWVALID),
        .S_AXI_AREADY               (sr_AWREADY),
        
        // Master Interface Write Address Port
        .M_AXI_AID                  (M_AXI_AWID),
        .M_AXI_AADDR                (M_AXI_AWADDR),
        .M_AXI_ALEN                 (M_AXI_AWLEN),
        .M_AXI_ASIZE                (M_AXI_AWSIZE),
        .M_AXI_ABURST               (M_AXI_AWBURST),
        .M_AXI_ALOCK                (M_AXI_AWLOCK),
        .M_AXI_ACACHE               (M_AXI_AWCACHE),
        .M_AXI_APROT                (M_AXI_AWPROT),
        .M_AXI_AREGION              (M_AXI_AWREGION),
        .M_AXI_AQOS                 (M_AXI_AWQOS),
        .M_AXI_AUSER                (M_AXI_AWUSER),
        .M_AXI_AVALID               (M_AXI_AWVALID),
        .M_AXI_AREADY               (M_AXI_AWREADY)
       );
       
      // Write Data channel.
      w_upsizer #
      (
       .C_FAMILY                    (C_FAMILY),
       .C_S_AXI_DATA_WIDTH          (C_S_AXI_DATA_WIDTH),
       .C_M_AXI_DATA_WIDTH          (C_M_AXI_DATA_WIDTH),
       .C_M_AXI_REGISTER            (1),
       .C_AXI_SUPPORTS_USER_SIGNALS (C_AXI_SUPPORTS_USER_SIGNALS),
       .C_AXI_WUSER_WIDTH           (C_AXI_WUSER_WIDTH),
       .C_PACKING_LEVEL             (C_PACKING_LEVEL),
       .C_SUPPORT_BURSTS            (C_SUPPORT_BURSTS),
       .C_S_AXI_BYTES_LOG           (C_S_AXI_BYTES_LOG),
       .C_M_AXI_BYTES_LOG           (C_M_AXI_BYTES_LOG),
       .C_RATIO                     (C_RATIO),
       .C_RATIO_LOG                 (C_RATIO_LOG)
        ) write_data_inst
       (
        // Global Signals
        .ARESET                     (ARESET),
        .ACLK                       (ACLK),
    
        // Command Interface
        .cmd_valid                  (wr_cmd_valid),
        .cmd_fix                    (wr_cmd_fix),
        .cmd_modified               (wr_cmd_modified),
        .cmd_complete_wrap          (wr_cmd_complete_wrap),
        .cmd_packed_wrap            (wr_cmd_packed_wrap),
        .cmd_first_word             (wr_cmd_first_word),
        .cmd_next_word              (wr_cmd_next_word),
        .cmd_last_word              (wr_cmd_last_word),
        .cmd_offset                 (wr_cmd_offset),
        .cmd_mask                   (wr_cmd_mask),
        .cmd_step                   (wr_cmd_step),
        .cmd_length                 (wr_cmd_length),
        .cmd_ready                  (wr_cmd_ready),
       
        // Slave Interface Write Data Ports
        .S_AXI_WDATA                (S_AXI_WDATA),
        .S_AXI_WSTRB                (S_AXI_WSTRB),
        .S_AXI_WLAST                (S_AXI_WLAST),
        .S_AXI_WUSER                (S_AXI_WUSER),
        .S_AXI_WVALID               (S_AXI_WVALID),
        .S_AXI_WREADY               (S_AXI_WREADY),
        
        // Master Interface Write Data Ports
        .M_AXI_WDATA                (M_AXI_WDATA),
        .M_AXI_WSTRB                (M_AXI_WSTRB),
        .M_AXI_WLAST                (M_AXI_WLAST),
        .M_AXI_WUSER                (),
        .M_AXI_WVALID               (M_AXI_WVALID),
        .M_AXI_WREADY               (M_AXI_WREADY)
       );
      
      // Write Response channel.
      assign S_AXI_BID     = M_AXI_BID;
      assign S_AXI_BRESP   = M_AXI_BRESP;
      assign S_AXI_BUSER   = M_AXI_BUSER;
      assign S_AXI_BVALID  = M_AXI_BVALID;
      assign M_AXI_BREADY  = S_AXI_BREADY;
       
    end else begin : NO_WRITE
      assign sr_AWREADY = 1'b0;
      assign S_AXI_WREADY  = 1'b0;
      assign S_AXI_BID     = {C_AXI_ID_WIDTH{1'b0}};
      assign S_AXI_BRESP   = 2'b0;
      assign S_AXI_BUSER   = {C_AXI_BUSER_WIDTH{1'b0}};
      assign S_AXI_BVALID  = 1'b0;
      
      assign M_AXI_AWID    = {C_AXI_ID_WIDTH{1'b0}};
      assign M_AXI_AWADDR  = {C_AXI_ADDR_WIDTH{1'b0}};
      assign M_AXI_AWLEN   = 8'b0;
      assign M_AXI_AWSIZE  = 3'b0;
      assign M_AXI_AWBURST = 2'b0;
      assign M_AXI_AWLOCK  = 2'b0;
      assign M_AXI_AWCACHE = 4'b0;
      assign M_AXI_AWPROT  = 3'b0;
      assign M_AXI_AWQOS   = 4'b0;
      assign M_AXI_AWUSER  = {C_AXI_AWUSER_WIDTH{1'b0}};
      assign M_AXI_AWVALID = 1'b0;
      assign M_AXI_WDATA   = {C_M_AXI_DATA_WIDTH{1'b0}};
      assign M_AXI_WSTRB   = {C_M_AXI_DATA_WIDTH/8{1'b0}};
      assign M_AXI_WLAST   = 1'b0;
      assign M_AXI_WVALID  = 1'b0;
      assign M_AXI_BREADY  = 1'b0;
      
    end
  endgenerate
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Handle Read Channels (AR/R)
  /////////////////////////////////////////////////////////////////////////////
  generate
    if (C_AXI_SUPPORTS_READ == 1) begin : USE_READ
    
      // Read Channel Signals for Commands Queue Interface.
      wire                              rd_cmd_valid;
      wire                              rd_cmd_fix;
      wire                              rd_cmd_modified;
      wire                              rd_cmd_complete_wrap;
      wire                              rd_cmd_packed_wrap;
      wire [C_M_AXI_BYTES_LOG-1:0]      rd_cmd_first_word;
      wire [C_M_AXI_BYTES_LOG-1:0]      rd_cmd_next_word;
      wire [C_M_AXI_BYTES_LOG-1:0]      rd_cmd_last_word;
      wire [C_M_AXI_BYTES_LOG-1:0]      rd_cmd_offset;
      wire [C_M_AXI_BYTES_LOG-1:0]      rd_cmd_mask;
      wire [C_S_AXI_BYTES_LOG:0]        rd_cmd_step;
      wire [8-1:0]                      rd_cmd_length;
      wire                              rd_cmd_ready;
      
      // Write Address Channel.
      a_upsizer #
      (
       .C_FAMILY                    (C_FAMILY),
       .C_AXI_ID_WIDTH              (C_AXI_ID_WIDTH),
       .C_AXI_ADDR_WIDTH            (C_AXI_ADDR_WIDTH),
       .C_S_AXI_DATA_WIDTH          (C_S_AXI_DATA_WIDTH),
       .C_M_AXI_DATA_WIDTH          (C_M_AXI_DATA_WIDTH),
       .C_M_AXI_REGISTER            (C_M_AXI_AR_REGISTER),
       .C_AXI_SUPPORTS_USER_SIGNALS (C_AXI_SUPPORTS_USER_SIGNALS),
       .C_AXI_AUSER_WIDTH           (C_AXI_ARUSER_WIDTH),
       .C_AXI_CHANNEL               (1),
       .C_PACKING_LEVEL             (C_PACKING_LEVEL),
       .C_SUPPORT_BURSTS            (C_SUPPORT_BURSTS),
       .C_SINGLE_THREAD             (C_SINGLE_THREAD),
       .C_S_AXI_BYTES_LOG           (C_S_AXI_BYTES_LOG),
       .C_M_AXI_BYTES_LOG           (C_M_AXI_BYTES_LOG)
        ) read_addr_inst
       (
        // Global Signals
        .ARESET                     (ARESET),
        .ACLK                       (ACLK),
    
        // Command Interface
        .cmd_valid                  (rd_cmd_valid),
        .cmd_fix                    (rd_cmd_fix),
        .cmd_modified               (rd_cmd_modified),
        .cmd_complete_wrap          (rd_cmd_complete_wrap),
        .cmd_packed_wrap            (rd_cmd_packed_wrap),
        .cmd_first_word             (rd_cmd_first_word),
        .cmd_next_word              (rd_cmd_next_word),
        .cmd_last_word              (rd_cmd_last_word),
        .cmd_offset                 (rd_cmd_offset),
        .cmd_mask                   (rd_cmd_mask),
        .cmd_step                   (rd_cmd_step),
        .cmd_length                 (rd_cmd_length),
        .cmd_ready                  (rd_cmd_ready),
       
        // Slave Interface Write Address Ports
        .S_AXI_AID                  (sr_ARID),
        .S_AXI_AADDR                (sr_ARADDR),
        .S_AXI_ALEN                 (sr_ARLEN),
        .S_AXI_ASIZE                (sr_ARSIZE),
        .S_AXI_ABURST               (sr_ARBURST),
        .S_AXI_ALOCK                (sr_ARLOCK),
        .S_AXI_ACACHE               (sr_ARCACHE),
        .S_AXI_APROT                (sr_ARPROT),
        .S_AXI_AREGION              (sr_ARREGION),
        .S_AXI_AQOS                 (sr_ARQOS),
        .S_AXI_AUSER                (sr_ARUSER),
        .S_AXI_AVALID               (sr_ARVALID),
        .S_AXI_AREADY               (sr_ARREADY),
        
        // Master Interface Write Address Port
        .M_AXI_AID                  (M_AXI_ARID),
        .M_AXI_AADDR                (M_AXI_ARADDR),
        .M_AXI_ALEN                 (M_AXI_ARLEN),
        .M_AXI_ASIZE                (M_AXI_ARSIZE),
        .M_AXI_ABURST               (M_AXI_ARBURST),
        .M_AXI_ALOCK                (M_AXI_ARLOCK),
        .M_AXI_ACACHE               (M_AXI_ARCACHE),
        .M_AXI_APROT                (M_AXI_ARPROT),
        .M_AXI_AREGION              (M_AXI_ARREGION),
        .M_AXI_AQOS                 (M_AXI_ARQOS),
        .M_AXI_AUSER                (M_AXI_ARUSER),
        .M_AXI_AVALID               (M_AXI_ARVALID),
        .M_AXI_AREADY               (M_AXI_ARREADY)
       );
       
      // Read Data channel.
      r_upsizer #
      (
       .C_FAMILY                    (C_FAMILY),
       .C_AXI_ID_WIDTH              (C_AXI_ID_WIDTH),
       .C_S_AXI_DATA_WIDTH          (C_S_AXI_DATA_WIDTH),
       .C_M_AXI_DATA_WIDTH          (C_M_AXI_DATA_WIDTH),
       .C_S_AXI_REGISTER            (C_S_AXI_R_REGISTER),
       .C_AXI_SUPPORTS_USER_SIGNALS (C_AXI_SUPPORTS_USER_SIGNALS),
       .C_AXI_RUSER_WIDTH           (C_AXI_RUSER_WIDTH),
       .C_PACKING_LEVEL             (C_PACKING_LEVEL),
       .C_SUPPORT_BURSTS            (C_SUPPORT_BURSTS),
       .C_S_AXI_BYTES_LOG           (C_S_AXI_BYTES_LOG),
       .C_M_AXI_BYTES_LOG           (C_M_AXI_BYTES_LOG),
       .C_RATIO                     (C_RATIO),
       .C_RATIO_LOG                 (C_RATIO_LOG)
        ) read_data_inst
       (
        // Global Signals
        .ARESET                     (ARESET),
        .ACLK                       (ACLK),
    
        // Command Interface
        .cmd_valid                  (rd_cmd_valid),
        .cmd_fix                    (rd_cmd_fix),
        .cmd_modified               (rd_cmd_modified),
        .cmd_complete_wrap          (rd_cmd_complete_wrap),
        .cmd_packed_wrap            (rd_cmd_packed_wrap),
        .cmd_first_word             (rd_cmd_first_word),
        .cmd_next_word              (rd_cmd_next_word),
        .cmd_last_word              (rd_cmd_last_word),
        .cmd_offset                 (rd_cmd_offset),
        .cmd_mask                   (rd_cmd_mask),
        .cmd_step                   (rd_cmd_step),
        .cmd_length                 (rd_cmd_length),
        .cmd_ready                  (rd_cmd_ready),
       
        // Slave Interface Read Data Ports
        .S_AXI_RID                  (S_AXI_RID),
        .S_AXI_RDATA                (S_AXI_RDATA),
        .S_AXI_RRESP                (S_AXI_RRESP),
        .S_AXI_RLAST                (S_AXI_RLAST),
        .S_AXI_RUSER                (),
        .S_AXI_RVALID               (S_AXI_RVALID),
        .S_AXI_RREADY               (S_AXI_RREADY),
        
        // Master Interface Read Data Ports
        .M_AXI_RID                  (mr_RID),
        .M_AXI_RDATA                (mr_RDATA),
        .M_AXI_RRESP                (mr_RRESP),
        .M_AXI_RLAST                (mr_RLAST),
        .M_AXI_RUSER                (mr_RUSER),
        .M_AXI_RVALID               (mr_RVALID),
        .M_AXI_RREADY               (mr_RREADY)
       );
       
    end else begin : NO_READ
      assign sr_ARREADY = 1'b0;
      assign S_AXI_RID     = {C_AXI_ID_WIDTH{1'b0}};
      assign S_AXI_RDATA   = {C_S_AXI_DATA_WIDTH{1'b0}};
      assign S_AXI_RRESP   = 2'b0;
      assign S_AXI_RLAST   = 1'b0;
      assign S_AXI_RVALID  = 1'b0;
      
      assign M_AXI_ARID    = {C_AXI_ID_WIDTH{1'b0}};
      assign M_AXI_ARADDR  = {C_AXI_ADDR_WIDTH{1'b0}};
      assign M_AXI_ARLEN   = 8'b0;
      assign M_AXI_ARSIZE  = 3'b0;
      assign M_AXI_ARBURST = 2'b0;
      assign M_AXI_ARLOCK  = 2'b0;
      assign M_AXI_ARCACHE = 4'b0;
      assign M_AXI_ARPROT  = 3'b0;
      assign M_AXI_ARQOS   = 4'b0;
      assign M_AXI_ARUSER  = {C_AXI_ARUSER_WIDTH{1'b0}};
      assign M_AXI_ARVALID = 1'b0;
      assign mr_RREADY  = 1'b0;
      
    end
  endgenerate
  
  
endmodule
`default_nettype wire










module axi_register_slice #
  (
   parameter C_FAMILY                            = "virtex6",
   parameter integer C_AXI_ID_WIDTH              = 4,
   parameter integer C_AXI_ADDR_WIDTH            = 32,
   parameter integer C_AXI_DATA_WIDTH            = 32,
   parameter integer C_AXI_SUPPORTS_USER_SIGNALS = 0,
   parameter integer C_AXI_AWUSER_WIDTH          = 1,
   parameter integer C_AXI_ARUSER_WIDTH          = 1,
   parameter integer C_AXI_WUSER_WIDTH           = 1,
   parameter integer C_AXI_RUSER_WIDTH           = 1,
   parameter integer C_AXI_BUSER_WIDTH           = 1,
   // C_REG_CONFIG_*:
   //   0 => BYPASS    = The channel is just wired through the module.
   //   1 => FWD_REV   = Both FWD and REV (fully-registered)
   //   2 => FWD       = The master VALID and payload signals are registrated. 
   //   3 => REV       = The slave ready signal is registrated
   //   4 => SLAVE_FWD = All slave side signals and master VALID and payload are registrated.
   //   5 => SLAVE_RDY = All slave side signals and master READY are registrated.
   //   6 => INPUTS    = Slave and Master side inputs are registrated.
   //   7 => LIGHT_WT  = 1-stage pipeline register with bubble cycle, both FWD and REV pipelining
   parameter         C_REG_CONFIG_AW = 32'h00000000,
   parameter         C_REG_CONFIG_W  = 32'h00000000,
   parameter         C_REG_CONFIG_B  = 32'h00000000,
   parameter         C_REG_CONFIG_AR = 32'h00000000,
   parameter         C_REG_CONFIG_R  = 32'h00000000
   )
  (
   // System Signals
   input wire ACLK,
   input wire ARESETN,

   // Slave Interface Write Address Ports
   input  wire [C_AXI_ID_WIDTH-1:0]     S_AXI_AWID,
   input  wire [C_AXI_ADDR_WIDTH-1:0]   S_AXI_AWADDR,
   input  wire [8-1:0]                  S_AXI_AWLEN,
   input  wire [3-1:0]                  S_AXI_AWSIZE,
   input  wire [2-1:0]                  S_AXI_AWBURST,
   input  wire [2-1:0]                  S_AXI_AWLOCK,
   input  wire [4-1:0]                  S_AXI_AWCACHE,
   input  wire [3-1:0]                  S_AXI_AWPROT,
   input  wire [4-1:0]                  S_AXI_AWREGION,
   input  wire [4-1:0]                  S_AXI_AWQOS,
   input  wire [C_AXI_AWUSER_WIDTH-1:0] S_AXI_AWUSER,
   input  wire                          S_AXI_AWVALID,
   output wire                          S_AXI_AWREADY,

   // Slave Interface Write Data Ports
   input wire [C_AXI_ID_WIDTH-1:0]      S_AXI_WID,
   input  wire [C_AXI_DATA_WIDTH-1:0]   S_AXI_WDATA,
   input  wire [C_AXI_DATA_WIDTH/8-1:0] S_AXI_WSTRB,
   input  wire                          S_AXI_WLAST,
   input  wire [C_AXI_WUSER_WIDTH-1:0]  S_AXI_WUSER,
   input  wire                          S_AXI_WVALID,
   output wire                          S_AXI_WREADY,

   // Slave Interface Write Response Ports
   output wire [C_AXI_ID_WIDTH-1:0]    S_AXI_BID,
   output wire [2-1:0]                 S_AXI_BRESP,
   output wire [C_AXI_BUSER_WIDTH-1:0] S_AXI_BUSER,
   output wire                         S_AXI_BVALID,
   input  wire                         S_AXI_BREADY,

   // Slave Interface Read Address Ports
   input  wire [C_AXI_ID_WIDTH-1:0]     S_AXI_ARID,
   input  wire [C_AXI_ADDR_WIDTH-1:0]   S_AXI_ARADDR,
   input  wire [8-1:0]                  S_AXI_ARLEN,
   input  wire [3-1:0]                  S_AXI_ARSIZE,
   input  wire [2-1:0]                  S_AXI_ARBURST,
   input  wire [2-1:0]                  S_AXI_ARLOCK,
   input  wire [4-1:0]                  S_AXI_ARCACHE,
   input  wire [3-1:0]                  S_AXI_ARPROT,
   input  wire [4-1:0]                  S_AXI_ARREGION,
   input  wire [4-1:0]                  S_AXI_ARQOS,
   input  wire [C_AXI_ARUSER_WIDTH-1:0] S_AXI_ARUSER,
   input  wire                          S_AXI_ARVALID,
   output wire                          S_AXI_ARREADY,

   // Slave Interface Read Data Ports
   output wire [C_AXI_ID_WIDTH-1:0]    S_AXI_RID,
   output wire [C_AXI_DATA_WIDTH-1:0]  S_AXI_RDATA,
   output wire [2-1:0]                 S_AXI_RRESP,
   output wire                         S_AXI_RLAST,
   output wire [C_AXI_RUSER_WIDTH-1:0] S_AXI_RUSER,
   output wire                         S_AXI_RVALID,
   input  wire                         S_AXI_RREADY,
   
   // Master Interface Write Address Port
   output wire [C_AXI_ID_WIDTH-1:0]     M_AXI_AWID,
   output wire [C_AXI_ADDR_WIDTH-1:0]   M_AXI_AWADDR,
   output wire [8-1:0]                  M_AXI_AWLEN,
   output wire [3-1:0]                  M_AXI_AWSIZE,
   output wire [2-1:0]                  M_AXI_AWBURST,
   output wire [2-1:0]                  M_AXI_AWLOCK,
   output wire [4-1:0]                  M_AXI_AWCACHE,
   output wire [3-1:0]                  M_AXI_AWPROT,
   output wire [4-1:0]                  M_AXI_AWREGION,
   output wire [4-1:0]                  M_AXI_AWQOS,
   output wire [C_AXI_AWUSER_WIDTH-1:0] M_AXI_AWUSER,
   output wire                          M_AXI_AWVALID,
   input  wire                          M_AXI_AWREADY,
   
   // Master Interface Write Data Ports
   output wire [C_AXI_ID_WIDTH-1:0]     M_AXI_WID,
   output wire [C_AXI_DATA_WIDTH-1:0]   M_AXI_WDATA,
   output wire [C_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
   output wire                          M_AXI_WLAST,
   output wire [C_AXI_WUSER_WIDTH-1:0]  M_AXI_WUSER,
   output wire                          M_AXI_WVALID,
   input  wire                          M_AXI_WREADY,
   
   // Master Interface Write Response Ports
   input  wire [C_AXI_ID_WIDTH-1:0]    M_AXI_BID,
   input  wire [2-1:0]                 M_AXI_BRESP,
   input  wire [C_AXI_BUSER_WIDTH-1:0] M_AXI_BUSER,
   input  wire                         M_AXI_BVALID,
   output wire                         M_AXI_BREADY,
   
   // Master Interface Read Address Port
   output wire [C_AXI_ID_WIDTH-1:0]     M_AXI_ARID,
   output wire [C_AXI_ADDR_WIDTH-1:0]   M_AXI_ARADDR,
   output wire [8-1:0]                  M_AXI_ARLEN,
   output wire [3-1:0]                  M_AXI_ARSIZE,
   output wire [2-1:0]                  M_AXI_ARBURST,
   output wire [2-1:0]                  M_AXI_ARLOCK,
   output wire [4-1:0]                  M_AXI_ARCACHE,
   output wire [3-1:0]                  M_AXI_ARPROT,
   output wire [4-1:0]                  M_AXI_ARREGION,
   output wire [4-1:0]                  M_AXI_ARQOS,
   output wire [C_AXI_ARUSER_WIDTH-1:0] M_AXI_ARUSER,
   output wire                          M_AXI_ARVALID,
   input  wire                          M_AXI_ARREADY,
   
   // Master Interface Read Data Ports
   input  wire [C_AXI_ID_WIDTH-1:0]    M_AXI_RID,
   input  wire [C_AXI_DATA_WIDTH-1:0]  M_AXI_RDATA,
   input  wire [2-1:0]                 M_AXI_RRESP,
   input  wire                         M_AXI_RLAST,
   input  wire [C_AXI_RUSER_WIDTH-1:0] M_AXI_RUSER,
   input  wire                         M_AXI_RVALID,
   output wire                         M_AXI_RREADY
  );

  (* shift_extract="no", iob="false", equivalent_register_removal = "no" *) reg reset;
  always @(posedge ACLK) begin
    reset <= ~ARESETN;
  end

  // Write Address Port bit positions
  localparam C_AWUSER_RIGHT   = 0;
  localparam C_AWUSER_LEN     = C_AXI_SUPPORTS_USER_SIGNALS*C_AXI_AWUSER_WIDTH;
  localparam C_AWQOS_RIGHT    = C_AWUSER_RIGHT + C_AWUSER_LEN;
  localparam C_AWQOS_LEN      = 4;
  localparam C_AWREGION_RIGHT = C_AWQOS_RIGHT + C_AWQOS_LEN;
  localparam C_AWREGION_LEN   = 4;
  localparam C_AWPROT_RIGHT   = C_AWREGION_RIGHT + C_AWREGION_LEN;
  localparam C_AWPROT_LEN     = 3;
  localparam C_AWCACHE_RIGHT  = C_AWPROT_RIGHT + C_AWPROT_LEN;
  localparam C_AWCACHE_LEN    = 4;
  localparam C_AWLOCK_RIGHT   = C_AWCACHE_RIGHT + C_AWCACHE_LEN;
  localparam C_AWLOCK_LEN     = 2;
  localparam C_AWBURST_RIGHT  = C_AWLOCK_RIGHT + C_AWLOCK_LEN;
  localparam C_AWBURST_LEN    = 2;
  localparam C_AWSIZE_RIGHT   = C_AWBURST_RIGHT + C_AWBURST_LEN;
  localparam C_AWSIZE_LEN     = 3;
  localparam C_AWLEN_RIGHT    = C_AWSIZE_RIGHT + C_AWSIZE_LEN;
  localparam C_AWLEN_LEN      = 8;
  localparam C_AWADDR_RIGHT   = C_AWLEN_RIGHT + C_AWLEN_LEN;
  localparam C_AWADDR_LEN     = C_AXI_ADDR_WIDTH;
  localparam C_AWID_RIGHT     = C_AWADDR_RIGHT + C_AWADDR_LEN;
  localparam C_AWID_LEN       = C_AXI_ID_WIDTH;
  localparam C_AW_SIZE        = C_AWID_RIGHT+C_AWID_LEN;

  // Write Address Port FIFO data read and write
  wire [C_AW_SIZE-1:0] s_aw_data ;
  wire [C_AW_SIZE-1:0] m_aw_data ;
  
  // Write Data Port bit positions
  localparam C_WUSER_RIGHT   = 0;
  localparam C_WUSER_LEN     = C_AXI_SUPPORTS_USER_SIGNALS*C_AXI_WUSER_WIDTH;
  localparam C_WLAST_RIGHT   = C_WUSER_RIGHT + C_WUSER_LEN;
  localparam C_WLAST_LEN     = 1;
  localparam C_WSTRB_RIGHT   = C_WLAST_RIGHT + C_WLAST_LEN;
  localparam C_WSTRB_LEN     = C_AXI_DATA_WIDTH/8;
  localparam C_WDATA_RIGHT   = C_WSTRB_RIGHT + C_WSTRB_LEN;
  localparam C_WDATA_LEN     = C_AXI_DATA_WIDTH;
  localparam C_WID_RIGHT     = C_WDATA_RIGHT + C_WDATA_LEN;
  localparam C_WID_LEN       = C_AXI_ID_WIDTH;
  localparam C_W_SIZE        = C_WID_RIGHT+C_WID_LEN;

  // Write Data Port FIFO data read and write
  wire [C_W_SIZE-1:0] s_w_data;
  wire [C_W_SIZE-1:0] m_w_data;

  // Write Response Port bit positions
  localparam C_BUSER_RIGHT   = 0;
  localparam C_BUSER_LEN     = C_AXI_SUPPORTS_USER_SIGNALS*C_AXI_BUSER_WIDTH;
  localparam C_BRESP_RIGHT   = C_BUSER_RIGHT + C_BUSER_LEN;
  localparam C_BRESP_LEN     = 2;
  localparam C_BID_RIGHT     = C_BRESP_RIGHT + C_BRESP_LEN;
  localparam C_BID_LEN       = C_AXI_ID_WIDTH;
  localparam C_B_SIZE        = C_BID_RIGHT+C_BID_LEN;

  // Write Response Port FIFO data read and write
  wire [C_B_SIZE-1:0] s_b_data;
  wire [C_B_SIZE-1:0] m_b_data;

  // Read Address Port bit positions
  localparam C_ARUSER_RIGHT   = 0;
  localparam C_ARUSER_LEN     = C_AXI_SUPPORTS_USER_SIGNALS*C_AXI_ARUSER_WIDTH;
  localparam C_ARQOS_RIGHT    = C_ARUSER_RIGHT + C_ARUSER_LEN;
  localparam C_ARQOS_LEN      = 4;
  localparam C_ARREGION_RIGHT = C_ARQOS_RIGHT + C_ARQOS_LEN;
  localparam C_ARREGION_LEN   = 4;
  localparam C_ARPROT_RIGHT   = C_ARREGION_RIGHT + C_ARREGION_LEN;
  localparam C_ARPROT_LEN     = 3;
  localparam C_ARCACHE_RIGHT  = C_ARPROT_RIGHT + C_ARPROT_LEN;
  localparam C_ARCACHE_LEN    = 4;
  localparam C_ARLOCK_RIGHT   = C_ARCACHE_RIGHT + C_ARCACHE_LEN;
  localparam C_ARLOCK_LEN     = 2;
  localparam C_ARBURST_RIGHT  = C_ARLOCK_RIGHT + C_ARLOCK_LEN;
  localparam C_ARBURST_LEN    = 2;
  localparam C_ARSIZE_RIGHT   = C_ARBURST_RIGHT + C_ARBURST_LEN;
  localparam C_ARSIZE_LEN     = 3;
  localparam C_ARLEN_RIGHT    = C_ARSIZE_RIGHT + C_ARSIZE_LEN;
  localparam C_ARLEN_LEN      = 8;
  localparam C_ARADDR_RIGHT   = C_ARLEN_RIGHT + C_ARLEN_LEN;
  localparam C_ARADDR_LEN     = C_AXI_ADDR_WIDTH;
  localparam C_ARID_RIGHT     = C_ARADDR_RIGHT + C_ARADDR_LEN;
  localparam C_ARID_LEN       = C_AXI_ID_WIDTH;
  localparam C_AR_SIZE        = C_ARID_RIGHT+C_ARID_LEN;

  // Read Address Port FIFO data read and write
  wire [C_AR_SIZE-1:0] s_ar_data;
  wire [C_AR_SIZE-1:0] m_ar_data;

  // Read Data Ports bit positions
  localparam C_RUSER_RIGHT   = 0;
  localparam C_RUSER_LEN     = C_AXI_SUPPORTS_USER_SIGNALS*C_AXI_RUSER_WIDTH;
  localparam C_RLAST_RIGHT   = C_RUSER_RIGHT + C_RUSER_LEN;
  localparam C_RLAST_LEN     = 1;
  localparam C_RRESP_RIGHT   = C_RLAST_RIGHT + C_RLAST_LEN;
  localparam C_RRESP_LEN     = 2;
  localparam C_RDATA_RIGHT   = C_RRESP_RIGHT + C_RRESP_LEN;
  localparam C_RDATA_LEN     = C_AXI_DATA_WIDTH;
  localparam C_RID_RIGHT     = C_RDATA_RIGHT + C_RDATA_LEN;
  localparam C_RID_LEN       = C_AXI_ID_WIDTH;
  localparam C_R_SIZE        = C_RID_RIGHT+C_RID_LEN;

  // Read Data Ports FIFO data read and write
  wire [C_R_SIZE-1:0] s_r_data;
  wire [C_R_SIZE-1:0] m_r_data;

  generate
    
    ///////////////////////////////////////////////////////
    //
    // AW PIPE
    //
    ///////////////////////////////////////////////////////
    
    if (C_AXI_SUPPORTS_USER_SIGNALS == 1) begin : gen_async_aw_user
      assign s_aw_data    = {S_AXI_AWID, S_AXI_AWADDR, S_AXI_AWLEN, S_AXI_AWSIZE, 
                             S_AXI_AWBURST, S_AXI_AWLOCK, S_AXI_AWCACHE, S_AXI_AWPROT, 
                             S_AXI_AWREGION, S_AXI_AWQOS, S_AXI_AWUSER};
      assign M_AXI_AWUSER = m_aw_data[C_AWUSER_RIGHT+:C_AWUSER_LEN];
    end
    else begin : gen_asynch_aw_no_user
      assign s_aw_data    = {S_AXI_AWID, S_AXI_AWADDR, S_AXI_AWLEN, S_AXI_AWSIZE, 
                             S_AXI_AWBURST, S_AXI_AWLOCK, S_AXI_AWCACHE, S_AXI_AWPROT, 
                             S_AXI_AWREGION, S_AXI_AWQOS};
      assign M_AXI_AWUSER = {C_AXI_AWUSER_WIDTH{1'b0}};
    end

    assign M_AXI_AWID     = m_aw_data[C_AWID_RIGHT+:C_AWID_LEN];
    assign M_AXI_AWADDR   = m_aw_data[C_AWADDR_RIGHT+:C_AWADDR_LEN];
    assign M_AXI_AWLEN    = m_aw_data[C_AWLEN_RIGHT+:C_AWLEN_LEN];
    assign M_AXI_AWSIZE   = m_aw_data[C_AWSIZE_RIGHT+:C_AWSIZE_LEN];
    assign M_AXI_AWBURST  = m_aw_data[C_AWBURST_RIGHT+:C_AWBURST_LEN];
    assign M_AXI_AWLOCK   = m_aw_data[C_AWLOCK_RIGHT+:C_AWLOCK_LEN];
    assign M_AXI_AWCACHE  = m_aw_data[C_AWCACHE_RIGHT+:C_AWCACHE_LEN];
    assign M_AXI_AWPROT   = m_aw_data[C_AWPROT_RIGHT+:C_AWPROT_LEN];
    assign M_AXI_AWREGION = m_aw_data[C_AWREGION_RIGHT+:C_AWREGION_LEN];
    assign M_AXI_AWQOS    = m_aw_data[C_AWQOS_RIGHT+:C_AWQOS_LEN];
    
    axic_register_slice #
      (
       .C_FAMILY(C_FAMILY),
       .C_DATA_WIDTH(C_AW_SIZE),
       .C_REG_CONFIG(C_REG_CONFIG_AW)
       )
    aw_pipe
      (
       // System Signals
       .ACLK(ACLK),
       .ARESET(reset),

       // Slave side
       .S_PAYLOAD_DATA(s_aw_data),
       .S_VALID(S_AXI_AWVALID),
       .S_READY(S_AXI_AWREADY),

       // Master side
       .M_PAYLOAD_DATA(m_aw_data),
       .M_VALID(M_AXI_AWVALID),
       .M_READY(M_AXI_AWREADY)
       );
    

    ///////////////////////////////////////////////////////
    //
    //  Data Write PIPE
    //
    ///////////////////////////////////////////////////////  
    if (C_AXI_SUPPORTS_USER_SIGNALS == 1) begin : gen_async_w_user
      assign s_w_data     = {S_AXI_WID, S_AXI_WDATA, S_AXI_WSTRB, S_AXI_WLAST, S_AXI_WUSER};
      assign M_AXI_WUSER = m_w_data[C_WUSER_RIGHT+:C_WUSER_LEN];
    end
    else begin : gen_asynch_w_no_user
      assign s_w_data     = {S_AXI_WID, S_AXI_WDATA, S_AXI_WSTRB, S_AXI_WLAST};
      assign M_AXI_WUSER  = {C_AXI_WUSER_WIDTH{1'b0}};
    end

    assign M_AXI_WID      = m_w_data[C_WID_RIGHT+:C_WID_LEN];
    assign M_AXI_WDATA    = m_w_data[C_WDATA_RIGHT+:C_WDATA_LEN];
    assign M_AXI_WSTRB    = m_w_data[C_WSTRB_RIGHT+:C_WSTRB_LEN];
    assign M_AXI_WLAST    = m_w_data[C_WLAST_RIGHT+:C_WLAST_LEN];

    axic_register_slice #
      (
       .C_FAMILY(C_FAMILY),
       .C_DATA_WIDTH(C_W_SIZE),
       .C_REG_CONFIG(C_REG_CONFIG_W)
       )
      w_pipe
      (
       // System Signals
       .ACLK(ACLK),
       .ARESET(reset),

       // Slave side
       .S_PAYLOAD_DATA(s_w_data),
       .S_VALID(S_AXI_WVALID),
       .S_READY(S_AXI_WREADY),

       // Master side
       .M_PAYLOAD_DATA(m_w_data),
       .M_VALID(M_AXI_WVALID),
       .M_READY(M_AXI_WREADY)
       );

    
    ///////////////////////////////////////////////////////
    //
    // Write Response PIPE
    //
    ///////////////////////////////////////////////////////  
    if (C_AXI_SUPPORTS_USER_SIGNALS == 1) begin : gen_async_b_user
      assign m_b_data     = {M_AXI_BID, M_AXI_BRESP, M_AXI_BUSER};
      assign S_AXI_BUSER  = s_b_data[C_BUSER_RIGHT+:C_BUSER_LEN];
    end
    else begin : gen_asynch_b_no_user
      assign m_b_data     = {M_AXI_BID, M_AXI_BRESP};
      assign S_AXI_BUSER  = {C_AXI_BUSER_WIDTH{1'b0}};
    end

    assign S_AXI_BID      = s_b_data[C_BID_RIGHT+:C_BID_LEN];
    assign S_AXI_BRESP    = s_b_data[C_BRESP_RIGHT+:C_BRESP_LEN];

    axic_register_slice #
      (
       .C_FAMILY(C_FAMILY),
       .C_DATA_WIDTH(C_B_SIZE),
       .C_REG_CONFIG(C_REG_CONFIG_B)
       )
      b_pipe
      (
       // System Signals
       .ACLK(ACLK),
       .ARESET(reset),

       // Slave side
       .S_PAYLOAD_DATA(m_b_data),
       .S_VALID(M_AXI_BVALID),
       .S_READY(M_AXI_BREADY),

       // Master side
       .M_PAYLOAD_DATA(s_b_data),
       .M_VALID(S_AXI_BVALID),
       .M_READY(S_AXI_BREADY)
       );
 
    ///////////////////////////////////////////////////////
    //
    // Address Read PIPE
    //
    ///////////////////////////////////////////////////////  

    if (C_AXI_SUPPORTS_USER_SIGNALS == 1) begin : gen_async_ar_user
      assign s_ar_data    = {S_AXI_ARID, S_AXI_ARADDR, S_AXI_ARLEN, S_AXI_ARSIZE, 
                             S_AXI_ARBURST, S_AXI_ARLOCK, S_AXI_ARCACHE, S_AXI_ARPROT, 
                             S_AXI_ARREGION, S_AXI_ARQOS, S_AXI_ARUSER};
      assign M_AXI_ARUSER = m_ar_data[C_ARUSER_RIGHT+:C_ARUSER_LEN];
    end
    else begin : gen_asynch_ar_no_user
      assign s_ar_data    = {S_AXI_ARID, S_AXI_ARADDR, S_AXI_ARLEN, S_AXI_ARSIZE, 
                             S_AXI_ARBURST, S_AXI_ARLOCK, S_AXI_ARCACHE, S_AXI_ARPROT, 
                             S_AXI_ARREGION, S_AXI_ARQOS};
      
      assign M_AXI_ARUSER = {C_AXI_ARUSER_WIDTH{1'b0}};
    end

    assign M_AXI_ARID     = m_ar_data[C_ARID_RIGHT+:C_ARID_LEN];
    assign M_AXI_ARADDR   = m_ar_data[C_ARADDR_RIGHT+:C_ARADDR_LEN];
    assign M_AXI_ARLEN    = m_ar_data[C_ARLEN_RIGHT+:C_ARLEN_LEN];
    assign M_AXI_ARSIZE   = m_ar_data[C_ARSIZE_RIGHT+:C_ARSIZE_LEN];
    assign M_AXI_ARBURST  = m_ar_data[C_ARBURST_RIGHT+:C_ARBURST_LEN];
    assign M_AXI_ARLOCK   = m_ar_data[C_ARLOCK_RIGHT+:C_ARLOCK_LEN];
    assign M_AXI_ARCACHE  = m_ar_data[C_ARCACHE_RIGHT+:C_ARCACHE_LEN];
    assign M_AXI_ARPROT   = m_ar_data[C_ARPROT_RIGHT+:C_ARPROT_LEN];
    assign M_AXI_ARREGION = m_ar_data[C_ARREGION_RIGHT+:C_ARREGION_LEN];
    assign M_AXI_ARQOS    = m_ar_data[C_ARQOS_RIGHT+:C_ARQOS_LEN];

    axic_register_slice #
      (
       .C_FAMILY(C_FAMILY),
       .C_DATA_WIDTH(C_AR_SIZE),
       .C_REG_CONFIG(C_REG_CONFIG_AR)
       )
      ar_pipe
      (
       // System Signals
       .ACLK(ACLK),
       .ARESET(reset),

       // Slave side
       .S_PAYLOAD_DATA(s_ar_data),
       .S_VALID(S_AXI_ARVALID),
       .S_READY(S_AXI_ARREADY),

       // Master side
       .M_PAYLOAD_DATA(m_ar_data),
       .M_VALID(M_AXI_ARVALID),
       .M_READY(M_AXI_ARREADY)
       );
        
    ///////////////////////////////////////////////////////
    //
    //  Data Read PIPE
    //
    ///////////////////////////////////////////////////////
    
    if (C_AXI_SUPPORTS_USER_SIGNALS == 1) begin : gen_async_r_user
      assign m_r_data     = {M_AXI_RID, M_AXI_RDATA, M_AXI_RRESP, M_AXI_RLAST, M_AXI_RUSER};
      assign S_AXI_RUSER  = s_r_data[C_RUSER_RIGHT+:C_RUSER_LEN];
    end
    else begin : gen_asynch_r_no_user
      assign m_r_data     = {M_AXI_RID, M_AXI_RDATA, M_AXI_RRESP, M_AXI_RLAST};
      assign S_AXI_RUSER  = {C_AXI_RUSER_WIDTH{1'b0}};
    end
    
    assign S_AXI_RID      = s_r_data[C_RID_RIGHT+:C_RID_LEN];
    assign S_AXI_RDATA    = s_r_data[C_RDATA_RIGHT+:C_RDATA_LEN];
    assign S_AXI_RRESP    = s_r_data[C_RRESP_RIGHT+:C_RRESP_LEN];
    assign S_AXI_RLAST    = s_r_data[C_RLAST_RIGHT+:C_RLAST_LEN];

    axic_register_slice #
      (
       .C_FAMILY(C_FAMILY),
       .C_DATA_WIDTH(C_R_SIZE),
       .C_REG_CONFIG(C_REG_CONFIG_R)
       )
      r_pipe
      (
       // System Signals
       .ACLK(ACLK),
       .ARESET(reset),

       // Slave side
       .S_PAYLOAD_DATA(m_r_data),
       .S_VALID(M_AXI_RVALID),
       .S_READY(M_AXI_RREADY),

       // Master side
       .M_PAYLOAD_DATA(s_r_data),
       .M_VALID(S_AXI_RVALID),
       .M_READY(S_AXI_RREADY)
       );

  endgenerate

endmodule // ddr_axi_register_slice












module axic_register_slice #
  (
   parameter C_FAMILY     = "virtex6",
   parameter C_DATA_WIDTH = 32,
   parameter C_REG_CONFIG = 32'h00000000
   // C_REG_CONFIG:
   //   0 => BYPASS    = The channel is just wired through the module.
   //   1 => FWD_REV   = Both FWD and REV (fully-registered)
   //   2 => FWD       = The master VALID and payload signals are registrated. 
   //   3 => REV       = The slave ready signal is registrated
   //   4 => RESERVED (all outputs driven to 0).
   //   5 => RESERVED (all outputs driven to 0).
   //   6 => INPUTS    = Slave and Master side inputs are registrated.
   //   7 => LIGHT_WT  = 1-stage pipeline register with bubble cycle, both FWD and REV pipelining
   )
  (
   // System Signals
   input wire ACLK,
   input wire ARESET,

   // Slave side
   input  wire [C_DATA_WIDTH-1:0] S_PAYLOAD_DATA,
   input  wire S_VALID,
   output wire S_READY,

   // Master side
   output  wire [C_DATA_WIDTH-1:0] M_PAYLOAD_DATA,
   output wire M_VALID,
   input  wire M_READY
   );

  (* use_clock_enable = "yes" *)

  generate
  ////////////////////////////////////////////////////////////////////
  //
  // C_REG_CONFIG = 0
  // Bypass mode
  //
  ////////////////////////////////////////////////////////////////////
    if (C_REG_CONFIG == 32'h00000000)
    begin
      assign M_PAYLOAD_DATA = S_PAYLOAD_DATA;
      assign M_VALID        = S_VALID;
      assign S_READY        = M_READY;      
    end
  ////////////////////////////////////////////////////////////////////
  //
  // C_REG_CONFIG = 1 (or 8)
  // Both FWD and REV mode
  //
  ////////////////////////////////////////////////////////////////////
    else if ((C_REG_CONFIG == 32'h00000001) || (C_REG_CONFIG == 32'h00000008))
    begin
      (* max_fanout = 50 *) reg [1:0] state /* synthesis syn_maxfan = 30 */;
      localparam [1:0] 
        ZERO = 2'b10,
        ONE  = 2'b11,
        TWO  = 2'b01;
      
      reg [C_DATA_WIDTH-1:0] storage_data1;
      reg [C_DATA_WIDTH-1:0] storage_data2;
      reg                    load_s1;
      wire                   load_s2;
      wire                   load_s1_from_s2;
      reg                    s_ready_i; //local signal of output
      wire                   m_valid_i; //local signal of output

      // assign local signal to its output signal
      assign S_READY = s_ready_i;
      assign M_VALID = m_valid_i;

      reg [1:0] areset_d; // Reset delay register
      always @(posedge ACLK) begin
        areset_d <= {areset_d[0], ARESET};
      end
      
      // Load storage1 with either slave side data or from storage2
      always @(posedge ACLK) 
      begin
        if (load_s1)
          if (load_s1_from_s2)
            storage_data1 <= storage_data2;
          else
            storage_data1 <= S_PAYLOAD_DATA;        
      end

      // Load storage2 with slave side data
      always @(posedge ACLK) 
      begin
        if (load_s2)
          storage_data2 <= S_PAYLOAD_DATA;
      end

      assign M_PAYLOAD_DATA = storage_data1;

      // Always load s2 on a valid transaction even if it's unnecessary
      assign load_s2 = S_VALID & s_ready_i;

      // Loading s1
      always @ *
      begin
        if ( ((state == ZERO) && (S_VALID == 1)) || // Load when empty on slave transaction
             // Load when ONE if we both have read and write at the same time
             ((state == ONE) && (S_VALID == 1) && (M_READY == 1)) ||
             // Load when TWO and we have a transaction on Master side
             ((state == TWO) && (M_READY == 1)))
          load_s1 = 1'b1;
        else
          load_s1 = 1'b0;
      end // always @ *

      assign load_s1_from_s2 = (state == TWO);
                       
      // State Machine for handling output signals
      always @(posedge ACLK) begin
        if (ARESET) begin
          s_ready_i <= 1'b0;
          state <= ZERO;
        end else if (areset_d == 2'b10) begin
          s_ready_i <= 1'b1;
        end else if (areset_d == 2'b00) begin
          case (state)
            // No transaction stored locally
            ZERO: if (S_VALID) state <= ONE; // Got one so move to ONE

            // One transaction stored locally
            ONE: begin
              if (M_READY & ~S_VALID) state <= ZERO; // Read out one so move to ZERO
//              if (~M_READY & S_VALID) begin
              else if (~M_READY & S_VALID) begin
                state <= TWO;  // Got another one so move to TWO
                s_ready_i <= 1'b0;
              end
            end

            // TWO transaction stored locally
            TWO: if (M_READY) begin
              state <= ONE; // Read out one so move to ONE
              s_ready_i <= 1'b1;
            end
          endcase // case (state)
        end
      end // always @ (posedge ACLK)
      
      assign m_valid_i = state[0];

    end // if (C_REG_CONFIG == 1)
    
  ////////////////////////////////////////////////////////////////////
  //
  // C_REG_CONFIG = 2
  // Only FWD mode
  //
  ////////////////////////////////////////////////////////////////////
    else if (C_REG_CONFIG == 32'h00000002)
    begin
      reg [C_DATA_WIDTH-1:0] storage_data;
      wire                   s_ready_i; //local signal of output
      reg                    m_valid_i; //local signal of output

      // assign local signal to its output signal
      assign S_READY = s_ready_i;
      assign M_VALID = m_valid_i;

      (* equivalent_register_removal = "no" *) reg [1:0] areset_d; // Reset delay register
      always @(posedge ACLK) begin
        areset_d <= {areset_d[0], ARESET};
      end
      
      // Save payload data whenever we have a transaction on the slave side
      always @(posedge ACLK) 
      begin
        if (S_VALID & s_ready_i)
          storage_data <= S_PAYLOAD_DATA;
      end

      assign M_PAYLOAD_DATA = storage_data;
      
      // M_Valid set to high when we have a completed transfer on slave side
      // Is removed on a M_READY except if we have a new transfer on the slave side
      always @(posedge ACLK) 
      begin
        if (areset_d) 
          m_valid_i <= 1'b0;
        else
          if (S_VALID) // Always set m_valid_i when slave side is valid
            m_valid_i <= 1'b1;
          else
            if (M_READY) // Clear (or keep) when no slave side is valid but master side is ready
              m_valid_i <= 1'b0;
      end // always @ (posedge ACLK)
      
      // Slave Ready is either when Master side drives M_Ready or we have space in our storage data
      assign s_ready_i = (M_READY | ~m_valid_i) & ~|areset_d;

    end // if (C_REG_CONFIG == 2)
  ////////////////////////////////////////////////////////////////////
  //
  // C_REG_CONFIG = 3
  // Only REV mode
  //
  ////////////////////////////////////////////////////////////////////
    else if (C_REG_CONFIG == 32'h00000003)
    begin
      reg [C_DATA_WIDTH-1:0] storage_data;
      reg                    s_ready_i; //local signal of output
      reg                    has_valid_storage_i;
      reg                    has_valid_storage;

      (* equivalent_register_removal = "no" *) reg areset_d; // Reset delay register
      always @(posedge ACLK) begin
        areset_d <= ARESET;
      end
      
      // Save payload data whenever we have a transaction on the slave side
      always @(posedge ACLK) 
      begin
        if (S_VALID & s_ready_i)
          storage_data <= S_PAYLOAD_DATA;
      end

      assign M_PAYLOAD_DATA = has_valid_storage?storage_data:S_PAYLOAD_DATA;

      // Need to determine when we need to save a payload
      // Need a combinatorial signals since it will also effect S_READY
      always @ *
      begin
        // Set the value if we have a slave transaction but master side is not ready
        if (S_VALID & s_ready_i & ~M_READY)
          has_valid_storage_i = 1'b1;
        
        // Clear the value if it's set and Master side completes the transaction but we don't have a new slave side 
        // transaction 
        else if ( (has_valid_storage == 1) && (M_READY == 1) && ( (S_VALID == 0) || (s_ready_i == 0)))
          has_valid_storage_i = 1'b0;
        else
          has_valid_storage_i = has_valid_storage;
      end // always @ *

      always @(posedge ACLK) 
      begin
        if (ARESET) 
          has_valid_storage <= 1'b0;
        else
          has_valid_storage <= has_valid_storage_i;
      end

      // S_READY is either clocked M_READY or that we have room in local storage
      always @(posedge ACLK) 
      begin
        if (ARESET) 
          s_ready_i <= 1'b0;
        else
          s_ready_i <= M_READY | ~has_valid_storage_i;
      end

      // assign local signal to its output signal
      assign S_READY = s_ready_i;

      // M_READY is either combinatorial S_READY or that we have valid data in local storage
      assign M_VALID = (S_VALID | has_valid_storage) & ~areset_d;
      
    end // if (C_REG_CONFIG == 3)
    
  ////////////////////////////////////////////////////////////////////
  //
  // C_REG_CONFIG = 4 or 5 is NO LONGER SUPPORTED
  //
  ////////////////////////////////////////////////////////////////////
    else if ((C_REG_CONFIG == 32'h00000004) || (C_REG_CONFIG == 32'h00000005))
    begin
// synthesis translate_off
      initial begin  
        $display ("ERROR: For axi_register_slice, C_REG_CONFIG = 4 or 5 is RESERVED.");
      end
// synthesis translate_on
      assign M_PAYLOAD_DATA = 0;
      assign M_VALID        = 1'b0;
      assign S_READY        = 1'b0;    
    end  

  ////////////////////////////////////////////////////////////////////
  //
  // C_REG_CONFIG = 6
  // INPUTS mode
  //
  ////////////////////////////////////////////////////////////////////
    else if (C_REG_CONFIG == 32'h00000006)
    begin
      reg [1:0] state;
      reg [1:0] next_state;
      localparam [1:0] 
        ZERO = 2'b00,
        ONE  = 2'b01,
        TWO  = 2'b11;

      reg [C_DATA_WIDTH-1:0] storage_data1;
      reg [C_DATA_WIDTH-1:0] storage_data2;
      reg                    s_valid_d;
      reg                    s_ready_d;
      reg                    m_ready_d;
      reg                    m_valid_d;
      reg                    load_s2;
      reg                    sel_s2;
      wire                   new_access;
      wire                   access_done;
      wire                   s_ready_i; //local signal of output
      reg                    s_ready_ii;
      reg                    m_valid_i; //local signal of output
      
      (* equivalent_register_removal = "no" *) reg areset_d; // Reset delay register
      always @(posedge ACLK) begin
        areset_d <= ARESET;
      end
      
      // assign local signal to its output signal
      assign S_READY = s_ready_i;
      assign M_VALID = m_valid_i;
      assign s_ready_i = s_ready_ii & ~areset_d;

      // Registrate input control signals
      always @(posedge ACLK) 
      begin
        if (ARESET) begin          
          s_valid_d <= 1'b0;
          s_ready_d <= 1'b0;
          m_ready_d <= 1'b0;
        end else begin
          s_valid_d <= S_VALID;
          s_ready_d <= s_ready_i;
          m_ready_d <= M_READY;
        end
      end // always @ (posedge ACLK)

      // Load storage1 with slave side payload data when slave side ready is high
      always @(posedge ACLK) 
      begin
        if (s_ready_i)
          storage_data1 <= S_PAYLOAD_DATA;          
      end

      // Load storage2 with storage data 
      always @(posedge ACLK) 
      begin
        if (load_s2)
          storage_data2 <= storage_data1;
      end

      always @(posedge ACLK) 
      begin
        if (ARESET) 
          m_valid_d <= 1'b0;
        else 
          m_valid_d <= m_valid_i;
      end

      // Local help signals
      assign new_access  = s_ready_d & s_valid_d;
      assign access_done = m_ready_d & m_valid_d;


      // State Machine for handling output signals
      always @*
      begin
        next_state = state; // Stay in the same state unless we need to move to another state
        load_s2   = 0;
        sel_s2    = 0;
        m_valid_i = 0;
        s_ready_ii = 0;
        case (state)
            // No transaction stored locally
            ZERO: begin
              load_s2   = 0;
              sel_s2    = 0;
              m_valid_i = 0;
              s_ready_ii = 1;
              if (new_access) begin
                next_state = ONE; // Got one so move to ONE
                load_s2   = 1;
                m_valid_i = 0;
              end
              else begin
                next_state = next_state;
                load_s2   = load_s2;
                m_valid_i = m_valid_i;
              end

            end // case: ZERO

            // One transaction stored locally
            ONE: begin
              load_s2   = 0;
              sel_s2    = 1;
              m_valid_i = 1;
              s_ready_ii = 1;
              if (~new_access & access_done) begin
                next_state = ZERO; // Read out one so move to ZERO
                m_valid_i = 0;                      
              end
              else if (new_access & ~access_done) begin
                next_state = TWO;  // Got another one so move to TWO
                s_ready_ii = 0;
              end
              else if (new_access & access_done) begin
                load_s2   = 1;
                sel_s2    = 0;
              end
              else begin
                load_s2   = load_s2;
                sel_s2    = sel_s2;
              end


            end // case: ONE

            // TWO transaction stored locally
            TWO: begin
              load_s2   = 0;
              sel_s2    = 1;
              m_valid_i = 1;
              s_ready_ii = 0;
              if (access_done) begin 
                next_state = ONE; // Read out one so move to ONE
                s_ready_ii  = 1;
                load_s2    = 1;
                sel_s2     = 0;
              end
              else begin
                next_state = next_state;
                s_ready_ii  = s_ready_ii;
                load_s2    = load_s2;
                sel_s2     = sel_s2;
              end
            end // case: TWO
        endcase // case (state)
      end // always @ *


      // State Machine for handling output signals
      always @(posedge ACLK) 
      begin
        if (ARESET) 
          state <= ZERO;
        else
          state <= next_state; // Stay in the same state unless we need to move to another state
      end
      
      // Master Payload mux
      assign M_PAYLOAD_DATA = sel_s2?storage_data2:storage_data1;

    end // if (C_REG_CONFIG == 6)
  ////////////////////////////////////////////////////////////////////
  //
  // C_REG_CONFIG = 7
  // Light-weight mode.
  // 1-stage pipeline register with bubble cycle, both FWD and REV pipelining
  // Operates same as 1-deep FIFO
  //
  ////////////////////////////////////////////////////////////////////
    else if (C_REG_CONFIG == 32'h00000007)
    begin
      reg [C_DATA_WIDTH-1:0] storage_data1;
      reg                    s_ready_i; //local signal of output
      reg                    m_valid_i; //local signal of output

      // assign local signal to its output signal
      assign S_READY = s_ready_i;
      assign M_VALID = m_valid_i;

      reg [1:0] areset_d; // Reset delay register
      always @(posedge ACLK) begin
        areset_d <= {areset_d[0], ARESET};
      end
      
      // Load storage1 with slave side data
      always @(posedge ACLK) 
      begin
        if (ARESET) begin
          s_ready_i <= 1'b0;
          m_valid_i <= 1'b0;
        end else if (areset_d == 2'b10) begin
          s_ready_i <= 1'b1;
        end else if (areset_d == 2'b00) begin
          if (m_valid_i & M_READY) begin
            s_ready_i <= 1'b1;
            m_valid_i <= 1'b0;
          end else if (S_VALID & s_ready_i) begin
            s_ready_i <= 1'b0;
            m_valid_i <= 1'b1;
          end
        end
        if (~m_valid_i) begin
          storage_data1 <= S_PAYLOAD_DATA;        
        end
      end
      assign M_PAYLOAD_DATA = storage_data1;
    end // if (C_REG_CONFIG == 7)
    
    else begin : default_case
      // Passthrough
      assign M_PAYLOAD_DATA = S_PAYLOAD_DATA;
      assign M_VALID        = S_VALID;
      assign S_READY        = M_READY;      
    end

  endgenerate
endmodule // reg_slice









module a_upsizer #
  (
   parameter         C_FAMILY                         = "rtl", 
                       // FPGA Family. Current version: virtex6 or spartan6.
   parameter integer C_AXI_ID_WIDTH                 = 4, 
                       // Width of all ID signals on SI and MI side of converter.
                       // Range: >= 1.
   parameter integer C_AXI_ADDR_WIDTH                 = 32, 
                       // Width of all ADDR signals on SI and MI side of converter.
                       // Range: 32.
   parameter         C_S_AXI_DATA_WIDTH               = 32'h00000020, 
                       // Width of S_AXI_WDATA and S_AXI_RDATA.
                       // Format: Bit32; 
                       // Range: 'h00000020, 'h00000040, 'h00000080, 'h00000100.
   parameter         C_M_AXI_DATA_WIDTH               = 32'h00000040, 
                       // Width of M_AXI_WDATA and M_AXI_RDATA.
                       // Assume greater than or equal to C_S_AXI_DATA_WIDTH.
                       // Format: Bit32;
                       // Range: 'h00000020, 'h00000040, 'h00000080, 'h00000100.
   parameter integer C_M_AXI_REGISTER                 = 0,
                       // Clock output data.
                       // Range: 0, 1
   parameter integer C_AXI_SUPPORTS_USER_SIGNALS      = 0,
                       // 1 = Propagate all USER signals, 0 = Don抰 propagate.
   parameter integer C_AXI_AUSER_WIDTH                = 1,
                       // Width of AWUSER/ARUSER signals. 
                       // Range: >= 1.
   parameter integer C_AXI_CHANNEL                      = 0,
                       // 0 = AXI AW Channel.
                       // 1 = AXI AR Channel.
   parameter integer C_PACKING_LEVEL                    = 1,
                       // 0 = Never pack (expander only); packing logic is omitted.
                       // 1 = Pack only when CACHE[1] (Modifiable) is high.
                       // 2 = Always pack, regardless of sub-size transaction or Modifiable bit.
                       //     (Required when used as helper-core by mem-con.)
   parameter integer C_SUPPORT_BURSTS                 = 1,
                       // Disabled when all connected masters and slaves are AxiLite,
                       //   allowing logic to be simplified.
   parameter integer C_SINGLE_THREAD                  = 1,
                       // 0 = Ignore ID when propagating transactions (assume all responses are in order).
                       // 1 = Allow multiple outstanding transactions only if the IDs are the same
                       //   to prevent response reordering.
                       //   (If ID mismatches, stall until outstanding transaction counter = 0.)
   parameter integer C_S_AXI_BYTES_LOG                = 3,
                       // Log2 of number of 32bit word on SI-side.
   parameter integer C_M_AXI_BYTES_LOG                = 3
                       // Log2 of number of 32bit word on MI-side.
   )
  (
   // Global Signals
   input  wire                                                    ARESET,
   input  wire                                                    ACLK,

   // Command Interface
   output wire                              cmd_valid,
   output wire                              cmd_fix,
   output wire                              cmd_modified,
   output wire                              cmd_complete_wrap,
   output wire                              cmd_packed_wrap,
   output wire [C_M_AXI_BYTES_LOG-1:0]      cmd_first_word, 
   output wire [C_M_AXI_BYTES_LOG-1:0]      cmd_next_word, 
   output wire [C_M_AXI_BYTES_LOG-1:0]      cmd_last_word,
   output wire [C_M_AXI_BYTES_LOG-1:0]      cmd_offset,
   output wire [C_M_AXI_BYTES_LOG-1:0]      cmd_mask,
   output wire [C_S_AXI_BYTES_LOG:0]        cmd_step,
   output wire [8-1:0]                      cmd_length,
   input  wire                              cmd_ready,
   
   // Slave Interface Write Address Ports
   input  wire [C_AXI_ID_WIDTH-1:0]          S_AXI_AID,
   input  wire [C_AXI_ADDR_WIDTH-1:0]          S_AXI_AADDR,
   input  wire [8-1:0]                         S_AXI_ALEN,
   input  wire [3-1:0]                         S_AXI_ASIZE,
   input  wire [2-1:0]                         S_AXI_ABURST,
   input  wire [2-1:0]                         S_AXI_ALOCK,
   input  wire [4-1:0]                         S_AXI_ACACHE,
   input  wire [3-1:0]                         S_AXI_APROT,
   input  wire [4-1:0]                         S_AXI_AREGION,
   input  wire [4-1:0]                         S_AXI_AQOS,
   input  wire [C_AXI_AUSER_WIDTH-1:0]         S_AXI_AUSER,
   input  wire                                                   S_AXI_AVALID,
   output wire                                                   S_AXI_AREADY,

   // Master Interface Write Address Port
   output wire [C_AXI_ID_WIDTH-1:0]          M_AXI_AID,
   output wire [C_AXI_ADDR_WIDTH-1:0]          M_AXI_AADDR,
   output wire [8-1:0]                         M_AXI_ALEN,
   output wire [3-1:0]                         M_AXI_ASIZE,
   output wire [2-1:0]                         M_AXI_ABURST,
   output wire [2-1:0]                         M_AXI_ALOCK,
   output wire [4-1:0]                         M_AXI_ACACHE,
   output wire [3-1:0]                         M_AXI_APROT,
   output wire [4-1:0]                         M_AXI_AREGION,
   output wire [4-1:0]                         M_AXI_AQOS,
   output wire [C_AXI_AUSER_WIDTH-1:0]         M_AXI_AUSER,
   output wire                                                   M_AXI_AVALID,
   input  wire                                                   M_AXI_AREADY
   );
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Local params
  /////////////////////////////////////////////////////////////////////////////
  
  // Decode the native transaction size on the SI-side interface.
  localparam [3-1:0] C_S_AXI_NATIVE_SIZE = (C_S_AXI_DATA_WIDTH == 1024) ? 3'b111 :
                                           (C_S_AXI_DATA_WIDTH ==  512) ? 3'b110 :
                                           (C_S_AXI_DATA_WIDTH ==  256) ? 3'b101 :
                                           (C_S_AXI_DATA_WIDTH ==  128) ? 3'b100 :
                                           (C_S_AXI_DATA_WIDTH ==   64) ? 3'b011 :
                                           (C_S_AXI_DATA_WIDTH ==   32) ? 3'b010 :
                                           (C_S_AXI_DATA_WIDTH ==   16) ? 3'b001 :
                                           3'b000;
  
  // Decode the native transaction size on the MI-side interface.
  localparam [3-1:0] C_M_AXI_NATIVE_SIZE = (C_M_AXI_DATA_WIDTH == 1024) ? 3'b111 :
                                           (C_M_AXI_DATA_WIDTH ==  512) ? 3'b110 :
                                           (C_M_AXI_DATA_WIDTH ==  256) ? 3'b101 :
                                           (C_M_AXI_DATA_WIDTH ==  128) ? 3'b100 :
                                           (C_M_AXI_DATA_WIDTH ==   64) ? 3'b011 :
                                           (C_M_AXI_DATA_WIDTH ==   32) ? 3'b010 :
                                           (C_M_AXI_DATA_WIDTH ==   16) ? 3'b001 :
                                           3'b000;
  
  // Constants used to generate maximum length on SI-side for complete wrap.
  localparam [24-1:0] C_DOUBLE_LEN       = 24'b0000_0000_0000_0000_1111_1111;
  
  // Constants for burst types.
  localparam [2-1:0] C_FIX_BURST         = 2'b00;
  localparam [2-1:0] C_INCR_BURST        = 2'b01;
  localparam [2-1:0] C_WRAP_BURST        = 2'b10;
  
  // Constants for packing levels.
  localparam integer C_NEVER_PACK        = 0;
  localparam integer C_DEFAULT_PACK      = 1;
  localparam integer C_ALWAYS_PACK       = 2;
  
  // Depth for command FIFO.
  localparam integer C_FIFO_DEPTH_LOG    = 5;
  
  // Maximum address bit coverage by WRAP.
  localparam integer C_BURST_BYTES_LOG   = 4 + C_S_AXI_BYTES_LOG;
  
  // Calculate unused address bits.
  localparam integer C_SI_UNUSED_LOG     = C_AXI_ADDR_WIDTH-C_S_AXI_BYTES_LOG;
  localparam integer C_MI_UNUSED_LOG     = C_AXI_ADDR_WIDTH-C_M_AXI_BYTES_LOG;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Variables for generating parameter controlled instances.
  /////////////////////////////////////////////////////////////////////////////
  
  genvar bit_cnt;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Functions
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Internal signals
  /////////////////////////////////////////////////////////////////////////////
  
  // Access decoding related signals.
  wire                                access_is_fix;
  wire                                access_is_incr;
  wire                                access_is_wrap;
  wire                                access_is_modifiable;
  wire                                access_is_unaligned;
  reg  [8-1:0]                        si_maximum_length;
  wire [16-1:0]                       mi_word_intra_len_complete;
  wire [20-1:0]                       mask_help_vector;
  reg  [C_M_AXI_BYTES_LOG-1:0]        mi_word_intra_len;
  reg  [8-1:0]                        upsized_length;
  wire                                sub_sized_wrap;
  reg  [C_M_AXI_BYTES_LOG-1:0]        size_mask;
  reg  [C_BURST_BYTES_LOG-1:0]        burst_mask;
  
  // Translation related signals.
  wire                                access_need_extra_word;
  wire [8-1:0]                        adjusted_length;
  wire [C_BURST_BYTES_LOG-1:0]        wrap_addr_aligned;
  
  // Command buffer help signals.
  wire                                cmd_empty;
  reg  [C_AXI_ID_WIDTH-1:0]           queue_id;
  wire                                id_match;
  wire                                cmd_id_check;
  wire                                s_ready;
  wire                                cmd_full;
  wire                                allow_new_cmd;
  wire                                cmd_push;
  reg                                 cmd_push_block;
  
  // Internal Command Interface signals.
  wire                                cmd_valid_i;
  wire                                cmd_fix_i;
  wire                                cmd_modified_i;
  wire                                cmd_complete_wrap_i;
  wire                                cmd_packed_wrap_i;
  wire [C_M_AXI_BYTES_LOG-1:0]        cmd_first_word_ii;
  wire [C_M_AXI_BYTES_LOG-1:0]        cmd_first_word_i;
  wire [C_M_AXI_BYTES_LOG-1:0]        cmd_next_word_ii;
  wire [C_M_AXI_BYTES_LOG-1:0]        cmd_next_word_i;
  wire [C_M_AXI_BYTES_LOG:0]          cmd_last_word_ii;
  wire [C_M_AXI_BYTES_LOG-1:0]        cmd_last_word_i;
  wire [C_M_AXI_BYTES_LOG-1:0]        cmd_offset_i;
  reg  [C_M_AXI_BYTES_LOG-1:0]        cmd_mask_i;
  wire [3-1:0]                        cmd_size_i;
  wire [3-1:0]                        cmd_size;
  reg  [8-1:0]                        cmd_step_ii;
  wire [C_S_AXI_BYTES_LOG:0]          cmd_step_i;
  reg  [8-1:0]                        cmd_length_i;
  
  // Internal SI-side signals.
  wire                                S_AXI_AREADY_I;
   
  // Internal MI-side signals.
  wire [C_AXI_ID_WIDTH-1:0]           M_AXI_AID_I;
  reg  [C_AXI_ADDR_WIDTH-1:0]         M_AXI_AADDR_I;
  reg  [8-1:0]                        M_AXI_ALEN_I;
  reg  [3-1:0]                        M_AXI_ASIZE_I;
  reg  [2-1:0]                        M_AXI_ABURST_I;
  wire [2-1:0]                        M_AXI_ALOCK_I;
  wire [4-1:0]                        M_AXI_ACACHE_I;
  wire [3-1:0]                        M_AXI_APROT_I;
  wire [4-1:0]                        M_AXI_AREGION_I;
  wire [4-1:0]                        M_AXI_AQOS_I;
  wire [C_AXI_AUSER_WIDTH-1:0]        M_AXI_AUSER_I;
  wire                                M_AXI_AVALID_I;
  wire                                M_AXI_AREADY_I;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Decode the incoming transaction:
  //
  // Determine the burst type sucha as FIX, INCR and WRAP. Only WRAP and INCR 
  // transactions can be upsized to the MI-side data width.
  // Detect if the transaction is modifiable and if it is of native size. Only
  // native sized transaction are upsized when allowed, unless forced by 
  // parameter. FIX can never be upsized (packed) regardless if force is 
  // turned on. However the FIX data will be steered to the correct 
  // byte lane(s) and the transaction will be native on MI-side when 
  // applicable.
  //
  // Calculate the MI-side length for the SI-side transaction.
  // 
  // Decode the affected address bits in the MI-side. Used to determine last 
  // word for a burst and if necassarily adjust the length of the upsized 
  // transaction. Length adjustment only occurs when the trasaction is longer 
  // than can fit in MI-side and there is an unalignment for the first word
  // (and the last word crosses MI-word boundary and wraps).
  // 
  // The maximum allowed SI-side length is calculated to be able to determine 
  // if a WRAP transaction can fit inside a single MI-side data word.
  // 
  // Determine address bits mask for the SI-side transaction size, i.e. address
  // bits that shall be removed for unalignment when managing data in W and 
  // R channels. For example: the two least significant bits are not used 
  // for data packing in a 32-bit SI-side transaction (address 1-3 will appear
  // as 0 for the W and R channels, but the untouched address is still forwarded 
  // to the MI-side).
  // 
  // Determine the Mask bits for the address bits that are affected by a
  // sub-sized WRAP transaction (up to and including complete WRAP). The Mask 
  // is used to generate the correct data mapping for a sub-sized and
  // complete WRAP, i.e. having a local wrap in a partial MI-side word.
  // 
  // Detect any SI-side address unalignment when used on the MI-side.
  // 
  /////////////////////////////////////////////////////////////////////////////
  
  // Transaction burst type.
  assign access_is_fix          = ( S_AXI_ABURST == C_FIX_BURST );
  assign access_is_incr         = ( S_AXI_ABURST == C_INCR_BURST );
  assign access_is_wrap         = ( S_AXI_ABURST == C_WRAP_BURST );
  assign cmd_fix_i              = access_is_fix;
  
  // Get if it is allowed to modify transaction.
  assign access_is_modifiable   = S_AXI_ACACHE[1];
  
  // Get SI-side maximum length to fit MI-side.
  always @ *
  begin
    case (S_AXI_ASIZE)
      3'b000: si_maximum_length = C_S_AXI_NATIVE_SIZE >= 3'b000 ? C_DOUBLE_LEN[ 8-C_M_AXI_BYTES_LOG +: 8] : 8'b0;
      3'b001: si_maximum_length = C_S_AXI_NATIVE_SIZE >= 3'b001 ? C_DOUBLE_LEN[ 9-C_M_AXI_BYTES_LOG +: 8] : 8'b0;
      3'b010: si_maximum_length = C_S_AXI_NATIVE_SIZE >= 3'b010 ? C_DOUBLE_LEN[10-C_M_AXI_BYTES_LOG +: 8] : 8'b0;
      3'b011: si_maximum_length = C_S_AXI_NATIVE_SIZE >= 3'b011 ? C_DOUBLE_LEN[11-C_M_AXI_BYTES_LOG +: 8] : 8'b0;
      3'b100: si_maximum_length = C_S_AXI_NATIVE_SIZE >= 3'b100 ? C_DOUBLE_LEN[12-C_M_AXI_BYTES_LOG +: 8] : 8'b0;
      3'b101: si_maximum_length = C_S_AXI_NATIVE_SIZE >= 3'b101 ? C_DOUBLE_LEN[13-C_M_AXI_BYTES_LOG +: 8] : 8'b0;
      3'b110: si_maximum_length = C_S_AXI_NATIVE_SIZE >= 3'b110 ? C_DOUBLE_LEN[14-C_M_AXI_BYTES_LOG +: 8] : 8'b0;
      3'b111: si_maximum_length = C_S_AXI_NATIVE_SIZE >= 3'b111 ? C_DOUBLE_LEN[15-C_M_AXI_BYTES_LOG +: 8] : 8'b0;
    endcase
  end
  
  // Help vector to determine the length of thransaction in the MI-side domain.
  assign mi_word_intra_len_complete = {S_AXI_ALEN, 8'b0};
  
  // Get intra MI-side word length bits (in bytes).
  always @ *
  begin
    if ( C_SUPPORT_BURSTS == 1 ) begin
      if ( ~cmd_fix_i ) begin
        case (S_AXI_ASIZE)
          3'b000: mi_word_intra_len = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                                      mi_word_intra_len_complete[8-0 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
          3'b001: mi_word_intra_len = C_S_AXI_NATIVE_SIZE >= 3'b001 ? 
                                      mi_word_intra_len_complete[8-1 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
          3'b010: mi_word_intra_len = C_S_AXI_NATIVE_SIZE >= 3'b010 ? 
                                      mi_word_intra_len_complete[8-2 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
          3'b011: mi_word_intra_len = C_S_AXI_NATIVE_SIZE >= 3'b011 ? 
                                      mi_word_intra_len_complete[8-3 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
          3'b100: mi_word_intra_len = C_S_AXI_NATIVE_SIZE >= 3'b100 ? 
                                      mi_word_intra_len_complete[8-4 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
          3'b101: mi_word_intra_len = C_S_AXI_NATIVE_SIZE >= 3'b101 ? 
                                      mi_word_intra_len_complete[8-5 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
          3'b110: mi_word_intra_len = C_S_AXI_NATIVE_SIZE >= 3'b110 ? 
                                      mi_word_intra_len_complete[8-6 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
          3'b111: mi_word_intra_len = C_S_AXI_NATIVE_SIZE >= 3'b111 ? 
                                      mi_word_intra_len_complete[8-7 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};  // Illegal setting.
        endcase
      end else begin
        mi_word_intra_len = {C_M_AXI_BYTES_LOG{1'b0}};
      end
    end else begin
      mi_word_intra_len = {C_M_AXI_BYTES_LOG{1'b0}};
    end
  end
  
  // Get MI-side length after upsizing.
  always @ *
  begin
    if ( C_SUPPORT_BURSTS == 1 ) begin
      if ( cmd_fix_i | ~cmd_modified_i ) begin
        // Fix has to maintain length even if forced packing.
        upsized_length = S_AXI_ALEN;
      end else begin
        case (S_AXI_ASIZE)
          3'b000: upsized_length = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                                   (S_AXI_ALEN >> C_M_AXI_BYTES_LOG-0) : 8'b0;
          3'b001: upsized_length = C_S_AXI_NATIVE_SIZE >= 3'b001 ? 
                                   (S_AXI_ALEN >> C_M_AXI_BYTES_LOG-1) : 8'b0;
          3'b010: upsized_length = C_S_AXI_NATIVE_SIZE >= 3'b010 ? 
                                   (S_AXI_ALEN >> C_M_AXI_BYTES_LOG-2) : 8'b0;
          3'b011: upsized_length = C_S_AXI_NATIVE_SIZE >= 3'b011 ? 
                                   (S_AXI_ALEN >> C_M_AXI_BYTES_LOG-3) : 8'b0;
          3'b100: upsized_length = C_S_AXI_NATIVE_SIZE >= 3'b100 ? 
                                   (S_AXI_ALEN >> C_M_AXI_BYTES_LOG-4) : 8'b0;
          3'b101: upsized_length = C_S_AXI_NATIVE_SIZE >= 3'b101 ? 
                                   (S_AXI_ALEN >> C_M_AXI_BYTES_LOG-5) : 8'b0;
          3'b110: upsized_length = C_S_AXI_NATIVE_SIZE >= 3'b110 ? 
                                   (S_AXI_ALEN >> C_M_AXI_BYTES_LOG-6) : 8'b0;
          3'b111: upsized_length = C_S_AXI_NATIVE_SIZE >= 3'b111 ? 
                                   (S_AXI_ALEN                       ) : 8'b0;  // Illegal setting.
        endcase
      end
    end else begin
      upsized_length = 8'b0;
    end
  end
  
  // Generate address bits used for SI-side transaction size.
  always @ *
  begin
    case (S_AXI_ASIZE)
      3'b000: size_mask = ~C_DOUBLE_LEN[8 +: C_S_AXI_BYTES_LOG];
      3'b001: size_mask = ~C_DOUBLE_LEN[7 +: C_S_AXI_BYTES_LOG];
      3'b010: size_mask = ~C_DOUBLE_LEN[6 +: C_S_AXI_BYTES_LOG];
      3'b011: size_mask = ~C_DOUBLE_LEN[5 +: C_S_AXI_BYTES_LOG];
      3'b100: size_mask = ~C_DOUBLE_LEN[4 +: C_S_AXI_BYTES_LOG];
      3'b101: size_mask = ~C_DOUBLE_LEN[3 +: C_S_AXI_BYTES_LOG];
      3'b110: size_mask = ~C_DOUBLE_LEN[2 +: C_S_AXI_BYTES_LOG];
      3'b111: size_mask = ~C_DOUBLE_LEN[1 +: C_S_AXI_BYTES_LOG];  // Illegal setting.
    endcase
  end
  
  // Help vector to determine the length of thransaction in the MI-side domain.
  assign mask_help_vector = {4'b0, S_AXI_ALEN, 8'b1};
  
  // Calculate the address bits that are affected when a complete wrap is detected.
  always @ *
  begin
    if ( sub_sized_wrap & ( C_SUPPORT_BURSTS == 1 ) ) begin
      case (S_AXI_ASIZE)
        3'b000: cmd_mask_i = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                             mask_help_vector[8-0 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
        3'b001: cmd_mask_i = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                             mask_help_vector[8-1 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
        3'b010: cmd_mask_i = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                             mask_help_vector[8-2 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
        3'b011: cmd_mask_i = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                             mask_help_vector[8-3 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
        3'b100: cmd_mask_i = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                             mask_help_vector[8-4 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
        3'b101: cmd_mask_i = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                             mask_help_vector[8-5 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
        3'b110: cmd_mask_i = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                             mask_help_vector[8-6 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};
        3'b111: cmd_mask_i = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                             mask_help_vector[8-7 +: C_M_AXI_BYTES_LOG] : {C_M_AXI_BYTES_LOG{1'b0}};  // Illegal setting.
      endcase
    end else begin
      cmd_mask_i = {C_M_AXI_BYTES_LOG{1'b1}};
    end
  end

  // Calculate the address bits that are affected when a complete wrap is detected.
  always @ *
  begin
    case (S_AXI_ASIZE)
      3'b000: burst_mask = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                           mask_help_vector[8-0 +: C_BURST_BYTES_LOG] : {C_BURST_BYTES_LOG{1'b0}};
      3'b001: burst_mask = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                           mask_help_vector[8-1 +: C_BURST_BYTES_LOG] : {C_BURST_BYTES_LOG{1'b0}};
      3'b010: burst_mask = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                           mask_help_vector[8-2 +: C_BURST_BYTES_LOG] : {C_BURST_BYTES_LOG{1'b0}};
      3'b011: burst_mask = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                           mask_help_vector[8-3 +: C_BURST_BYTES_LOG] : {C_BURST_BYTES_LOG{1'b0}};
      3'b100: burst_mask = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                           mask_help_vector[8-4 +: C_BURST_BYTES_LOG] : {C_BURST_BYTES_LOG{1'b0}};
      3'b101: burst_mask = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                           mask_help_vector[8-5 +: C_BURST_BYTES_LOG] : {C_BURST_BYTES_LOG{1'b0}};
      3'b110: burst_mask = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                           mask_help_vector[8-6 +: C_BURST_BYTES_LOG] : {C_BURST_BYTES_LOG{1'b0}};
      3'b111: burst_mask = C_S_AXI_NATIVE_SIZE >= 3'b000 ? 
                           mask_help_vector[8-7 +: C_BURST_BYTES_LOG] : {C_BURST_BYTES_LOG{1'b0}};  // Illegal setting.
    endcase
  end

  // Propagate the SI-side size of the transaction.
  assign cmd_size_i = S_AXI_ASIZE;
  
  // Detect if there is any unalignment in regards to the MI-side.
  assign access_is_unaligned = ( S_AXI_AADDR[0 +: C_M_AXI_BYTES_LOG] != {C_M_AXI_BYTES_LOG{1'b0}} );
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Evaluate if transaction is to be translated:
  // * Forcefully translate when C_PACKING_LEVEL is set to C_ALWAYS_PACK. 
  // * When SI-side transaction size is native, it is allowed and default 
  //   packing is set. (Expander mode never packs).
  //
  /////////////////////////////////////////////////////////////////////////////
  
  // Modify transaction forcefully or when transaction allows it
  assign cmd_modified_i = ~access_is_fix &
                          ( ( C_PACKING_LEVEL == C_ALWAYS_PACK  ) | 
                            ( access_is_modifiable & ( S_AXI_ALEN != 8'b0 ) & ( C_PACKING_LEVEL == C_DEFAULT_PACK ) ) );
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Translate SI-side access to MI-side:
  //
  // Detemine if this is a complete WRAP. Conditions are that it must fit 
  // inside a single MI-side data word, it must be a WRAP access and that
  // bursts are allowed. Without burst there can never be a WRAP access.
  //
  // Determine if this ia a packed WRAP, i.e. a WRAP that is to large to 
  // be a complete wrap and it is unaligned SI-side address relative to 
  // the native MI-side data width.
  //
  // The address for the First SI-side data word is adjusted to when there 
  // is a complete WRAP, otherwise it only the least significant bits of the 
  // SI-side address.
  // For complete WRAP access the Offset is generated as the most significant 
  // bits that are left by the Mask.
  // Last address is calculated with the adjusted First word address.
  //
  // The Adjusted MI-side burst length is calculated as the Upsized length
  // plus one when the SI-side data must wrap on the MI-side (unless it is
  // a complete or packed WRAP).
  // 
  // Depending on the conditions some of the forwarded MI-side tranaction 
  // and Command Queue parameters has to be adjusted:
  // * For unmodified transaction the parameter are left un affected.
  //   (M_AXI_AADDR, M_AXI_ASIZE, M_AXI_ABURST, M_AXI_ALEN and cmd_length 
  //    are untouched)
  // * For complete WRAP transactions the burst type is changed to INCR
  //   and the address is adjusted to the sub-size affected by the transaction
  //   (the sub-size can be 2 bytes up to a full MI-side data word).
  //   The size is set to the native MI-side transaction size. And the length
  //   is set to the calculated upsized length.
  // * For all other modified transations the address and burst type remains 
  //   the same. The length is adjusted to the previosly described length
  //   and size is set to native MI-side transaction size.
  //
  /////////////////////////////////////////////////////////////////////////////
  
  // Detemine if this is a sub-sized transaction.
  assign sub_sized_wrap         = access_is_wrap & ( S_AXI_ALEN <= si_maximum_length ) & 
                                  ( C_SUPPORT_BURSTS == 1);
  
  // See if entite burst can fit inside one MI-side word.
  assign cmd_complete_wrap_i    = cmd_modified_i & sub_sized_wrap;
  
  // Detect if this is a packed WRAP (multiple MI-side words).
  assign cmd_packed_wrap_i      = cmd_modified_i & access_is_wrap & ( S_AXI_ALEN > si_maximum_length ) & 
                                  access_is_unaligned & ( C_SUPPORT_BURSTS == 1);
  
  // Get unalignment address bits (including aligning it inside covered area).
  assign cmd_first_word_ii      = S_AXI_AADDR[C_M_AXI_BYTES_LOG-1:0];
  assign cmd_first_word_i       = cmd_first_word_ii & cmd_mask_i & size_mask;
  
  // Generate next word address.
  assign cmd_next_word_ii       = cmd_first_word_ii + cmd_step_ii[C_M_AXI_BYTES_LOG-1:0];
  assign cmd_next_word_i        = cmd_next_word_ii & cmd_mask_i & size_mask;
  
  // Offset is the bits that is outside of the Mask.
  assign cmd_offset_i           = cmd_first_word_ii & ~cmd_mask_i;
  
  // Select RTL or Optimized implementation.
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_ADJUSTED_LEN
      // Calculate Last word on MI-side.
      assign cmd_last_word_ii       = cmd_first_word_i + mi_word_intra_len;
      assign cmd_last_word_i        = cmd_last_word_ii[C_M_AXI_BYTES_LOG-1:0] & cmd_mask_i & size_mask;
      
      // Detect if extra word on MI-side is needed.
      assign access_need_extra_word = cmd_last_word_ii[C_M_AXI_BYTES_LOG] & 
                                      access_is_incr & cmd_modified_i;
      
      // Calculate true length of modified transaction.
      assign adjusted_length        = upsized_length + access_need_extra_word;
          
    end else begin : USE_FPGA_ADJUSTED_LEN
      
      wire [C_M_AXI_BYTES_LOG:0]          last_word_local_carry;
      wire [C_M_AXI_BYTES_LOG-1:0]        last_word_sel;
      wire [C_M_AXI_BYTES_LOG:0]          last_word_for_mask_local_carry;
      wire [C_M_AXI_BYTES_LOG-1:0]        last_word_for_mask_dummy_carry1;
      wire [C_M_AXI_BYTES_LOG-1:0]        last_word_for_mask_dummy_carry2;
      wire [C_M_AXI_BYTES_LOG-1:0]        last_word_for_mask_dummy_carry3;
      wire [C_M_AXI_BYTES_LOG-1:0]        last_word_for_mask_sel;
      wire [C_M_AXI_BYTES_LOG-1:0]        last_word_for_mask;
      wire [C_M_AXI_BYTES_LOG-1:0]        last_word_mask;
      wire                                sel_access_need_extra_word;
      wire [8:0]                          adjusted_length_local_carry;
      wire [8-1:0]                        adjusted_length_sel;
    
      
      assign last_word_local_carry[0] = 1'b0;
      assign last_word_for_mask_local_carry[0] = 1'b0;
      
      for (bit_cnt = 0; bit_cnt < C_M_AXI_BYTES_LOG ; bit_cnt = bit_cnt + 1) begin : LUT_LAST_MASK
        
        assign last_word_for_mask_sel[bit_cnt]  = cmd_first_word_ii[bit_cnt] ^ mi_word_intra_len[bit_cnt];
        assign last_word_mask[bit_cnt]          = cmd_mask_i[bit_cnt] & size_mask[bit_cnt];
        
        MUXCY and_inst1 
        (
         .O (last_word_for_mask_dummy_carry1[bit_cnt]), 
         .CI (last_word_for_mask_local_carry[bit_cnt]), 
         .DI (mi_word_intra_len[bit_cnt]), 
         .S (last_word_for_mask_sel[bit_cnt])
        ); 
        
        MUXCY and_inst2 
        (
         .O (last_word_for_mask_dummy_carry2[bit_cnt]), 
         .CI (last_word_for_mask_dummy_carry1[bit_cnt]), 
         .DI (1'b0), 
         .S (1'b1)
        ); 
        
        MUXCY and_inst3 
        (
         .O (last_word_for_mask_dummy_carry3[bit_cnt]), 
         .CI (last_word_for_mask_dummy_carry2[bit_cnt]), 
         .DI (1'b0), 
         .S (1'b1)
        ); 
        
        MUXCY and_inst4 
        (
         .O (last_word_for_mask_local_carry[bit_cnt+1]), 
         .CI (last_word_for_mask_dummy_carry3[bit_cnt]), 
         .DI (1'b0), 
         .S (1'b1)
        ); 
        
        XORCY xorcy_inst 
        (
         .O(last_word_for_mask[bit_cnt]),
         .CI(last_word_for_mask_local_carry[bit_cnt]),
         .LI(last_word_for_mask_sel[bit_cnt])
        );
        
        carry_latch_and #
          (
           .C_FAMILY(C_FAMILY)
           ) last_mask_inst
          (
           .CIN(last_word_for_mask[bit_cnt]),
           .I(last_word_mask[bit_cnt]),
           .O(cmd_last_word_i[bit_cnt])
           );
           
      end // end for bit_cnt
      
      for (bit_cnt = 0; bit_cnt < C_M_AXI_BYTES_LOG ; bit_cnt = bit_cnt + 1) begin : LUT_LAST
        
        assign last_word_sel[bit_cnt] = cmd_first_word_ii[bit_cnt] ^ mi_word_intra_len[bit_cnt];
        
        MUXCY and_inst 
        (
         .O (last_word_local_carry[bit_cnt+1]), 
         .CI (last_word_local_carry[bit_cnt]), 
         .DI (mi_word_intra_len[bit_cnt]), 
         .S (last_word_sel[bit_cnt])
        ); 
        
        XORCY xorcy_inst 
        (
         .O(cmd_last_word_ii[bit_cnt]),
         .CI(last_word_local_carry[bit_cnt]),
         .LI(last_word_sel[bit_cnt])
        );
        
      end // end for bit_cnt
      
      assign sel_access_need_extra_word = access_is_incr & cmd_modified_i;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) access_need_extra_word_inst
        (
         .CIN(last_word_local_carry[C_M_AXI_BYTES_LOG]),
         .S(sel_access_need_extra_word),
         .COUT(adjusted_length_local_carry[0])
         );
         
      for (bit_cnt = 0; bit_cnt < 8 ; bit_cnt = bit_cnt + 1) begin : LUT_ADJUST
        
        assign adjusted_length_sel[bit_cnt] = ( upsized_length[bit_cnt] &  cmd_modified_i) |
                                              ( S_AXI_ALEN[bit_cnt]     & ~cmd_modified_i);
        
        MUXCY and_inst 
        (
         .O (adjusted_length_local_carry[bit_cnt+1]), 
         .CI (adjusted_length_local_carry[bit_cnt]), 
         .DI (1'b0), 
         .S (adjusted_length_sel[bit_cnt])
        ); 
        
        XORCY xorcy_inst 
        (
         .O(adjusted_length[bit_cnt]),
         .CI(adjusted_length_local_carry[bit_cnt]),
         .LI(adjusted_length_sel[bit_cnt])
        );
        
      end // end for bit_cnt
      
    end
  endgenerate
  
  // Generate adjusted wrap address.
  assign wrap_addr_aligned      = ( C_AXI_CHANNEL != 0 ) ? 
                                  ( S_AXI_AADDR[0 +: C_BURST_BYTES_LOG] ) :
                                  ( S_AXI_AADDR[0 +: C_BURST_BYTES_LOG] + ( 2 ** C_M_AXI_BYTES_LOG ) );
  
  // Select directly forwarded or modified transaction.
  always @ *
  begin
    if ( cmd_modified_i ) begin
      // SI to MI-side transaction translation.
      if ( cmd_complete_wrap_i ) begin
        // Complete wrap is turned into incr
        M_AXI_AADDR_I  = S_AXI_AADDR & {{C_MI_UNUSED_LOG{1'b1}}, ~cmd_mask_i};
        M_AXI_ABURST_I = C_INCR_BURST;
        
      end else begin
        // Retain the currenent 
        if ( cmd_packed_wrap_i ) begin
            M_AXI_AADDR_I  = {S_AXI_AADDR[C_BURST_BYTES_LOG +: C_AXI_ADDR_WIDTH-C_BURST_BYTES_LOG], 
                              (S_AXI_AADDR[0 +: C_BURST_BYTES_LOG] & ~burst_mask) | (wrap_addr_aligned & burst_mask) } & 
                             {{C_MI_UNUSED_LOG{1'b1}}, ~cmd_mask_i};
        end else begin
          M_AXI_AADDR_I  = S_AXI_AADDR;
        end
        M_AXI_ABURST_I = S_AXI_ABURST;
        
      end
      
      M_AXI_ASIZE_I  = C_M_AXI_NATIVE_SIZE;
    end else begin
      // SI to MI-side transaction forwarding.
      M_AXI_AADDR_I  = S_AXI_AADDR;
      M_AXI_ASIZE_I  = S_AXI_ASIZE;
      M_AXI_ABURST_I = S_AXI_ABURST;
    end
    
    M_AXI_ALEN_I   = adjusted_length;
    cmd_length_i   = adjusted_length;
  end
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Forward the command to the MI-side interface.
  //
  // It is determined that this is an allowed command/access when there is 
  // room in the command queue (and it passes any ID checks as required).
  //
  /////////////////////////////////////////////////////////////////////////////
  
  // Select RTL or Optimized implementation.
  generate
    if ( C_FAMILY == "rtl" || ( C_SINGLE_THREAD == 0 ) ) begin : USE_RTL_AVALID
      // Only allowed to forward translated command when command queue is ok with it.
      assign M_AXI_AVALID_I = allow_new_cmd & S_AXI_AVALID;
      
    end else begin : USE_FPGA_AVALID
      
      wire sel_s_axi_avalid;
      
      assign sel_s_axi_avalid = S_AXI_AVALID & ~ARESET;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) avalid_inst
        (
         .CIN(allow_new_cmd),
         .S(sel_s_axi_avalid),
         .COUT(M_AXI_AVALID_I)
         );
      
    end
  endgenerate
                          
  
  /////////////////////////////////////////////////////////////////////////////
  // Simple transfer of paramters that doesn't need to be adjusted.
  //
  // ID     - Transaction still recognized with the same ID.
  // LOCK   - No need to change exclusive or barrier transactions.
  // CACHE  - No need to change the chache features. Even if the modyfiable
  //          bit is overridden (forcefully) there is no need to let downstream
  //          component beleive it is ok to modify it further.
  // PROT   - Security level of access is not changed when upsizing.
  // REGION - Address region stays the same.
  // QOS    - Quality of Service remains the same.
  // USER   - User bits remains the same.
  // 
  /////////////////////////////////////////////////////////////////////////////
  
  assign M_AXI_AID_I      = S_AXI_AID;
  assign M_AXI_ALOCK_I    = S_AXI_ALOCK;
  assign M_AXI_ACACHE_I   = S_AXI_ACACHE;
  assign M_AXI_APROT_I    = S_AXI_APROT;
  assign M_AXI_AREGION_I  = S_AXI_AREGION;
  assign M_AXI_AQOS_I     = S_AXI_AQOS;
  assign M_AXI_AUSER_I    = ( C_AXI_SUPPORTS_USER_SIGNALS ) ? S_AXI_AUSER : {C_AXI_AUSER_WIDTH{1'b0}};
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Command queue to W/R channel.
  // 
  // Commands can be pushed into the Cmd FIFO even if MI-side is stalling.
  // A flag is set if MI-side is stalling when Command is pushed to the 
  // Cmd FIFO. This will prevent multiple push of the same Command as well as
  // keeping the MI-side Valid signal if the Allow Cmd requirement has been 
  // updated to disable furter Commands (I.e. it is made sure that the SI-side 
  // Command has been forwarded to both Cmd FIFO and MI-side).
  // 
  // It is allowed to continue pushing new commands as long as
  // * There is room in the queue
  // * The ID is the same as previously queued. Since data is not reordered
  //   for the same ID it is ok to let them proceed.
  //
  /////////////////////////////////////////////////////////////////////////////
  
  // Keep track of current ID in queue.
  always @ (posedge ACLK) begin
    if (ARESET) begin
      queue_id <= {C_AXI_ID_WIDTH{1'b0}};
    end else begin
      if ( cmd_push ) begin
        // Store ID (it will be matching ID or a "new beginning").
        queue_id <= S_AXI_AID;
      end
    end
  end
  
  // Select RTL or Optimized implementation.
  generate
    if ( C_FAMILY == "rtl" || ( C_SINGLE_THREAD == 0 ) ) begin : USE_RTL_ID_MATCH
      // Check ID to make sure this command is allowed.
      assign id_match       = ( C_SINGLE_THREAD == 0 ) | ( queue_id == S_AXI_AID);
      assign cmd_id_check   = cmd_empty | ( id_match & ~cmd_empty );
      
      // Check if it is allowed to push more commands (ID is allowed and there is room in the queue).
      assign allow_new_cmd  = (~cmd_full & cmd_id_check) | cmd_push_block;
      
      // Push new command when allowed and MI-side is able to receive the command.
      assign cmd_push       = M_AXI_AVALID_I & ~cmd_push_block;
      
    end else begin : USE_FPGA_ID_MATCH
      
      wire cmd_id_check_i;
      wire allow_new_cmd_i;
      wire sel_cmd_id_check;
      wire sel_cmd_push;
      
      comparator #
        (
         .C_FAMILY(C_FAMILY),
         .C_DATA_WIDTH(C_AXI_ID_WIDTH)
         ) id_match_inst
        (
         .CIN(1'b1),
         .A(queue_id),
         .B(S_AXI_AID),
         .COUT(id_match)
         );
         
      assign sel_cmd_id_check = ~cmd_empty;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) cmd_id_check_inst_1
        (
         .CIN(id_match),
         .S(sel_cmd_id_check),
         .COUT(cmd_id_check_i)
         );

      carry_or #
        (
         .C_FAMILY(C_FAMILY)
         ) cmd_id_check_inst_2
        (
         .CIN(cmd_id_check_i),
         .S(cmd_empty),
         .COUT(cmd_id_check)
         );
         
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) allow_new_cmd_inst_1
        (
         .CIN(cmd_id_check),
         .S(s_ready),
         .COUT(allow_new_cmd_i)
         );

      carry_or #
        (
         .C_FAMILY(C_FAMILY)
         ) allow_new_cmd_inst_2
        (
         .CIN(allow_new_cmd_i),
         .S(cmd_push_block),
         .COUT(allow_new_cmd)
         );
         
      assign sel_cmd_push = ~cmd_push_block;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) cmd_push_inst
        (
         .CIN(M_AXI_AVALID_I),
         .S(sel_cmd_push),
         .COUT(cmd_push)
         );

    end
  endgenerate
  
  // Block furter push until command has been forwarded to MI-side.
  always @ (posedge ACLK) begin
    if (ARESET) begin
      cmd_push_block <= 1'b0;
    end else begin
      cmd_push_block <= M_AXI_AVALID_I & ~M_AXI_AREADY_I;
    end
  end
  
  // Acknowledge command when we can push it into queue (and forward it).
  assign S_AXI_AREADY_I = M_AXI_AREADY_I & allow_new_cmd & ~ARESET;
  assign S_AXI_AREADY   = S_AXI_AREADY_I;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Command Queue:
  // 
  // Instantiate a FIFO as the queue and adjust the control signals.
  //
  // Decode size to step before passing it along.
  //
  // When there is no need for bursts the command FIFO can be greatly reduced 
  // becase the following is always true:
  // * first = last
  // * length = 0
  // * nothing can be packed (i.e. no WRAP at all)
  //   * never any sub-size wraping => static offset (0) and mask (1)
  // 
  /////////////////////////////////////////////////////////////////////////////
  
  // Translate SI-side size to step for upsizer function.
  always @ *
  begin
    case (cmd_size_i)
      3'b000: cmd_step_ii = 8'b00000001;
      3'b001: cmd_step_ii = 8'b00000010;
      3'b010: cmd_step_ii = 8'b00000100;
      3'b011: cmd_step_ii = 8'b00001000;
      3'b100: cmd_step_ii = 8'b00010000;
      3'b101: cmd_step_ii = 8'b00100000;
      3'b110: cmd_step_ii = 8'b01000000;
      3'b111: cmd_step_ii = 8'b10000000; // Illegal setting.
    endcase
  end
  
  // Get only the applicable bits in step.
  assign cmd_step_i = cmd_step_ii[C_S_AXI_BYTES_LOG:0];
  
  // Instantiated queue.
  generate
    if (C_SUPPORT_BURSTS == 1) begin : USE_BURSTS
      command_fifo #
      (
       .C_FAMILY                    (C_FAMILY),
       .C_ENABLE_S_VALID_CARRY      (1),
       .C_ENABLE_REGISTERED_OUTPUT  (1),
       .C_FIFO_DEPTH_LOG            (C_FIFO_DEPTH_LOG),
       .C_FIFO_WIDTH                (1+1+1+1+C_M_AXI_BYTES_LOG+C_M_AXI_BYTES_LOG+
                                     C_M_AXI_BYTES_LOG+C_M_AXI_BYTES_LOG+C_M_AXI_BYTES_LOG+C_S_AXI_BYTES_LOG+1+8)
       ) 
       cmd_queue
      (
       .ACLK    (ACLK),
       .ARESET  (ARESET),
       .EMPTY   (cmd_empty),
       .S_MESG  ({cmd_fix_i, cmd_modified_i, cmd_complete_wrap_i, cmd_packed_wrap_i, cmd_first_word_i, cmd_next_word_i, 
                  cmd_last_word_i, cmd_offset_i, cmd_mask_i, cmd_step_i, cmd_length_i}),
       .S_VALID (cmd_push),
       .S_READY (s_ready),
       .M_MESG  ({cmd_fix, cmd_modified, cmd_complete_wrap, cmd_packed_wrap, cmd_first_word, cmd_next_word, 
                  cmd_last_word, cmd_offset, cmd_mask, cmd_step, cmd_length}),
       .M_VALID (cmd_valid_i),
       .M_READY (cmd_ready)
       );
    end else begin : NO_BURSTS
    
      wire [C_M_AXI_BYTES_LOG-1:0]        cmd_first_word_out;
  
      command_fifo #
      (
       .C_FAMILY                    (C_FAMILY),
       .C_ENABLE_S_VALID_CARRY      (1),
       .C_ENABLE_REGISTERED_OUTPUT  (1),
       .C_FIFO_DEPTH_LOG            (C_FIFO_DEPTH_LOG),
       .C_FIFO_WIDTH                (1+C_M_AXI_BYTES_LOG+C_S_AXI_BYTES_LOG+1)
       ) 
       cmd_queue
      (
       .ACLK    (ACLK),
       .ARESET  (ARESET),
       .EMPTY   (cmd_empty),
       .S_MESG  ({cmd_fix_i, cmd_first_word_i, cmd_step_i}),
       .S_VALID (cmd_push),
       .S_READY (s_ready),
       .M_MESG  ({cmd_fix, cmd_first_word_out, cmd_step}),
       .M_VALID (cmd_valid_i),
       .M_READY (cmd_ready)
       );
       
       assign cmd_modified      = ( C_PACKING_LEVEL == C_ALWAYS_PACK ) ? 1'b1 : 1'b0;
       assign cmd_complete_wrap = 1'b0;
       assign cmd_packed_wrap   = 1'b0;
       assign cmd_first_word    = cmd_first_word_out;
       assign cmd_next_word     = cmd_first_word_out;
       assign cmd_last_word     = cmd_first_word_out;
       assign cmd_offset        = {C_M_AXI_BYTES_LOG{1'b0}};
       assign cmd_mask          = {C_M_AXI_BYTES_LOG{1'b1}};
       assign cmd_length        = 8'b0;
    end
  endgenerate

  // Queue is concidered full when not ready.
  assign cmd_full = ~s_ready;
  
  // Assign external signal.
  assign cmd_valid = cmd_valid_i;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // MI-side output handling
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_M_AXI_REGISTER ) begin : USE_REGISTER
    
      reg  [C_AXI_ID_WIDTH-1:0]           M_AXI_AID_q;
      reg  [C_AXI_ADDR_WIDTH-1:0]         M_AXI_AADDR_q;
      reg  [8-1:0]                        M_AXI_ALEN_q;
      reg  [3-1:0]                        M_AXI_ASIZE_q;
      reg  [2-1:0]                        M_AXI_ABURST_q;
      reg  [2-1:0]                        M_AXI_ALOCK_q;
      reg  [4-1:0]                        M_AXI_ACACHE_q;
      reg  [3-1:0]                        M_AXI_APROT_q;
      reg  [4-1:0]                        M_AXI_AREGION_q;
      reg  [4-1:0]                        M_AXI_AQOS_q;
      reg  [C_AXI_AUSER_WIDTH-1:0]        M_AXI_AUSER_q;
      reg                                 M_AXI_AVALID_q;
    
      // Register MI-side Data.
      always @ (posedge ACLK) begin
        if (ARESET) begin
          M_AXI_AVALID_q    <= 1'b0;
        end else if ( M_AXI_AREADY_I ) begin
          M_AXI_AVALID_q    <= M_AXI_AVALID_I;
        end

        if ( M_AXI_AREADY_I ) begin
          M_AXI_AID_q       <= M_AXI_AID_I;
          M_AXI_AADDR_q     <= M_AXI_AADDR_I;
          M_AXI_ALEN_q      <= M_AXI_ALEN_I;
          M_AXI_ASIZE_q     <= M_AXI_ASIZE_I;
          M_AXI_ABURST_q    <= M_AXI_ABURST_I;
          M_AXI_ALOCK_q     <= M_AXI_ALOCK_I;
          M_AXI_ACACHE_q    <= M_AXI_ACACHE_I;
          M_AXI_APROT_q     <= M_AXI_APROT_I;
          M_AXI_AREGION_q   <= M_AXI_AREGION_I;
          M_AXI_AQOS_q      <= M_AXI_AQOS_I;
          M_AXI_AUSER_q     <= M_AXI_AUSER_I;
        end
      end
      
      assign M_AXI_AID        = M_AXI_AID_q;
      assign M_AXI_AADDR      = M_AXI_AADDR_q;
      assign M_AXI_ALEN       = M_AXI_ALEN_q;
      assign M_AXI_ASIZE      = M_AXI_ASIZE_q;
      assign M_AXI_ABURST     = M_AXI_ABURST_q;
      assign M_AXI_ALOCK      = M_AXI_ALOCK_q;
      assign M_AXI_ACACHE     = M_AXI_ACACHE_q;
      assign M_AXI_APROT      = M_AXI_APROT_q;
      assign M_AXI_AREGION    = M_AXI_AREGION_q;
      assign M_AXI_AQOS       = M_AXI_AQOS_q;
      assign M_AXI_AUSER      = M_AXI_AUSER_q;
      assign M_AXI_AVALID     = M_AXI_AVALID_q;
      assign M_AXI_AREADY_I = ( M_AXI_AVALID_q & M_AXI_AREADY) | ~M_AXI_AVALID_q;
      
    end else begin : NO_REGISTER
    
      // Combinatorial MI-side Data.
      assign M_AXI_AID      = M_AXI_AID_I;
      assign M_AXI_AADDR    = M_AXI_AADDR_I;
      assign M_AXI_ALEN     = M_AXI_ALEN_I;
      assign M_AXI_ASIZE    = M_AXI_ASIZE_I;
      assign M_AXI_ABURST   = M_AXI_ABURST_I;
      assign M_AXI_ALOCK    = M_AXI_ALOCK_I;
      assign M_AXI_ACACHE   = M_AXI_ACACHE_I;
      assign M_AXI_APROT    = M_AXI_APROT_I;
      assign M_AXI_AREGION  = M_AXI_AREGION_I;
      assign M_AXI_AQOS     = M_AXI_AQOS_I;
      assign M_AXI_AUSER    = M_AXI_AUSER_I;
      assign M_AXI_AVALID   = M_AXI_AVALID_I;
      assign M_AXI_AREADY_I = M_AXI_AREADY;
                          
    end
  endgenerate
  
  
endmodule










module command_fifo #
  (
   parameter         C_FAMILY                        = "virtex6",
   parameter integer C_ENABLE_S_VALID_CARRY          = 0,
   parameter integer C_ENABLE_REGISTERED_OUTPUT      = 0,
   parameter integer C_FIFO_DEPTH_LOG                = 5,      // FIFO depth = 2**C_FIFO_DEPTH_LOG
                                                               // Range = [4:5].
   parameter integer C_FIFO_WIDTH                    = 64      // Width of payload [1:512]
   )
  (
   // Global inputs
   input  wire                        ACLK,    // Clock
   input  wire                        ARESET,  // Reset
   // Information
   output wire                        EMPTY,   // FIFO empty (all stages)
   // Slave  Port
   input  wire [C_FIFO_WIDTH-1:0]     S_MESG,  // Payload (may be any set of channel signals)
   input  wire                        S_VALID, // FIFO push
   output wire                        S_READY, // FIFO not full
   // Master  Port
   output wire [C_FIFO_WIDTH-1:0]     M_MESG,  // Payload
   output wire                        M_VALID, // FIFO not empty
   input  wire                        M_READY  // FIFO pop
   );

  /////////////////////////////////////////////////////////////////////////////
  // Variables for generating parameter controlled instances.
  /////////////////////////////////////////////////////////////////////////////
  
  // Generate variable for data vector.
  genvar addr_cnt;
  genvar bit_cnt;
  integer index;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Internal signals
  /////////////////////////////////////////////////////////////////////////////
  
  wire [C_FIFO_DEPTH_LOG-1:0] addr;
  wire                        buffer_Full;
  wire                        buffer_Empty;
  
  wire                        next_Data_Exists;
  reg                         data_Exists_I;
  
  wire                        valid_Write;
  wire                        new_write;
  
  wire [C_FIFO_DEPTH_LOG-1:0] hsum_A;
  wire [C_FIFO_DEPTH_LOG-1:0] sum_A;
  wire [C_FIFO_DEPTH_LOG-1:0] addr_cy;

  wire                        buffer_full_early;
  
  wire [C_FIFO_WIDTH-1:0]     M_MESG_I;   // Payload
  wire                        M_VALID_I;  // FIFO not empty
  wire                        M_READY_I;  // FIFO pop
  
  /////////////////////////////////////////////////////////////////////////////
  // Create Flags 
  /////////////////////////////////////////////////////////////////////////////
  
  assign buffer_full_early  = ( (addr == {{C_FIFO_DEPTH_LOG-1{1'b1}}, 1'b0}) & valid_Write & ~M_READY_I ) |
                              ( buffer_Full & ~M_READY_I );

  assign S_READY            = ~buffer_Full;

  assign buffer_Empty       = (addr == {C_FIFO_DEPTH_LOG{1'b0}});

  assign next_Data_Exists   = (data_Exists_I & ~buffer_Empty) |
                              (buffer_Empty & S_VALID) |
                              (data_Exists_I & ~(M_READY_I & data_Exists_I));

  always @ (posedge ACLK) begin
    if (ARESET) begin
      data_Exists_I <= 1'b0;
    end else begin
      data_Exists_I <= next_Data_Exists;
    end
  end

  assign M_VALID_I = data_Exists_I;
  
  // Select RTL or FPGA optimized instatiations for critical parts.
  generate
    if ( C_FAMILY == "rtl" || C_ENABLE_S_VALID_CARRY == 0 ) begin : USE_RTL_VALID_WRITE
      reg                         buffer_Full_q;
      
      assign valid_Write = S_VALID & ~buffer_Full;
      
      assign new_write = (S_VALID | ~buffer_Empty);
     
      assign addr_cy[0] = valid_Write;
      
      always @ (posedge ACLK) begin
        if (ARESET) begin
          buffer_Full_q <= 1'b0;
        end else if ( data_Exists_I ) begin
          buffer_Full_q <= buffer_full_early;
        end
      end
      assign buffer_Full = buffer_Full_q;
      
    end else begin : USE_FPGA_VALID_WRITE
      wire s_valid_dummy1;
      wire s_valid_dummy2;
      wire sel_s_valid;
      wire sel_new_write;
      wire valid_Write_dummy1;
      wire valid_Write_dummy2;
      
      assign sel_s_valid = ~buffer_Full;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) s_valid_dummy_inst1
        (
         .CIN(S_VALID),
         .S(1'b1),
         .COUT(s_valid_dummy1)
         );
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) s_valid_dummy_inst2
        (
         .CIN(s_valid_dummy1),
         .S(1'b1),
         .COUT(s_valid_dummy2)
         );
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) valid_write_inst
        (
         .CIN(s_valid_dummy2),
         .S(sel_s_valid),
         .COUT(valid_Write)
         );
      
      assign sel_new_write = ~buffer_Empty;
       
      carry_latch_or #
        (
         .C_FAMILY(C_FAMILY)
         ) new_write_inst
        (
         .CIN(valid_Write),
         .I(sel_new_write),
         .O(new_write)
         );
         
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) valid_write_dummy_inst1
        (
         .CIN(valid_Write),
         .S(1'b1),
         .COUT(valid_Write_dummy1)
         );
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) valid_write_dummy_inst2
        (
         .CIN(valid_Write_dummy1),
         .S(1'b1),
         .COUT(valid_Write_dummy2)
         );
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) valid_write_dummy_inst3
        (
         .CIN(valid_Write_dummy2),
         .S(1'b1),
         .COUT(addr_cy[0])
         );
      
      FDRE #(
       .INIT(1'b0)              // Initial value of register (1'b0 or 1'b1)
       ) FDRE_I1 (
       .Q(buffer_Full),         // Data output
       .C(ACLK),                // Clock input
       .CE(data_Exists_I),      // Clock enable input
       .R(ARESET),              // Synchronous reset input
       .D(buffer_full_early)    // Data input
       );
       
    end
  endgenerate
      
    
  /////////////////////////////////////////////////////////////////////////////
  // Create address pointer
  /////////////////////////////////////////////////////////////////////////////

  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_ADDR
    
      reg  [C_FIFO_DEPTH_LOG-1:0] addr_q;
      
      always @ (posedge ACLK) begin
        if (ARESET) begin
          addr_q <= {C_FIFO_DEPTH_LOG{1'b0}};
        end else if ( data_Exists_I ) begin
          if ( valid_Write & ~(M_READY_I & data_Exists_I) ) begin
            addr_q <= addr_q + 1'b1;
          end else if ( ~valid_Write & (M_READY_I & data_Exists_I) & ~buffer_Empty ) begin
            addr_q <= addr_q - 1'b1;
          end
          else begin
            addr_q <= addr_q;
          end
        end
        else begin
          addr_q <= addr_q;
        end
      end
      
      assign addr = addr_q;
      
    end else begin : USE_FPGA_ADDR
      for (addr_cnt = 0; addr_cnt < C_FIFO_DEPTH_LOG ; addr_cnt = addr_cnt + 1) begin : ADDR_GEN
        assign hsum_A[addr_cnt] = ((M_READY_I & data_Exists_I) ^ addr[addr_cnt]) & new_write;
        
        // Don't need the last muxcy, addr_cy(last) is not used anywhere
        if ( addr_cnt < C_FIFO_DEPTH_LOG - 1 ) begin : USE_MUXCY
          MUXCY MUXCY_inst (
           .DI(addr[addr_cnt]),
           .CI(addr_cy[addr_cnt]),
           .S(hsum_A[addr_cnt]),
           .O(addr_cy[addr_cnt+1])
           );
           
        end
        else begin : NO_MUXCY
        end
        
        XORCY XORCY_inst (
         .LI(hsum_A[addr_cnt]),
         .CI(addr_cy[addr_cnt]),
         .O(sum_A[addr_cnt])
         );
        
        FDRE #(
         .INIT(1'b0)             // Initial value of register (1'b0 or 1'b1)
         ) FDRE_inst (
         .Q(addr[addr_cnt]),     // Data output
         .C(ACLK),               // Clock input
         .CE(data_Exists_I),     // Clock enable input
         .R(ARESET),             // Synchronous reset input
         .D(sum_A[addr_cnt])     // Data input
         );
        
      end // end for bit_cnt
    end // C_FAMILY
  endgenerate
      
      
  /////////////////////////////////////////////////////////////////////////////
  // Data storage
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_FIFO
      reg  [C_FIFO_WIDTH-1:0] data_srl[2 ** C_FIFO_DEPTH_LOG-1:0];
      
      always @ (posedge ACLK) begin
        if ( valid_Write ) begin
          for (index = 0; index < 2 ** C_FIFO_DEPTH_LOG-1 ; index = index + 1) begin
            data_srl[index+1] <= data_srl[index];
          end
          data_srl[0]   <= S_MESG;
        end
      end
      
      assign M_MESG_I = data_srl[addr];
      
    end else begin : USE_FPGA_FIFO
      for (bit_cnt = 0; bit_cnt < C_FIFO_WIDTH ; bit_cnt = bit_cnt + 1) begin : DATA_GEN
        
        if ( C_FIFO_DEPTH_LOG == 5 ) begin : USE_32
            SRLC32E # (
             .INIT(32'h00000000)    // Initial Value of Shift Register
            ) SRLC32E_inst (
             .Q(M_MESG_I[bit_cnt]), // SRL data output
             .Q31(),                // SRL cascade output pin
             .A(addr),              // 5-bit shift depth select input
             .CE(valid_Write),      // Clock enable input
             .CLK(ACLK),            // Clock input
             .D(S_MESG[bit_cnt])    // SRL data input
            );
        end else begin : USE_16
            SRLC16E # (
             .INIT(32'h00000000)    // Initial Value of Shift Register
            ) SRLC16E_inst (
             .Q(M_MESG_I[bit_cnt]), // SRL data output
             .Q15(),                // SRL cascade output pin
             .A0(addr[0]),          // 4-bit shift depth select input 0
             .A1(addr[1]),          // 4-bit shift depth select input 1
             .A2(addr[2]),          // 4-bit shift depth select input 2
             .A3(addr[3]),          // 4-bit shift depth select input 3
             .CE(valid_Write),      // Clock enable input
             .CLK(ACLK),            // Clock input
             .D(S_MESG[bit_cnt])    // SRL data input
            );
        end // C_FIFO_DEPTH_LOG
      
      end // end for bit_cnt
    end // C_FAMILY
  endgenerate
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Pipeline stage
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_ENABLE_REGISTERED_OUTPUT != 0 ) begin : USE_FF_OUT
      
      wire [C_FIFO_WIDTH-1:0]     M_MESG_FF;    // Payload
      wire                        M_VALID_FF;   // FIFO not empty
      
      // Select RTL or FPGA optimized instatiations for critical parts.
      if ( C_FAMILY == "rtl" ) begin : USE_RTL_OUTPUT_PIPELINE
      
        reg  [C_FIFO_WIDTH-1:0]     M_MESG_Q;   // Payload
        reg                         M_VALID_Q;  // FIFO not empty
        
        always @ (posedge ACLK) begin
          if (ARESET) begin
            M_MESG_Q    <= {C_FIFO_WIDTH{1'b0}};
            M_VALID_Q   <= 1'b0;
          end else begin
            if ( M_READY_I ) begin
              M_MESG_Q    <= M_MESG_I;
              M_VALID_Q   <= M_VALID_I;
            end
          end
        end
      
        assign M_MESG_FF     = M_MESG_Q;
        assign M_VALID_FF    = M_VALID_Q;
        
      end else begin : USE_FPGA_OUTPUT_PIPELINE
      
        reg  [C_FIFO_WIDTH-1:0]     M_MESG_CMB;   // Payload
        reg                         M_VALID_CMB;  // FIFO not empty
        
        always @ *
        begin
          if ( M_READY_I ) begin
            M_MESG_CMB  <= M_MESG_I;
            M_VALID_CMB <= M_VALID_I;
          end else begin
            M_MESG_CMB  <= M_MESG_FF;
            M_VALID_CMB <= M_VALID_FF;
          end
        end
        
        for (bit_cnt = 0; bit_cnt < C_FIFO_WIDTH ; bit_cnt = bit_cnt + 1) begin : DATA_GEN
              
          FDRE #(
           .INIT(1'b0)                    // Initial value of register (1'b0 or 1'b1)
           ) FDRE_inst (
           .Q(M_MESG_FF[bit_cnt]),        // Data output
           .C(ACLK),                      // Clock input
           .CE(1'b1),                     // Clock enable input
           .R(ARESET),                    // Synchronous reset input
           .D(M_MESG_CMB[bit_cnt])        // Data input
           );
        end // end for bit_cnt
            
        FDRE #(
         .INIT(1'b0)                    // Initial value of register (1'b0 or 1'b1)
         ) FDRE_inst (
         .Q(M_VALID_FF),                // Data output
         .C(ACLK),                      // Clock input
         .CE(1'b1),                     // Clock enable input
         .R(ARESET),                    // Synchronous reset input
         .D(M_VALID_CMB)                // Data input
         );
      
      end
      
      assign EMPTY      = ~M_VALID_I & ~M_VALID_FF;
      assign M_MESG     = M_MESG_FF;
      assign M_VALID    = M_VALID_FF;
      assign M_READY_I  = ( M_READY & M_VALID_FF ) | ~M_VALID_FF;
      
    end else begin : NO_FF_OUT
      
      assign EMPTY      = ~M_VALID_I;
      assign M_MESG     = M_MESG_I;
      assign M_VALID    = M_VALID_I;
      assign M_READY_I  = M_READY;
      
    end
  endgenerate

endmodule









module w_upsizer #
  (
   parameter         C_FAMILY                         = "rtl", 
                       // FPGA Family. Current version: virtex6 or spartan6.
   parameter         C_S_AXI_DATA_WIDTH               = 32'h00000020, 
                       // Width of S_AXI_WDATA and S_AXI_RDATA.
                       // Format: Bit32; 
                       // Range: 'h00000020, 'h00000040, 'h00000080, 'h00000100.
   parameter         C_M_AXI_DATA_WIDTH               = 32'h00000040, 
                       // Width of M_AXI_WDATA and M_AXI_RDATA.
                       // Assume greater than or equal to C_S_AXI_DATA_WIDTH.
                       // Format: Bit32;
                       // Range: 'h00000020, 'h00000040, 'h00000080, 'h00000100.
   parameter integer C_M_AXI_REGISTER                 = 0,
                       // Clock output data.
                       // Range: 0, 1
   parameter integer C_AXI_SUPPORTS_USER_SIGNALS      = 0,
                       // 1 = Propagate all USER signals, 0 = Dont propagate.
   parameter integer C_AXI_WUSER_WIDTH                = 1,
                       // Width of WUSER signals. 
                       // Range: >= 1.
   parameter integer C_PACKING_LEVEL                    = 1,
                       // 0 = Never pack (expander only); packing logic is omitted.
                       // 1 = Pack only when CACHE[1] (Modifiable) is high.
                       // 2 = Always pack, regardless of sub-size transaction or Modifiable bit.
                       //     (Required when used as helper-core by mem-con.)
   parameter integer C_SUPPORT_BURSTS                 = 1,
                       // Disabled when all connected masters and slaves are AxiLite,
                       //   allowing logic to be simplified.
   parameter integer C_S_AXI_BYTES_LOG                = 3,
                       // Log2 of number of 32bit word on SI-side.
   parameter integer C_M_AXI_BYTES_LOG                = 3,
                       // Log2 of number of 32bit word on MI-side.
   parameter integer C_RATIO                          = 2,
                       // Up-Sizing ratio for data.
   parameter integer C_RATIO_LOG                      = 1
                       // Log2 of Up-Sizing ratio for data.
   )
  (
   // Global Signals
   input  wire                                                    ARESET,
   input  wire                                                    ACLK,

   // Command Interface
   input  wire                              cmd_valid,
   input  wire                              cmd_fix,
   input  wire                              cmd_modified,
   input  wire                              cmd_complete_wrap,
   input  wire                              cmd_packed_wrap,
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_first_word, 
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_next_word,
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_last_word,
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_offset,
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_mask,
   input  wire [C_S_AXI_BYTES_LOG:0]        cmd_step,
   input  wire [8-1:0]                      cmd_length,
   output wire                              cmd_ready,
   
   // Slave Interface Write Data Ports
   input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
   input  wire [C_S_AXI_DATA_WIDTH/8-1:0]   S_AXI_WSTRB,
   input  wire                                                    S_AXI_WLAST,
   input  wire [C_AXI_WUSER_WIDTH-1:0]          S_AXI_WUSER,
   input  wire                                                    S_AXI_WVALID,
   output wire                                                    S_AXI_WREADY,

   // Master Interface Write Data Ports
   output wire [C_M_AXI_DATA_WIDTH-1:0]    M_AXI_WDATA,
   output wire [C_M_AXI_DATA_WIDTH/8-1:0]  M_AXI_WSTRB,
   output wire                                                   M_AXI_WLAST,
   output wire [C_AXI_WUSER_WIDTH-1:0]         M_AXI_WUSER,
   output wire                                                   M_AXI_WVALID,
   input  wire                                                   M_AXI_WREADY
   );
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Variables for generating parameter controlled instances.
  /////////////////////////////////////////////////////////////////////////////
  
  // Generate variable for SI-side word lanes on MI-side.
  genvar word_cnt;
  
  // Generate variable for intra SI-word byte control (on MI-side) for always pack.
  genvar byte_cnt;
  genvar bit_cnt;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Local params
  /////////////////////////////////////////////////////////////////////////////
  
  // Constants for packing levels.
  localparam integer C_NEVER_PACK        = 0;
  localparam integer C_DEFAULT_PACK      = 1;
  localparam integer C_ALWAYS_PACK       = 2;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Functions
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Internal signals
  /////////////////////////////////////////////////////////////////////////////

  // Sub-word handling.
  wire                            sel_first_word;
  wire                            first_word;
  wire [C_M_AXI_BYTES_LOG-1:0]    current_word_1;
  wire [C_M_AXI_BYTES_LOG-1:0]    current_word;
  wire [C_M_AXI_BYTES_LOG-1:0]    current_word_adjusted;
  wire [C_RATIO-1:0]              current_word_idx;
  wire                            last_beat;
  wire                            last_word;
  wire                            last_word_extra_carry;
  wire [C_M_AXI_BYTES_LOG-1:0]    cmd_step_i;
  
  // Sub-word handling for the next cycle.
  wire [C_M_AXI_BYTES_LOG-1:0]    pre_next_word_i;
  wire [C_M_AXI_BYTES_LOG-1:0]    pre_next_word;
  wire [C_M_AXI_BYTES_LOG-1:0]    pre_next_word_1;
  wire [C_M_AXI_BYTES_LOG-1:0]    next_word_i;
  wire [C_M_AXI_BYTES_LOG-1:0]    next_word;
  
  // Burst length handling.
  wire                            first_mi_word;
  wire [8-1:0]                    length_counter_1;
  reg  [8-1:0]                    length_counter;
  wire [8-1:0]                    next_length_counter;
  
  // Handle wrap buffering.
  wire                            store_in_wrap_buffer_enabled;
  wire                            store_in_wrap_buffer;
  wire                            ARESET_or_store_in_wrap_buffer;
  wire                            use_wrap_buffer;
  reg                             wrap_buffer_available;
  
  // Detect start of MI word.
  wire                            first_si_in_mi;
  
  // Throttling help signals.
  wire                            word_complete_next_wrap;
  wire                            word_complete_next_wrap_qual;
  wire                            word_complete_next_wrap_valid;
  wire                            word_complete_next_wrap_pop;
  wire                            word_complete_next_wrap_last;
  wire                            word_complete_next_wrap_stall;
  wire                            word_complete_last_word;
  wire                            word_complete_rest;
  wire                            word_complete_rest_qual;
  wire                            word_complete_rest_valid;
  wire                            word_complete_rest_pop;
  wire                            word_complete_rest_last;
  wire                            word_complete_rest_stall;
  wire                            word_completed;
  wire                            word_completed_qualified;
  wire                            cmd_ready_i;
  wire                            pop_si_data;
  wire                            pop_mi_data_i;
  wire                            pop_mi_data;
  wire                            mi_stalling;
  
  // Internal SI side control signals.
  wire                            S_AXI_WREADY_I;
   
  // Internal packed write data.
  wire                            use_expander_data;
  wire [C_M_AXI_DATA_WIDTH/8-1:0] wdata_qualifier;          // For FPGA only
  wire [C_M_AXI_DATA_WIDTH/8-1:0] wstrb_qualifier;          // For FPGA only
  wire [C_M_AXI_DATA_WIDTH/8-1:0] wrap_qualifier;           // For FPGA only
  wire [C_M_AXI_DATA_WIDTH-1:0]   wdata_buffer_i;           // For FPGA only
  wire [C_M_AXI_DATA_WIDTH/8-1:0] wstrb_buffer_i;           // For FPGA only
  reg  [C_M_AXI_DATA_WIDTH-1:0]   wdata_buffer_q;           // For RTL only
  reg  [C_M_AXI_DATA_WIDTH/8-1:0] wstrb_buffer_q;           // For RTL only
  wire [C_M_AXI_DATA_WIDTH-1:0]   wdata_buffer;
  wire [C_M_AXI_DATA_WIDTH/8-1:0] wstrb_buffer;
  reg  [C_AXI_WUSER_WIDTH-1:0]    M_AXI_WUSER_II;
  reg  [C_M_AXI_DATA_WIDTH-1:0]   wdata_last_word_mux;
  reg  [C_M_AXI_DATA_WIDTH/8-1:0] wstrb_last_word_mux;
  reg  [C_M_AXI_DATA_WIDTH-1:0]   wdata_wrap_buffer_cmb;    // For FPGA only
  reg  [C_M_AXI_DATA_WIDTH/8-1:0] wstrb_wrap_buffer_cmb;    // For FPGA only
  reg  [C_M_AXI_DATA_WIDTH-1:0]   wdata_wrap_buffer_q;      // For RTL only
  reg  [C_M_AXI_DATA_WIDTH/8-1:0] wstrb_wrap_buffer_q;      // For RTL only
  wire [C_M_AXI_DATA_WIDTH-1:0]   wdata_wrap_buffer;
  wire [C_M_AXI_DATA_WIDTH/8-1:0] wstrb_wrap_buffer;
  
  // Internal signals for MI-side.
  wire [C_M_AXI_DATA_WIDTH-1:0]   M_AXI_WDATA_cmb;          // For FPGA only
  wire [C_M_AXI_DATA_WIDTH-1:0]   M_AXI_WDATA_q;            // For FPGA only
  reg  [C_M_AXI_DATA_WIDTH-1:0]   M_AXI_WDATA_I;
  wire [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB_cmb;          // For FPGA only
  wire [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB_q;            // For FPGA only
  reg  [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB_I;
  wire                            M_AXI_WLAST_I;
  reg  [C_AXI_WUSER_WIDTH-1:0]    M_AXI_WUSER_I;
  wire                            M_AXI_WVALID_I;
  wire                            M_AXI_WREADY_I;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Handle interface handshaking:
  //
  // Data on the MI-side is available when data a complete word has been 
  // assembled from the data on SI-side (and potentially from any remainder in
  // the wrap buffer).
  // No data is produced on the MI-side when a unaligned packed wrap is 
  // encountered, instead it stored in the wrap buffer to be used when the 
  // last SI-side data beat is received.
  //
  // The command is popped from the command queue once the last beat on the 
  // SI-side has been ackowledged.
  // 
  // The packing process is stalled when a new MI-side is completed but not 
  // yet acknowledged (by ready).
  //
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_RATIO_LOG > 1 ) begin : USE_LARGE_UPSIZING
      assign cmd_step_i = {{C_RATIO_LOG-1{1'b0}}, cmd_step};
    end else begin : NO_LARGE_UPSIZING
      assign cmd_step_i = cmd_step;
    end
  endgenerate
  
  generate
    if ( C_FAMILY == "rtl" || ( C_SUPPORT_BURSTS == 0 ) || 
       ( C_PACKING_LEVEL == C_NEVER_PACK ) ) begin : USE_RTL_WORD_COMPLETED
      
      // Detect when MI-side word is completely assembled.
      assign word_completed = ( cmd_fix ) |
                              ( ~cmd_fix & ~cmd_complete_wrap & next_word == {C_M_AXI_BYTES_LOG{1'b0}} ) | 
                              ( ~cmd_fix & last_word ) | 
                              ( ~cmd_modified ) |
                              ( C_PACKING_LEVEL == C_NEVER_PACK ) | 
                              ( C_SUPPORT_BURSTS == 0 );
      
      assign word_completed_qualified   = word_completed & cmd_valid & ~store_in_wrap_buffer_enabled;
      
      // RTL equivalent of optimized partial extressions (address wrap for next word).
      assign word_complete_next_wrap        = ( ~cmd_fix & ~cmd_complete_wrap & 
                                                next_word == {C_M_AXI_BYTES_LOG{1'b0}} ) | 
                                              ( C_PACKING_LEVEL == C_NEVER_PACK ) | 
                                              ( C_SUPPORT_BURSTS == 0 );
      assign word_complete_next_wrap_qual   = word_complete_next_wrap & cmd_valid & ~store_in_wrap_buffer_enabled;
      assign word_complete_next_wrap_valid  = word_complete_next_wrap_qual & S_AXI_WVALID;
      assign word_complete_next_wrap_pop    = word_complete_next_wrap_valid & M_AXI_WREADY_I;
      assign word_complete_next_wrap_last   = word_complete_next_wrap_pop & M_AXI_WLAST_I;
      assign word_complete_next_wrap_stall  = word_complete_next_wrap_valid & ~M_AXI_WREADY_I;
      
      // RTL equivalent of optimized partial extressions (last word and the remaining).
      assign word_complete_last_word   = last_word & ~cmd_fix;
      assign word_complete_rest        = word_complete_last_word | cmd_fix | ~cmd_modified;
      assign word_complete_rest_qual   = word_complete_rest & cmd_valid & ~store_in_wrap_buffer_enabled;
      assign word_complete_rest_valid  = word_complete_rest_qual & S_AXI_WVALID;
      assign word_complete_rest_pop    = word_complete_rest_valid & M_AXI_WREADY_I;
      assign word_complete_rest_last   = word_complete_rest_pop & M_AXI_WLAST_I;
      assign word_complete_rest_stall  = word_complete_rest_valid & ~M_AXI_WREADY_I;
      
    end else begin : USE_FPGA_WORD_COMPLETED
    
      wire next_word_wrap;
      wire sel_word_complete_next_wrap;
      wire sel_word_complete_next_wrap_qual;
      wire sel_word_complete_next_wrap_stall;
      
      wire sel_last_word;
      wire sel_word_complete_rest;
      wire sel_word_complete_rest_qual;
      wire sel_word_complete_rest_stall;
      
      
      // Optimize next word address wrap branch of expression.
      //
      comparator_sel_static #
        (
         .C_FAMILY(C_FAMILY),
         .C_VALUE({C_M_AXI_BYTES_LOG{1'b0}}),
         .C_DATA_WIDTH(C_M_AXI_BYTES_LOG)
         ) next_word_wrap_inst
        (
         .CIN(1'b1),
         .S(sel_first_word),
         .A(pre_next_word_1),
         .B(cmd_next_word),
         .COUT(next_word_wrap)
         );
         
      assign sel_word_complete_next_wrap = ~cmd_fix & ~cmd_complete_wrap;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_inst
        (
         .CIN(next_word_wrap),
         .S(sel_word_complete_next_wrap),
         .COUT(word_complete_next_wrap)
         );
         
      assign sel_word_complete_next_wrap_qual = cmd_valid & ~store_in_wrap_buffer_enabled;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_valid_inst
        (
         .CIN(word_complete_next_wrap),
         .S(sel_word_complete_next_wrap_qual),
         .COUT(word_complete_next_wrap_qual)
         );
         
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_qual_inst
        (
         .CIN(word_complete_next_wrap_qual),
         .S(S_AXI_WVALID),
         .COUT(word_complete_next_wrap_valid)
         );
         
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_pop_inst
        (
         .CIN(word_complete_next_wrap_valid),
         .S(M_AXI_WREADY_I),
         .COUT(word_complete_next_wrap_pop)
         );
         
      assign sel_word_complete_next_wrap_stall = ~M_AXI_WREADY_I;
      
      carry_latch_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_stall_inst
        (
         .CIN(word_complete_next_wrap_valid),
         .I(sel_word_complete_next_wrap_stall),
         .O(word_complete_next_wrap_stall)
         );
         
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_last_inst
        (
         .CIN(word_complete_next_wrap_pop),
         .S(M_AXI_WLAST_I),
         .COUT(word_complete_next_wrap_last)
         );
         
      // Optimize last word and "rest" branch of expression.
      //
      assign sel_last_word = ~cmd_fix;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) last_word_inst_2
        (
         .CIN(last_word_extra_carry),
         .S(sel_last_word),
         .COUT(word_complete_last_word)
         );
      
      assign sel_word_complete_rest = cmd_fix | ~cmd_modified;
      
      carry_or #
        (
         .C_FAMILY(C_FAMILY)
         ) pop_si_data_inst
        (
         .CIN(word_complete_last_word),
         .S(sel_word_complete_rest),
         .COUT(word_complete_rest)
         );
      
      assign sel_word_complete_rest_qual = cmd_valid & ~store_in_wrap_buffer_enabled;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_rest_valid_inst
        (
         .CIN(word_complete_rest),
         .S(sel_word_complete_rest_qual),
         .COUT(word_complete_rest_qual)
         );
         
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_rest_qual_inst
        (
         .CIN(word_complete_rest_qual),
         .S(S_AXI_WVALID),
         .COUT(word_complete_rest_valid)
         );
         
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_rest_pop_inst
        (
         .CIN(word_complete_rest_valid),
         .S(M_AXI_WREADY_I),
         .COUT(word_complete_rest_pop)
         );
         
      assign sel_word_complete_rest_stall = ~M_AXI_WREADY_I;
      
      carry_latch_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_rest_stall_inst
        (
         .CIN(word_complete_rest_valid),
         .I(sel_word_complete_rest_stall),
         .O(word_complete_rest_stall)
         );
         
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_rest_last_inst
        (
         .CIN(word_complete_rest_pop),
         .S(M_AXI_WLAST_I),
         .COUT(word_complete_rest_last)
         );
      
      // Combine the two branches to generate the full signal.
      assign word_completed = word_complete_next_wrap | word_complete_rest;
      
      assign word_completed_qualified   = word_complete_next_wrap_qual | word_complete_rest_qual;
      
    end
  endgenerate
      
  // Pop word from SI-side.
  assign S_AXI_WREADY_I = ~mi_stalling & cmd_valid;
  assign S_AXI_WREADY   = S_AXI_WREADY_I;
  
  // Indicate when there is data available @ MI-side.
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_M_WVALID
      assign M_AXI_WVALID_I = S_AXI_WVALID & word_completed_qualified;
      
    end else begin : USE_FPGA_M_WVALID
      
      assign M_AXI_WVALID_I = ( word_complete_next_wrap_valid | word_complete_rest_valid);
      
    end
  endgenerate
  
  // Get SI-side data.
  generate
    if ( C_M_AXI_REGISTER ) begin : USE_REGISTER_SI_POP
      assign pop_si_data    = S_AXI_WVALID & ~mi_stalling & cmd_valid;
    end else begin : NO_REGISTER_SI_POP
      if ( C_FAMILY == "rtl" ) begin : USE_RTL_POP_SI
        assign pop_si_data    = S_AXI_WVALID & S_AXI_WREADY_I;
      end else begin : USE_FPGA_POP_SI
        assign pop_si_data = ~( word_complete_next_wrap_stall | word_complete_rest_stall ) &
                             cmd_valid & S_AXI_WVALID;
      end
    end
  endgenerate
      
  // Signal that the command is done (so that it can be poped from command queue).
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_CMD_READY
      assign cmd_ready_i    = cmd_valid & M_AXI_WLAST_I & pop_mi_data_i;
      
    end else begin : USE_FPGA_CMD_READY
      assign cmd_ready_i = ( word_complete_next_wrap_last | word_complete_rest_last);
      
    end
  endgenerate
  assign cmd_ready      = cmd_ready_i;
  
  // Set last upsized word.
  assign M_AXI_WLAST_I  = S_AXI_WLAST;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Keep track of data extraction:
  // 
  // Current address is taken form the command buffer for the first data beat
  // to handle unaligned Write transactions. After this is the extraction 
  // address usually calculated from this point.
  // FIX transactions uses the same word address for all data beats. 
  // 
  // Next word address is generated as current word plus the current step 
  // size, with masking to facilitate sub-sized wraping. The Mask is all ones
  // for normal wraping, and less when sub-sized wraping is used.
  // 
  // The calculated word addresses (current and next) is offseted by the 
  // current Offset. For sub-sized transaction the Offest points to the least 
  // significant address of the included data beats. (The least significant 
  // word is not necessarily the first data to be packed, consider WRAP).
  // Offset is only used for sub-sized WRAP transcation that are Complete.
  // 
  // First word is active during the first SI-side data beat.
  // 
  // First MI is set while the entire first MI-side word is processed.
  //
  // The transaction length is taken from the command buffer combinatorialy
  // during the First MI cycle. For each generated MI word it is decreased 
  // until Last beat is reached.
  // 
  /////////////////////////////////////////////////////////////////////////////
  
  // Select if the offset comes from command queue directly or 
  // from a counter while when extracting multiple SI words per MI word
  assign sel_first_word = first_word | cmd_fix;
  assign current_word   = sel_first_word ? cmd_first_word : 
                                           current_word_1;
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_NEXT_WORD
      
      // Calculate next word.
      assign pre_next_word_i  = ( next_word_i + cmd_step_i );
      
      // Calculate next word.
      assign next_word_i      = sel_first_word ? cmd_next_word : 
                                                 pre_next_word_1;
      
    end else begin : USE_FPGA_NEXT_WORD
      wire [C_M_AXI_BYTES_LOG-1:0]  next_sel;
      wire [C_M_AXI_BYTES_LOG:0]    next_carry_local;
      
      // Assign input to local vectors.
      assign next_carry_local[0]      = 1'b0;
    
      // Instantiate one carry and per level.
      for (bit_cnt = 0; bit_cnt < C_M_AXI_BYTES_LOG ; bit_cnt = bit_cnt + 1) begin : LUT_LEVEL
        
        LUT6_2 # (
         .INIT(64'h5A5A_5A66_F0F0_F0CC) 
        ) LUT6_2_inst (
        .O6(next_sel[bit_cnt]),         // 6/5-LUT output (1-bit)
        .O5(next_word_i[bit_cnt]),      // 5-LUT output (1-bit)
        .I0(cmd_step_i[bit_cnt]),       // LUT input (1-bit)
        .I1(pre_next_word_1[bit_cnt]),  // LUT input (1-bit)
        .I2(cmd_next_word[bit_cnt]),    // LUT input (1-bit)
        .I3(first_word),                // LUT input (1-bit)
        .I4(cmd_fix),                   // LUT input (1-bit)
        .I5(1'b1)                       // LUT input (1-bit)
        );
        
        MUXCY next_carry_inst 
        (
         .O (next_carry_local[bit_cnt+1]), 
         .CI (next_carry_local[bit_cnt]), 
         .DI (cmd_step_i[bit_cnt]), 
         .S (next_sel[bit_cnt])
        ); 
        
        XORCY next_xorcy_inst 
        (
         .O(pre_next_word_i[bit_cnt]),
         .CI(next_carry_local[bit_cnt]),
         .LI(next_sel[bit_cnt])
        );
        
      end // end for bit_cnt
      
    end
  endgenerate
  
  // Calculate next word.
  assign next_word              = next_word_i & cmd_mask;
  assign pre_next_word          = pre_next_word_i & cmd_mask;
      
  // Calculate the word address with offset.
  assign current_word_adjusted  = sel_first_word ? ( cmd_first_word | cmd_offset ) : 
                                                   ( current_word_1 | cmd_offset );

  // Prepare next word address.
  generate
    if ( C_FAMILY == "rtl" || C_M_AXI_REGISTER ) begin : USE_RTL_CURR_WORD
      reg  [C_M_AXI_BYTES_LOG-1:0]    current_word_q;
      reg                             first_word_q;
      reg  [C_M_AXI_BYTES_LOG-1:0]    pre_next_word_q;
    
      always @ (posedge ACLK) begin
        if (ARESET) begin
          first_word_q    <= 1'b1;
          current_word_q  <= {C_M_AXI_BYTES_LOG{1'b0}};
          pre_next_word_q <= {C_M_AXI_BYTES_LOG{1'b0}};
        end else begin
          if ( pop_si_data ) begin
            if ( S_AXI_WLAST ) begin
              // Prepare for next access.
              first_word_q    <= 1'b1;
            end else begin
              first_word_q    <= 1'b0;
            end
            
            current_word_q  <= next_word;
            pre_next_word_q <= pre_next_word;
          end
        end
      end
      
      assign first_word       = first_word_q;
      assign current_word_1   = current_word_q;
      assign pre_next_word_1  = pre_next_word_q;
      
    end else begin : USE_FPGA_CURR_WORD
      reg                             first_word_cmb;
      wire                            first_word_i;
      wire [C_M_AXI_BYTES_LOG-1:0]    current_word_i;
      wire [C_M_AXI_BYTES_LOG-1:0]    local_pre_next_word_i;
      
      
      always @ *
      begin
          if ( S_AXI_WLAST ) begin
            // Prepare for next access.
            first_word_cmb    = 1'b1;
          end else begin
            first_word_cmb    = 1'b0;
          end
      end
      
      for (bit_cnt = 0; bit_cnt < C_M_AXI_BYTES_LOG ; bit_cnt = bit_cnt + 1) begin : BIT_LANE
        LUT6 # (
         .INIT(64'hCCCA_CCCC_CCCC_CCCC) 
        ) LUT6_current_inst (
        .O(current_word_i[bit_cnt]),          // 6-LUT output (1-bit)
        .I0(next_word[bit_cnt]),              // LUT input (1-bit)
        .I1(current_word_1[bit_cnt]),         // LUT input (1-bit)
        .I2(word_complete_rest_stall),        // LUT input (1-bit)
        .I3(word_complete_next_wrap_stall),   // LUT input (1-bit)
        .I4(cmd_valid),                       // LUT input (1-bit)
        .I5(S_AXI_WVALID)                     // LUT input (1-bit)
        );
            
        FDRE #(
         .INIT(1'b0)                          // Initial value of register (1'b0 or 1'b1)
         ) FDRE_current_inst (
         .Q(current_word_1[bit_cnt]),         // Data output
         .C(ACLK),                            // Clock input
         .CE(1'b1),                           // Clock enable input
         .R(ARESET),                          // Synchronous reset input
         .D(current_word_i[bit_cnt])          // Data input
         );
         
        LUT6 # (
         .INIT(64'hCCCA_CCCC_CCCC_CCCC) 
        ) LUT6_next_inst (
        .O(local_pre_next_word_i[bit_cnt]),   // 6-LUT output (1-bit)
        .I0(pre_next_word[bit_cnt]),          // LUT input (1-bit)
        .I1(pre_next_word_1[bit_cnt]),        // LUT input (1-bit)
        .I2(word_complete_rest_stall),        // LUT input (1-bit)
        .I3(word_complete_next_wrap_stall),   // LUT input (1-bit)
        .I4(cmd_valid),                       // LUT input (1-bit)
        .I5(S_AXI_WVALID)                     // LUT input (1-bit)
        );
            
        FDRE #(
         .INIT(1'b0)                          // Initial value of register (1'b0 or 1'b1)
         ) FDRE_next_inst (
         .Q(pre_next_word_1[bit_cnt]),        // Data output
         .C(ACLK),                            // Clock input
         .CE(1'b1),                           // Clock enable input
         .R(ARESET),                          // Synchronous reset input
         .D(local_pre_next_word_i[bit_cnt])   // Data input
         );
      end // end for bit_cnt
      
      LUT6 # (
       .INIT(64'hCCCA_CCCC_CCCC_CCCC) 
      ) LUT6_first_inst (
      .O(first_word_i),                     // 6-LUT output (1-bit)
      .I0(first_word_cmb),                  // LUT input (1-bit)
      .I1(first_word),                      // LUT input (1-bit)
      .I2(word_complete_rest_stall),        // LUT input (1-bit)
      .I3(word_complete_next_wrap_stall),   // LUT input (1-bit)
      .I4(cmd_valid),                       // LUT input (1-bit)
      .I5(S_AXI_WVALID)                     // LUT input (1-bit)
      );
          
      FDSE #(
       .INIT(1'b1)                    // Initial value of register (1'b0 or 1'b1)
       ) FDSE_first_inst (
       .Q(first_word),                // Data output
       .C(ACLK),                      // Clock input
       .CE(1'b1),                     // Clock enable input
       .S(ARESET),                    // Synchronous reset input
       .D(first_word_i)               // Data input
       );
    end
  endgenerate
  
  // Select command length or counted length.
  always @ *
  begin
    if ( first_mi_word )
      length_counter = cmd_length;
    else
      length_counter = length_counter_1;
  end
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_LENGTH
      reg  [8-1:0]                    length_counter_q;
      reg                             first_mi_word_q;
    
      // Calculate next length counter value.
      assign next_length_counter = length_counter - 1'b1;
      
      // Keep track of burst length.
      always @ (posedge ACLK) begin
        if (ARESET) begin
          first_mi_word_q  <= 1'b1;
          length_counter_q <= 8'b0;
        end else begin
          if ( pop_mi_data_i ) begin
            if ( M_AXI_WLAST_I ) begin
              first_mi_word_q  <= 1'b1;
            end else begin
              first_mi_word_q  <= 1'b0;
            end
          
            length_counter_q <= next_length_counter;
          end
        end
      end
      
      assign first_mi_word    = first_mi_word_q;
      assign length_counter_1 = length_counter_q;
      
    end else begin : USE_FPGA_LENGTH
      wire [8-1:0]  length_counter_i;
      wire [8-1:0]  length_counter_ii;
      wire [8-1:0]  length_sel;
      wire [8-1:0]  length_di;
      wire [8:0]    length_local_carry;
      
      // Assign input to local vectors.
      assign length_local_carry[0] = 1'b0;
    
      for (bit_cnt = 0; bit_cnt < 8 ; bit_cnt = bit_cnt + 1) begin : BIT_LANE

        LUT6_2 # (
         .INIT(64'h333C_555A_FFF0_FFF0) 
        ) LUT6_length_inst (
        .O6(length_sel[bit_cnt]),           // 6/5-LUT output (1-bit)
        .O5(length_di[bit_cnt]),            // 5-LUT output (1-bit)
        .I0(length_counter_1[bit_cnt]),     // LUT input (1-bit)
        .I1(cmd_length[bit_cnt]),           // LUT input (1-bit)
        .I2(1'b1),                          // LUT input (1-bit)
        .I3(1'b1),                          // LUT input (1-bit)
        .I4(first_mi_word),                 // LUT input (1-bit)
        .I5(1'b1)                           // LUT input (1-bit)
        );
        
        MUXCY carry_inst 
        (
         .O (length_local_carry[bit_cnt+1]), 
         .CI (length_local_carry[bit_cnt]), 
         .DI (length_di[bit_cnt]), 
         .S (length_sel[bit_cnt])
        ); 
        
        XORCY xorcy_inst 
        (
         .O(length_counter_ii[bit_cnt]),
         .CI(length_local_carry[bit_cnt]),
         .LI(length_sel[bit_cnt])
        );
        
        LUT4 # (
         .INIT(16'hCCCA) 
        ) LUT4_inst (
        .O(length_counter_i[bit_cnt]),    // 5-LUT output (1-bit)
        .I0(length_counter_1[bit_cnt]),     // LUT input (1-bit)
        .I1(length_counter_ii[bit_cnt]),  // LUT input (1-bit)
        .I2(word_complete_rest_pop),      // LUT input (1-bit)
        .I3(word_complete_next_wrap_pop)  // LUT input (1-bit)
        );
        
        FDRE #(
         .INIT(1'b0)                    // Initial value of register (1'b0 or 1'b1)
         ) FDRE_length_inst (
         .Q(length_counter_1[bit_cnt]), // Data output
         .C(ACLK),                      // Clock input
         .CE(1'b1),                     // Clock enable input
         .R(ARESET),                    // Synchronous reset input
         .D(length_counter_i[bit_cnt])  // Data input
         );
         
      end // end for bit_cnt
      
      wire first_mi_word_i;
      
      LUT6 # (
       .INIT(64'hAAAC_AAAC_AAAC_AAAC) 
      ) LUT6_first_mi_inst (
      .O(first_mi_word_i),                // 6-LUT output (1-bit)
      .I0(M_AXI_WLAST_I),                 // LUT input (1-bit)
      .I1(first_mi_word),                 // LUT input (1-bit)
      .I2(word_complete_rest_pop),        // LUT input (1-bit)
      .I3(word_complete_next_wrap_pop),   // LUT input (1-bit)
      .I4(1'b1),                          // LUT input (1-bit)
      .I5(1'b1)                           // LUT input (1-bit)
      );
          
      FDSE #(
       .INIT(1'b1)                    // Initial value of register (1'b0 or 1'b1)
       ) FDSE_inst (
       .Q(first_mi_word),             // Data output
       .C(ACLK),                      // Clock input
       .CE(1'b1),                     // Clock enable input
       .S(ARESET),                    // Synchronous reset input
       .D(first_mi_word_i)            // Data input
       );
      
    end
  endgenerate
  
  generate
    if ( C_FAMILY == "rtl" || C_SUPPORT_BURSTS == 0 ) begin : USE_RTL_LAST_WORD
      // Detect last beat in a burst.
      assign last_beat = ( length_counter == 8'b0 );
      
      // Determine if this last word that shall be assembled into this MI-side word.
      assign last_word = ( cmd_modified & last_beat & ( current_word == cmd_last_word ) ) |
                         ( C_SUPPORT_BURSTS == 0 );
      
    end else begin : USE_FPGA_LAST_WORD
      wire last_beat_curr_word;
      
      comparator_sel_static #
        (
         .C_FAMILY(C_FAMILY),
         .C_VALUE(8'b0),
         .C_DATA_WIDTH(8)
         ) last_beat_inst
        (
         .CIN(1'b1),
         .S(first_mi_word),
         .A(length_counter_1),
         .B(cmd_length),
         .COUT(last_beat)
         );
      
      comparator_sel #
        (
         .C_FAMILY(C_FAMILY),
         .C_DATA_WIDTH(C_M_AXI_BYTES_LOG)
         ) last_beat_curr_word_inst
        (
         .CIN(last_beat),
         .S(sel_first_word),
         .A(current_word_1),
         .B(cmd_first_word),
         .V(cmd_last_word),
         .COUT(last_beat_curr_word)
         );
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) last_word_inst
        (
         .CIN(last_beat_curr_word),
         .S(cmd_modified),
         .COUT(last_word)
         );

    end
  endgenerate
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Handle wrap buffer:
  //
  // The wrap buffer is used to move data around in an unaligned WRAP 
  // transaction. SI-side data word(s) for an unaligned accesses are delay 
  // to be packed with with the tail of the transaction to make it a WRAP
  // transaction that is aligned to native MI-side data with.
  // For example: an 32bit to 64bit write upsizing @ 0x4 will delay the first 
  // word until the 0x0 data arrives in the last data beat. This will make the 
  // Upsized transaction be WRAP at 0x8 on the MI-side 
  // (was WRAP @ 0x4 on SI-side).
  // 
  /////////////////////////////////////////////////////////////////////////////
  
  // The unaligned SI-side words are pushed into the wrap buffer.
  assign store_in_wrap_buffer_enabled   = cmd_packed_wrap & ~wrap_buffer_available & cmd_valid;
  assign store_in_wrap_buffer           = store_in_wrap_buffer_enabled & S_AXI_WVALID;
  assign ARESET_or_store_in_wrap_buffer = store_in_wrap_buffer | ARESET;
  // The wrap buffer is used to complete last word.
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_USE_WRAP
      assign use_wrap_buffer      = wrap_buffer_available & last_word;
      
    end else begin : USE_FPGA_USE_WRAP
      wire last_word_carry;  
    
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) last_word_inst2
        (
         .CIN(last_word),
         .S(1'b1),
         .COUT(last_word_carry)
         );

      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) last_word_inst3
        (
         .CIN(last_word_carry),
         .S(1'b1),
         .COUT(last_word_extra_carry)
         );

      carry_latch_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_stall_inst
        (
         .CIN(last_word_carry),
         .I(wrap_buffer_available),
         .O(use_wrap_buffer)
         );
    end
  endgenerate
  
  // Wrap buffer becomes available when the unaligned wrap words has been taken care of.
  always @ (posedge ACLK) begin
    if (ARESET) begin
      wrap_buffer_available <= 1'b0;
    end else begin
      if ( store_in_wrap_buffer & word_completed ) begin
        wrap_buffer_available <= 1'b1;
      end else if ( cmd_ready_i ) begin
        wrap_buffer_available <= 1'b0;
      end
    end
  end
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Handle USER bits:
  // 
  // The USER bits are always propagated from the least significant SI-side 
  // beat to the Up-Sized MI-side data beat. That means:
  // * FIX transactions propagate all USER data (1:1 SI- vs MI-side beat ratio).
  // * INCR transactions uses the first SI-side beat that goes into a MI-side
  //   data word.
  // * WRAP always propagates the USER bits from the most zero aligned SI-side 
  //   data word, regardless if the data is packed or not. For unpacked data 
  //   this would be a 1:1 ratio.
  /////////////////////////////////////////////////////////////////////////////
  
  // Detect first SI-side word per MI-side word.
  assign first_si_in_mi = cmd_fix | 
                          first_word |
                          ~cmd_modified |
                          (cmd_modified & current_word == {C_M_AXI_BYTES_LOG{1'b0}}) |
                          ( C_SUPPORT_BURSTS == 0 );
  
  // Select USER bits combinatorially when expanding or fix.
  always @ *
  begin
    if ( C_AXI_SUPPORTS_USER_SIGNALS ) begin
      if ( first_si_in_mi ) begin
        M_AXI_WUSER_I = S_AXI_WUSER;
      end else begin
        M_AXI_WUSER_I = M_AXI_WUSER_II;
      end
    end else begin
      M_AXI_WUSER_I = {C_AXI_WUSER_WIDTH{1'b0}};
    end
  end
  
  // Capture user bits.
  always @ (posedge ACLK) begin
    if (ARESET) begin
      M_AXI_WUSER_II <= {C_AXI_WUSER_WIDTH{1'b0}};
    end else begin
      if ( first_si_in_mi & pop_si_data ) begin
        M_AXI_WUSER_II <= S_AXI_WUSER;
      end
    end
  end
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Pack multiple data SI-side words into fewer MI-side data word.
  // Data is only packed when modify is set. Granularity is SI-side word for 
  // the combinatorial data mux.
  //
  // Expander:
  // WDATA is expanded to all SI-word lane on the MI-side.
  // WSTRB is activted to the correct SI-word lane on the MI-side.
  //
  // Packer:
  // The WDATA and WSTRB registers are always cleared before a new word is 
  // assembled.
  // WDATA is (SI-side word granularity)
  //  * Combinatorial WDATA is used for current word line or when expanding.
  //  * All other is taken from registers.
  // WSTRB is
  //  * Combinatorial for single data to matching word lane
  //  * Zero for single data to mismatched word lane
  //  * Register data when multiple data
  // 
  // To support sub-sized packing during Always Pack is the combinatorial 
  // information packed with "or" instead of multiplexing.
  //
  /////////////////////////////////////////////////////////////////////////////
  
  // Determine if expander data should be used.
  assign use_expander_data = ~cmd_modified & cmd_valid;
  
  // Registers and combinatorial data word mux.
  generate
    for (word_cnt = 0; word_cnt < C_RATIO ; word_cnt = word_cnt + 1) begin : WORD_LANE
      
      // Generate select signal per SI-side word.
      if ( C_RATIO == 1 ) begin : SINGLE_WORD
        assign current_word_idx[word_cnt] = 1'b1;
      end else begin : MULTIPLE_WORD
        assign current_word_idx[word_cnt] = current_word_adjusted[C_M_AXI_BYTES_LOG-C_RATIO_LOG +: C_RATIO_LOG] == word_cnt;
      end
      
      if ( ( C_PACKING_LEVEL == C_NEVER_PACK ) | ( C_SUPPORT_BURSTS == 0 ) ) begin : USE_EXPANDER
        // Expander only functionality.
      
        if ( C_M_AXI_REGISTER ) begin : USE_REGISTER
            
          always @ (posedge ACLK) begin
            if (ARESET) begin
              M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH   +: C_S_AXI_DATA_WIDTH]    = {C_S_AXI_DATA_WIDTH{1'b0}};
              M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8 +: C_S_AXI_DATA_WIDTH/8]  = {C_S_AXI_DATA_WIDTH/8{1'b0}};
            end else begin
              if ( pop_si_data ) begin
                M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH   +: C_S_AXI_DATA_WIDTH] = S_AXI_WDATA;
            
                // Multiplex write strobe.
                if ( current_word_idx[word_cnt] ) begin
                  // Combinatorial for last word to MI-side (only word for single).
                  M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8 +: C_S_AXI_DATA_WIDTH/8] = S_AXI_WSTRB;
                end else begin
                  // Use registered strobes. Registers are zero until valid data is written.
                  // I.e. zero when used for mismatched lanes while expanding.
                  M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8 +: C_S_AXI_DATA_WIDTH/8] = {C_S_AXI_DATA_WIDTH/8{1'b0}};
                end
              end
            end
          end
          
        end else begin : NO_REGISTER
          always @ *
          begin
            M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH   +: C_S_AXI_DATA_WIDTH] = S_AXI_WDATA;
          
            // Multiplex write strobe.
            if ( current_word_idx[word_cnt] ) begin
              // Combinatorial for last word to MI-side (only word for single).
              M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8 +: C_S_AXI_DATA_WIDTH/8] = S_AXI_WSTRB;
            end else begin
              // Use registered strobes. Registers are zero until valid data is written.
              // I.e. zero when used for mismatched lanes while expanding.
              M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8 +: C_S_AXI_DATA_WIDTH/8] = {C_S_AXI_DATA_WIDTH/8{1'b0}};
            end
          end
          
        end // end if C_M_AXI_REGISTER
        
      end else begin : USE_ALWAYS_PACKER
        // Packer functionality
      
        for (byte_cnt = 0; byte_cnt < C_S_AXI_DATA_WIDTH / 8 ; byte_cnt = byte_cnt + 1) begin : BYTE_LANE
        
          if ( C_FAMILY == "rtl" ) begin : USE_RTL_DATA
            // Generate extended write data and strobe in wrap buffer.
            always @ (posedge ACLK) begin
              if (ARESET) begin
                wdata_wrap_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= 8'b0;
                wstrb_wrap_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= 1'b0;
              end else begin
                if ( cmd_ready_i ) begin
                  wdata_wrap_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= 8'b0;
                  wstrb_wrap_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= 1'b0;
                end else if ( current_word_idx[word_cnt] & store_in_wrap_buffer & S_AXI_WSTRB[byte_cnt] ) begin
                  wdata_wrap_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= S_AXI_WDATA[byte_cnt*8 +: 8];
                  wstrb_wrap_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= S_AXI_WSTRB[byte_cnt];
                end
              end
            end
            
            assign wdata_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = 
                                    wdata_wrap_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8];
            assign wstrb_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = 
                                    wstrb_wrap_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1];
            
            if ( C_M_AXI_REGISTER ) begin : USE_REGISTER
              
              always @ (posedge ACLK) begin
                if (ARESET) begin
                  M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= 8'b0;
                  M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= 1'b0;
                end else begin
                  if ( ( current_word_idx[word_cnt] & S_AXI_WSTRB[byte_cnt] | use_expander_data ) & pop_si_data & ~store_in_wrap_buffer ) begin
                    M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= S_AXI_WDATA[byte_cnt*8 +: 8];
                  end else if ( use_wrap_buffer & pop_si_data &
                                wstrb_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] ) begin
                    M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= wdata_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8];
                  end else if ( pop_mi_data ) begin
                    M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= 8'b0;
                  end
                  
                  if ( current_word_idx[word_cnt] & S_AXI_WSTRB[byte_cnt] & pop_si_data & ~store_in_wrap_buffer ) begin
                    M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= S_AXI_WSTRB[byte_cnt];
                  end else if ( use_wrap_buffer & pop_si_data &
                                wstrb_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] ) begin
                    M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= 1'b1;
                  end else if ( pop_mi_data ) begin
                    M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= 1'b0;
                  end
                end
              end
              
            end else begin : NO_REGISTER
              
              // Generate extended write data and strobe.
              always @ (posedge ACLK) begin
                if (ARESET) begin
                  wdata_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= 8'b0;
                  wstrb_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= 1'b0;
                end else begin
                  if ( pop_mi_data | store_in_wrap_buffer_enabled ) begin
                    wdata_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= 8'b0;
                    wstrb_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= 1'b0;
                  end else if ( current_word_idx[word_cnt] & pop_si_data & S_AXI_WSTRB[byte_cnt] ) begin
                    wdata_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] <= S_AXI_WDATA[byte_cnt*8 +: 8];
                    wstrb_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] <= S_AXI_WSTRB[byte_cnt];
                  end
                end
              end
              
              assign wdata_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = 
                                 wdata_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8];
              assign wstrb_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = 
                                 wstrb_buffer_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1];
              
              // Select packed or extended data.
              always @ *
              begin
                // Multiplex data.
                if ( ( current_word_idx[word_cnt] & S_AXI_WSTRB[byte_cnt] ) | use_expander_data ) begin
                  wdata_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = S_AXI_WDATA[byte_cnt*8 +: 8];
                end else begin
                  wdata_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = 8'b0;
                end
              
                // Multiplex write strobe.
                if ( current_word_idx[word_cnt] ) begin
                  // Combinatorial for last word to MI-side (only word for single).
                  wstrb_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = S_AXI_WSTRB[byte_cnt];
                end else begin
                  // Use registered strobes. Registers are zero until valid data is written.
                  // I.e. zero when used for mismatched lanes while expanding.
                  wstrb_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = 1'b0;
                end
              end
              
              // Merge previous with current data.
              always @ *
              begin
                M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = 
                                (        wstrb_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] ) | 
                                ( wstrb_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] ) | 
                                (   wstrb_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] & use_wrap_buffer );
                                
                M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = 
                                (        wdata_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] ) | 
                                ( wdata_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] ) |
                                (   wdata_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] & {8{use_wrap_buffer}} );
              end
              
            end // end if C_M_AXI_REGISTER
          end else begin : USE_FPGA_DATA
          
            always @ *
            begin
              if ( cmd_ready_i ) begin
                wdata_wrap_buffer_cmb[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = 8'b0;
                wstrb_wrap_buffer_cmb[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = 1'b0;
              end else if ( current_word_idx[word_cnt] & store_in_wrap_buffer & S_AXI_WSTRB[byte_cnt] ) begin
                wdata_wrap_buffer_cmb[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = S_AXI_WDATA[byte_cnt*8 +: 8];
                wstrb_wrap_buffer_cmb[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = 1'b1;
              end else begin
                wdata_wrap_buffer_cmb[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = 
                                      wdata_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8];
                wstrb_wrap_buffer_cmb[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = 
                                      wstrb_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1];
              end
            end
            
            for (bit_cnt = 0; bit_cnt < 8 ; bit_cnt = bit_cnt + 1) begin : BIT_LANE
              FDRE #(
               .INIT(1'b0)             // Initial value of register (1'b0 or 1'b1)
               ) FDRE_wdata_inst (
               .Q(wdata_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt]),    // Data output
               .C(ACLK),                                                                 // Clock input
               .CE(1'b1),                                                                // Clock enable input
               .R(ARESET),                                                               // Synchronous reset input
               .D(wdata_wrap_buffer_cmb[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt]) // Data input
               );
              
            end // end for bit_cnt
            
            FDRE #(
             .INIT(1'b0)             // Initial value of register (1'b0 or 1'b1)
             ) FDRE_wstrb_inst (
             .Q(wstrb_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),      // Data output
             .C(ACLK),                                                           // Clock input
             .CE(1'b1),                                                          // Clock enable input
             .R(ARESET),                                                         // Synchronous reset input
             .D(wstrb_wrap_buffer_cmb[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt])   // Data input
             );
             
            if ( C_M_AXI_REGISTER ) begin : USE_REGISTER
            
              assign wdata_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt] = ( current_word_idx[word_cnt] & S_AXI_WSTRB[byte_cnt] | use_expander_data ) & pop_si_data & ~store_in_wrap_buffer_enabled;
              assign wstrb_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt] = current_word_idx[word_cnt] & S_AXI_WSTRB[byte_cnt] & pop_si_data & ~store_in_wrap_buffer_enabled;
            
              assign wrap_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]  = use_wrap_buffer & pop_si_data &
                                                                               wstrb_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1];
            
              for (bit_cnt = 0; bit_cnt < 8 ; bit_cnt = bit_cnt + 1) begin : BIT_LANE
                    
                LUT6 # (
                 .INIT(64'hF0F0_F0F0_CCCC_00AA) 
                ) LUT6_data_inst (
                .O(M_AXI_WDATA_cmb[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt]),    // 6-LUT output (1-bit)
                .I0(M_AXI_WDATA_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt]),     // LUT input (1-bit)
                .I1(wdata_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt]), // LUT input (1-bit)
                .I2(S_AXI_WDATA[byte_cnt*8+bit_cnt]),                                   // LUT input (1-bit)
                .I3(pop_mi_data),                                                       // LUT input (1-bit)
                .I4(wrap_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),            // LUT input (1-bit)
                .I5(wdata_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt])            // LUT input (1-bit)
                );
                    
                FDRE #(
                 .INIT(1'b0)             // Initial value of register (1'b0 or 1'b1)
                 ) FDRE_wdata_inst (
                 .Q(M_AXI_WDATA_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt]),     // Data output
                 .C(ACLK),                                                              // Clock input
                 .CE(1'b1),                                                             // Clock enable input
                 .R(ARESET),                                                            // Synchronous reset input
                 .D(M_AXI_WDATA_cmb[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt])    // Data input
                 );
                
              end // end for bit_cnt
              
              LUT6 # (
               .INIT(64'hF0F0_F0F0_CCCC_00AA) 
              ) LUT6_strb_inst (
              .O(M_AXI_WSTRB_cmb[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),            // 6-LUT output (1-bit)
              .I0(M_AXI_WSTRB_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),             // LUT input (1-bit)
              .I1(wrap_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),            // LUT input (1-bit)
              .I2(S_AXI_WSTRB[byte_cnt]),                                             // LUT input (1-bit)
              .I3(pop_mi_data),                                                       // LUT input (1-bit)
              .I4(wrap_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),            // LUT input (1-bit)
              .I5(wstrb_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt])            // LUT input (1-bit)
              );
            
              FDRE #(
               .INIT(1'b0)             // Initial value of register (1'b0 or 1'b1)
               ) FDRE_wstrb_inst (
               .Q(M_AXI_WSTRB_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),     // Data output
               .C(ACLK),                                                      // Clock input
               .CE(1'b1),                                                     // Clock enable input
               .R(ARESET),                                                    // Synchronous reset input
               .D(M_AXI_WSTRB_cmb[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt])    // Data input
               );
               
              always @ * 
              begin
                M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = M_AXI_WDATA_q[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8];
                M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = M_AXI_WSTRB_q[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1];
              end
              
            end else begin : NO_REGISTER
            
              assign wdata_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]  = current_word_idx[word_cnt] & cmd_valid & S_AXI_WSTRB[byte_cnt];
            
              assign wstrb_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]  = current_word_idx[word_cnt] & 
                                                                                S_AXI_WSTRB[byte_cnt] & 
                                                                                cmd_valid & S_AXI_WVALID;
              
              for (bit_cnt = 0; bit_cnt < 8 ; bit_cnt = bit_cnt + 1) begin : BIT_LANE
                LUT6 # (
                 .INIT(64'hCCCA_CCCC_CCCC_CCCC) 
                ) LUT6_data_inst (
                .O(wdata_buffer_i[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt]),   // 6-LUT output (1-bit)
                .I0(S_AXI_WDATA[byte_cnt*8+bit_cnt]),                                 // LUT input (1-bit)
                .I1(wdata_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt]),    // LUT input (1-bit)
                .I2(word_complete_rest_stall),                                        // LUT input (1-bit)
                .I3(word_complete_next_wrap_stall),                                   // LUT input (1-bit)
                .I4(wdata_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),         // LUT input (1-bit)
                .I5(S_AXI_WVALID)                                                     // LUT input (1-bit)
                );
                    
                FDRE #(
                 .INIT(1'b0)             // Initial value of register (1'b0 or 1'b1)
                 ) FDRE_wdata_inst (
                 .Q(wdata_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt]),    // Data output
                 .C(ACLK),                                                            // Clock input
                 .CE(1'b1),                                                           // Clock enable input
                 .R(ARESET),                                                          // Synchronous reset input
                 .D(wdata_buffer_i[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8+bit_cnt])   // Data input
                 );
                
              end // end for bit_cnt
              
              LUT6 # (
               .INIT(64'h0000_0000_0000_AAAE) 
              ) LUT6_strb_inst (
              .O(wstrb_buffer_i[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),     // 6-LUT output (1-bit)
              .I0(wstrb_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),      // LUT input (1-bit)
              .I1(wstrb_qualifier[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),   // LUT input (1-bit)
              .I2(word_complete_rest_stall),                                  // LUT input (1-bit)
              .I3(word_complete_next_wrap_stall),                             // LUT input (1-bit)
              .I4(word_complete_rest_pop),                                    // LUT input (1-bit)
              .I5(word_complete_next_wrap_pop)                                // LUT input (1-bit)
              );
              
              FDRE #(
               .INIT(1'b0)             // Initial value of register (1'b0 or 1'b1)
               ) FDRE_wstrb_inst (
               .Q(wstrb_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]),      // Data output
               .C(ACLK),                                                      // Clock input
               .CE(1'b1),                                                     // Clock enable input
               .R(ARESET_or_store_in_wrap_buffer),                            // Synchronous reset input
               .D(wstrb_buffer_i[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt])     // Data input
               );
              
              // Select packed or extended data.
              always @ *
              begin
                // Multiplex data.
                if ( ( current_word_idx[word_cnt] & S_AXI_WSTRB[byte_cnt] ) | use_expander_data ) begin
                  wdata_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = S_AXI_WDATA[byte_cnt*8 +: 8];
                end else begin
                  wdata_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = 
                                (        wdata_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] & {8{wstrb_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt]}} ) | 
                                (   wdata_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] & {8{use_wrap_buffer}} );
                end
              
                // Multiplex write strobe.
                if ( current_word_idx[word_cnt] ) begin
                  // Combinatorial for last word to MI-side (only word for single).
                  wstrb_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = S_AXI_WSTRB[byte_cnt] |
                                (        wstrb_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt] ) | 
                                (   wstrb_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] & use_wrap_buffer );
                end else begin
                  // Use registered strobes. Registers are zero until valid data is written.
                  // I.e. zero when used for mismatched lanes while expanding.
                  wstrb_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = 
                                (        wstrb_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt] ) | 
                                (   wstrb_wrap_buffer[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] & use_wrap_buffer );
                end
              end
              
              // Merge previous with current data.
              always @ *
              begin
                M_AXI_WSTRB_I[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] = 
                                ( wstrb_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH/8+byte_cnt +: 1] );
                                
                M_AXI_WDATA_I[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] = 
                                ( wdata_last_word_mux[word_cnt*C_S_AXI_DATA_WIDTH+byte_cnt*8 +: 8] );
              end
              
            end // end if C_M_AXI_REGISTER
          end // end if C_FAMILY
        end // end for byte_cnt
      end // end if USE_ALWAYS_PACKER
    end // end for word_cnt
  endgenerate
      
  
  /////////////////////////////////////////////////////////////////////////////
  // MI-side output handling
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_M_AXI_REGISTER ) begin : USE_REGISTER
      reg                             M_AXI_WLAST_q;
      reg  [C_AXI_WUSER_WIDTH-1:0]    M_AXI_WUSER_q;
      reg                             M_AXI_WVALID_q;
    
      // Register MI-side Data.
      always @ (posedge ACLK) begin
        if (ARESET) begin
          M_AXI_WLAST_q     <= 1'b0;
          M_AXI_WUSER_q     <= {C_AXI_WUSER_WIDTH{1'b0}};
          M_AXI_WVALID_q    <= 1'b0;
          
        end else begin
          if ( M_AXI_WREADY_I ) begin
            M_AXI_WLAST_q     <= M_AXI_WLAST_I;
            M_AXI_WUSER_q     <= M_AXI_WUSER_I;
            M_AXI_WVALID_q    <= M_AXI_WVALID_I;
          end
          
        end
      end
      
      assign M_AXI_WDATA    = M_AXI_WDATA_I;
      assign M_AXI_WSTRB    = M_AXI_WSTRB_I;
      assign M_AXI_WLAST    = M_AXI_WLAST_q;
      assign M_AXI_WUSER    = M_AXI_WUSER_q;
      assign M_AXI_WVALID   = M_AXI_WVALID_q;
      assign M_AXI_WREADY_I = ( M_AXI_WVALID_q & M_AXI_WREADY) | ~M_AXI_WVALID_q;
      
      // Get MI-side data.
      assign pop_mi_data_i  = M_AXI_WVALID_I & M_AXI_WREADY_I;
      assign pop_mi_data    = M_AXI_WVALID_q & M_AXI_WREADY_I;
      
      // Detect when MI-side is stalling.
      assign mi_stalling    = ( M_AXI_WVALID_q & ~M_AXI_WREADY_I ) & ~store_in_wrap_buffer_enabled;
                          
    end else begin : NO_REGISTER
    
      // Combinatorial MI-side Data.
      assign M_AXI_WDATA    = M_AXI_WDATA_I;
      assign M_AXI_WSTRB    = M_AXI_WSTRB_I;
      assign M_AXI_WLAST    = M_AXI_WLAST_I;
      assign M_AXI_WUSER    = M_AXI_WUSER_I;
      assign M_AXI_WVALID   = M_AXI_WVALID_I;
      assign M_AXI_WREADY_I = M_AXI_WREADY;
      
      // Get MI-side data.
      if ( C_FAMILY == "rtl" ) begin : USE_RTL_POP_MI
        assign pop_mi_data_i  = M_AXI_WVALID_I & M_AXI_WREADY_I;
        
      end else begin : USE_FPGA_POP_MI
        
        assign pop_mi_data_i  = ( word_complete_next_wrap_pop | word_complete_rest_pop);
                             
      end
      assign pop_mi_data    = pop_mi_data_i;
      
      // Detect when MI-side is stalling.
      assign mi_stalling    = word_completed_qualified & ~M_AXI_WREADY_I;
                          
    end
  endgenerate
  
  
endmodule










module r_upsizer #
  (
   parameter         C_FAMILY                         = "rtl", 
                       // FPGA Family. Current version: virtex6 or spartan6.
   parameter integer C_AXI_ID_WIDTH                   = 4, 
                       // Width of all ID signals on SI and MI side of converter.
                       // Range: >= 1.
   parameter         C_S_AXI_DATA_WIDTH               = 32'h00000020, 
                       // Width of S_AXI_WDATA and S_AXI_RDATA.
                       // Format: Bit32; 
                       // Range: 'h00000020, 'h00000040, 'h00000080, 'h00000100.
   parameter         C_M_AXI_DATA_WIDTH               = 32'h00000040, 
                       // Width of M_AXI_WDATA and M_AXI_RDATA.
                       // Assume greater than or equal to C_S_AXI_DATA_WIDTH.
                       // Format: Bit32;
                       // Range: 'h00000020, 'h00000040, 'h00000080, 'h00000100.
   parameter integer C_S_AXI_REGISTER                 = 0,
                       // Clock output data.
                       // Range: 0, 1
   parameter integer C_AXI_SUPPORTS_USER_SIGNALS      = 0,
                       // 1 = Propagate all USER signals, 0 = Dont propagate.
   parameter integer C_AXI_RUSER_WIDTH                = 1,
                       // Width of RUSER signals. 
                       // Range: >= 1.
   parameter integer C_PACKING_LEVEL                    = 1,
                       // 0 = Never pack (expander only); packing logic is omitted.
                       // 1 = Pack only when CACHE[1] (Modifiable) is high.
                       // 2 = Always pack, regardless of sub-size transaction or Modifiable bit.
                       //     (Required when used as helper-core by mem-con.)
   parameter integer C_SUPPORT_BURSTS                 = 1,
                       // Disabled when all connected masters and slaves are AxiLite,
                       //   allowing logic to be simplified.
   parameter integer C_S_AXI_BYTES_LOG                = 3,
                       // Log2 of number of 32bit word on SI-side.
   parameter integer C_M_AXI_BYTES_LOG                = 3,
                       // Log2 of number of 32bit word on MI-side.
   parameter integer C_RATIO                          = 2,
                       // Up-Sizing ratio for data.
   parameter integer C_RATIO_LOG                      = 1
                       // Log2 of Up-Sizing ratio for data.
   )
  (
   // Global Signals
   input  wire                                                    ARESET,
   input  wire                                                    ACLK,

   // Command Interface
   input  wire                              cmd_valid,
   input  wire                              cmd_fix,
   input  wire                              cmd_modified,
   input  wire                              cmd_complete_wrap,
   input  wire                              cmd_packed_wrap,
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_first_word, 
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_next_word,
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_last_word,
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_offset,
   input  wire [C_M_AXI_BYTES_LOG-1:0]      cmd_mask,
   input  wire [C_S_AXI_BYTES_LOG:0]        cmd_step,
   input  wire [8-1:0]                      cmd_length,
   output wire                              cmd_ready,
   
   // Slave Interface Read Data Ports
   output wire [C_AXI_ID_WIDTH-1:0]           S_AXI_RID,
   output wire [C_S_AXI_DATA_WIDTH-1:0]    S_AXI_RDATA,
   output wire [2-1:0]                          S_AXI_RRESP,
   output wire                                                    S_AXI_RLAST,
   output wire [C_AXI_RUSER_WIDTH-1:0]          S_AXI_RUSER,
   output wire                                                    S_AXI_RVALID,
   input  wire                                                    S_AXI_RREADY,

   // Master Interface Read Data Ports
   input  wire [C_AXI_ID_WIDTH-1:0]          M_AXI_RID,
   input  wire [C_M_AXI_DATA_WIDTH-1:0]    M_AXI_RDATA,
   input  wire [2-1:0]                         M_AXI_RRESP,
   input  wire                                                   M_AXI_RLAST,
   input  wire [C_AXI_RUSER_WIDTH-1:0]         M_AXI_RUSER,
   input  wire                                                   M_AXI_RVALID,
   output wire                                                   M_AXI_RREADY
   );
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Variables for generating parameter controlled instances.
  /////////////////////////////////////////////////////////////////////////////
  
  genvar bit_cnt;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Local params
  /////////////////////////////////////////////////////////////////////////////
  
  // Constants for packing levels.
  localparam integer C_NEVER_PACK        = 0;
  localparam integer C_DEFAULT_PACK      = 1;
  localparam integer C_ALWAYS_PACK       = 2;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Functions
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Internal signals
  /////////////////////////////////////////////////////////////////////////////
  
  // Sub-word handling.
  wire                            sel_first_word;
  reg                             first_word;
  reg  [C_M_AXI_BYTES_LOG-1:0]    current_word_1;
  reg  [C_M_AXI_BYTES_LOG-1:0]    current_word_cmb;
  wire [C_M_AXI_BYTES_LOG-1:0]    current_word;
  wire [C_M_AXI_BYTES_LOG-1:0]    current_word_adjusted;
  wire                            last_beat;
  wire                            last_word;
  wire [C_M_AXI_BYTES_LOG-1:0]    cmd_step_i;
  
  // Sub-word handling for the next cycle.
  wire [C_M_AXI_BYTES_LOG-1:0]    pre_next_word_i;
  wire [C_M_AXI_BYTES_LOG-1:0]    pre_next_word;
  reg  [C_M_AXI_BYTES_LOG-1:0]    pre_next_word_1;
  wire [C_M_AXI_BYTES_LOG-1:0]    next_word_i;
  wire [C_M_AXI_BYTES_LOG-1:0]    next_word;
  
  // Burst length handling.
  wire                            first_mi_word;
  wire [8-1:0]                    length_counter_1;
  reg  [8-1:0]                    length_counter;
  wire [8-1:0]                    next_length_counter;
  
  // Handle wrap buffering.
  wire                            store_in_wrap_buffer;
  reg                             use_wrap_buffer;
  reg                             wrap_buffer_available;
  reg [C_AXI_ID_WIDTH-1:0]        rid_wrap_buffer;
  reg [2-1:0]                     rresp_wrap_buffer;
  reg [C_AXI_RUSER_WIDTH-1:0]     ruser_wrap_buffer;
  
  // Throttling help signals.
  wire                            next_word_wrap;
  wire                            word_complete_next_wrap;
  wire                            word_complete_next_wrap_ready;
  wire                            word_complete_next_wrap_pop;
  wire                            word_complete_last_word;
  wire                            word_complete_rest;
  wire                            word_complete_rest_ready;
  wire                            word_complete_rest_pop;
  wire                            word_completed;
  wire                            cmd_ready_i;
  wire                            pop_si_data;
  wire                            pop_mi_data;
  wire                            si_stalling;
  
  // Internal signals for MI-side.
  reg  [C_M_AXI_DATA_WIDTH-1:0]   M_AXI_RDATA_I;
  wire                            M_AXI_RLAST_I;
  wire                            M_AXI_RVALID_I;
  wire                            M_AXI_RREADY_I;
  
  // Internal signals for SI-side.
  wire [C_AXI_ID_WIDTH-1:0]       S_AXI_RID_I;
  wire [C_S_AXI_DATA_WIDTH-1:0]   S_AXI_RDATA_I;
  wire [2-1:0]                    S_AXI_RRESP_I;
  wire                            S_AXI_RLAST_I;
  wire [C_AXI_RUSER_WIDTH-1:0]    S_AXI_RUSER_I;
  wire                            S_AXI_RVALID_I;
  wire                            S_AXI_RREADY_I;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Handle interface handshaking:
  //
  // Determine if a MI side word has been completely used. For FIX transactions
  // the MI-side word is used to extract a single data word. This is also true
  // for for an upsizer in Expander mode (Never Pack). Unmodified burst also 
  // only use the MI word to extract a single SI-side word (although with 
  // different offsets).
  // Otherwise is the MI-side word considered to be used when last SI-side beat
  // has been extracted or when the last (most significant) SI-side word has 
  // been extracted from ti MI word.
  //
  // Data on the SI-side is available when data is being taken from MI-side or
  // from wrap buffer.
  //
  // The command is popped from the command queue once the last beat on the 
  // SI-side has been ackowledged.
  //
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_RATIO_LOG > 1 ) begin : USE_LARGE_UPSIZING
      assign cmd_step_i = {{C_RATIO_LOG-1{1'b0}}, cmd_step};
    end else begin : NO_LARGE_UPSIZING
      assign cmd_step_i = cmd_step;
    end
  endgenerate
  
  generate
    if ( C_FAMILY == "rtl" || ( C_SUPPORT_BURSTS == 0 ) || 
       ( C_PACKING_LEVEL == C_NEVER_PACK ) ) begin : USE_RTL_WORD_COMPLETED
      // Detect when MI-side word is completely used.
      assign word_completed = cmd_valid & 
                              ( ( cmd_fix ) |
                                ( ~cmd_fix & ~cmd_complete_wrap & next_word == {C_M_AXI_BYTES_LOG{1'b0}} ) | 
                                ( ~cmd_fix & last_word & ~use_wrap_buffer ) | 
                                ( ~cmd_modified & ( C_PACKING_LEVEL == C_DEFAULT_PACK ) ) |
                                ( C_PACKING_LEVEL == C_NEVER_PACK ) |
                                ( C_SUPPORT_BURSTS == 0 ) );
      
      // RTL equivalent of optimized partial extressions (address wrap for next word).
      assign word_complete_next_wrap       = ( ~cmd_fix & ~cmd_complete_wrap & next_word == {C_M_AXI_BYTES_LOG{1'b0}} ) | 
                                            ( C_PACKING_LEVEL == C_NEVER_PACK ) |
                                            ( C_SUPPORT_BURSTS == 0 );
      assign word_complete_next_wrap_ready = word_complete_next_wrap & M_AXI_RVALID_I & ~si_stalling;
      assign word_complete_next_wrap_pop   = word_complete_next_wrap_ready & M_AXI_RVALID_I;
      
      // RTL equivalent of optimized partial extressions (last word and the remaining).
      assign word_complete_last_word  = last_word & (~cmd_fix & ~use_wrap_buffer);
      assign word_complete_rest       = word_complete_last_word | cmd_fix | 
                                        ( ~cmd_modified & ( C_PACKING_LEVEL == C_DEFAULT_PACK ) );
      assign word_complete_rest_ready = word_complete_rest & M_AXI_RVALID_I & ~si_stalling;
      assign word_complete_rest_pop   = word_complete_rest_ready & M_AXI_RVALID_I;
      
    end else begin : USE_FPGA_WORD_COMPLETED
    
      wire sel_word_complete_next_wrap;
      wire sel_word_completed;
      wire sel_m_axi_rready;
      wire sel_word_complete_last_word;
      wire sel_word_complete_rest;
      
      // Optimize next word address wrap branch of expression.
      //
      comparator_sel_static #
        (
         .C_FAMILY(C_FAMILY),
         .C_VALUE({C_M_AXI_BYTES_LOG{1'b0}}),
         .C_DATA_WIDTH(C_M_AXI_BYTES_LOG)
         ) next_word_wrap_inst
        (
         .CIN(1'b1),
         .S(sel_first_word),
         .A(pre_next_word_1),
         .B(cmd_next_word),
         .COUT(next_word_wrap)
         );
         
      assign sel_word_complete_next_wrap = ~cmd_fix & ~cmd_complete_wrap;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_inst
        (
         .CIN(next_word_wrap),
         .S(sel_word_complete_next_wrap),
         .COUT(word_complete_next_wrap)
         );
         
      assign sel_m_axi_rready = cmd_valid & S_AXI_RREADY_I;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_ready_inst
        (
         .CIN(word_complete_next_wrap),
         .S(sel_m_axi_rready),
         .COUT(word_complete_next_wrap_ready)
         );
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_next_wrap_pop_inst
        (
         .CIN(word_complete_next_wrap_ready),
         .S(M_AXI_RVALID_I),
         .COUT(word_complete_next_wrap_pop)
         );
      
      // Optimize last word and "rest" branch of expression.
      //
      assign sel_word_complete_last_word = ~cmd_fix & ~use_wrap_buffer;
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_last_word_inst
        (
         .CIN(last_word),
         .S(sel_word_complete_last_word),
         .COUT(word_complete_last_word)
         );
      
      assign sel_word_complete_rest = cmd_fix | ( ~cmd_modified & ( C_PACKING_LEVEL == C_DEFAULT_PACK ) );
      
      carry_or #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_rest_inst
        (
         .CIN(word_complete_last_word),
         .S(sel_word_complete_rest),
         .COUT(word_complete_rest)
         );
         
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_rest_ready_inst
        (
         .CIN(word_complete_rest),
         .S(sel_m_axi_rready),
         .COUT(word_complete_rest_ready)
         );
      
      carry_and #
        (
         .C_FAMILY(C_FAMILY)
         ) word_complete_rest_pop_inst
        (
         .CIN(word_complete_rest_ready),
         .S(M_AXI_RVALID_I),
         .COUT(word_complete_rest_pop)
         );
      
      // Combine the two branches to generate the full signal.
      assign word_completed = word_complete_next_wrap | word_complete_rest;
      
    end
  endgenerate
  
  // Only propagate Valid when there is command information available.
  assign M_AXI_RVALID_I = M_AXI_RVALID & cmd_valid;
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_CTRL
      // Pop word from MI-side.
      assign M_AXI_RREADY_I = word_completed & S_AXI_RREADY_I;
      
      // Get MI-side data.
      assign pop_mi_data    = M_AXI_RVALID_I & M_AXI_RREADY_I;
      
      // Signal that the command is done (so that it can be poped from command queue).
      assign cmd_ready_i    = cmd_valid & S_AXI_RLAST_I & pop_si_data;
      
    end else begin : USE_FPGA_CTRL
      wire sel_cmd_ready;
      
      assign M_AXI_RREADY_I = word_complete_next_wrap_ready | word_complete_rest_ready;
      
      assign pop_mi_data    = word_complete_next_wrap_pop | word_complete_rest_pop;
      
      assign sel_cmd_ready  = cmd_valid & pop_si_data;
    
      carry_latch_and #
        (
         .C_FAMILY(C_FAMILY)
         ) cmd_ready_inst
        (
         .CIN(S_AXI_RLAST_I),
         .I(sel_cmd_ready),
         .O(cmd_ready_i)
         );
      
    end
  endgenerate
  
  // Indicate when there is data available @ SI-side.
  assign S_AXI_RVALID_I = ( M_AXI_RVALID_I | use_wrap_buffer );
  
  // Get SI-side data.
  assign pop_si_data    = S_AXI_RVALID_I & S_AXI_RREADY_I;
  
  // Assign external signals.
  assign M_AXI_RREADY   = M_AXI_RREADY_I;
  assign cmd_ready      = cmd_ready_i;
  
  // Detect when SI-side is stalling.
  assign si_stalling    = S_AXI_RVALID_I & ~S_AXI_RREADY_I;
                          
  
  /////////////////////////////////////////////////////////////////////////////
  // Keep track of data extraction:
  // 
  // Current address is taken form the command buffer for the first data beat
  // to handle unaligned Read transactions. After this is the extraction 
  // address usually calculated from this point.
  // FIX transactions uses the same word address for all data beats. 
  // 
  // Next word address is generated as current word plus the current step 
  // size, with masking to facilitate sub-sized wraping. The Mask is all ones
  // for normal wraping, and less when sub-sized wraping is used.
  // 
  // The calculated word addresses (current and next) is offseted by the 
  // current Offset. For sub-sized transaction the Offset points to the least 
  // significant address of the included data beats. (The least significant 
  // word is not necessarily the first data to be extracted, consider WRAP).
  // Offset is only used for sub-sized WRAP transcation that are Complete.
  // 
  // First word is active during the first SI-side data beat.
  // 
  // First MI is set while the entire first MI-side word is processed.
  //
  // The transaction length is taken from the command buffer combinatorialy
  // during the First MI cycle. For each used MI word it is decreased until 
  // Last beat is reached.
  // 
  // Last word is determined depending on the current command, i.e. modified 
  // burst has to scale since multiple words could be packed into one MI-side
  // word.
  // Last word is 1:1 for:
  // FIX, when burst support is disabled or unmodified for Normal Pack.
  // Last word is scaled for all other transactions.
  //
  /////////////////////////////////////////////////////////////////////////////
  
  // Select if the offset comes from command queue directly or 
  // from a counter while when extracting multiple SI words per MI word
  assign sel_first_word = first_word | cmd_fix;
  assign current_word   = sel_first_word ? cmd_first_word : 
                                           current_word_1;
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_NEXT_WORD
      
      // Calculate next word.
      assign pre_next_word_i  = ( next_word_i + cmd_step_i );
      
      // Calculate next word.
      assign next_word_i      = sel_first_word ? cmd_next_word : 
                                                 pre_next_word_1;
      
    end else begin : USE_FPGA_NEXT_WORD
      wire [C_M_AXI_BYTES_LOG-1:0]  next_sel;
      wire [C_M_AXI_BYTES_LOG:0]    next_carry_local;

      // Assign input to local vectors.
      assign next_carry_local[0]      = 1'b0;
    
      // Instantiate one carry and per level.
      for (bit_cnt = 0; bit_cnt < C_M_AXI_BYTES_LOG ; bit_cnt = bit_cnt + 1) begin : LUT_LEVEL
        
        LUT6_2 # (
         .INIT(64'h5A5A_5A66_F0F0_F0CC) 
        ) LUT6_2_inst (
        .O6(next_sel[bit_cnt]),         // 6/5-LUT output (1-bit)
        .O5(next_word_i[bit_cnt]),      // 5-LUT output (1-bit)
        .I0(cmd_step_i[bit_cnt]),       // LUT input (1-bit)
        .I1(pre_next_word_1[bit_cnt]),  // LUT input (1-bit)
        .I2(cmd_next_word[bit_cnt]),    // LUT input (1-bit)
        .I3(first_word),                // LUT input (1-bit)
        .I4(cmd_fix),                   // LUT input (1-bit)
        .I5(1'b1)                       // LUT input (1-bit)
        );
        
        MUXCY next_carry_inst 
        (
         .O (next_carry_local[bit_cnt+1]), 
         .CI (next_carry_local[bit_cnt]), 
         .DI (cmd_step_i[bit_cnt]), 
         .S (next_sel[bit_cnt])
        ); 
        
        XORCY next_xorcy_inst 
        (
         .O(pre_next_word_i[bit_cnt]),
         .CI(next_carry_local[bit_cnt]),
         .LI(next_sel[bit_cnt])
        );
        
      end // end for bit_cnt
      
    end
  endgenerate
  
  // Calculate next word.
  assign next_word              = next_word_i     & cmd_mask;
  assign pre_next_word          = pre_next_word_i & cmd_mask;
  
  // Calculate the word address with offset.
  assign current_word_adjusted  = current_word | cmd_offset;
  
  // Prepare next word address.
  always @ (posedge ACLK) begin
    if (ARESET) begin
      first_word      <= 1'b1;
      current_word_1  <= 'b0;
      pre_next_word_1 <= {C_M_AXI_BYTES_LOG{1'b0}};
    end else begin
      if ( pop_si_data ) begin
        if ( last_word ) begin
          // Prepare for next access.
          first_word      <=  1'b1;
        end else begin
          first_word      <=  1'b0;
        end
      
        current_word_1  <= next_word;
        pre_next_word_1 <= pre_next_word;
      end
    end
  end
  
  // Select command length or counted length.
  always @ *
  begin
    if ( first_mi_word )
      length_counter = cmd_length;
    else
      length_counter = length_counter_1;
  end
  
  // Calculate next length counter value.
  assign next_length_counter = length_counter - 1'b1;
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL_LENGTH
      reg  [8-1:0]                    length_counter_q;
      reg                             first_mi_word_q;
    
      always @ (posedge ACLK) begin
        if (ARESET) begin
          first_mi_word_q  <= 1'b1;
          length_counter_q <= 8'b0;
        end else begin
          if ( pop_mi_data ) begin
            if ( M_AXI_RLAST ) begin
              first_mi_word_q  <= 1'b1;
            end else begin
              first_mi_word_q  <= 1'b0;
            end
          
            length_counter_q <= next_length_counter;
          end
        end
      end
      
      assign first_mi_word    = first_mi_word_q;
      assign length_counter_1 = length_counter_q;
      
    end else begin : USE_FPGA_LENGTH
      wire [8-1:0]  length_counter_i;
      wire [8-1:0]  length_sel;
      wire [8-1:0]  length_di;
      wire [8:0]    length_local_carry;
      
      // Assign input to local vectors.
      assign length_local_carry[0] = 1'b0;
    
      for (bit_cnt = 0; bit_cnt < 8 ; bit_cnt = bit_cnt + 1) begin : BIT_LANE

        LUT6_2 # (
         .INIT(64'h333C_555A_FFF0_FFF0) 
        ) LUT6_2_inst (
        .O6(length_sel[bit_cnt]),           // 6/5-LUT output (1-bit)
        .O5(length_di[bit_cnt]),            // 5-LUT output (1-bit)
        .I0(length_counter_1[bit_cnt]),     // LUT input (1-bit)
        .I1(cmd_length[bit_cnt]),           // LUT input (1-bit)
        .I2(word_complete_next_wrap_pop),  // LUT input (1-bit)
        .I3(word_complete_rest_pop),        // LUT input (1-bit)
        .I4(first_mi_word),                 // LUT input (1-bit)
        .I5(1'b1)                           // LUT input (1-bit)
        );
        
        MUXCY and_inst 
        (
         .O (length_local_carry[bit_cnt+1]), 
         .CI (length_local_carry[bit_cnt]), 
         .DI (length_di[bit_cnt]), 
         .S (length_sel[bit_cnt])
        ); 
        
        XORCY xorcy_inst 
        (
         .O(length_counter_i[bit_cnt]),
         .CI(length_local_carry[bit_cnt]),
         .LI(length_sel[bit_cnt])
        );
        
        FDRE #(
         .INIT(1'b0)                    // Initial value of register (1'b0 or 1'b1)
         ) FDRE_inst (
         .Q(length_counter_1[bit_cnt]), // Data output
         .C(ACLK),                      // Clock input
         .CE(1'b1),                     // Clock enable input
         .R(ARESET),                    // Synchronous reset input
         .D(length_counter_i[bit_cnt])  // Data input
         );
      end // end for bit_cnt
      
      wire first_mi_word_i;
      
      LUT6 # (
       .INIT(64'hAAAC_AAAC_AAAC_AAAC) 
      ) LUT6_cnt_inst (
      .O(first_mi_word_i),                // 6-LUT output (1-bit)
      .I0(M_AXI_RLAST),                   // LUT input (1-bit)
      .I1(first_mi_word),                 // LUT input (1-bit)
      .I2(word_complete_next_wrap_pop),  // LUT input (1-bit)
      .I3(word_complete_rest_pop),        // LUT input (1-bit)
      .I4(1'b1),                          // LUT input (1-bit)
      .I5(1'b1)                           // LUT input (1-bit)
      );
          
      FDSE #(
       .INIT(1'b1)                    // Initial value of register (1'b0 or 1'b1)
       ) FDRE_inst (
       .Q(first_mi_word),             // Data output
       .C(ACLK),                      // Clock input
       .CE(1'b1),                     // Clock enable input
       .S(ARESET),                    // Synchronous reset input
       .D(first_mi_word_i)            // Data input
       );
      
    end
  endgenerate
  
  generate
    if ( C_FAMILY == "rtl" || C_SUPPORT_BURSTS == 0 ) begin : USE_RTL_LAST_WORD
      // Detect last beat in a burst.
      assign last_beat = ( length_counter == 8'b0 );
      
      // Determine if this last word that shall be extracted from this MI-side word.
      assign last_word = ( last_beat & ( current_word == cmd_last_word ) & ~wrap_buffer_available & ( current_word == cmd_last_word ) ) |
                         ( use_wrap_buffer & ( current_word == cmd_last_word ) ) |
                         ( last_beat & ( current_word == cmd_last_word ) & ( C_PACKING_LEVEL == C_NEVER_PACK ) ) |
                         ( C_SUPPORT_BURSTS == 0 );
  
    end else begin : USE_FPGA_LAST_WORD
    
      wire sel_last_word;
      wire last_beat_ii;
      
      
      comparator_sel_static #
        (
         .C_FAMILY(C_FAMILY),
         .C_VALUE(8'b0),
         .C_DATA_WIDTH(8)
         ) last_beat_inst
        (
         .CIN(1'b1),
         .S(first_mi_word),
         .A(length_counter_1),
         .B(cmd_length),
         .COUT(last_beat)
         );
      
      if ( C_PACKING_LEVEL != C_NEVER_PACK  ) begin : USE_FPGA_PACK
        // 
        //
        wire sel_last_beat;
        wire last_beat_i;
        
        assign sel_last_beat = ~wrap_buffer_available;
        
        carry_and #
          (
           .C_FAMILY(C_FAMILY)
           ) last_beat_inst_1
          (
           .CIN(last_beat),
           .S(sel_last_beat),
           .COUT(last_beat_i)
           );
  
        carry_or #
          (
           .C_FAMILY(C_FAMILY)
           ) last_beat_wrap_inst
          (
           .CIN(last_beat_i),
           .S(use_wrap_buffer),
           .COUT(last_beat_ii)
           );
  
      end else begin : NO_PACK
        assign last_beat_ii = last_beat;
           
      end
        
      comparator_sel #
        (
         .C_FAMILY(C_FAMILY),
         .C_DATA_WIDTH(C_M_AXI_BYTES_LOG)
         ) last_beat_curr_word_inst
        (
         .CIN(last_beat_ii),
         .S(sel_first_word),
         .A(current_word_1),
         .B(cmd_first_word),
         .V(cmd_last_word),
         .COUT(last_word)
         );
      
    end
  endgenerate
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Handle wrap buffer:
  // 
  // The wrap buffer is used to move data around in an unaligned WRAP 
  // transaction. The requested read address has been rounded down, meaning 
  // that parts of the first MI-side data beat has to be delayed for later use.
  // The extraction starts at the origian unaligned address, the remaining data
  // is stored in the wrap buffer to be extracted after the last MI-side data 
  // beat has been fully processed.
  // For example: an 32bit to 64bit read upsizing @ 0x4 will request a MI-side
  // read WRAP transaction 0x0. The 0x4 data word is used at once and the 0x0 
  // word is delayed to be used after all data in the last MI-side beat has 
  // arrived.
  // 
  /////////////////////////////////////////////////////////////////////////////
  
  // Save data to be able to perform buffer wraping.
  assign store_in_wrap_buffer = M_AXI_RVALID_I & cmd_packed_wrap & first_mi_word & ~use_wrap_buffer;
  
  // Mark that there are data available for wrap buffering.
  always @ (posedge ACLK) begin
    if (ARESET) begin
      wrap_buffer_available <= 1'b0;
    end else begin
      if ( store_in_wrap_buffer & word_completed & pop_si_data  ) begin
        wrap_buffer_available <= 1'b1;
      end else if ( last_beat & word_completed & pop_si_data  ) begin
        wrap_buffer_available <= 1'b0;
      end
    end
  end
  
  // Start using the wrap buffer.
  always @ (posedge ACLK) begin
    if (ARESET) begin
      use_wrap_buffer <= 1'b0;
    end else begin
      if ( wrap_buffer_available & last_beat & word_completed & pop_si_data ) begin
        use_wrap_buffer <= 1'b1;
      end else if ( cmd_ready_i ) begin
        use_wrap_buffer <= 1'b0;
      end
    end
  end
  
  // Store data in wrap buffer.
  always @ (posedge ACLK) begin
    if (ARESET) begin
      M_AXI_RDATA_I     <= {C_M_AXI_DATA_WIDTH{1'b0}};
      rid_wrap_buffer   <= {C_AXI_ID_WIDTH{1'b0}};
      rresp_wrap_buffer <= 2'b0;
      ruser_wrap_buffer <= {C_AXI_ID_WIDTH{1'b0}};
    end else begin
      if ( store_in_wrap_buffer ) begin
        M_AXI_RDATA_I     <= M_AXI_RDATA;
        rid_wrap_buffer   <= M_AXI_RID;
        rresp_wrap_buffer <= M_AXI_RRESP;
        ruser_wrap_buffer <= M_AXI_RUSER;
      end
    end
  end
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Select the SI-side word to read.
  //
  // Everything must be multiplexed since the next transfer can be arriving 
  // with a different set of signals while the wrap buffer is still being 
  // processed for the current transaction.
  // 
  // Non modifiable word has a 1:1 ratio, i.e. only one SI-side word is 
  // generated per MI-side word.
  // Data is taken either directly from the incomming MI-side data or the 
  // wrap buffer (for packed WRAP).
  //
  // Last need special handling since it is the last SI-side word generated 
  // from the MI-side word.
  //
  /////////////////////////////////////////////////////////////////////////////
  
  // ID, RESP and USER has to be multiplexed.
  assign S_AXI_RID_I    = ( use_wrap_buffer & ( C_SUPPORT_BURSTS == 1 ) ) ? 
                          rid_wrap_buffer :
                          M_AXI_RID;
  assign S_AXI_RRESP_I  = ( use_wrap_buffer & ( C_SUPPORT_BURSTS == 1 ) ) ? 
                          rresp_wrap_buffer :
                          M_AXI_RRESP;
  assign S_AXI_RUSER_I  = ( C_AXI_SUPPORTS_USER_SIGNALS ) ? 
                            ( use_wrap_buffer & ( C_SUPPORT_BURSTS == 1 ) ) ? 
                            ruser_wrap_buffer :
                            M_AXI_RUSER :
                          {C_AXI_RUSER_WIDTH{1'b0}};
                          
  // Data has to be multiplexed.
  generate
    if ( C_RATIO == 1 ) begin : SINGLE_WORD
      assign S_AXI_RDATA_I  = ( use_wrap_buffer & ( C_SUPPORT_BURSTS == 1 ) ) ? 
                              M_AXI_RDATA_I :
                              M_AXI_RDATA;
    end else begin : MULTIPLE_WORD
      // Get the ratio bits (MI-side words vs SI-side words).
      wire [C_RATIO_LOG-1:0]          current_index;
      assign current_index  = current_word_adjusted[C_M_AXI_BYTES_LOG-C_RATIO_LOG +: C_RATIO_LOG];
      
      assign S_AXI_RDATA_I  = ( use_wrap_buffer & ( C_SUPPORT_BURSTS == 1 ) ) ? 
                              M_AXI_RDATA_I[current_index * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] :
                              M_AXI_RDATA[current_index * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
    end
  endgenerate
  
  // Generate the true last flag including "keep" while using wrap buffer.
  assign M_AXI_RLAST_I  = ( M_AXI_RLAST | use_wrap_buffer );
  
  // Handle last flag, i.e. set for SI-side last word.
  assign S_AXI_RLAST_I  = last_word;
  
  
  /////////////////////////////////////////////////////////////////////////////
  // SI-side output handling
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_S_AXI_REGISTER ) begin : USE_REGISTER
      reg  [C_AXI_ID_WIDTH-1:0]       S_AXI_RID_q;
      reg  [C_S_AXI_DATA_WIDTH-1:0]   S_AXI_RDATA_q;
      reg  [2-1:0]                    S_AXI_RRESP_q;
      reg                             S_AXI_RLAST_q;
      reg  [C_AXI_RUSER_WIDTH-1:0]    S_AXI_RUSER_q;
      reg                             S_AXI_RVALID_q;
      reg                             S_AXI_RREADY_q;
    
      // Register SI-side Data.
      always @ (posedge ACLK) begin
        if (ARESET) begin
          S_AXI_RID_q       <= {C_AXI_ID_WIDTH{1'b0}};
          S_AXI_RDATA_q     <= {C_S_AXI_DATA_WIDTH{1'b0}};
          S_AXI_RRESP_q     <= 2'b0;
          S_AXI_RLAST_q     <= 1'b0;
          S_AXI_RUSER_q     <= {C_AXI_RUSER_WIDTH{1'b0}};
          S_AXI_RVALID_q    <= 1'b0;
        end else begin
          if ( S_AXI_RREADY_I ) begin
            S_AXI_RID_q       <= S_AXI_RID_I;
            S_AXI_RDATA_q     <= S_AXI_RDATA_I;
            S_AXI_RRESP_q     <= S_AXI_RRESP_I;
            S_AXI_RLAST_q     <= S_AXI_RLAST_I;
            S_AXI_RUSER_q     <= S_AXI_RUSER_I;
            S_AXI_RVALID_q    <= S_AXI_RVALID_I;
          end
          
        end
      end
      
      assign S_AXI_RID      = S_AXI_RID_q;
      assign S_AXI_RDATA    = S_AXI_RDATA_q;
      assign S_AXI_RRESP    = S_AXI_RRESP_q;
      assign S_AXI_RLAST    = S_AXI_RLAST_q;
      assign S_AXI_RUSER    = S_AXI_RUSER_q;
      assign S_AXI_RVALID   = S_AXI_RVALID_q;
      assign S_AXI_RREADY_I = ( S_AXI_RVALID_q & S_AXI_RREADY) | ~S_AXI_RVALID_q;
      
    end else begin : NO_REGISTER
    
      // Combinatorial SI-side Data.
      assign S_AXI_RREADY_I = S_AXI_RREADY;
      assign S_AXI_RVALID   = S_AXI_RVALID_I;
      assign S_AXI_RID      = S_AXI_RID_I;
      assign S_AXI_RDATA    = S_AXI_RDATA_I;
      assign S_AXI_RRESP    = S_AXI_RRESP_I;
      assign S_AXI_RLAST    = S_AXI_RLAST_I;
      assign S_AXI_RUSER    = S_AXI_RUSER_I;
  
    end
  endgenerate
  
  
endmodule











module carry_latch_or #
  (
   parameter          C_FAMILY                         = "virtex6"
                       // FPGA Family. Current version: virtex6 or spartan6.
   )
  (
   input  wire        CIN,
   input  wire        I,
   output wire        O
   );
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Variables for generating parameter controlled instances.
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Local params
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Functions
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Internal signals
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Instantiate or use RTL code
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL
      assign O = CIN | I;
      
    end else begin : USE_FPGA
      OR2L or2l_inst1
        (
         .O(O),
         .DI(CIN),
         .SRI(I)
        );
      
    end
  endgenerate
  
  
endmodule










module carry_latch_and #
  (
   parameter          C_FAMILY                         = "virtex6"
                       // FPGA Family. Current version: virtex6 or spartan6.
   )
  (
   input  wire        CIN,
   input  wire        I,
   output wire        O
   );
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Variables for generating parameter controlled instances.
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Local params
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Functions
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Internal signals
  /////////////////////////////////////////////////////////////////////////////

  
  /////////////////////////////////////////////////////////////////////////////
  // Instantiate or use RTL code
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL
      assign O = CIN & ~I;
      
    end else begin : USE_FPGA
      wire I_n;
      
      assign I_n = ~I;
    
      AND2B1L and2b1l_inst 
        (
         .O(O),
         .DI(CIN),
         .SRI(I_n)
        );
      
    end
  endgenerate
  
  
endmodule







module carry_and #
  (
   parameter         C_FAMILY                         = "virtex6"
                       // FPGA Family. Current version: virtex6 or spartan6.
   )
  (
   input  wire        CIN,
   input  wire        S,
   output wire        COUT
   );
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Variables for generating parameter controlled instances.
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Local params
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Functions
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Internal signals
  /////////////////////////////////////////////////////////////////////////////

  
  /////////////////////////////////////////////////////////////////////////////
  // Instantiate or use RTL code
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL
      assign COUT = CIN & S;
      
    end else begin : USE_FPGA
      MUXCY and_inst 
      (
       .O (COUT), 
       .CI (CIN), 
       .DI (1'b0), 
       .S (S)
      ); 
      
    end
  endgenerate
  
  
endmodule







module carry_or #
  (
   parameter         C_FAMILY                         = "virtex6"
                       // FPGA Family. Current version: virtex6 or spartan6.
   )
  (
   input  wire        CIN,
   input  wire        S,
   output wire        COUT
   );
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Variables for generating parameter controlled instances.
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Local params
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Functions
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Internal signals
  /////////////////////////////////////////////////////////////////////////////
  
  
  /////////////////////////////////////////////////////////////////////////////
  // Instantiate or use RTL code
  /////////////////////////////////////////////////////////////////////////////
  
  generate
    if ( C_FAMILY == "rtl" ) begin : USE_RTL
      assign COUT = CIN | S;
      
    end else begin : USE_FPGA
      wire S_n;
      
      assign S_n = ~S;
    
      MUXCY and_inst 
      (
       .O (COUT), 
       .CI (CIN), 
       .DI (1'b1), 
       .S (S_n)
      ); 
      
    end
  endgenerate
  
  
endmodule

