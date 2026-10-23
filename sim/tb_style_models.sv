`timescale 1ns/1ps
module tb_style_models;
parameter W=32,H=30,N=1,COUNT=19;
reg clk=0;always #3.5 clk=~clk;
reg rst=1,start=0,param_bank=0,cfg_valid=0,cfg_bank=1;
reg [1:0] cfg_kind;reg [9:0] cfg_addr;reg [575:0] cfg_data;
wire busy,done,mv,mw,ld;wire [23:0] ma;wire [63:0] wd;
reg ready=0,rv=0;reg [63:0] rd;wire [4:0] li;wire [31:0] cycles;
glass_int8 #(.EXT_W(W),.EXT_H(H)) dut(clk,rst,start,busy,done,param_bank,cfg_valid,cfg_bank,cfg_kind,cfg_addr,cfg_data,mv,mw,ma,wd,,ready,rv,rd,ld,li,cycles);
reg [63:0] mem[0:786431],input_words[0:W*H-1],expected[0:N-1];
reg [23:0] addresses[0:N-1];reg [587:0] config_words[0:667];
string folder,sub;integer writes=0,frame,fd;
reg [23:0] queue_addr[0:15];integer queue_due[0:15];
integer sent_reads=0,returned_reads=0,clock_count=0;
reg [31:0] rng=32'h12671;
always @(posedge clk) begin
 clock_count<=clock_count+1;rng<={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
 ready<=sent_reads-returned_reads<3 && (rng%100>=35);rv<=0;
 if(sent_reads!=returned_reads && clock_count>=queue_due[returned_reads%16])begin
  rv<=1;rd<=mem[queue_addr[returned_reads%16]>>3];returned_reads<=returned_reads+1;
 end
 if(!rst&&mv&&ready)begin
  if(mw)begin
   if(writes>=N || ma!==addresses[writes] || wd!==expected[writes])
    $fatal(1,"model=%0d layer=%0d word=%0d addr=%h expected=%h got=%h want=%h",frame,li,writes,ma,addresses[writes],wd,expected[writes]);
   mem[ma>>3]<=wd;writes=writes+1;
  end else begin
   if(sent_reads-returned_reads>=4)$fatal(1,"too many reads");
   queue_addr[sent_reads%16]<=ma;queue_due[sent_reads%16]<=clock_count+1+rng%7;sent_reads<=sent_reads+1;
  end
 end
 if(cfg_valid && cfg_bank==param_bank)$fatal(1,"write active bank");
end
initial begin
 if(!$value$plusargs("DIR=%s",folder))$fatal(1,"missing DIR");
 repeat(8)@(negedge clk);rst=0;
 for(frame=0;frame<COUNT;frame=frame+1)begin
  sub=$sformatf("%s/%0d",folder,frame);
  $readmemh({sub,"/input.hex"},input_words);$readmemh({sub,"/features.hex"},expected);$readmemh({sub,"/addresses.hex"},addresses);
  $readmemh({sub,"/config.hex"},config_words);
  cfg_bank=~param_bank;
  for(integer k=0;k<668;k=k+1)begin
   @(negedge clk);{cfg_kind,cfg_addr,cfg_data}=config_words[k];cfg_valid=1;
  end
  @(negedge clk);cfg_valid=0;param_bank=cfg_bank;
  for(integer i=0;i<W*H;i=i+1)mem[i]=input_words[i];
  writes=0;repeat(4)@(negedge clk);start=1;@(negedge clk);start=0;
  // Refill the inactive bank throughout active computation, preserving outputs.
  cfg_bank=~param_bank;
  for(integer k=0;k<668;k=k+1)begin
   @(negedge clk);{cfg_kind,cfg_addr,cfg_data}=config_words[667-k];cfg_data=~cfg_data;cfg_valid=1;
  end
  @(negedge clk);cfg_valid=0;
  wait(done);@(negedge clk);if(writes!=N)$fatal(1,"wrong count");
  $display("MODEL PASS id=%0d words=%0d cycles=%0d",frame,writes,cycles);$fflush();
 end
 $display("tb_style_models PASS");$finish;
end
initial begin #2000000000;$fatal(1,"timeout state=%0d layer=%0d",dut.state,li);end
endmodule
