#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#define AFS_PACKET 1056
#define AFS_HEADER 28
#define AFS_PAYLOAD 1024
#define AFS_IMAGE 28800
#define AFS_WS (AFS_HEADER+AFS_IMAGE+4)
enum {AFS_POLL,AFS_BEGIN,AFS_DATA,AFS_END,AFS_CANCEL,AFS_TEST,AFS_STATUS=128};
uint32_t afs_crc_update(uint32_t c,const uint8_t *p,size_t n);
uint32_t afs_crc(const uint8_t *p,size_t n);
uint32_t afs_u32(const uint8_t *p);
uint16_t afs_u16(const uint8_t *p);
void afs_put32(uint8_t *p,uint32_t v);
void afs_header(uint8_t *p,uint8_t type,uint32_t session,uint32_t seq,uint32_t off,uint16_t len);
void afs_packet(uint8_t *p,uint8_t type,uint32_t session,uint32_t seq,uint32_t off,const uint8_t *data,uint16_t len);
typedef struct {uint32_t session,seq,offset,crc,good,bad,tests;bool active;uint8_t *image;} afs_rx;
void afs_reset(afs_rx *r,uint32_t session,uint8_t *image);
/* 1 complete frame, 0 valid intermediate/diagnostic, -1 rejected. */
int afs_accept(afs_rx *r,const uint8_t *p,size_t n);
