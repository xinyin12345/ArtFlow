
module ddr_wr_buffer#(
    parameter AXI_DATA_WIDTH = 512, //!AXI接口位宽
    parameter AXI_ADDR_WIDTH = 33,  //!AXI地址位宽
    parameter WR_FIFO_DEPTH	= 1024, //!Write fifo depth   
    parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH/8,//!总共的字节数量，= AXI_DATA_WIDTH/8
    parameter BURST_LEN       = 8'd15
    
    
    )(
        
input 								        axi_clk,
input 								        rst_n,
input								        wr_start, // pulse signal 

input		[AXI_ADDR_WIDTH-1:0]	        start_addr,
input		[24:0]							total_burst_len,
input wire                                  bank_sw_ack	,
output   wire                                 bank_sw 		  ,
output		[7:0] test_cnt ,
input                                       wr_fifo_rst_p,
input										wr_fifo_wrclk,
input										wr_fifo_wren,
output										wr_fifo_wrfull,
input	 [AXI_DATA_WIDTH-1:0]		        wr_fifo_wrdata, 

output 	[5:0] 								awid,
output  [AXI_ADDR_WIDTH-1:0] 	            awaddr,
output  [8-1:0] 				awlen,
output  [2:0] 					            awsize,
output  [1:0] 								awburst,

output  									awlock,
output  reg 								awvalid = 'd0,
output  									awcobuf,
output  									awapcmd,
output  									awallstrb,
output  									awqos,
output  [3:0] 								awcache,
output [2:0]                                awprot,
input 										awready,


output  [AXI_DATA_WIDTH-1:0] 	            wdata,  
output  [AXI_STRB_WIDTH-1:0] 	            wstrb,
output  reg									wlast,
output  reg									wvalid,
input 										wready,
input [5:0] 								bid,
input 										bvalid,
output  									bready,

output [33:0] addr_width_test,

output [7:0] test_BURST_LEN
);
assign test_BURST_LEN = BURST_LEN;
//=================================================================================

assign addr_width_test = AXI_ADDR_WIDTH;
    localparam WR_ADDR_SHIFT_BITS = $clog2(AXI_STRB_WIDTH);
    localparam MAX_BURST_LEN = 4096/(AXI_DATA_WIDTH/8);
    localparam WR_USEDW_WITH = $clog2(WR_FIFO_DEPTH); //!内部数据
    localparam AXSIZE_WTH = $clog2(AXI_DATA_WIDTH/8);//,//!内部数据

    //=============================================================
    //reg define 
    //=============================================================   
    
    
    reg	[AXI_ADDR_WIDTH-1:0] 			                    ddr_wr_addr 	= 'd0;
    
    wire										 			burst_add_en ;
    reg	[8-1:0]							    ddr_awlen = 0;
    reg	    	[1:0]							                start_sync = 'd0;
    reg [24:0]	burst_len_r   = 'd0;
   
    reg														burst_last = 'd0;      
    reg	[8-1:0] 						                    last_burst_cnt = 'd0;
    reg [8-1:0]                                             first_burst_cnt = 'd0;
    reg                                                     sync_r1 = 1'b0;
    reg                                                     sync_r0 = 1'b0;
    reg                                                     sync_r2 = 1'b0;
    reg                                                     sync_r3 = 1'b0;
    reg [24:0]                                              align_burst_num = 'd0;
    reg [24:0]                                              burst_num = 'd0;
    reg [24:0]                                              total_burst_num = 'd0;
    reg [AXI_ADDR_WIDTH-1:0]                                start_addr_r = 'd0;
    //=============================================================
    //wire define 
    //============================================================= 
    wire   [ WR_USEDW_WITH:0] 		wr_fifo_rdusedw;
wire [AXI_DATA_WIDTH-1:0]		wr_fifo_rddata;
wire							wr_fifo_rdempty;  
wire							wr_fifo_rden;
wire 							pos_sync;
wire [AXI_ADDR_WIDTH-1:0]  		nx_ddr_wr_addr;
wire axi_wr_clk = axi_clk;
//=============================================================  
//RTL                                                     
//=============================================================  

