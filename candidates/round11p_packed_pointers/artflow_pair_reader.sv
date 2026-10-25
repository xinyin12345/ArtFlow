// AXI128 input -> serialized 32-bit local memory; no extra clock domain.
// AXI R backpressure permits four writes per accepted beat. This reduces
// physical port-width fragmentation from seven RAM10s to two RAM10s.
module artflow_pair_reader #(parameter WIDTH=960,HEIGHT=540,BURST=16,FIXED_BURST=0,PACKED_RGB25=0)(
 input logic clk,rst_n,start,cancel,input logic [31:0] original_base,style_base,
 output wire busy,output logic done,failed,
 output wire [31:0] araddr,output wire [7:0] arlen,output wire arvalid,input logic arready,
 input logic [127:0] rdata,input logic rvalid,rlast,input logic [1:0] rresp,output wire rready,
 output wire valid,input logic ready,output wire [31:0] original_pixel,style_pixel,
 output logic [10:0] x,y);
localparam TOTAL=WIDTH*HEIGHT/4;
localparam IDLE=0,PREP=1,IAR=2,IRD=3,SAR=4,SRD=5,LOAD=6,EMIT=7,FIN=8,LOAD_STYLE=9,LOAD_DONE=10,STORE=11;
localparam OFFSET_W=(TOTAL<2)?1:$clog2(TOTAL+1);
logic [3:0] state,next_state;logic [31:0] ib,sb;logic [OFFSET_W-1:0] offset;
// Counter ranges include received==BURST for malformed/late RLAST drain.
localparam RECEIVE_W=$clog2(BURST+1),PIXEL_W=$clog2(4*BURST);
logic [8:0] dynamic_beats;logic [RECEIVE_W-1:0] received;logic [PIXEL_W-1:0] pixel_index;
// Opt-in aligned whole-frame mode removes the unreachable partial-burst cone.
wire [8:0] beats=FIXED_BURST ? BURST[8:0] : dynamic_beats;
wire bad_alignment=(original_base[3:0]!=0 || style_base[3:0]!=0) ||
 (FIXED_BURST && ((original_base & (BURST*16-1))!=0 || (style_base & (BURST*16-1))!=0));
logic [1:0] lane;logic aborted,saving_style,saved_last;
(* syn_ramstyle="block_ram" *) logic [31:0] storage[0:8*BURST-1];
logic [127:0] incoming;logic [31:0] iq,sq,mq;
(* syn_preserve="true" *) logic memory_store,read_original,capture_original,capture_style;
wire [11:0] read_index=read_original?pixel_index:4*BURST+pixel_index;
wire [11:0] write_index=(saving_style?4*BURST:0)+received*4+lane;
// Registered state decodes have exactly the same cycle as state. Each
// incoming word owns its control FFs; no new pipeline stage or clock domain.
(* syn_preserve="true" *) logic [3:0] store_local,receive_local;
// Local idle-phase initialization removes start from coordinate/offset muxes.
// Each decode matches IDLE in the same cycle; no new state or request latency.
(* syn_preserve="true" *) logic idle_init_x,idle_init_y,idle_init_offset;
always_ff @(posedge clk or negedge rst_n)
 if(!rst_n)begin idle_init_x<=1;idle_init_y<=1;idle_init_offset<=1;end
 else begin idle_init_x<=next_state==IDLE;idle_init_y<=next_state==IDLE;idle_init_offset<=next_state==IDLE;end
