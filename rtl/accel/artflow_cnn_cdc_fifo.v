// Small register FIFO with Gray pointers and a registered elastic read port.
// Storage deliberately has an asynchronous read: these shallow queues use FFs,
// preserving the scarce block RAM for CNN weights/lines. Data stays in its slot
// until the receiving clock has captured it; only registered Gray pointers cross.
module artflow_cnn_cdc_fifo #(parameter WIDTH=8, AW=3)(
 input wclk,wrst_n,input [WIDTH-1:0] wdata,input wvalid,output wready,
 input rclk,rrst_n,output reg [WIDTH-1:0] rdata,output reg rvalid,input rready
);
(* syn_ramstyle="registers" *) reg [WIDTH-1:0] storage[0:(1<<AW)-1];
reg [AW:0] wbin,wgray,rbin,rgray;
(* async_reg="true" *) reg [AW:0] rgray_meta,rgray_sync,wgray_meta,wgray_sync;
wire full=wgray=={~rgray_sync[AW:AW-1],rgray_sync[AW-2:0]};
wire empty=rgray==wgray_sync;
wire [AW:0] wnext=wbin+1'b1,rnext=rbin+1'b1;
assign wready=wrst_n && !full;
always @(posedge wclk) if(wvalid && wready) storage[wbin[AW-1:0]]<=wdata;
always @(posedge wclk or negedge wrst_n) begin
 if(!wrst_n) begin wbin<=0;wgray<=0;rgray_meta<=0;rgray_sync<=0;end
 else begin
  rgray_meta<=rgray;rgray_sync<=rgray_meta;
  if(wvalid && wready) begin wbin<=wnext;wgray<=(wnext>>1)^wnext;end
 end
end
always @(posedge rclk or negedge rrst_n) begin
 if(!rrst_n) begin rbin<=0;rgray<=0;wgray_meta<=0;wgray_sync<=0;rvalid<=0;end
 else begin
  wgray_meta<=wgray;wgray_sync<=wgray_meta;
  if(!rvalid || rready) begin
   rvalid<=!empty;
   if(!empty) begin rbin<=rnext;rgray<=(rnext>>1)^rnext;end
  end
 end
end
// No reset on the payload; validity protects uninitialized contents.
always @(posedge rclk) if((!rvalid || rready) && !empty) rdata<=storage[rbin[AW-1:0]];
// synthesis translate_off
initial if(AW<2) $fatal(1,"CDC FIFO requires AW >= 2");
// synthesis translate_on
endmodule
