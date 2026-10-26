#include "afs_generation.h"
#include <assert.h>
#include <stdio.h>
int main(void){afs_generation g={0x12345678,0,false};
 assert(!afs_generation_begin(&g,g.session,7,99));afs_generation_accept(&g,1000);
 assert(!afs_generation_begin(&g,g.session,1001,99));
 assert(afs_generation_begin(&g,g.session,2,99));assert(g.session==99&&!g.seen);
 assert(!afs_generation_begin(&g,0x12345678,2,100));
 assert(!afs_generation_begin(&g,99,2,100));afs_generation_accept(&g,2);
 assert(!afs_generation_begin(&g,99,3,100));assert(afs_generation_begin(&g,99,2,0));assert(g.session==100);
 afs_generation_accept(&g,0xfffffffeu);assert(!afs_generation_begin(&g,100,1,101));
 puts("PASS FPGA-only reset, stale echo, first new BEGIN, duplicate epoch and wrap");}
