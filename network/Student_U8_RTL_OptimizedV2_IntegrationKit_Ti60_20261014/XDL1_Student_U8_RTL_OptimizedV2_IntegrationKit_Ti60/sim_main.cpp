// Cycle-accurate external DDR model. Every real RTL feature write is checked.
#include "Vstudent_u8.h"
#include "verilated.h"
#include <vector>
#include <fstream>
#include <iostream>
#include <string>
#include <cstdint>
#include <stdexcept>
std::vector<uint64_t> readhex(const char* name){
 std::ifstream f(name);if(!f)throw std::runtime_error(name);
 std::vector<uint64_t> v;std::string s;while(f>>s)v.push_back(std::stoull(s,nullptr,16));return v;
}
int main(int argc,char**argv){try{
 if(argc!=4)throw std::runtime_error("usage sim latency stall frames");
 int latency=std::stoi(argv[1]),stall=std::stoi(argv[2]),nframes=std::stoi(argv[3]);
 auto inputs=readhex("input.mem"),gold=readhex("expected.mem"),addr=readhex("addresses.mem");
 const size_t goldlen=addr.size(),inputlen=inputs.size()/nframes;
 if(gold.size()!=goldlen*nframes)throw std::runtime_error("gold length");
 VerilatedContext context;context.commandArgs(argc,argv);Vstudent_u8 d(&context);
 std::vector<uint64_t> memory(786432,0);size_t writes=0,reads=0;int frame=0,waitread=0;
 uint32_t pending=0,rng=0x12345678;bool held=false,held_write=false,begin=true;
 uint32_t held_addr=0;uint64_t held_data=0;
 std::ofstream rgbdump("rtl_rgb_frame0.bin",std::ios::binary);
 for(size_t i=0;i<inputlen;i++)memory[i]=inputs[i];
 d.rst=1;d.start=0;d.mem_ready=0;d.mem_rvalid=0;d.mem_rdata=0;
 for(int i=0;i<5;i++){d.clk=0;d.eval();d.clk=1;d.eval();}
 d.rst=0;
 for(uint64_t cycles=0;cycles<100000000;cycles++){
  d.clk=0;d.start=begin;begin=false;
  rng=(rng<<1)|(((rng>>31)^(rng>>21)^(rng>>1)^rng)&1);
  d.mem_ready=waitread==0&&(!stall||(rng&7)!=0);d.mem_rvalid=0;
  if(waitread>0&&--waitread==0){d.mem_rvalid=1;d.mem_rdata=memory.at(pending>>3);}
  d.eval();
  bool valid=d.mem_valid,wr=d.mem_write,accept=valid&&d.mem_ready;
  uint32_t a=d.mem_addr;uint64_t data=d.mem_wdata;
  if(held&&(!valid||a!=held_addr||wr!=held_write||(wr&&data!=held_data)))throw std::runtime_error("unstable command");
  held=valid&&!d.mem_ready;held_addr=a;held_write=wr;held_data=data;
  if(accept){
   if((a&7)||d.mem_wstrb!=255)throw std::runtime_error("alignment/strobe");
   if(wr){
    if(writes>=goldlen||a!=addr[writes]||data!=gold[frame*goldlen+writes]){
     std::cerr<<"FAIL frame="<<frame<<" layer="<<int(d.layer_index)<<" word="<<writes
      <<" address="<<std::hex<<a<<" got="<<data<<" expected="<<gold.at(frame*goldlen+writes)<<std::dec<<std::endl;
     return 2;
    }
    memory.at(a>>3)=data;writes++;
    if(d.layer_index==18)for(int c=0;c<3;c++)rgbdump.put(char((data>>(8*c))&255));
   }else{pending=a;waitread=latency;reads++;}
  }
  d.clk=1;d.eval();context.timeInc(2);
  if(d.layer_done)std::cout<<"LAYER index_next="<<int(d.layer_index)<<" cycles="<<d.frame_cycles<<" writes="<<writes<<" reads="<<reads<<std::endl;
  if(d.done){
   if(writes!=goldlen)throw std::runtime_error("missing writes");
   std::cout<<"PASS frame="<<frame<<" cycles="<<d.frame_cycles<<" reads="<<reads<<" writes="<<writes<<std::endl;
   rgbdump.close();
   if(++frame==nframes){d.final();return 0;}
   rgbdump.open("rtl_rgb_frame"+std::to_string(frame)+".bin",std::ios::binary);
   writes=reads=0;for(size_t i=0;i<inputlen;i++)memory[i]=inputs[frame*inputlen+i];begin=true;
  }
 }
 throw std::runtime_error("timeout");
}catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<std::endl;return 1;}}