wire [OFFSET_W:0] offset_sum={1'b0,offset}+beats;
wire emit_advance=state==EMIT && !(aborted || cancel) && ready;
always_ff @(posedge clk or negedge rst_n)
 if(!rst_n)x<=0;
 else if(idle_init_x)x<=0;
 else if(emit_advance)begin if(x==WIDTH-1)x<=0;else x<=x+1;end
always_ff @(posedge clk or negedge rst_n)
 if(!rst_n)y<=0;
 else if(idle_init_y)y<=0;
 else if(emit_advance && x==WIDTH-1)y<=y+1;
always_ff @(posedge clk or negedge rst_n)
 if(!rst_n)offset<=0;
 else if(idle_init_offset)offset<=0;
 else if(emit_advance && pixel_index==beats*4-1)offset<=offset_sum[OFFSET_W-1:0];
wire accept_payload=rvalid && !(aborted || cancel || failed || rresp!=0 || received>=beats);
always_ff @(posedge clk or negedge rst_n)
 if(!rst_n)begin state<=IDLE;store_local<=0;receive_local<=0;memory_store<=0;read_original<=0;capture_original<=0;capture_style<=0;end
 else begin
  state<=next_state;
  store_local<={4{next_state==STORE}};
  receive_local<={4{next_state==IRD || next_state==SRD}};
  memory_store<=next_state==STORE;read_original<=next_state==LOAD;
  capture_original<=next_state==LOAD_STYLE;capture_style<=next_state==LOAD_DONE;
 end
// State sequencing is unchanged. Compute the next decodes before the same edge
// as state, rather than delaying a decoded enable by one cycle.
always_comb begin
 next_state=state;
 case(state)
 IDLE:if(start)next_state=bad_alignment?FIN:PREP;
 PREP:next_state=(aborted || cancel)?FIN:IAR;
 IAR:if(arready)next_state=IRD;
 SAR:if(arready)next_state=SRD;
 IRD,SRD:if(rvalid)begin
  if(aborted || cancel || failed || rresp!=0 || received>=beats)begin if(rlast)next_state=FIN;end
  else next_state=STORE;
 end
 STORE:if(lane==3)begin
  if(saved_last)begin
   if(aborted || cancel || failed || received!=beats-1)next_state=FIN;
   else next_state=saving_style?LOAD:SAR;
  end else next_state=saving_style?SRD:IRD;
 end
 LOAD:next_state=(aborted || cancel)?FIN:LOAD_STYLE;
 LOAD_STYLE:next_state=(aborted || cancel)?FIN:LOAD_DONE;
 LOAD_DONE:next_state=(aborted || cancel)?FIN:EMIT;
 EMIT:if(aborted || cancel)next_state=FIN;
 else if(ready)begin
  if(pixel_index==beats*4-1)next_state=(offset+beats==TOTAL)?FIN:PREP;
  else next_state=LOAD;
 end
 FIN:next_state=IDLE;
 default:next_state=IDLE;
 endcase
end
generate if(!PACKED_RGB25)begin:generic_storage
 for(genvar slice=0;slice<4;slice=slice+1)begin:incoming_slices
  always_ff @(posedge clk or negedge rst_n)
   if(!rst_n)incoming[slice*32+:32]<=0;
   else if(receive_local[slice] && accept_payload)incoming[slice*32+:32]<=rdata[slice*32+:32];
   else if(store_local[slice])begin
    if(slice==3)incoming[slice*32+:32]<=0;
    else incoming[slice*32+:32]<=incoming[(slice+1)*32+:32];
   end
 end
 always_ff @(posedge clk)begin
  mq<=storage[read_index];
  if(capture_original)iq<=mq;
  if(capture_style)sq<=mq;
  if(memory_store)storage[write_index]<=incoming[31:0];
 end
end else begin:packed_storage
 // Production XRGB carries exactly RGB24 + Gamma flag, with upper7 zero.
 // 4x25 bits are written as five pairs of ten-bit words, at acceptance and
 // the four existing STORE edges. The three LOAD edges fetch both streams.
 wire [99:0] packed_input={rdata[120:96],rdata[88:64],rdata[56:32],rdata[24:0]};
 logic [79:0] pending_bits;
 wire accept_word=rready && accept_payload;
 wire write_phase=accept_word || memory_store;
 wire [19:0] write_bits=accept_word?packed_input[19:0]:pending_bits[19:0];
 // Sparse stream banks remove cross-stream address addition: base0/base512.
 // Both addresses on a write differ only in bit0; no multiply-by10 cone.
 logic [6:0] write_pair;
 logic [7:0] read_word;
 wire writing_style=accept_word?(state==SRD):saving_style;
 wire load_phase=state==LOAD || state==LOAD_STYLE || state==LOAD_DONE;
 wire [9:0] address_a=write_phase?{writing_style,1'b0,write_pair,1'b0}:{2'b00,read_word};
 wire [9:0] address_b=write_phase?{writing_style,1'b0,write_pair,1'b1}:{2'b10,read_word};
 always_ff @(posedge clk or negedge rst_n)
  if(!rst_n)write_pair<=0;
  else if(state==PREP || (memory_store && lane==3 && saved_last && !saving_style))write_pair<=0;
  else if(write_phase)write_pair<=write_pair+1'b1;
 always_ff @(posedge clk or negedge rst_n)
  if(!rst_n)read_word<=0;
  else if(memory_store && lane==3 && saved_last && saving_style)read_word<=0;
  else if(state==LOAD || state==LOAD_STYLE || (emit_advance && pixel_index[0]))read_word<=read_word+1'b1;
 // Hold one parity selector per byte/flag and stream. Capture in existing LOAD,
 // before valid; preserve distinct local FFs so one select does not drive50 muxes.
 (* syn_preserve="true" *) logic [3:0] shift_original,shift_style;
 always_ff @(posedge clk or negedge rst_n)
  if(!rst_n)begin shift_original<=0;shift_style<=0;end
  else if(read_original)begin shift_original<={4{pixel_index[0]}};shift_style<={4{pixel_index[0]}};end
 wire [9:0] data_a,data_b;
 logic [9:0] first_a,first_b,second_a,second_b;
 wire [29:0] assembled_a={data_a,second_a,first_a},assembled_b={data_b,second_b,first_b};
 assign iq[31:25]=0;assign sq[31:25]=0;
 for(genvar byte_slice=0;byte_slice<3;byte_slice=byte_slice+1)begin:pixel_bytes
  assign iq[byte_slice*8+:8]=shift_original[byte_slice]?assembled_a[byte_slice*8+5+:8]:assembled_a[byte_slice*8+:8];
  assign sq[byte_slice*8+:8]=shift_style[byte_slice]?assembled_b[byte_slice*8+5+:8]:assembled_b[byte_slice*8+:8];
 end
 assign iq[24]=shift_original[3]?assembled_a[29]:assembled_a[24];
 assign sq[24]=shift_style[3]?assembled_b[29]:assembled_b[24];
 for(genvar slice=0;slice<4;slice=slice+1)begin:pending_slices
  always_ff @(posedge clk or negedge rst_n)
   if(!rst_n)pending_bits[slice*20+:20]<=0;
   else if(receive_local[slice] && accept_payload)pending_bits[slice*20+:20]<=packed_input[(slice+1)*20+:20];
   else if(store_local[slice])begin
    if(slice==3)pending_bits[slice*20+:20]<=0;
    else pending_bits[slice*20+:20]<=pending_bits[(slice+1)*20+:20];
   end
 end
 always_ff @(posedge clk)begin
  if(capture_original)begin first_a<=data_a;first_b<=data_b;end
  if(capture_style)begin second_a<=data_a;second_b<=data_b;end
 end
 EFX_DPRAM10 #(.READ_WIDTH_A(10),.WRITE_WIDTH_A(10),.READ_WIDTH_B(10),.WRITE_WIDTH_B(10),
  .OUTPUT_REG_A(1'b0),.OUTPUT_REG_B(1'b0)) pair_memory(
  .CLKA(clk),.CLKEA(rst_n && (write_phase || load_phase)),.WEA(rst_n && write_phase),.RSTA(!rst_n),.ADDRENA(1'b1),.WDATAA(write_bits[9:0]),.ADDRA(address_a),.RDATAA(data_a),
  .CLKB(clk),.CLKEB(rst_n && (write_phase || load_phase)),.WEB(rst_n && write_phase),.RSTB(!rst_n),.ADDRENB(1'b1),.WDATAB(write_bits[19:10]),.ADDRB(address_b),.RDATAB(data_b));
 // synthesis translate_off
 always @(posedge clk)if(rst_n)begin
  if(valid && {shift_original,shift_style}!={8{pixel_index[0]}})$fatal(1,"packed25 local parity lost valid-cycle identity");
  if(accept_word && {rdata[127:121],rdata[95:89],rdata[63:57],rdata[31:25]}!=0)$fatal(1,"packed25 input padding contract violated");
  if(write_phase && (write_pair>=80 || address_b!=address_a+1 || address_a[8] || address_b[8]))$fatal(1,"packed25 write address/collision");
  if(load_phase && (address_a>=160 || address_b<512 || address_b>=672))$fatal(1,"packed25 load address/collision");
 end
 // synthesis translate_on
 initial if(BURST!=16)$fatal(1,"packed25 implementation requires BURST16; use generic storage otherwise");
end endgenerate
// synthesis translate_off
always @(posedge clk)if(rst_n)begin
 if(received>BURST)$fatal(1,"received counter exceeded burst bound");
 if(emit_advance && pixel_index!=beats*4-1 && pixel_index+1>=4*BURST)$fatal(1,"pixel index would overflow narrowed range");
 if(FIXED_BURST && busy && offset%BURST!=0)$fatal(1,"fixed burst lost aligned offset");
 if(offset>TOTAL || (emit_advance && pixel_index==beats*4-1 && offset_sum>TOTAL))$fatal(1,"bounded offset exceeded frame");
 if(idle_init_x!=(state==IDLE) || idle_init_y!=(state==IDLE) || idle_init_offset!=(state==IDLE))$fatal(1,"idle initialization decode lost cycle alignment");
 if(store_local!={4{state==STORE}} || receive_local!={4{state==IRD || state==SRD}} ||
    memory_store!=(state==STORE) || read_original!=(state==LOAD) ||
    capture_original!=(state==LOAD_STYLE) || capture_style!=(state==LOAD_DONE))
  $fatal(1,"reader local decode lost cycle alignment");
end
// synthesis translate_on
integer wanted,ibound,sbound;
always_comb begin
 wanted=TOTAL-offset;
 ibound=(4096-((ib+(offset<<4))&4095))>>4;
 sbound=(4096-((sb+(offset<<4))&4095))>>4;
 if(wanted>BURST)wanted=BURST;if(wanted>ibound)wanted=ibound;if(wanted>sbound)wanted=sbound;
end
assign busy=state!=IDLE;assign arvalid=state==IAR || state==SAR;
assign araddr=(state==SAR?sb:ib)+(offset<<4);assign arlen=beats-1;
assign rready=state==IRD || state==SRD;
assign valid=state==EMIT && !aborted && !cancel;
assign original_pixel=iq;assign style_pixel=sq;
always_ff @(posedge clk or negedge rst_n)
 if(!rst_n)begin ib<=0;sb<=0;dynamic_beats<=0;received<=0;pixel_index<=0;lane<=0;done<=0;failed<=0;aborted<=0;saving_style<=0;saved_last<=0;end
 else begin
 done<=0;if(cancel && busy)aborted<=1;
 case(state)
 IDLE:if(start)begin
  ib<=original_base;sb<=style_base;failed<=0;aborted<=0;
  if(bad_alignment)failed<=1;
 end
 PREP:if(!(aborted || cancel))begin dynamic_beats<=wanted;received<=0;end
 IRD,SRD:if(rvalid)begin
  if(rresp!=0 || rlast!=(received==beats-1))failed<=1;
  if(aborted || cancel || failed || rresp!=0 || received>=beats)begin
   if(received<beats)received<=received+1;
  end else begin saving_style<=state==SRD;saved_last<=rlast;lane<=0;end
 end
 STORE:begin
  lane<=lane+1'b1;
  if(lane==3)begin
   if(received<beats)received<=received+1;
   if(saved_last)begin
    received<=0;
    if(!(aborted || cancel || failed || received!=beats-1) && saving_style)pixel_index<=0;
   end
  end
 end
 EMIT:if(!(aborted || cancel) && ready)begin
  if(pixel_index!=beats*4-1)pixel_index<=pixel_index+1;
 end
 FIN:done<=1;
 default:;
 endcase
 end
initial begin
 if(FIXED_BURST && ((BURST & (BURST-1))!=0 || TOTAL%BURST!=0))$fatal(1,"fixed burst requires power-of-two bursts dividing frame");
 if(WIDTH%4!=0 || WIDTH<4 || WIDTH>2048 || HEIGHT<1 || HEIGHT>2048 || BURST<1 || BURST>256)$fatal(1,"unsupported pair-reader parameters");
end
endmodule
