#pragma once
#include <stdbool.h>
// Call under the caller's lock. Exactly two buffers: producer owns current;
// consumer owns sending until release. offer never blocks or overwrites sending.
typedef struct {int current,sending;} afs_mailbox;
static inline int afs_mailbox_offer(afs_mailbox*m,bool connected){
 if(!connected||m->sending>=0)return -1;
 int old=m->current;m->sending=old;m->current^=1;return old;
}
static inline void afs_mailbox_release(afs_mailbox*m,int index){if(m->sending==index)m->sending=-1;}
