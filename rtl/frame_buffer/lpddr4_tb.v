`timescale 1 ns / 1 ns

module lpddr4_tb;

 /////////////   
parameter   AXI_DATA_WIDTH    = 128               ; //AXI Data Width(Bit)
  
parameter   DDR_WRITE_FIRST   = 1'h1              ; //1:Write First ; 0: Read First   
parameter   AXI_ID_WIDTH    =   8         ;
localparam   AXI0_WR_ID        = 8'haa           ; //AXI Write ID
localparam   AXI0_RD_ID        = 8'h55           ; //AXI Read ID	
localparam   AXI_ADDR_WIDTH 	= 32;//Address Width    

localparam H_FRONT_PORCH   	= 13'd88 	;//	
localparam H_SYNC 	 		= 13'd44 	;//
localparam H_VALID 	 	  	= 13'd199  ;//
localparam H_BACK_PORCH  	= 13'd148   ;// 	
localparam V_FRONT_PORCH   	= 13'd4 	;//	
localparam V_SYNC 	 	    = 13'd5 	;//
localparam V_VALID 	 	  	= 13'd9  ;//
localparam V_BACK_PORCH  	= 13'd36 	;//	

localparam WR_FIFO_DEPTH  = 1024;
localparam RD_FIFO_DEPTH  = 1024;

wire  axi0_ARQOS;         
wire  axi0_AWQOS;         
wire  [5:0] axi0_AWID;    
wire  [32:0] axi0_AWADDR; 
wire  [7:0] axi0_AWLEN;   
wire  [2:0] axi0_AWSIZE;  
wire  [1:0] axi0_AWBURST; 
wire  axi0_AWVALID;       
wire  [3:0] axi0_AWCACHE; 
wire  axi0_AWCOBUF;       
wire  axi0_AWLOCK;        
wire  axi0_AWAPCMD;       
wire  axi0_AWALLSTRB;     
wire  [5:0] axi0_ARID;   
wire  [32:0] axi0_ARADDR; 
wire  [7:0] axi0_ARLEN;   
wire  [2:0] axi0_ARSIZE;  
wire  [1:0] axi0_ARBURST; 
wire  axi0_ARVALID;       
wire  axi0_ARLOCK;        
wire  axi0_ARAPCMD;       
wire  axi0_WLAST;         
wire  axi0_WVALID;        
wire  [511:0] axi0_WDATA; 
wire  [63:0] axi0_WSTRB;  
wire  axi0_BREADY;        
wire  axi0_RREADY;        
wire axi0_AWREADY;        
wire axi0_ARREADY;        
wire axi0_WREADY;         
wire [5:0] axi0_BID;      
wire [1:0] axi0_BRESP;    
wire axi0_BVALID;         
wire [5:0] axi0_RID;      
wire axi0_RLAST;          
wire axi0_RVALID;         
wire [511:0] axi0_RDATA;  
wire [1:0] axi0_RRESP;   

  //Ports
  reg  clk= 0;
  reg  rst_n = 0;
  wire [7:0] i_rdata;
  wire [7:0] i_gdata;
  wire [7:0] i_bdata;

  wire  hs;
  wire  vs;
  wire  de;

  wire [7:0] rgb_r;
  wire [7:0] rgb_g;
  wire [7:0] rgb_b;

  
  wire [7:0] 	ch0_r;
  wire [7:0]    ch0_g;
  wire [7:0]    ch0_b;
  wire ch0_vs;
  wire ch0_hs;
  wire ch0_de;

  always #10 clk = !clk;
  assign axi0_ACLK = clk;
  initial begin
    #0  rst_n = 0;
    # 100 rst_n = 1;
  end

color_bar_rgb # (
  .HS_POLORY(1'b1),
  .VS_POLORY(1'b1),
  .NUM_OF_PIXERS_PER_CLOCK(1),
  .H_FRONT_PORCH(H_FRONT_PORCH),
  .H_SYNC(H_SYNC),
  .H_VALID(H_VALID),
  .H_BACK_PORCH(H_BACK_PORCH),
  .V_FRONT_PORCH(V_FRONT_PORCH),
  .V_SYNC(V_SYNC),
  .V_VALID(V_VALID),
  .V_BACK_PORCH(V_BACK_PORCH),
  .TEST_MODE(0)
)
color_bar_rgb_inst (
  .clk(clk),
  .rst_n(rst_n),
  .i_rdata(i_rdata),
  .i_gdata(i_gdata),
  .i_bdata(i_bdata),
  .h_cnt(h_cnt),
  .v_cnt(v_cnt),
  .hs(hs),
  .vs(vs),
  .de(de),
  .w_h_state(w_h_state),
  .w_v_state(w_v_state),
  .rgb_r(rgb_r),
  .rgb_g(rgb_g),
  .rgb_b(rgb_b)
);



frame_buffer #(
.I_VID_WIDTH (16),
.O_VID_WIDTH (16),
.START_ADDR     (32'h00120        ),
.FB_NUM			    (3),   
.MAX_VID_WIDTH  (1920),		
.MAX_VID_HIGHT	(1080)	,
.BURST_LEN  	(63),
.AXI_DATA_WIDTH ( AXI_DATA_WIDTH	),
.AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH	),
.WR_FIFO_DEPTH	( WR_FIFO_DEPTH		),    
.RD_FIFO_DEPTH 	( RD_FIFO_DEPTH 	)
)checker0(
    .axi_clk(axi0_ACLK),
    .rst_n(rst_n),

/*i*/.i_clk			(clk   ),// (CLK_148P5M),//	(VI_CLK3_PLL		),    //(CLK_148P5M   ),//    
/*i*/.i_vs			(vs),//(rx_vsync 			),// (sync_vs2  ),//(e3_v							),  //(sw0_vs 			),//
/*i*/.i_de			(de),//(rx_de 				),// (sync_de2  ),//(e3_de						),    //(sw0_de 			),//
/*i*/.vin 			({rgb_r,rgb_g,rgb_b}),//({y_422,c_422}),//
                  
/*i*/.o_clk			  (clk	 ),//(clk_o),//
/*i*/.o_hs    		(ch0_hs),//(ch0_hs_o			), //active high
/*i*/.o_vs    		(ch0_vs),//(ch0_vs_o			), //active hgih
/*i*/.o_de    		(ch0_de),//(ch0_de_o			), //active high
/*i*/.vout    		({ch0_r,ch0_g,ch0_b}		),//({ch0_rdata,ch0_gdata,ch0_bdata}			),

  /*i*/.H_FRONT_PORCH (H_FRONT_PORCH   ),//( 50 			),
	/*i*/.H_SYNC 	 		(H_SYNC 	 		),//( 50 			),
	/*i*/.H_VALID 	 	(H_VALID 	 	),//( 48 			),
	/*i*/.H_BACK_PORCH(H_BACK_PORCH),//( 50 			),
	/*i*/.V_FRONT_PORCH (V_FRONT_PORCH   ),//( 5 			),
	/*i*/.V_SYNC 	 		(V_SYNC 	 		),//( 5 			),
	/*i*/.V_VALID 	 	(V_VALID 	 	),//( 20 			),
	/*i*/.V_BACK_PORCH(V_BACK_PORCH),//( 5 			),
  
    .awid(axi0_AWID),
    .awaddr(axi0_AWADDR),
    .awlen(axi0_AWLEN),
    .awsize(axi0_AWSIZE),
    .awburst(axi0_AWBURST),
    .awcache(axi0_AWCACHE),
    .awlock(axi0_AWLOCK),
    .awvalid(axi0_AWVALID),
    .awcobuf(axi0_AWCOBUF),
    .awapcmd(axi0_AWAPCMD),
    .awallstrb(axi0_AWALLSTRB),
    .awready(axi0_AWREADY),
    .awqos(axi0_AWQOS),
    .arid(axi0_ARID),
    .araddr(axi0_ARADDR),
    .arlen(axi0_ARLEN),
    .arsize(axi0_ARSIZE),
    .arburst(axi0_ARBURST),
    .arlock(axi0_ARLOCK),
    .arvalid(axi0_ARVALID),
    .arapcmd(axi0_ARAPCMD),
    .arready(axi0_ARREADY),
    .arqos(axi0_ARQOS),
    .wdata(axi0_WDATA),
    .wstrb(axi0_WSTRB),
    .wlast(axi0_WLAST),
    .wvalid(axi0_WVALID),
    .wready(axi0_WREADY),
    .rid(axi0_RID),
    .rdata(axi0_RDATA),
    .rlast(axi0_RLAST),
    .rvalid(axi0_RVALID),
    .rready(axi0_RREADY),
    .rresp(axi0_RRESP),
    .bid(axi0_BID),
    .bvalid(axi0_BVALID),
    .bready(axi0_BREADY)
);

vid_check  u_vid_check(
	/*i*/.clk		(clk ),
	/*i*/.rst_n		(rst_n),
	/*i*/.i_hs		(ch0_hs),
	/*i*/.i_vs		(ch0_vs),
	/*i*/.i_de		(ch0_de),
	/*i*/.vin 		({ch0_r,ch0_g,ch0_b }),
	/*o*/.check_fail()
	
	);

axi_ram #
(
    .DATA_WIDTH            (AXI_DATA_WIDTH       ),
    .ADDR_WIDTH            (20       ),
    .ID_WIDTH              (6            ),
    .PIPELINE_OUTPUT       (0            )
)                                        
u_axi_ram
(
    .clk                   (axi0_ACLK     ),
    .rst                   (!io_asyncResetn     	),
    .s_axi_awid            (0     ),
    .s_axi_awaddr          (axi0_AWADDR   ), 
    .s_axi_awlen           (axi0_AWLEN   ), 
    .s_axi_awsize          (axi0_AWSIZE   ), 
    .s_axi_awburst         (axi0_AWBURST  ), 
    .s_axi_awlock          (axi0_AWLOCK   ), 
    .s_axi_awcache         (axi0_AWCACHE  ), 
    .s_axi_awprot          (axi0_AWPROT   ), 
    .s_axi_awvalid         (axi0_AWVALID  ), 
    .s_axi_awready         (axi0_AWREADY  ), 
    .s_axi_wdata           (axi0_WDATA    ), 
    .s_axi_wstrb           (axi0_WSTRB    ), 
    .s_axi_wlast           (axi0_WLAST    ), 
    .s_axi_wvalid          (axi0_WVALID   ), 
    .s_axi_wready          (axi0_WREADY   ), 
    .s_axi_bid             (axi0_BID      ),
    .s_axi_bresp           (axi0_BRESP    ), 
    .s_axi_bvalid          (axi0_BVALID   ), 
    .s_axi_bready          (axi0_BREADY   ),
    .s_axi_arid            (0     ),
    .s_axi_araddr          (axi0_ARADDR   ), 
    .s_axi_arlen           (axi0_ARLEN    ), 
    .s_axi_arsize          (axi0_ARSIZE   ), 
    .s_axi_arburst         (axi0_ARBURST  ), 
    .s_axi_arlock          (axi0_ARLOCK   ), 
    .s_axi_arcache         (axi0_ARCACHE  ), 
    .s_axi_arprot          (axi0_ARPROT   ), 
    .s_axi_arvalid         (axi0_ARVALID  ), 
    .s_axi_arready         (axi0_ARREADY  ),
    .s_axi_rid             (axi0_RID      ),
    .s_axi_rdata           (axi0_RDATA    ), 
    .s_axi_rresp           (axi0_RRESP    ), 
    .s_axi_rlast           (axi0_RLAST    ), 
    .s_axi_rvalid          (axi0_RVALID   ), 
    .s_axi_rready          (axi0_RREADY   )
);






endmodule

