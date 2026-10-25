// Transaction generator only. Actual wrapper, CDC FIFOs and lease logic remain real.
// No claim about CNN numerics, clock throughput or style values.
module artflow_cnn_dma #(parameter WIDTH=960,HEIGHT=540,BURST=64)(
 input clk,rst_n,start,input [31:0] src_addr,dst_addr,
 input param_bank,cfg_valid,cfg_bank,input [1:0] cfg_kind,input [9:0] cfg_addr,input [575:0] cfg_data,
 output wire busy,output reg done,failed,output reg [31:0] cycles,output reg source_consumed,
 output wire [31:0] araddr,output wire [7:0] arlen,output wire arvalid,input arready,
 input [127:0] rdata,input rvalid,rlast,input [1:0] rresp,output wire rready,
 output wire [31:0] awaddr,output wire [7:0] awlen,output wire awvalid,input awready,
 output wire [127:0] wdata,output wire [15:0] wstrb,output wire wvalid,wlast,input wready,
 input bvalid,input [1:0] bresp,output wire bready);
localparam N=WIDTH*HEIGHT/4;reg [127:0] frame[0:N-1];integer state=0,idx=0,delay_count=0,offset=0;wire [8:0] beats=N-offset>16?16:N-offset;reg [31:0] src,dst;
assign busy=state!=0;assign araddr=src+offset*16;assign arlen=beats-1;assign arvalid=state==1;assign rready=state==2;
assign awaddr=dst+offset*16;assign awlen=beats-1;assign awvalid=state==4;assign wdata=frame[offset+idx];assign wstrb='1;assign wvalid=state==5;assign wlast=idx==beats-1;assign bready=state==6;
always @(posedge clk)begin
 done<=0;source_consumed<=0;
 if(!rst_n)begin state<=0;idx<=0;failed<=0;cycles<=0;end
 else begin

 if(busy)cycles<=cycles+1;
 case(state)
 0:if(start)begin src<=src_addr;dst<=dst_addr;state<=1;idx<=0;offset<=0;cycles<=0;failed<=0;end
 1:if(arready)state<=2;
 2:if(rvalid)begin for(integer k=0;k<4;k++)frame[offset+idx][k*32+:32]<={8'h01,~rdata[k*32+:24]};idx<=idx+1;if(rlast)begin idx<=0;if(offset+beats==N)begin state<=3;delay_count<=100;source_consumed<=1;end else begin offset<=offset+beats;state<=1;end end end
 3:if(delay_count==0)begin idx<=0;offset<=0;state<=4;end else delay_count<=delay_count-1;
 4:if(awready)state<=5;
 5:if(wready)begin if(idx==beats-1)state<=6;else idx<=idx+1;end
 6:if(bvalid)begin if(offset+beats==N)begin failed<=bresp!=0;done<=1;state<=0;end else begin offset<=offset+beats;idx<=0;state<=4;end end
 endcase
 end
end
endmodule
