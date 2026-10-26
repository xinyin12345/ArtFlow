#include <winsock2.h>
#include <windows.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <inttypes.h>
#include <errno.h>
#include <assert.h>
#include "afs.h"
#include "afs_mailbox.h"
#include "afs_pipeline.h"
#define API __declspec(dllexport)
#define ESP_OK 0
#define ESP_FAIL -1
#define ESP_ERR_INVALID_ARG -2
#define ESP_ERR_NO_MEM -3
#define HTTP_GET 1
#define HTTPD_400_BAD_REQUEST 400
#define HTTPD_WS_CLIENT_WEBSOCKET 2
#define HTTPD_WS_CLIENT_HTTP 1
#define HTTPD_WS_TYPE_BINARY 2
#define HTTPD_WS_FIN_BIT 128
#define HTTPD_WS_CONTINUE 0
#define HTTPD_WS_MASK_BIT 128
#define CONFIG_HTTPD_WS_POST_HANDSHAKE_CB_SUPPORT 1
#define LOG_FMT(x) x
#define ESP_LOGD(...) ((void)0)
#define ESP_LOGW(...) ((void)0)
#define portENTER_CRITICAL(x) ((void)0)
#define portEXIT_CRITICAL(x) ((void)0)
typedef int esp_err_t;typedef void* httpd_handle_t;
typedef struct {int unused;} spi_slave_transaction_t;
typedef struct {bool final,fragmented;int type;uint8_t*payload;size_t len;} httpd_ws_frame_t;
struct sock_db;
struct httpd_req_aux {bool ws_handshake_detect;struct sock_db*sd;};
typedef struct {int method,fd;void*handle;struct httpd_req_aux*aux;} httpd_req_t;
typedef struct {bool is_websocket,handle_ws_control_frames;int method;const char*supported_subprotocol;void*user_ctx;esp_err_t(*handler)(httpd_req_t*);esp_err_t(*ws_post_handshake_cb)(httpd_req_t*);} httpd_uri_t;
struct httpd_data {httpd_req_t hd_req;};
struct sock_db {int fd;bool valid,ws_handshake_done,ws_close,ws_control_frames;void*ws_user_ctx;esp_err_t(*ws_handler)(httpd_req_t*);int(*send_fn)(httpd_handle_t,int,const char*,size_t,int);};
static struct sock_db sessions[8];static const char*response;static char json_out[3072];
static void*server;static unsigned short_limit;static bool send_failure,work_failure;static void(*pending)(void*);static void*pending_arg;
static int64_t esp_timer_get_time(void){return (int64_t)GetTickCount64()*1000;}
static struct sock_db*httpd_sess_get(httpd_handle_t h,int fd){(void)h;for(int i=0;i<8;i++)if(sessions[i].valid&&sessions[i].fd==fd)return &sessions[i];return NULL;}
static int native_send(int fd,const char*b,size_t n,int flags){if(send_failure){errno=EPIPE;return -1;}if(short_limit&&n>short_limit)n=short_limit;return send((SOCKET)fd,b,(int)n,flags);}
#define send native_send
static int default_send(httpd_handle_t h,int fd,const char*b,size_t n,int flags){(void)h;return native_send(fd,b,n,flags);}
static int httpd_req_to_sockfd(httpd_req_t*r){return r->fd;}
static int httpd_ws_get_fd_info(httpd_handle_t h,int fd){struct sock_db*d=httpd_sess_get(h,fd);return d&&d->ws_handshake_done&&!d->ws_close?2:d?1:0;}
static int httpd_sess_set_send_override(httpd_handle_t h,int fd,int(*fn)(httpd_handle_t,int,const char*,size_t,int)){struct sock_db*d=httpd_sess_get(h,fd);if(!d)return -1;d->send_fn=fn;return 0;}
static int httpd_ws_recv_frame(httpd_req_t*r,httpd_ws_frame_t*f,size_t n){(void)r;(void)f;(void)n;return -1;}
static int httpd_resp_send_err(httpd_req_t*r,int code,const char*b){(void)r;(void)code;(void)b;return -1;}
static int httpd_resp_set_type(httpd_req_t*r,const char*s){(void)r;(void)s;return 0;}
static int httpd_resp_set_hdr(httpd_req_t*r,const char*s,const char*v){(void)r;(void)s;(void)v;return 0;}
static int httpd_resp_send(httpd_req_t*r,const char*s,int n){(void)r;assert(n<3072);memcpy(json_out,s,n);json_out[n]=0;return 0;}
static int stub_close(int fd){struct sock_db*d=httpd_sess_get(NULL,fd);if(d)d->valid=false;return 0;}
#define close stub_close
static int httpd_sess_trigger_close(httpd_handle_t h,int fd){(void)h;return stub_close(fd);}
static int httpd_queue_work(httpd_handle_t h,void(*fn)(void*),void*arg){(void)h;if(work_failure)return -1;assert(!pending);pending=fn;pending_arg=arg;return 0;}
static int httpd_ws_respond_server_handshake(httpd_req_t*r,const char*p){(void)p;size_t n=strlen(response),used=0;while(used<n){int v=native_send(r->fd,response+used,n-used,0);if(v<=0)return -1;used+=v;}return 0;}
esp_err_t httpd_ws_send_frame_async(httpd_handle_t hd, int fd, httpd_ws_frame_t *frame)
{
    if (!frame) {
        ESP_LOGW(TAG, LOG_FMT("Argument is invalid"));
        return ESP_ERR_INVALID_ARG;
    }

    /* Prepare Tx buffer - maximum length is 14, which includes 2 bytes header, 8 bytes length, 4 bytes mask key */
    uint8_t tx_len = 0;
    uint8_t header_buf[10] = {0 };
    /* Set the `FIN` bit by default if message is not fragmented. Else, set it as per the `final` field */
    header_buf[0] |= (!frame->fragmented) ? HTTPD_WS_FIN_BIT : (frame->final? HTTPD_WS_FIN_BIT: HTTPD_WS_CONTINUE);
    header_buf[0] |= frame->type; /* Type (opcode): 4 bits */

    if (frame->len <= 125) {
        header_buf[1] = frame->len & 0x7fU; /* Length for 7 bits */
        tx_len = 2;
    } else if (frame->len > 125 && frame->len < UINT16_MAX) {
        header_buf[1] = 126;                /* Length for 16 bits */
        header_buf[2] = (frame->len >> 8U) & 0xffU;
        header_buf[3] = frame->len & 0xffU;
        tx_len = 4;
    } else {
        header_buf[1] = 127;                /* Length for 64 bits */
        uint8_t shift_idx = sizeof(uint64_t) - 1; /* Shift index starts at 7 */
        uint64_t len64 = frame->len; /* Raise variable size to make sure we won't shift by more bits
                                      * than the length has (to avoid undefined behaviour) */
        for (int8_t idx = 2; idx <= 9; idx++) {
            /* Now do shifting (be careful of endianness, i.e. when buffer index is 2, frame length shift index is 7) */
            header_buf[idx] = (len64 >> (shift_idx * 8)) & 0xffU;
            shift_idx--;
        }
        tx_len = 10;
    }

    /* WebSocket server does not required to mask response payload, so leave the MASK bit as 0. */
    header_buf[1] &= (~HTTPD_WS_MASK_BIT);

    struct sock_db *sess = httpd_sess_get(hd, fd);
    if (!sess) {
        return ESP_ERR_INVALID_ARG;
    }

    /* Send off header */
    if (sess->send_fn(hd, fd, (const char *)header_buf, tx_len, 0) < 0) {
        ESP_LOGW(TAG, LOG_FMT("Failed to send WS header"));
        return ESP_FAIL;
    }

    /* Send off payload */
    if(frame->len > 0 && frame->payload != NULL) {
        if (sess->send_fn(hd, fd, (const char *)frame->payload, frame->len, 0) < 0) {
            ESP_LOGW(TAG, LOG_FMT("Failed to send WS payload"));
            return ESP_FAIL;
        }
    }

    return ESP_OK;
}

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