DC_FIFO
# (
  	.FIFO_MODE  ( "Normal"    ), //"Normal"; //"ShowAhead"
    .DATA_WIDTH ( AXI_DATA_WIDTH ),
    .FIFO_DEPTH ( WR_FIFO_DEPTH   )
  ) u_wr_fifo(   
  //System Signal
  /*i*/.Reset   (wr_fifo_rst_p	    ), 
  /*i*/.WrClk   (wr_fifo_wrclk		), 
  /*i*/.WrEn    (wr_fifo_wren		), 
  /*o*/.WrDNum  (	), 
  /*o*/.WrFull  (wr_fifo_wrfull 	), 
  /*i*/.WrData  (wr_fifo_wrdata 	), 
  /*i*/.RdClk   (axi_clk			), 
  /*i*/.RdEn    (wr_fifo_rden		), 
  /*o*/.RdDNum  (wr_fifo_rdusedw	), 
  /*o*/.RdEmpty (wr_fifo_rdempty	), 
  /*o*/.RdData  (wr_fifo_rddata		)  
);


always @( posedge axi_clk or negedge rst_n )
begin
    if( !rst_n )		start_sync <= 'd0;
    else 			start_sync <= {start_sync[0],wr_start};
end

assign pos_sync = start_sync[1:0] == 2'b01;
//each frame before have enogh time
always @( posedge axi_clk or negedge rst_n )
begin
	if( !rst_n ) begin
		sync_r0 <= 1'b0;
		sync_r1 <= 1'b0;
		sync_r2 <= 1'b0;
        sync_r3 <= 1'b0;
	end else begin 
		sync_r0 <= pos_sync;
		sync_r1 <= sync_r0;
		sync_r2 <= sync_r1;
        sync_r3 <= sync_r2;
	end 
end

always @( posedge axi_clk or negedge rst_n )
begin
	if( !rst_n ) begin
		burst_len_r   <= total_burst_len;//end_address - start_address
        start_addr_r <= start_addr;
	end else begin
		burst_len_r   <= pos_sync ? total_burst_len : burst_len_r ;
        start_addr_r <= pos_sync ? start_addr:start_addr_r;
	end
