#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include "lwip/sockets.h"
#include <string.h>
#include <inttypes.h>
#include <assert.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_chip_info.h"
#include "esp_system.h"
#include "esp_random.h"
#include "esp_log.h"
#include "esp_flash.h"
#include "esp_psram.h"
#include "esp_heap_caps.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "esp_http_server.h"
#include "esp_timer.h"
#include "nvs_flash.h"
#include "driver/spi_slave.h"
#include "driver/gpio.h"
#include "wifi_credentials.h"
#include "afs.h"
#include "afs_pipeline.h"
#include "esp_rom_sys.h"
#include "hal/gpio_ll.h"
#include "soc/gpio_struct.h"
#include "afs_mailbox.h"
#include "afs_generation.h"
static const char *TAG="stream";
static uint32_t flash_physical,flash_configured;
static esp_err_t flash_result;
static size_t psram_bytes;
static const char *psram_status="not_initialized_degraded";
static esp_chip_info_t chip;
static httpd_handle_t server;
static portMUX_TYPE mux=portMUX_INITIALIZER_UNLOCKED;
static int ws_fd=-1;
enum {ND_NO_CLIENT,ND_VIDEO_OFF,ND_BUSY,ND_WORK_QUEUE,ND_STALE,ND_SEND,ND_COUNT};
static uint32_t net_reasons[ND_COUNT],ws_generation,ws_registered,ws_unregistered,ws_extra_rejected,send_attempts;
static int last_send_error;
typedef struct {int index,fd;uint32_t generation;} send_job;
static send_job jobs[2];
static afs_mailbox mailbox={.current=0,.sending=-1};
static bool video_enabled=false,spi_available=false;
static uint8_t fps=1;
static uint32_t session,good,bad,tests,dropped,sent,last_seq;
static uint8_t *frames[2];
static afs_diag diag;
typedef struct {spi_slave_transaction_t trans;uint8_t *rx,*tx;bool cached,en;uint8_t rate;uint32_t seq,session;} dma_slot;
static dma_slot slots[AFS_PIPE_SLOTS];static afs_pipe pipe_state;
static afs_gap rearm_all,rearm_video;
static bool link_stopped=false,rearm_pending=false,rearm_was_video=false;
static int64_t rearm_low_at;
static uint32_t setup_callbacks,complete_callbacks,queue_failures;

