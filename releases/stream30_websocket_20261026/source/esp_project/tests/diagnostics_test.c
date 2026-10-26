#include "afs.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static uint8_t image[AFS_IMAGE],p[AFS_PACKET];
static afs_rx r;
static void packet(unsigned t){afs_packet(p,t,123,7,0,NULL,0);}
static void crc(void){afs_put32(p+1052,afs_crc(p,1052));}
static void reject_as(unsigned reason,size_t n){unsigned b=r.bad;assert(afs_accept(&r,p,n)==-1);assert(r.bad==b+1);assert(r.diag.last_reason==reason+1);assert(!r.active&&r.offset==0);}
int main(void){
 afs_reset(&r,123,image);
 uint8_t test[16];for(int i=0;i<16;i++)test[i]=i;
 afs_packet(p,AFS_TEST,999,42,0,test,16);assert(afs_accept(&r,p,sizeof p)==0);assert(r.diag.test_seen&&r.diag.test_session==999&&r.diag.test_capture_epoch==42&&r.tests==1);
 p[100]^=1;reject_as(DR_PACKET_CRC,sizeof p);assert(r.diag.test_session==999);
 packet(AFS_BEGIN);reject_as(DR_LENGTH,0);reject_as(DR_LENGTH,10);reject_as(DR_LENGTH,1055);
 packet(AFS_BEGIN);p[0]=0;reject_as(DR_HEADER,sizeof p);
 packet(AFS_BEGIN);p[20]=1;p[21]=4;crc();reject_as(DR_PAYLOAD_LENGTH,sizeof p);
 packet(AFS_BEGIN);p[40]=1;crc();reject_as(DR_PADDING,sizeof p);
 packet(AFS_TEST);reject_as(DR_TEST,sizeof p);
 packet(AFS_POLL);p[16]=1;crc();reject_as(DR_POLL,sizeof p);
 packet(AFS_BEGIN);p[8]=124;crc();reject_as(DR_SESSION,sizeof p);
 packet(AFS_CANCEL);p[20]=1;crc();reject_as(DR_CANCEL,sizeof p);
 packet(AFS_BEGIN);p[16]=1;crc();reject_as(DR_BEGIN,sizeof p);
 packet(AFS_DATA);reject_as(DR_ORDER,sizeof p);
 packet(AFS_BEGIN);assert(afs_accept(&r,p,sizeof p)==0);
 packet(AFS_DATA);reject_as(DR_DATA,sizeof p);
 packet(AFS_BEGIN);assert(afs_accept(&r,p,sizeof p)==0);
 packet(AFS_END);reject_as(DR_END,sizeof p);
 packet(AFS_BEGIN);assert(afs_accept(&r,p,sizeof p)==0);unsigned bad=r.bad;
 packet(AFS_CANCEL);assert(afs_accept(&r,p,sizeof p)==0&&r.bad==bad&&!r.active);assert(r.diag.accepted[AFS_CANCEL]==1);
 packet(AFS_BEGIN);assert(afs_accept(&r,p,sizeof p)==0);afs_timeout(&r);assert(r.diag.last_reason==DR_TIMEOUT+1&&r.bad==bad+1);afs_timeout(&r);assert(r.bad==bad+1);
 packet(AFS_POLL);assert(afs_accept(&r,p,sizeof p)==0);
 unsigned sum=0;for(unsigned i=0;i<DR_COUNT;i++){assert(r.diag.reject_reason[i]>0);sum+=r.diag.reject_reason[i];}assert(sum==r.bad);
 puts("PASS: all 14 mutually exclusive reasons, short/zero/CRC/session/cancel/timeout, TEST echo trust boundary");return 0;
}
