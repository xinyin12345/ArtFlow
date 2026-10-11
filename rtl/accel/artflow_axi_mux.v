// Video wins at burst boundaries. Read/write ownership is independent.
module artflow_axi_mux(
    input clk,rst_n,
    input [31:0] v_awaddr,
    input [7:0] v_awlen,
    input v_awvalid,
    output v_awready,
    input [127:0] v_wdata,
    input [15:0] v_wstrb,
    input v_wvalid,
    input v_wlast,
    output v_wready,
    output v_bvalid,
    output [1:0] v_bresp,
    input v_bready,
    input [31:0] v_araddr,
    input [7:0] v_arlen,
    input v_arvalid,
    output v_arready,
    output [127:0] v_rdata,
    output v_rvalid,
    output [1:0] v_rresp,
    output v_rlast,
    input v_rready,
    input [31:0] a_awaddr,
    input [7:0] a_awlen,
    input a_awvalid,
    output a_awready,
    input [127:0] a_wdata,
    input [15:0] a_wstrb,
    input a_wvalid,
    input a_wlast,
    output a_wready,
    output a_bvalid,
    output [1:0] a_bresp,
    input a_bready,
    input [31:0] a_araddr,
    input [7:0] a_arlen,
    input a_arvalid,
    output a_arready,
    output [127:0] a_rdata,
    output a_rvalid,
    output [1:0] a_rresp,
    output a_rlast,
    input a_rready,
    output [31:0] awaddr,
    output [7:0] awlen,
    output awvalid,
    input awready,
    output [127:0] wdata,
    output [15:0] wstrb,
    output wvalid,
    output wlast,
    input wready,
    input bvalid,
    input [1:0] bresp,
    output bready,
    output [31:0] araddr,
    output [7:0] arlen,
    output arvalid,
    input arready,
    input [127:0] rdata,
    input rvalid,
    input [1:0] rresp,
    input rlast,
    output rready
);
reg [1:0] ws,rs; reg wo,ro;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin ws<=0;rs<=0;wo<=0;ro<=0;end
 else begin
 case(ws)
 0:if(v_awvalid || a_awvalid) begin wo<=!v_awvalid;ws<=1;end
 1:if(awready && awvalid) ws<=2;
 2:if(bvalid && bready) ws<=0;
 endcase
 case(rs)
 0:if(v_arvalid || a_arvalid) begin ro<=!v_arvalid;rs<=1;end
 1:if(arready && arvalid) rs<=2;
 2:if(rvalid && rready && rlast) rs<=0;
 endcase
 end
end
assign awaddr=(wo ? a_awaddr : v_awaddr);
assign awlen=(wo ? a_awlen : v_awlen);
assign awvalid=ws==1 && (wo ? a_awvalid : v_awvalid);
assign v_awready=ws==1 && !wo && awready;
assign a_awready=ws==1 && wo && awready;
assign wdata=(wo ? a_wdata : v_wdata);
assign wstrb=(wo ? a_wstrb : v_wstrb);
assign wvalid=ws==2 && (wo ? a_wvalid : v_wvalid);
assign wlast=(wo ? a_wlast : v_wlast);
assign v_wready=ws==2 && !wo && wready;
assign a_wready=ws==2 && wo && wready;
assign v_bvalid=ws==2 && !wo && bvalid;
assign a_bvalid=ws==2 && wo && bvalid;
assign v_bresp=bresp;
assign a_bresp=bresp;
assign bready=ws==2 && (wo ? a_bready : v_bready);
assign araddr=(ro ? a_araddr : v_araddr);
assign arlen=(ro ? a_arlen : v_arlen);
assign arvalid=rs==1 && (ro ? a_arvalid : v_arvalid);
assign v_arready=rs==1 && !ro && arready;
assign a_arready=rs==1 && ro && arready;
assign v_rdata=rdata;
assign a_rdata=rdata;
assign v_rvalid=rs==2 && !ro && rvalid;
assign a_rvalid=rs==2 && ro && rvalid;
assign v_rresp=rresp;
assign a_rresp=rresp;
assign v_rlast=rlast;
assign a_rlast=rlast;
assign rready=rs==2 && (ro ? a_rready : v_rready);
endmodule