static uint32_t txn_bins[5],last_bits,max_bits,status_prepared,status_completed;
static uint32_t completed_status_session;static bool completed_status_enable;
static esp_err_t diagnostics_handler(httpd_req_t*r){
 uint32_t nr[ND_COUNT],wg,wr,wu,we,sa;int wf,se;
 afs_gap ga,gv;uint32_t setups,completes,qfails;bool stopped;
 afs_diag d;uint32_t bins[5],lb,mb,prep,comp,ss;bool en;
 portENTER_CRITICAL(&mux);memcpy(nr,net_reasons,sizeof nr);wg=ws_generation;wr=ws_registered;wu=ws_unregistered;we=ws_extra_rejected;sa=send_attempts;wf=ws_fd;se=last_send_error;ga=rearm_all;gv=rearm_video;setups=setup_callbacks;completes=complete_callbacks;qfails=queue_failures;stopped=link_stopped;d=diag;memcpy(bins,txn_bins,sizeof bins);lb=last_bits;mb=max_bits;prep=status_prepared;comp=status_completed;ss=completed_status_session;en=completed_status_enable;portEXIT_CRITICAL(&mux);
 char *b=calloc(1,3072);if(!b)return ESP_ERR_NO_MEM;
 int n=snprintf(b,3072,"{\"diagnostic_version\":3,\"build_id\":\"websocket-20261026-v1\",\"fpga_enable_ack_available\":false,\"test_seen\":%s,\"fpga_test_session\":%"PRIu32",\"fpga_test_capture_epoch\":%"PRIu32",\"status_prepared\":%"PRIu32",\"status_transactions_completed\":%"PRIu32",\"last_completed_status_session\":%"PRIu32",\"last_completed_status_enable_request\":%s,\"txn_last_bits\":%"PRIu32",\"txn_max_bits\":%"PRIu32",\"txn_bins_zero_nonbyte_short_exact_long\":[%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32"],\"accepted_poll_begin_data_end_cancel_test\":[%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32"],\"last_reject_reason_code\":%"PRIu32",\"rejected_by_reason\":{",d.test_seen?"true":"false",d.test_session,d.test_capture_epoch,prep,comp,ss,en?"true":"false",lb,mb,bins[0],bins[1],bins[2],bins[3],bins[4],d.accepted[0],d.accepted[1],d.accepted[2],d.accepted[3],d.accepted[4],d.accepted[5],d.last_reason);
 const char*names[]={"length","header","packet_crc","payload_length","padding","test","poll","session","cancel","begin","order","data","end_or_frame_crc","timeout"};
 for(unsigned i=0;i<DR_COUNT;i++)n+=snprintf(b+n,3072-n,"%s\"%s\":%"PRIu32,i?",":"",names[i],d.reject_reason[i]);
 n+=snprintf(b+n,3072-n,"},\"pipeline\":{\"slots\":2,\"setup_callbacks\":%"PRIu32",\"complete_callbacks\":%"PRIu32",\"queue_failures\":%"PRIu32",\"stopped\":%s,\"ready_low_hold_us\":1},\"rearm_software_us\":{",setups,completes,qfails,stopped?"true":"false");
 afs_gap gs[2]={ga,gv};for(unsigned i=0;i<2;i++){afs_gap*g=&gs[i];n+=snprintf(b+n,3072-n,"%s\"%s\":{\"count\":%"PRIu32",\"last\":%"PRIu32",\"min\":%"PRIu32",\"max\":%"PRIu32",\"sum\":%"PRIu64",\"bins_le10_le27_le54_le122_gt122\":[%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32"]}",i?",":"",i?"previous_status_video_requested":"all",g->count,g->last_us,g->min_us,g->max_us,g->sum_us,g->bins[0],g->bins[1],g->bins[2],g->bins[3],g->bins[4]);}
 n+=snprintf(b+n,3072-n,"},\"network\":{\"registered\":%s,\"client_fd\":%d,\"generation\":%"PRIu32",\"registrations\":%"PRIu32",\"unregistrations\":%"PRIu32",\"extra_clients_rejected\":%"PRIu32",\"send_attempts\":%"PRIu32",\"last_send_error\":%d,\"drops_no_client_video_off_busy_work_queue_stale_send\":[%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32",%"PRIu32"]}}",wf>=0?"true":"false",wf,wg,wr,wu,we,sa,se,nr[0],nr[1],nr[2],nr[3],nr[4],nr[5]);httpd_resp_set_type(r,"application/json");httpd_resp_set_hdr(r,"Cache-Control","no-store");esp_err_t e=httpd_resp_send(r,b,n);free(b);return e;
}

