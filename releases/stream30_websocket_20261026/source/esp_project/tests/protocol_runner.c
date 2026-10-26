#include "afs.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char**argv){assert(argc==4);FILE*f=fopen(argv[1],"rb"),*out=fopen(argv[2],"wb");assert(f&&out);uint8_t image[AFS_IMAGE],p[AFS_PACKET],ws[AFS_WS];afs_rx r;afs_reset(&r,0x12345678,image);unsigned frames=0;while(fread(p,1,AFS_PACKET,f)==AFS_PACKET){int v=afs_accept(&r,p,AFS_PACKET);if(v==1){afs_header(ws,AFS_END,r.session,r.seq,AFS_IMAGE,0);for(unsigned i=0;i<AFS_IMAGE;i++)ws[28+i]=image[i];afs_put32(ws+AFS_WS-4,afs_crc(ws,AFS_WS-4));assert(fwrite(ws,1,AFS_WS,out)==AFS_WS);frames++;}}assert(!ferror(f));fclose(f);fclose(out);assert(frames==(unsigned)atoi(argv[3]));printf("PASS C receiver: %u complete, %u rejected, %u diagnostics\n",frames,r.bad,r.tests);return 0;}
