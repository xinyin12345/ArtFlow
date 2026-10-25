// Native simple-dual-port RAM payload with unchanged Gray pointers and elastic read timing.
// Experimental storage-only candidate. Not yet integrated into any system project.
module artflow_cnn_return_ram_fifo #(parameter WIDTH=8, AW=3)(
 input wclk,wrst_n,input [WIDTH-1:0] wdata,input wvalid,output wready,
 input rclk,rrst_n,output [WIDTH-1:0] rdata,output reg rvalid,input rready,output r_idle,output w_idle
);
localparam SLICES=(WIDTH+19)/20;
wire [SLICES*20-1:0] padded_write={{(SLICES*20-WIDTH){1'b0}},wdata};
wire [SLICES*20-1:0] ram_read;
assign rdata=ram_read[WIDTH-1:0];
reg [AW:0] wbin,wgray,rbin,rgray;
(* async_reg="true" *) reg [AW:0] rgray_meta,rgray_sync,wgray_meta,wgray_sync;
wire full=wgray=={~rgray_sync[AW:AW-1],rgray_sync[AW-2:0]};
wire empty=rgray==wgray_sync;
wire [AW:0] wnext=wbin+1'b1,rnext=rbin+1'b1;
assign r_idle=empty && !rvalid;
assign w_idle=wgray==rgray_sync;
assign wready=wrst_n && !full;
// Same existing registered read edge, now supplied by native RAM output.
// No reset of payload. Gray-pointer ownership excludes live read/write collision.
genvar slice;
generate for(slice=0;slice<SLICES;slice=slice+1)begin:storage_ram
 EFX_RAM10 #(.READ_WIDTH(20),.WRITE_WIDTH(20),.OUTPUT_REG(1'b0),.WRITE_MODE("READ_UNKNOWN")) memory(
  .WCLK(wclk),.WCLKE(1'b1),.WADDREN(1'b1),.WE({2{wvalid && wready}}),
  .WDATA(padded_write[slice*20+:20]),.WADDR({{(9-AW){1'b0}},wbin[AW-1:0]}),
  .RCLK(rclk),.RE((!rvalid || rready) && !empty),.RST(1'b0),.RADDREN(1'b1),
  .RADDR({{(9-AW){1'b0}},rbin[AW-1:0]}),.RDATA(ram_read[slice*20+:20]));
end endgenerate
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

// synthesis translate_off
initial if(AW<2 || AW>9 || WIDTH<1) $fatal(1,"RAM CDC FIFO requires 2 <= AW <= 9 and WIDTH >= 1");
// synthesis translate_on
endmodule