static esp_err_t dispatch(struct httpd_data*hd,httpd_uri_t*uri){httpd_req_t*req=&hd->hd_req;struct httpd_req_aux*aux=req->aux;
    if (uri->is_websocket && aux->ws_handshake_detect && uri->method == HTTP_GET) {
#ifdef CONFIG_HTTPD_WS_PRE_HANDSHAKE_CB_SUPPORT
        if (uri->ws_pre_handshake_cb && uri->ws_pre_handshake_cb(req) != ESP_OK) {
            ESP_LOGW(TAG, LOG_FMT("ws_pre_handshake_cb failed"));
            return ESP_FAIL;
        }
#endif /* CONFIG_HTTPD_WS_PRE_HANDSHAKE_CB_SUPPORT */

        ESP_LOGD(TAG, LOG_FMT("Responding WS handshake to sock %d"), aux->sd->fd);
        esp_err_t ret = httpd_ws_respond_server_handshake(&hd->hd_req, uri->supported_subprotocol);
        if (ret != ESP_OK) {
            return ret;
        }

        aux->sd->ws_handshake_done = true;
        aux->sd->ws_handler = uri->handler;
        aux->sd->ws_control_frames = uri->handle_ws_control_frames;
        aux->sd->ws_user_ctx = uri->user_ctx;

#ifdef CONFIG_HTTPD_WS_POST_HANDSHAKE_CB_SUPPORT
        if (uri->ws_post_handshake_cb && uri->ws_post_handshake_cb(req) != ESP_OK) {
            ESP_LOGW(TAG, LOG_FMT("ws_post_handshake_cb failed"));
            return ESP_FAIL;
        }
#endif /* CONFIG_HTTPD_WS_POST_HANDSHAKE_CB_SUPPORT */
        /* If the request is websocket handshake, then do not call the uri->handler */
        return ESP_OK;
    }

return uri->handler(req);}
API void host_init(void){for(int i=0;i<2;i++)frames[i]=calloc(1,AFS_WS);session=123;}
API int host_handshake(int fd,const char*headers,int legacy){struct sock_db*d=NULL;for(int i=0;i<8;i++)if(!sessions[i].valid){d=&sessions[i];break;}assert(d);*d=(struct sock_db){.fd=fd,.valid=true,.send_fn=default_send};response=headers;
 struct httpd_req_aux aux={.ws_handshake_detect=true,.sd=d};struct httpd_data hd={.hd_req={.method=HTTP_GET,.fd=fd,.aux=&aux}};
 httpd_uri_t route={.is_websocket=true,.method=HTTP_GET,.handler=ws_handler,.ws_post_handshake_cb=legacy?NULL:ws_connected};return dispatch(&hd,&route);}
API void host_enable(int enabled){video_enabled=enabled;}
API void host_frame(unsigned seq){int idx=mailbox.current;afs_rx a={.seq=seq,.image=frames[idx]+AFS_HEADER};for(unsigned i=0;i<AFS_IMAGE;i++)a.image[i]=(uint8_t)(i*37+i/320);good++;publish_frame(&a,&idx);}
API int host_work(void){if(!pending)return 0;void(*f)(void*)=pending;void*a=pending_arg;pending=NULL;f(a);return 1;}
API const char*host_diag(void){diagnostics_handler(NULL);return json_out;}
API unsigned host_stat(int which){switch(which){case 0:return sent;case 1:return dropped;case 2:return last_seq;case 3:return good;default:return 0;}}
API void host_close(int fd){ws_close(NULL,fd);}
API void host_limits(unsigned limit,int fail,int queuefail){short_limit=limit;send_failure=fail;work_failure=queuefail;}
API void host_same_fd_reconnect(int fd){ws_forget(fd);httpd_req_t r={.fd=fd};assert(ws_connected(&r)==0);}
