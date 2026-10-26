#pragma once
#include <stdint.h>
#include <stdbool.h>
#ifdef ESP_PLATFORM
#include "esp_attr.h"
#define PIPE_IRAM IRAM_ATTR
#else
#define PIPE_IRAM
#endif
#define AFS_PIPE_SLOTS 2
typedef struct {unsigned driver_mask;uint32_t submitted,reclaimed;} afs_pipe;
static inline bool afs_pipe_submit(afs_pipe*p,unsigned i){if(i>=AFS_PIPE_SLOTS||(p->driver_mask&(1u<<i)))return false;p->driver_mask|=1u<<i;p->submitted++;return true;}
/* Call only after successful driver get_trans_result, never from completion callback. */
static inline bool afs_pipe_reclaim(afs_pipe*p,unsigned i){if(i>=AFS_PIPE_SLOTS||!(p->driver_mask&(1u<<i)))return false;p->driver_mask&=~(1u<<i);p->reclaimed++;return true;}
typedef struct {uint32_t count,last_us,min_us,max_us,bins[5];uint64_t sum_us;} afs_gap;
static inline void PIPE_IRAM afs_gap_add(afs_gap*g,uint32_t us){if(!g->count||us<g->min_us)g->min_us=us;if(us>g->max_us)g->max_us=us;g->last_us=us;g->count++;g->sum_us+=us;g->bins[us<=10?0:us<=27?1:us<=54?2:us<=122?3:4]++;}