end


  
wire [12-WR_ADDR_SHIFT_BITS:0]     first_4k_burst_len = {1'b0,~start_addr_r[11:WR_ADDR_SHIFT_BITS]} + 1'b1;
wire [31:0]     last_4k_burst_len  = burst_len_r - first_4k_burst_len;


generate
    if( BURST_LEN == 8'd1) begin : b1
        always @( posedge axi_clk )
        begin
            first_burst_cnt <= |first_4k_burst_len[0]  ? {7'd0,first_4k_burst_len[0]}-'d1  :BURST_LEN;
            last_burst_cnt <= |last_4k_burst_len[0]  ? {7'd0,last_4k_burst_len[0]}-1  :BURST_LEN;
            burst_num <= align_burst_num[24:1] + 2 ;
        end 
    end else if( BURST_LEN == 8'd3 ) begin : b3
        always @( posedge axi_clk )
        begin
            first_burst_cnt <= |first_4k_burst_len[1:0]? {6'd0,first_4k_burst_len[1:0]}-'d1:BURST_LEN;
            last_burst_cnt <= |last_4k_burst_len[1:0]? {6'd0,last_4k_burst_len[1:0]}-1:BURST_LEN;
            burst_num <= align_burst_num[24:2] + 2 ;
        end 
    end else if( BURST_LEN == 8'd7) begin : b7
        always @( posedge axi_clk )
        begin
            first_burst_cnt <= |first_4k_burst_len[2:0]? {5'd0,first_4k_burst_len[2:0]}-'d1:BURST_LEN;
            last_burst_cnt <= |last_4k_burst_len[2:0]? {5'd0,last_4k_burst_len[2:0]}-1:BURST_LEN;
            burst_num <= align_burst_num[24:3] + 2 ;
        end 
    end else if( BURST_LEN == 8'd15) begin : b15
        always @( posedge axi_clk )
        begin
            first_burst_cnt <= |first_4k_burst_len[3:0]? {4'd0,first_4k_burst_len[3:0]}-'d1:BURST_LEN;
            last_burst_cnt <= |last_4k_burst_len[3:0]? {4'd0,last_4k_burst_len[3:0]}-1:BURST_LEN;
            burst_num <= align_burst_num[24:4] + 2 ;
        end 
    end else if( BURST_LEN == 8'd31) begin : b31
        always @( posedge axi_clk )
        begin
            first_burst_cnt <= |first_4k_burst_len[4:0]? {3'd0,first_4k_burst_len[4:0]}-'d1:BURST_LEN;
            last_burst_cnt <= |last_4k_burst_len[4:0]? {3'd0,last_4k_burst_len[4:0]}-1:BURST_LEN;
            burst_num <= align_burst_num[24:5] + 2 ;
        end 
    end else if( BURST_LEN == 8'd63) begin : b63
        always @( posedge axi_clk )
        begin
            first_burst_cnt <= |first_4k_burst_len[5:0]? {2'd0,first_4k_burst_len[5:0]}-'d1:BURST_LEN;
            last_burst_cnt <= |last_4k_burst_len[5:0]? {2'd0,last_4k_burst_len[5:0]}-1:BURST_LEN;
            burst_num <= align_burst_num[24:6] + 2 ;
        end 
    end else if( BURST_LEN == 8'd127) begin : b127
        always @( posedge axi_clk )
        begin
            first_burst_cnt <= |first_4k_burst_len[6:0]?{1'd0,first_4k_burst_len[6:0]}-1:BURST_LEN;
            last_burst_cnt <= |last_4k_burst_len[6:0]? {1'd0,last_4k_burst_len[6:0]}-1:BURST_LEN;
            burst_num <= align_burst_num[24:7] + 2 ;
        end 
    end else if( BURST_LEN == 8'd255) begin : b255
        always @( posedge axi_clk )
        begin
            first_burst_cnt <= |first_4k_burst_len[7:0]?first_4k_burst_len[7:0]-1:BURST_LEN;
            last_burst_cnt <= |last_4k_burst_len[7:0]? last_4k_burst_len[7:0]-1:BURST_LEN;
            burst_num <= align_burst_num[24:8] + 2 ;
        end 
    end else begin :b127_2
        always @( posedge axi_clk ) 
        begin
            first_burst_cnt <= |first_4k_burst_len[6:0]?{1'd0,first_4k_burst_len[6:0]}-1:BURST_LEN;
            last_burst_cnt <= |last_4k_burst_len[6:0]? {1'd0,last_4k_burst_len[6:0]}-1:BURST_LEN;
            burst_num <= align_burst_num[24:7] + 2 ;
        end 
    end 
endgenerate


always @( posedge axi_clk or negedge rst_n   )
begin 
    if( !rst_n ) begin
        align_burst_num <= 'd0;
    end else begin //sync_r1;
	    align_burst_num <= burst_len_r - first_burst_cnt - last_burst_cnt -'d2 ;
    end 
end

//=======================================================================================
//address process
reg addr_add_en = 'd0;
reg addr_add_last = 'd0;
reg [31:0] addr_cnt_num = 'd0;
always @(posedge axi_clk or negedge rst_n) 
begin
	if (!rst_n) 						                        ddr_wr_addr <= start_addr_r;//start_addr;
	else if(sync_r2)				                            ddr_wr_addr <= start_addr_r;//start_addr;//( pos_sync )
	else if( addr_add_en ) 				                        ddr_wr_addr <= nx_ddr_wr_addr;
end      
assign nx_ddr_wr_addr =  ddr_wr_addr + {(ddr_awlen+1) ,{WR_ADDR_SHIFT_BITS{1'b0}}};  
always @( posedge axi_clk or negedge rst_n )
begin
 	if( !rst_n )  							                    addr_cnt_num <= 'd0;
 	else if(sync_r2)					                        addr_cnt_num <= 'd0;//( pos_sync )
    // else if( addr_add_en & addr_add_last)                       addr_cnt_num <= 'd0;
 	else if( addr_add_en )					                    addr_cnt_num <= addr_cnt_num + 1'b1;
end 
always @( posedge axi_clk or negedge rst_n )
begin
	if( !rst_n )										        addr_add_last <= 1'b0;
	else if(sync_r2)						                    addr_add_last <= 1'b0;	//( pos_sync )	
	else if(addr_add_en && burst_num == addr_cnt_num+'d2  ) 	addr_add_last <= 1'b1;
    else if(addr_add_en && burst_num == addr_cnt_num+'d1  )     addr_add_last <= 1'b0;
end 

always @( posedge axi_clk or negedge rst_n )
begin
    if( !rst_n )                                                addr_add_en <= 1'b0;
    else if( awvalid & awready )                                addr_add_en <= 1'b1;
    else                                                        addr_add_en <= 1'b0;
end     


//=============================================================================================

//burst process
always @( posedge axi_clk or negedge rst_n )
begin
 	if( !rst_n )  							total_burst_num <= 'd0;
 	else if(sync_r2)					    total_burst_num <= 'd0;//( pos_sync )
    // else if( burst_add_en & burst_last)     total_burst_num <= 'd0;
 	else if( burst_add_en )					total_burst_num <= total_burst_num + 1'b1;
end 
always @( posedge axi_clk or negedge rst_n  )
begin
    if( !rst_n ) 								                ddr_awlen 	<= first_burst_cnt;//cfg_alen;
    else if( sync_r2 )						                    ddr_awlen 	<= first_burst_cnt;	 
    else if(burst_add_en && burst_num == total_burst_num+2)		ddr_awlen	<= last_burst_cnt;
    else if( burst_add_en )						                ddr_awlen 	<= BURST_LEN;//cfg_alen_r;	
end


always @( posedge axi_clk or negedge rst_n )
begin
	if( !rst_n )										            burst_last <= 1'b0;
	else if(sync_r2)						                    burst_last <= 1'b0;	//( pos_sync )	
	else if(burst_add_en && burst_num == total_burst_num+'d2  ) burst_last <= 1'b1;
    else if(burst_add_en && burst_num == total_burst_num+'d1 )  burst_last <= 1'b0;
end 
assign bank_sw = burst_last;


//======================================================================================================
reg [1:0] state = 2'd0;
reg wr_req = 0;
always @( posedge axi_clk or negedge rst_n )
begin
    if( !rst_n )
        wr_req <= 1'b0;
    else if( wr_fifo_rdusedw > ddr_awlen )
        wr_req <= 1'b1;
    else 
        wr_req <= 1'b0;
end


always @( posedge axi_clk  or negedge rst_n)//or negedge rst_n
begin
    if( !rst_n ) begin
        awvalid <= 1'b0;
        wvalid  <= 1'b0;
        state   <= 2'd0;
    end else if( sync_r0 ) begin
        awvalid <= 1'b0;
        wvalid  <= 1'b0;
        state   <= 2'd0;
    end else begin
        case(state )    
        2'd0 : begin
            state <= sync_r2 ? 2'd1:2'd0;
            awvalid <= 1'b0;
            wvalid  <= 1'b0;
        end
        2'd1 : begin
            if( wr_req ) begin
                state   <= 2'd2;
                awvalid <= 1'b1;
            end else begin 
                awvalid <= 1'b0;
                state   <= 2'd1;
            end 
            wvalid <= 1'b0;   
        end
        2'd2 : begin
            if( awready) begin
                state   <= 2'd3;
                awvalid <= 1'b0;
                wvalid  <= 1'b1;
            end else begin 
                state   <= 2'd2;
                awvalid <= 1'b1;
                wvalid  <= 1'b0;
            end 
        end
        2'd3 : begin
            if( wvalid & wlast & wready ) begin
                wvalid  <= 1'b0;
                state   <= 2'd1;
            end else begin 
                state   <= 2'd3;
                wvalid  <= 1'b1;
            end 
            awvalid     <= 1'b0;
        end
        default : begin 
            state   <= state;
            awvalid <= 1'b0;
            wvalid  <= 1'b0;
        end 
    
        endcase
    end
end
//======================================================================================================

reg [8:0] write_cnt = 'd0;
reg burst_end_r = 'd0;
always @(posedge axi_clk or negedge rst_n) 
begin
	if (!rst_n) 												burst_end_r <= 1'b0;
	else 							 							burst_end_r <= burst_add_en;
end

always @( posedge axi_clk or negedge rst_n ) 
begin
		if( !rst_n ) 											wlast <= 1'b0;
		else if(awlen == 0 )   begin   			
				if( sync_r3)
						wlast <= 1'b1;
				if( burst_end_r )
						wlast <= 1'b1;	
				else if(wready)			
						wlast <= 1'b0;						
		end else if( write_cnt+1 == awlen && wready && wvalid)	wlast <= 1'b1;
		else if( write_cnt == awlen && wready && wvalid) 		wlast <= 1'b0;
end
always @(posedge axi_clk or negedge rst_n) 
begin
	if (!rst_n) 												write_cnt <= 0;
	else if(sync_r3)											write_cnt <= 0;
	else if( wready && wvalid && wlast) 						write_cnt <= 0;
	else if (wready && wvalid )									write_cnt <= write_cnt + 'd1;
end  

//============================================================================================================

assign burst_add_en = wlast & wvalid & wready;       
assign wr_fifo_rden = (awvalid & awready )||(wready && wvalid && !wlast );//write_cnt != 0);//(start_sync == 2'b01 
assign awaddr			= ddr_wr_addr;
assign awlen			= ddr_awlen;

assign wdata			= wr_fifo_rddata;
assign awlock 		= 2'b00;  
assign awapcmd 		= 1'b0;  
assign awcobuf 		= 1'b0;  
 
assign awallstrb 	= 1'b0;
assign awburst 		= 2'b01;
assign awsize  		= AXSIZE_WTH;
assign awid 		= 8'd0;
assign wstrb 		= {AXI_STRB_WIDTH{1'b1}};  
assign awqos        = 1'b0;
assign bready       = 1'b1;
assign awprot       = 3'd2;
assign awcache 		= 4'd3; 
endmodule 
