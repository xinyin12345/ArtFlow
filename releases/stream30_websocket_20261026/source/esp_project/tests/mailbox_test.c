#include "afs_mailbox.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
int main(void){afs_mailbox m={0,-1};unsigned char buffer[2][28800];unsigned char held=0;unsigned published=0,dropped=0;
 for(unsigned i=0;i<10000;i++){
  assert(m.current!=m.sending);
  if(m.sending>=0)for(unsigned j=0;j<28800;j++)assert(buffer[m.sending][j]==held);
  if(i%73==0&&m.sending>=0)afs_mailbox_release(&m,m.sending);
  memset(buffer[m.current],i&255,28800);
  int offered=afs_mailbox_offer(&m,i%1000<700); // reconnect/disconnect + slow consumer
  if(offered>=0){held=i&255;published++;}else dropped++;
 }
 assert(published>0&&dropped>9000);printf("PASS shared mailbox: %u offered, %u dropped; no producer overwrite or blocking\n",published,dropped);return 0;
}
