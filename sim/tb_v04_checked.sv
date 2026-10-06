// v04 end-to-end scoreboard: absolute frame IDs, strict black-tail semantics,
// publication/ownership checks and bounded recovery from protocol/camera faults.
`timescale 1ns/1ps
module tb_v04_checked;
parameter int DUAL_WINDOW=1;
parameter int STRESS=0, REV=0, VS_MODE=0, FAULT=0, MUTATION=0;
parameter int W=160,H=40,PHASE=0,GAP_PCT=25,NGOOD=6,MAXFRM=100;
parameter int VBLANK=20,LINE_BLANK=8,NOMINAL_FPS=0;
parameter int HFP=44,HSP=22,HBP=74,VFP=4,VSP=5,VBP=36;
parameter [15:0] GAIN_R=16'h118,GAIN_G=16'hff,GAIN_B=16'h15e;
parameter string PREFIX="small";
localparam int OW=W/2,OH=H/2,VARIANTS=8;
localparam [31:0] BANK=32'h00400000;
localparam real FRAME_NS=(OW+HFP+HSP+HBP)*(H+VFP+VSP+VBP)*13.468;
localparam real CAMERA_NS=1.0e9/(NOMINAL_FPS>0?NOMINAL_FPS:1);
reg pclk=0; always #10 pclk=~pclk;
reg aclk=0; always #5 aclk=~aclk;
reg hclk=0; always #3.367 hclk=~hclk;
reg vclk=0; always @(posedge hclk) vclk<=~vclk;
reg rst_n=0,prst_n=0,s_vs=0,s_hs=0,s_valid=0;
reg [39:0] s_raw=0;
wire o_de,o_hs,o_vs;
wire [7:0] o_r,o_g,o_b;
wire [5:0] awid,arid;
wire [31:0] awaddr,araddr;
wire [7:0] awlen,arlen;
wire [2:0] awsize,arsize,awprot,arprot;
wire [1:0] awburst,arburst,bresp,rresp;
wire [3:0] awcache,arcache;
wire awlock,arlock,awvalid,awready,arvalid,arready;
wire [127:0] wdata,rdata;
wire [15:0] wstrb;
wire wlast,wvalid,wready,rlast,rvalid,rready,bvalid,bready;
reg hold_aw=0,hold_w=0,hold_b=0,hold_ar=0,hold_r=0,inject_b=0,inject_r=0;
reg sensor_pause=0,truncate_once=0;
bit fault_window=0,fault_done=(STRESS==0 && FAULT==0);
int current_seq=0,in_frames=0,truncated=0,pauses=0,reset_events=0;
int ar_stall_cycles=0,b_error_seen=0,r_error_seen=0;
cam_fb_pipe #(.DUAL_WINDOW(DUAL_WINDOW),.AXI_DATA_WIDTH(128),.AXI_ADDR_WIDTH(32),.START_ADDR(0),.BANK_BYTES(BANK),
 .MAX_IN_HEIGHT(H),.MAX_IN_WIDTH(W),.MAX_OUT_WIDTH(OW)) dut (
 .cfg_bayer(PHASE[1:0]),.cfg_pix_rev(REV[0]),.cfg_gain_r(GAIN_R),.cfg_gain_g(GAIN_G),.cfg_gain_b(GAIN_B),
 .i_pclk(pclk),.i_pclk_rstn(prst_n),.i_vs(s_vs),.i_hs(s_hs),.i_valid(s_valid),.i_raw(s_raw),
 .H_FRONT_PORCH(HFP[12:0]),.H_SYNC(HSP[12:0]),.H_VALID(OW[12:0]),.H_BACK_PORCH(HBP[12:0]),
 .V_FRONT_PORCH(VFP[12:0]),.V_SYNC(VSP[12:0]),.V_VALID(H[12:0]),.V_BACK_PORCH(VBP[12:0]),
 .rst_n(rst_n),.o_clk(vclk),.o_hdmi_clk(hclk),.o_de(o_de),.o_hs(o_hs),.o_vs(o_vs),.o_r(o_r),.o_g(o_g),.o_b(o_b),
 .axi_clk(aclk),.awid(awid),.awaddr(awaddr),.awlen(awlen),.awsize(awsize),.awburst(awburst),
 .awcache(awcache),.awprot(awprot),.awlock(awlock),.awvalid(awvalid),.awready(awready),
 .arid(arid),.araddr(araddr),.arlen(arlen),.arsize(arsize),.arburst(arburst),
 .arcache(arcache),.arprot(arprot),.arlock(arlock),.arvalid(arvalid),.arready(arready),
 .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
 .rid(6'd0),.rdata(rdata),.rlast(rlast),.rvalid(rvalid),.rready(rready),.rresp(rresp),
 .bid(6'd0),.bvalid(bvalid),.bresp(bresp),.bready(bready));
axi_memory_checked #(.DW(128),.AW(32),.STALL_PCT(20),.RD_LAT(12)) u_mem (
 .clk(aclk),.rst_n(rst_n),.awaddr(awaddr),.awlen(awlen),.awsize(awsize),.awlock(awlock),.awburst(awburst),
 .awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
 .bvalid(bvalid),.bresp(bresp),.bready(bready),.araddr(araddr),.arlen(arlen),.arsize(arsize),.arlock(arlock),
 .arburst(arburst),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rlast(rlast),.rvalid(rvalid),.rready(rready),.rresp(rresp),
 .hold_aw(hold_aw),.hold_w(hold_w),.hold_b(hold_b),.hold_ar(hold_ar),.hold_r(hold_r),
 .inject_b_error(inject_b),.inject_r_error(inject_r));
reg [9:0] raw[0:W*H-1];
reg [23:0] exp_px[0:VARIANTS*OW*OH-1];
initial begin
 $readmemh({PREFIX,"_raw.hex"},raw);
 for(int v=0;v<VARIANTS;v++)
  $readmemh($sformatf("%s_exp_p%0d_f%0d.hex",PREFIX,PHASE,v),exp_px,v*OW*OH,(v+1)*OW*OH-1);
 foreach(raw[n]) if($isunknown(raw[n])) $fatal(1,"Invalid RAW vector %0d",n);
 foreach(exp_px[n]) if($isunknown(exp_px[n])) $fatal(1,"Invalid golden vector %0d",n);
end
function automatic [9:0] raw_pixel(int seq,int y,int x);
 int n,value;
 n=(y/2)*OW+x/2;
 value=(n<8)?64+((seq>>(4*n))&15)*48:(raw[y*W+x]^((seq%VARIANTS)*128));
 return value[9:0];
endfunction
function automatic [23:0] expected_pixel(int seq,int n);
 int value,r,g,b;
 if(n>=8) return exp_px[(seq%VARIANTS)*OW*OH+n];
 value=64+((seq>>(4*n))&15)*48;
 r=(value*int'(GAIN_R))>>10; if(r>255)r=255;
 g=(value*int'(GAIN_G))>>10; if(g>255)g=255;
 b=(value*int'(GAIN_B))>>10; if(b>255)b=255;
 return {r[7:0],g[7:0],b[7:0]};
endfunction
realtime previous_sensor_start=0;
initial begin : sensor
 int x;
 bit cut;
 wait(prst_n);
 repeat(20) @(negedge pclk);
 forever begin
  while(!prst_n || sensor_pause) begin
   s_vs=0;s_hs=0;s_valid=0; @(negedge pclk);
  end
  if(NOMINAL_FPS>0 && previous_sensor_start>0 &&
     (($realtime-previous_sensor_start)<CAMERA_NS*0.97 ||
      ($realtime-previous_sensor_start)>CAMERA_NS*1.03))
   $fatal(1,"Camera frame period is not nominal %0d fps",NOMINAL_FPS);
  previous_sensor_start=$realtime;
  s_vs=1; cut=0;
  repeat(10) @(negedge pclk);
  if(VS_MODE) begin s_vs=0;repeat(3)@(negedge pclk);end
  for(int y=0;y<H;y++) begin
   if(!prst_n) begin cut=1;break;end
   // The admission scheduler may skip a sensor frame. Inject only into a
   // granted capture, otherwise no rejected-frame event can be expected.
   if(truncate_once && y==H/2 && dut.u_store.capturing) begin truncate_once=0;truncated++;cut=1;break;end
   s_hs=1;x=0;
   while(x<W && prst_n) begin
    @(negedge pclk);
    if($urandom_range(99)>=GAP_PCT) begin
     s_valid=1;
     for(int k=0;k<4;k++) s_raw[(REV?3-k:k)*10+:10]=raw_pixel(current_seq,y,x+k);
     x+=4;
    end else begin s_valid=0;s_raw={$urandom,$urandom};end
   end
   @(negedge pclk);s_valid=0;s_hs=0;
   repeat(LINE_BLANK)@(negedge pclk);
  end
  repeat(4)@(negedge pclk);
  s_vs=0;s_hs=0;s_valid=0;in_frames++;current_seq++;
  repeat(VBLANK)@(negedge pclk);
 end
end
int bank_seq[3]='{-1,-1,-1};
int epoch_seq[int];
int capture_seq=-1,published_seen=0,latest_seq=-1;
int write_outstanding=0,read_outstanding=0;
bit read_active_d=0,capture_d=0;
bit [2:0] banks_checked=0;
int reject_seq[int];
always @(negedge pclk) begin
 if(!rst_n) begin capture_d=0;capture_seq=-1;end
 else begin
  if(capture_d!=dut.u_store.capture_begin)capture_seq=current_seq;
  capture_d=dut.u_store.capture_begin;
 end
end
int rejected_seen=0;
always @(posedge aclk) begin
 if(!rst_n) begin
  write_outstanding=0;read_outstanding=0;read_active_d=0;published_seen=0;rejected_seen=0;
  bank_seq='{-1,-1,-1};epoch_seq.delete();reject_seq.delete();latest_seq=-1;banks_checked=0;
 end else begin
  if(dut.u_store.ws==1 && dut.u_store.capture_finished &&
     (dut.u_store.completed_words!==dut.u_store.capture_words ||
      dut.u_store.bad_sync[1]!==dut.u_store.capture_bad))
   $fatal(1,"CDC completion arrived before stable capture metadata");
  if(awvalid&&awready)write_outstanding++;
  if(bvalid&&bready)begin write_outstanding--;if(bresp!=0)b_error_seen++;end
  if(arvalid&&arready)read_outstanding++;
  if(arvalid&&!arready)ar_stall_cycles++;
  if(rvalid&&rready)begin if(rlast)read_outstanding--;if(rresp!=0)r_error_seen++;end
  if(write_outstanding+read_outstanding>1)$fatal(1,"Scheduler allowed overlapping bursts");
  if(write_outstanding<0 || write_outstanding>1 || read_outstanding<0 || read_outstanding>1)
   $fatal(1,"Invalid outstanding transaction count");
  if(read_active_d&&!dut.u_store.read_active&&read_outstanding!=0)$fatal(1,"Read bank released before RLAST");
  if(dut.u_store.read_active&&!read_active_d) begin
   if(bank_seq[dut.u_store.read_bank]<0)$fatal(1,"Reading unpublished bank");
   epoch_seq[dut.u_store.read_epoch]=bank_seq[dut.u_store.read_bank];
  end
  read_active_d=dut.u_store.read_active;
  if((dut.u_store.ws==2||dut.u_store.ws==3||dut.u_store.ws==4)&&dut.u_store.read_active&&
    dut.u_store.write_bank==dut.u_store.read_bank)$fatal(1,"Reader and writer own same bank");
  if(dut.u_store.rejected_frames!=rejected_seen) begin
   reject_seq[capture_seq]=1;rejected_seen=dut.u_store.rejected_frames;
  end
  if(dut.u_store.published_frames!=published_seen) begin
   int b;logic[127:0]word;
   if(write_outstanding!=0)$fatal(1,"Bank published before B response");
   if(capture_seq<=latest_seq || reject_seq.exists(capture_seq))$fatal(1,"Publication order/rejected frame violation");
   b=dut.u_store.latest_bank;
   for(int n=0;n<OW*OH;n++)begin
    word=u_mem.rd_word((b*BANK+n*4)>>4);
    if(word[(n%4)*32+:32]!=={8'h00,expected_pixel(capture_seq,n)})
     $fatal(1,"Published bank %0d sequence %0d pixel %0d is incomplete/wrong",b,capture_seq,n);
   end
   bank_seq[b]=capture_seq;latest_seq=capture_seq;banks_checked[b]=1;published_seen=dut.u_store.published_frames;
  end
 end
end
int frm=0,x=0,y=-1,npx=0,seq=-1,good_run=0,first_good=-1,updates=0,prev_seq=-1,repeat_count=0,stale_frames=0;
int black_frames=0,black_tails=0,complete_frames=0,repeat_frames=0,recovery_at=1000000;
bit de_d=0,vs_d=0,black_tail=0,dumped=0,cap_this=0;
int fd=0;
realtime last_vs=0;
function automatic bit in_window(int yy);
 return !DUAL_WINDOW || (yy>=OH/2 && yy<OH/2+OH);
endfunction
function automatic int source_index(int xx,int yy);
 return DUAL_WINDOW ? (yy-OH/2)*OW+(xx%OW) : (yy/2)*OW+xx/2;
endfunction
function automatic bit disruption_allowed();
 return (STRESS!=0 || FAULT==2) &&
        (fault_window || !fault_done || frm<=recovery_at+2);
endfunction
always @(posedge hclk) begin : display_check
 logic[23:0] actual,expected;
 if(!rst_n) begin
  if(cap_this)begin $fclose(fd);cap_this=0;end
  frm=0;x=0;y=-1;npx=0;seq=-1;good_run=0;first_good=-1;prev_seq=-1;updates=0;repeat_count=0;stale_frames=0;
  de_d=0;vs_d=0;black_tail=0;last_vs=0;recovery_at=1000000;dumped=0;
 end else begin
  vs_d<=o_vs;de_d<=o_de;
  if(o_vs&&!vs_d) begin
   if(npx>0)begin
    if(npx!=W*H || y!=H-1)$fatal(1,"Frame geometry mismatch %0d pixels %0d lines",npx,y+1);
    if(!black_tail && seq>=0) begin
     good_run++;complete_frames++;
     if(first_good<0)first_good=frm;
     if(seq<prev_seq)$fatal(1,"Display frame order went backward");
     if(seq==prev_seq)begin repeat_count++;repeat_frames++;end
     else begin repeat_count=1;updates++;end
     if(seq==prev_seq && latest_seq>seq && !disruption_allowed())stale_frames++;else stale_frames=0;
     if(stale_frames>3)$fatal(1,"Display frozen while new frames published");
     prev_seq=seq;
    end else begin
     good_run=0;if(seq<0)black_frames++;else black_tails++;
     if(first_good>=0&&!disruption_allowed())$fatal(1,"Unexpected black output frame");
    end
    $display("FRAME %0d sequence=%0d pixels=%0d black_tail=%0d good_run=%0d",frm,seq,npx,black_tail,good_run);
    if(cap_this)begin
     $fclose(fd);cap_this=0;
     if(!black_tail)begin
      int mf;dumped=1;mf=$fopen({PREFIX,"_cap_variant.txt"},"w");$fdisplay(mf,"%0d",seq);$fclose(mf);
     end
    end
    if(last_vs>0 && (($realtime-last_vs)-FRAME_NS>0.01 || ($realtime-last_vs)-FRAME_NS< -0.01))
     $fatal(1,"Output video timing mismatch");
   end
   last_vs=$realtime;frm++;npx=0;y=-1;seq=-1;black_tail=0;
   if(fault_done&&recovery_at==1000000)recovery_at=frm;
  end
  if(o_de&&!de_d)begin y++;x=0;end
  if(!o_de&&de_d&&x!=W)$fatal(1,"Line width mismatch");
  if(o_de)begin
   actual={o_r,o_g,o_b};
   if(npx==0)begin
    seq=epoch_seq.exists(dut.u_store.display_epoch)?epoch_seq[dut.u_store.display_epoch]:-1;
    if(seq>=0&&!dumped&&fault_done)begin fd=$fopen({PREFIX,"_cap.hex"},"w");cap_this=1;end
   end
   if(MUTATION==1 && first_good<0 && npx==0)actual=24'h123456;
   if(MUTATION==2 && fault_window && in_window(y) && x==20)actual=24'h123456;
   if(MUTATION==3 && seq>=1)actual=in_window(y)?expected_pixel(0,source_index(x,y)):0;
   if(MUTATION==4 && seq>=0 && y==OH/2 && x==OW)actual=actual^24'h000001;
   if(MUTATION==5 && seq>=0 && y==0 && x==W-1)actual=24'h000001;
   if($isunknown(actual))$fatal(1,"Unknown display pixel");
   if(y>=H||x>=W)$fatal(1,"Display pixel outside geometry");
   expected=seq<0 || !in_window(y)?24'd0:expected_pixel(seq,source_index(x,y));
   if(seq<0 || black_tail || !in_window(y))begin
    if(actual!==24'd0)$fatal(1,"Nonblack pixel in startup/black tail");
   end else if(actual!==expected)begin
    if(actual===24'd0 && disruption_allowed())black_tail=1;
    else $fatal(1,"Display pixel mismatch sequence=%0d x=%0d y=%0d got=%h expected=%h",seq,x,y,actual,expected);
   end
   if(cap_this)$fdisplay(fd,"%h",actual);
   npx++;x++;
  end
 end
end
initial begin : faults
 if(STRESS||FAULT)begin
  wait(first_good>=0);
  @(negedge aclk);fault_window=1;
  if(STRESS)begin
   hold_aw=1;repeat(20000)@(negedge aclk);hold_aw=0;
   wait(wvalid);@(negedge aclk);hold_w=1;repeat(150000)@(negedge aclk);hold_w=0;
   hold_b=1;wait(bready);repeat(100000)@(negedge aclk);hold_b=0;
   hold_ar=1;wait(arvalid);repeat(200000)@(negedge aclk);hold_ar=0;
   wait(arvalid&&arready);@(negedge aclk);hold_r=1;repeat(200000)@(negedge aclk);hold_r=0;
  end
  case(FAULT)
   1:begin inject_b=1;wait(b_error_seen>=2);@(negedge aclk);inject_b=0;end
   2:begin inject_r=1;wait(r_error_seen>=8);@(negedge aclk);inject_r=0;end
   3:begin
    int before_seq,before_updates;
    sensor_pause=1;wait(!s_vs&&!s_valid);pauses++;
    repeat(2)@(posedge o_vs);
    repeat(2)@(posedge hclk);
    wait(prev_seq==latest_seq);
    before_seq=prev_seq;before_updates=updates;
    repeat(5)@(posedge o_vs);
    if(prev_seq!=before_seq)$fatal(1,"Stopped camera did not hold last complete frame");
    sensor_pause=0;wait(updates>before_updates+1);
   end
   4:begin truncate_once=1;wait(truncated>0);wait(dut.u_store.rejected_frames>0);end
   5,6:begin
    if(FAULT==5)wait(wvalid&&wready);else wait(rvalid&&rready&&!rlast);
    @(negedge aclk);rst_n=0;prst_n=0;reset_events++;
    repeat(30)@(negedge aclk);
    rst_n=1;prst_n=1;
   end
  endcase
  fault_window=0;fault_done=1;
 end
end
initial begin
 repeat(20)@(negedge aclk);prst_n=1;rst_n=1;
 wait(frm>MAXFRM || (fault_done&&frm>recovery_at+2&&good_run>=NGOOD&&banks_checked==3'b111&&updates>=3));
 @(negedge hclk);
 if(frm>MAXFRM)$fatal(1,"Timeout: no ordered-frame convergence");
 if(STRESS&&(dut.u_store.dropped_frames==0||dut.u_store.overflow_frames==0||dut.u_store.rejected_frames==0||ar_stall_cycles<100000))
  $fatal(1,"Stress coverage incomplete");
 if(FAULT==1 && (b_error_seen<2||dut.u_store.rejected_frames==0))$fatal(1,"BRESP case not exercised");
 if(FAULT==2 && (r_error_seen<8||black_tails==0))$fatal(1,"RRESP case not exercised");
 if(NOMINAL_FPS>0&&repeat_frames==0)$fatal(1,"30fps/60Hz repeat not exercised");
 $display("COUNTERS published=%0d rejected=%0d dropped=%0d overflow=%0d underflow=%0d banks=%b updates=%0d repeats=%0d black=%0d tails=%0d B_errors=%0d R_errors=%0d AR_stall=%0d truncated=%0d pauses=%0d resets=%0d",
  dut.u_store.published_frames,dut.u_store.rejected_frames,dut.u_store.dropped_frames,dut.u_store.overflow_frames,
  dut.u_store.underflow_frames,banks_checked,updates,repeat_frames,black_frames,black_tails,b_error_seen,r_error_seen,ar_stall_cycles,truncated,pauses,reset_events);
 $display("=== tb_v04_checked PASS %0dx%0d phase=%0d rev=%0d vs=%0d stress=%0d fault=%0d ===",W,H,PHASE,REV,VS_MODE,STRESS,FAULT);
 $finish;
end
initial begin #(FRAME_NS*(MAXFRM+10)*2);$fatal(1,"Global watchdog");end
endmodule