extern const char page_start[] asm("_binary_index_html_start");
extern const char page_end[] asm("_binary_index_html_end");
extern const char js_start[] asm("_binary_afs_js_start");
extern const char js_end[] asm("_binary_afs_js_end");
static void inspect_memory(void)
{
    esp_chip_info(&chip);
    flash_result = esp_flash_get_physical_size(NULL, &flash_physical);
    esp_err_t configured_result = esp_flash_get_size(NULL, &flash_configured);
    ESP_LOGI(TAG, "IDF %s; revision %u.%u; cores %u", esp_get_idf_version(),
             chip.revision / 100, chip.revision % 100, chip.cores);
    ESP_LOGI(TAG, "Flash physical probe: %s, bytes=%" PRIu32 "; configured API: %s, bytes=%" PRIu32,
             esp_err_to_name(flash_result), flash_physical, esp_err_to_name(configured_result), flash_configured);
    if (flash_result != ESP_OK || flash_physical != 16 * 1024 * 1024)
        ESP_LOGE(TAG, "FLASH_NOT_VERIFIED_16MB: physical probe failed or size differs");
    if (esp_psram_is_initialized()) {
        psram_bytes = esp_psram_get_size();
        volatile uint32_t *sample = heap_caps_malloc(4096, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
        if (!sample) {
            psram_status = "allocation_failed_degraded";
        } else {
            bool ok = true;
            for (unsigned pass = 0; pass < 2; ++pass) {
                for (unsigned i = 0; i < 1024; ++i) sample[i] = (0xA55A1234u ^ i) ^ (pass ? 0xFFFFFFFFu : 0);
                for (unsigned i = 0; i < 1024; ++i)
                    if (sample[i] != ((0xA55A1234u ^ i) ^ (pass ? 0xFFFFFFFFu : 0))) ok = false;
            }
            heap_caps_free((void *)sample);
            psram_status = ok ? (psram_bytes == 8 * 1024 * 1024 ? "8MiB_detected_4KiB_sample_pass" : "unexpected_size_4KiB_sample_pass") : "sample_failed_degraded";
        }
    }
    ESP_LOGI(TAG, "PSRAM bytes=%u status=%s (sample is not a full RAM test)", (unsigned)psram_bytes, psram_status);
    if (strcmp(psram_status, "8MiB_detected_4KiB_sample_pass") != 0)
        ESP_LOGE(TAG, "PSRAM_NOT_VERIFIED_8MB: continuing with internal-RAM web service");
}


static esp_err_t page_handler(httpd_req_t*r){httpd_resp_set_type(r,"text/html; charset=utf-8");httpd_resp_set_hdr(r,"Cache-Control","no-store");return httpd_resp_send(r,page_start,page_end-page_start-1);}
static esp_err_t js_handler(httpd_req_t*r){httpd_resp_set_type(r,"application/javascript");return httpd_resp_send(r,js_start,js_end-js_start-1);}
static esp_err_t status_handler(httpd_req_t*r){
 char b[768];portENTER_CRITICAL(&mux);uint32_t g=good,e=bad,t=tests,d=dropped,s=sent,q=last_seq;bool v=video_enabled;unsigned rate=fps;portEXIT_CRITICAL(&mux);
 int n=snprintf(b,sizeof b,"{\"protocol\":1,\"source\":\"FPGA styled framebuffer RGB565, before HDMI gamma/OSD\",\"physical_tested\":false,\"spi_available\":%s,\"video_enabled\":%s,\"fps_request\":%u,\"session\":%"PRIu32",\"complete_frames\":%"PRIu32",\"rejected\":%"PRIu32",\"diagnostic_packets\":%"PRIu32",\"network_dropped\":%"PRIu32",\"sent\":%"PRIu32",\"last_epoch\":%"PRIu32",\"flash_physical_bytes\":%"PRIu32",\"psram_status\":\"%s\",\"frame_memory\":\"internal RAM\"}",spi_available?"true":"false",v?"true":"false",rate,session,g,e,t,d,s,q,flash_physical,psram_status);
 if(n<0||(size_t)n>=sizeof b){return ESP_FAIL;}
 httpd_resp_set_type(r,"application/json");httpd_resp_set_hdr(r,"Cache-Control","no-store");return httpd_resp_send(r,b,n);
}
static esp_err_t control_handler(httpd_req_t*r){char b[32];if(r->content_len<=0||r->content_len>=sizeof b)return httpd_resp_send_err(r,HTTPD_400_BAD_REQUEST,"bad length");int got=0;while(got<r->content_len){int n=httpd_req_recv(r,b+got,r->content_len-got);if(n<=0)return ESP_FAIL;got+=n;}b[got]=0;unsigned en,rate;int end=0;if(sscanf(b,"enabled=%u&fps=%u%n",&en,&rate,&end)!=2||end!=got||en>1||rate<1||rate>5)return httpd_resp_send_err(r,HTTPD_400_BAD_REQUEST,"enabled 0/1; fps 1..5");portENTER_CRITICAL(&mux);video_enabled=en&&spi_available;fps=rate;portEXIT_CRITICAL(&mux);return httpd_resp_sendstr(r,"ok");}
// Network callbacks and work run on the HTTP server task. SPI task only offers
// immutable completed frame buffers and queues work; it never traverses HTTP sessions.
static void ws_forget(int fd){portENTER_CRITICAL(&mux);if(ws_fd==fd){ws_fd=-1;ws_generation++;ws_unregistered++;video_enabled=false;}portEXIT_CRITICAL(&mux);}
static void ws_close(httpd_handle_t h,int fd){(void)h;ws_forget(fd);close(fd);}
// IDF's WS sender calls send_fn once for header and once for payload. A successful
// short socket send must be finished before reporting success for the whole frame.
static int ws_send_all(httpd_handle_t h,int fd,const char*b,size_t n,int flags){
 (void)h;size_t used=0;int64_t deadline=esp_timer_get_time()+1000000;
 while(used<n){if(esp_timer_get_time()>=deadline)return -1;int v=send(fd,b+used,n-used,flags);if(v<0&&errno==EINTR)continue;if(v<=0)return -1;used+=(size_t)v;}
 return (int)used;
}
static esp_err_t ws_connected(httpd_req_t*r){
 int fd=httpd_req_to_sockfd(r);if(httpd_ws_get_fd_info(r->handle,fd)!=HTTPD_WS_CLIENT_WEBSOCKET)return ESP_FAIL;
 portENTER_CRITICAL(&mux);int old=ws_fd;portEXIT_CRITICAL(&mux);
 if(old>=0&&old!=fd&&httpd_ws_get_fd_info(r->handle,old)==HTTPD_WS_CLIENT_WEBSOCKET){portENTER_CRITICAL(&mux);ws_extra_rejected++;portEXIT_CRITICAL(&mux);return ESP_FAIL;}
 esp_err_t e=httpd_sess_set_send_override(r->handle,fd,ws_send_all);if(e!=ESP_OK)return e;
 portENTER_CRITICAL(&mux);ws_fd=fd;ws_generation++;ws_registered++;portEXIT_CRITICAL(&mux);return ESP_OK;
}
static esp_err_t ws_handler(httpd_req_t*r){
 if(httpd_ws_get_fd_info(r->handle,httpd_req_to_sockfd(r))!=HTTPD_WS_CLIENT_WEBSOCKET)return httpd_resp_send_err(r,HTTPD_400_BAD_REQUEST,"WebSocket upgrade required");
 httpd_ws_frame_t f={0};esp_err_t e=httpd_ws_recv_frame(r,&f,0);if(e!=ESP_OK)return e;if(f.len>32)return ESP_FAIL;uint8_t data[32];f.payload=data;e=httpd_ws_recv_frame(r,&f,sizeof data);return e;
}
static void send_work(void*arg){
 send_job j=*(send_job*)arg;portENTER_CRITICAL(&mux);bool current=ws_fd==j.fd&&ws_generation==j.generation&&video_enabled;portEXIT_CRITICAL(&mux);
 esp_err_t e=ESP_FAIL;unsigned reason=ND_STALE;
 if(current){reason=ND_SEND;portENTER_CRITICAL(&mux);send_attempts++;portEXIT_CRITICAL(&mux);
  if(httpd_ws_get_fd_info(server,j.fd)==HTTPD_WS_CLIENT_WEBSOCKET){httpd_ws_frame_t f={.final=true,.type=HTTPD_WS_TYPE_BINARY,.payload=frames[j.index],.len=AFS_WS};e=httpd_ws_send_frame_async(server,j.fd,&f);}
 }
 portENTER_CRITICAL(&mux);if(e==ESP_OK)sent++;else{dropped++;net_reasons[reason]++;if(reason==ND_SEND)last_send_error=e;}afs_mailbox_release(&mailbox,j.index);portEXIT_CRITICAL(&mux);
 if(current&&e!=ESP_OK){ws_forget(j.fd);httpd_sess_trigger_close(server,j.fd);}
}
static void publish_frame(afs_rx*a,int*index){
 portENTER_CRITICAL(&mux);unsigned reason=ws_fd<0?ND_NO_CLIENT:!video_enabled?ND_VIDEO_OFF:ND_BUSY;
 int offered=afs_mailbox_offer(&mailbox,ws_fd>=0&&video_enabled);int next=mailbox.current;
 if(offered>=0){assert(offered==*index);jobs[offered]=(send_job){.index=offered,.fd=ws_fd,.generation=ws_generation};last_seq=a->seq;}
 else{dropped++;net_reasons[reason]++;}portEXIT_CRITICAL(&mux);
 if(offered>=0){afs_header(frames[*index],AFS_END,session,a->seq,AFS_IMAGE,0);afs_put32(frames[*index]+AFS_WS-4,afs_crc(frames[*index],AFS_WS-4));esp_err_t e=httpd_queue_work(server,send_work,&jobs[offered]);
  if(e!=ESP_OK){portENTER_CRITICAL(&mux);afs_mailbox_release(&mailbox,offered);dropped++;net_reasons[ND_WORK_QUEUE]++;last_send_error=e;portEXIT_CRITICAL(&mux);}
  *index=next;a->image=frames[next]+AFS_HEADER;
 }
}
// IDF 5.5.6 invokes completion before installing/starting the next queued transaction.
// GPIO LL, esp_timer_get_time (configured IRAM), ROM delay and inline counters only.
static void IRAM_ATTR ready_low(spi_slave_transaction_t*t){
 dma_slot*q=t->user;
 portENTER_CRITICAL_ISR(&mux);gpio_ll_set_level(&GPIO,9,0);rearm_low_at=esp_timer_get_time();rearm_pending=true;rearm_was_video=q->en;complete_callbacks++;portEXIT_CRITICAL_ISR(&mux);
 // Ensure the FPGA's two synchronizer stages can observe READY low even with a full queue.
 esp_rom_delay_us(1);
}
static void IRAM_ATTR ready_high(spi_slave_transaction_t*t){
 (void)t;portENTER_CRITICAL_ISR(&mux);setup_callbacks++;
 if(!link_stopped){gpio_ll_set_level(&GPIO,9,1);int64_t now=esp_timer_get_time();if(rearm_pending){uint64_t dt=(uint64_t)(now-rearm_low_at);uint32_t us=dt>UINT32_MAX?UINT32_MAX:(uint32_t)dt;afs_gap_add(&rearm_all,us);if(rearm_was_video)afs_gap_add(&rearm_video,us);rearm_pending=false;}}
 else gpio_ll_set_level(&GPIO,9,0);
 portEXIT_CRITICAL_ISR(&mux);
}
static esp_err_t queue_slot(unsigned i){
 dma_slot*q=&slots[i];assert(!(pipe_state.driver_mask&(1u<<i)));
 portENTER_CRITICAL(&mux);bool en=video_enabled;uint8_t rate=fps;uint32_t seq=last_seq,sess=session;portEXIT_CRITICAL(&mux);
 if(!q->cached||q->en!=en||q->rate!=rate||q->seq!=seq||q->session!=sess){
  afs_packet(q->tx,AFS_STATUS,sess,seq,0,NULL,0);q->tx[6]=en;q->tx[7]=rate;afs_put32(q->tx+1052,afs_crc(q->tx,1052));
  q->cached=true;q->en=en;q->rate=rate;q->seq=seq;q->session=sess;
  portENTER_CRITICAL(&mux);status_prepared++;portEXIT_CRITICAL(&mux);
 }
 q->trans=(spi_slave_transaction_t){.length=AFS_PACKET*8,.tx_buffer=q->tx,.rx_buffer=q->rx,.user=q};
 bool owned=afs_pipe_submit(&pipe_state,i);assert(owned);
 esp_err_t e=spi_slave_queue_trans(SPI2_HOST,&q->trans,0);
 if(e!=ESP_OK){bool returned=afs_pipe_reclaim(&pipe_state,i);assert(returned);portENTER_CRITICAL(&mux);queue_failures++;portEXIT_CRITICAL(&mux);}
 return e;
}
static void spi_task(void*arg){
 (void)arg;bool allocated=true;
 for(unsigned i=0;i<AFS_PIPE_SLOTS;i++){slots[i].rx=heap_caps_calloc(1,AFS_PACKET,MALLOC_CAP_DMA|MALLOC_CAP_INTERNAL);slots[i].tx=heap_caps_calloc(1,AFS_PACKET,MALLOC_CAP_DMA|MALLOC_CAP_INTERNAL);if(!slots[i].rx||!slots[i].tx)allocated=false;}
 for(int i=0;i<2;i++)frames[i]=heap_caps_malloc(AFS_WS,MALLOC_CAP_INTERNAL|MALLOC_CAP_8BIT);
 if(!allocated||!frames[0]||!frames[1]){ESP_LOGE(TAG,"FRAME_ALLOCATION_FAILED: SPI disabled; no PSRAM dependency");vTaskDelete(NULL);return;}
 gpio_set_level(GPIO_NUM_9,0);gpio_set_direction(GPIO_NUM_9,GPIO_MODE_OUTPUT);
 gpio_set_pull_mode(GPIO_NUM_10,GPIO_PULLUP_ONLY);
 spi_bus_config_t bus={.mosi_io_num=11,.miso_io_num=13,.sclk_io_num=12,.quadwp_io_num=-1,.quadhd_io_num=-1,.max_transfer_sz=AFS_PACKET};
 spi_slave_interface_config_t dev={.spics_io_num=10,.flags=0,.queue_size=AFS_PIPE_SLOTS,.mode=0,.post_setup_cb=ready_high,.post_trans_cb=ready_low};
 esp_err_t e=spi_slave_initialize(SPI2_HOST,&bus,&dev,SPI_DMA_CH_AUTO);if(e!=ESP_OK){ESP_LOGE(TAG,"SPI init failed %s",esp_err_to_name(e));vTaskDelete(NULL);return;}
 spi_available=true;int idx=0;afs_rx a;afs_reset(&a,session,frames[0]+AFS_HEADER);int64_t last=esp_timer_get_time();afs_generation generation={.session=session,.last=0,.seen=false};
 for(unsigned i=0;i<AFS_PIPE_SLOTS;i++){e=queue_slot(i);if(e!=ESP_OK)goto stopped;}
 for(;;){
  spi_slave_transaction_t *done=NULL;
  do{e=spi_slave_get_trans_result(SPI2_HOST,&done,pdMS_TO_TICKS(250));if(a.active&&esp_timer_get_time()-last>1000000){afs_timeout(&a);portENTER_CRITICAL(&mux);diag=a.diag;bad=a.bad;portEXIT_CRITICAL(&mux);}}while(e==ESP_ERR_TIMEOUT);
  if(e!=ESP_OK){break;}
  unsigned si=done==&slots[0].trans?0:done==&slots[1].trans?1:AFS_PIPE_SLOTS;
  if(!afs_pipe_reclaim(&pipe_state,si)){e=ESP_ERR_INVALID_STATE;break;}
  dma_slot*q=&slots[si];uint8_t*rx=q->rx;
  portENTER_CRITICAL(&mux);
   uint32_t bits=done->trans_len;last_bits=bits;if(bits>max_bits)max_bits=bits;
   txn_bins[bits==0?0:(bits%8?1:(bits<AFS_PACKET*8?2:(bits==AFS_PACKET*8?3:4)))]++;
   status_completed++;completed_status_session=q->session;completed_status_enable=q->en;
   portEXIT_CRITICAL(&mux);
   if(rx[5]>=AFS_BEGIN&&rx[5]<=AFS_CANCEL)last=esp_timer_get_time();
  // CRC-valid BEGIN from a restarted FPGA receives a fresh session challenge.
  if(done->trans_len==AFS_PACKET*8 && rx[5]==AFS_BEGIN && afs_crc(rx,1052)==afs_u32(rx+1052) &&
     afs_generation_begin(&generation,afs_u32(rx+8),afs_u32(rx+12),esp_random())){
   portENTER_CRITICAL(&mux);session=generation.session;last_seq=0;portEXIT_CRITICAL(&mux);
   a.session=generation.session;a.active=false;a.offset=0;
  }
  int result=afs_accept(&a,rx,done->trans_len/8);
  portENTER_CRITICAL(&mux);good=a.good;bad=a.bad;tests=a.tests;diag=a.diag;portEXIT_CRITICAL(&mux);
  if(result==1){afs_generation_accept(&generation,a.seq);publish_frame(&a,&idx);}
  e=queue_slot(si);if(e!=ESP_OK)break;
 }
stopped:
 // Never free or overwrite driver-owned descriptors/buffers. Suppress future READY
 // under the same lock as setup callback; already active transactions may finish.
 portENTER_CRITICAL(&mux);link_stopped=true;spi_available=false;video_enabled=false;gpio_ll_set_level(&GPIO,9,0);portEXIT_CRITICAL(&mux);
 ESP_LOGE(TAG,"SPI stopped: %s",esp_err_to_name(e));vTaskDelete(NULL);
}
void app_main(void){
 ESP_LOGW(TAG,"CANDIDATE: requires reviewed wiring before any future flash. Offline compilation is not hardware validation.");inspect_memory();session=esp_random();if(!session)session=1;
    /* Do not auto-erase existing NVS on an error. Preserve evidence instead. */
    esp_err_t err = nvs_flash_init();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "NVS init failed: %s. AP stopped; no automatic erase.", esp_err_to_name(err));
        return;
    }
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_t *ap = esp_netif_create_default_wifi_ap();
    assert(ap);
    ESP_ERROR_CHECK(esp_netif_dhcps_stop(ap));
    esp_netif_ip_info_t ip;
    ip.ip.addr = ESP_IP4TOADDR(192, 168, 4, 1);
    ip.gw.addr = ESP_IP4TOADDR(192, 168, 4, 1);
    ip.netmask.addr = ESP_IP4TOADDR(255, 255, 255, 0);
    ESP_ERROR_CHECK(esp_netif_set_ip_info(ap, &ip));
    ESP_ERROR_CHECK(esp_netif_dhcps_start(ap));
    wifi_init_config_t init = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&init));
    ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));
    wifi_config_t cfg = {.ap = {.ssid = BRINGUP_SSID, .password = BRINGUP_PASSWORD,
        .ssid_len = sizeof(BRINGUP_SSID) - 1, .channel = 6, .max_connection = 2,
        .authmode = WIFI_AUTH_WPA2_PSK, .pmf_cfg = {.required = false}}};
    _Static_assert(sizeof(BRINGUP_PASSWORD) >= 13 && sizeof(BRINGUP_PASSWORD) <= 64, "WPA2 password length");
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &cfg));
    ESP_ERROR_CHECK(esp_wifi_start());

 httpd_config_t http=HTTPD_DEFAULT_CONFIG();http.max_open_sockets=4;http.send_wait_timeout=1;http.recv_wait_timeout=1;http.stack_size=6144;http.close_fn=ws_close;
 ESP_ERROR_CHECK(httpd_start(&server,&http));
 const httpd_uri_t routes[]={
  {.uri="/api/diagnostics",.method=HTTP_GET,.handler=diagnostics_handler},
 {.uri="/",.method=HTTP_GET,.handler=page_handler},
 {.uri="/afs.js",.method=HTTP_GET,.handler=js_handler},
 {.uri="/api/status",.method=HTTP_GET,.handler=status_handler},
 {.uri="/api/control",.method=HTTP_POST,.handler=control_handler},
 {.uri="/ws",.method=HTTP_GET,.handler=ws_handler,.is_websocket=true,.ws_post_handshake_cb=ws_connected}};
 for(unsigned i=0;i<sizeof routes/sizeof routes[0];i++)ESP_ERROR_CHECK(httpd_register_uri_handler(server,&routes[i]));
 if(xTaskCreatePinnedToCore(spi_task,"spi_receive",6144,NULL,8,NULL,1)!=pdPASS)ESP_LOGE(TAG,"SPI task unavailable");
 ESP_LOGI(TAG,"WPA2 local page http://192.168.4.1; video disabled until page request; credentials in WIFI_LOCAL.txt");
}
