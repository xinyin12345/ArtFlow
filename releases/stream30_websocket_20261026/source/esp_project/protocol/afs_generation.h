#pragma once
#include <stdint.h>
#include <stdbool.h>
typedef struct {uint32_t session,last;bool seen;} afs_generation;
// Call only for a CRC-validated BEGIN. A new challenge is accepted once;
// a regressed FPGA epoch must not cause an infinite session-rotation loop.
static inline bool afs_generation_begin(afs_generation*g,uint32_t echo,uint32_t next,uint32_t fresh){
 uint32_t delta=next-g->last;
 if(echo!=g->session||!g->seen||(delta!=0&&delta<0x80000000u))return false;
 if(!fresh||fresh==g->session)fresh=g->session+1u;
 if(!fresh)fresh=1;
 g->session=fresh;g->seen=false;return true;
}
static inline void afs_generation_accept(afs_generation*g,uint32_t seq){g->last=seq;g->seen=true;}
