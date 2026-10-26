from pathlib import Path
import subprocess,ctypes,socket,hashlib,base64,struct,zlib,json
R=Path(__file__).resolve().parents[1];SDK=Path('D:/Espressif/v5.5.6/esp-idf');s=(R/'esp32/main/main.c').read_text()
network=s[s.index('// Network callbacks'):s.index('// IDF 5.5.6 invokes completion')]
glob=s[s.index('static int ws_fd=-1;'):s.index('extern const char page_start')].replace('static portMUX_TYPE mux=portMUX_INITIALIZER_UNLOCKED;','')
uri=(SDK/'components/esp_http_server/src/httpd_uri.c').read_text();branch=uri[uri.index('    if (uri->is_websocket && aux->ws_handshake_detect'):uri.index('#endif /* CONFIG_HTTPD_WS_SUPPORT */',uri.index('    if (uri->is_websocket && aux->ws_handshake_detect'))]
ws=(SDK/'components/esp_http_server/src/httpd_ws.c').read_text();sender=ws[ws.index('esp_err_t httpd_ws_send_frame_async('):ws.index('esp_err_t httpd_ws_get_frame_type(')]
stub=r'''#include <winsock2.h>
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
'''
tail=r'''
static esp_err_t dispatch(struct httpd_data*hd,httpd_uri_t*uri){httpd_req_t*req=&hd->hd_req;struct httpd_req_aux*aux=req->aux;
'''+branch+r'''
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
'''
p=R/'tests/ws_host_bridge.c';p.write_text(stub+sender+glob+network+tail)
dll=R/'logs/ws-host.dll';subprocess.run(['C:/msys64/ucrt64/bin/gcc.exe','-std=c11','-O2','-Wall','-Wextra','-Werror','-Wno-unused-variable','-shared','-I'+str(R/'protocol'),str(p),str(R/'protocol/afs.c'),'-lws2_32','-o',str(dll)],check=True)
h=ctypes.CDLL(str(dll));h.host_diag.restype=ctypes.c_char_p;h.host_handshake.argtypes=[ctypes.c_int,ctypes.c_char_p,ctypes.c_int];h.host_init()
def diag():return json.loads(h.host_diag())
def pair(legacy=False):
 listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen();client=socket.create_connection(listener.getsockname());server,_=listener.accept();listener.close();client.settimeout(2);server.settimeout(2)
 key=base64.b64encode(b'0123456789abcdef').decode();request=f'GET /ws HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n'.encode();client.sendall(request);assert server.recv(4096)==request
 accept=base64.b64encode(hashlib.sha1((key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode();response=f'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n\r\n'.encode()
 assert server.fileno()<2**31
 result=h.host_handshake(server.fileno(),response,int(legacy));raw=b''
 while not raw.endswith(b'\r\n\r\n'):raw+=client.recv(4096)
 assert raw==response
 return client,server,result
def exact(sock,n):
 b=b''
 while len(b)<n:
  x=sock.recv(n-len(b));assert x;b+=x
 return b
def frame(sock,seq):
 head=exact(sock,2);assert head==bytes([0x82,126]);n=struct.unpack('!H',exact(sock,2))[0];assert n==28832
 b=exact(sock,n);assert b[:4]==b'AFS1' and struct.unpack_from('<I',b,12)[0]==seq and zlib.crc32(b[:-4])==struct.unpack_from('<I',b,n-4)[0]
 assert b[28:-4]==bytes((i*37+i//320)&255 for i in range(28800));return b
events=[]
c,b,ret=pair(True);assert ret==0 and not diag()['network']['registered'];h.host_enable(1);h.host_frame(1);assert h.host_stat(0)==0 and h.host_stat(1)==1 and diag()['network']['drops_no_client_video_off_busy_work_queue_stale_send'][0]==1;h.host_close(b.fileno());b.close();c.close();events.append('legacy: real HTTP 101 succeeds but SDK dispatch skips URI handler; complete frame drops no_client')
c,b,ret=pair();assert ret==0 and diag()['network']['registered'];h.host_enable(1);h.host_limits(113,0,0);h.host_frame(2);h.host_frame(3);assert h.host_work()==1;payload=frame(c,2);assert h.host_stat(0)==1;events.append('fixed post-handshake registers; exact 28832-byte WS frame despite 113-byte short sends; busy frame drops without overwriting')
c2,b2,ret=pair();assert ret!=0;h.host_close(b2.fileno());b2.close();c2.close();assert diag()['network']['registered'];events.append('second client rejected without clearing primary')
h.host_frame(4);h.host_enable(0);h.host_work();assert h.host_stat(0)==1;h.host_enable(1);h.host_frame(5);h.host_same_fd_reconnect(b.fileno());h.host_enable(1);h.host_work();assert h.host_stat(0)==1;events.append('queued work drops after stop or same-fd new connection generation; cannot send stale frame to new session')
h.host_limits(0,0,1);h.host_frame(6);assert not h.host_work();h.host_limits(0,0,0);h.host_frame(7);h.host_work();frame(c,7);assert h.host_stat(0)==2;events.append('work queue failure releases buffer; next complete frame sends successfully')
h.host_limits(0,1,0);h.host_frame(8);h.host_work();assert not diag()['network']['registered'];b.close();c.close();h.host_limits(0,0,0)
c,b,ret=pair();assert ret==0;h.host_enable(1);h.host_frame(9);h.host_work();frame(c,9);h.host_close(b.fileno());b.close();c.close();assert not diag()['network']['registered'];events.append('send failure unregisters/pauses; reconnect and subsequent binary frame recover; close cleans registration')
d=diag();assert sum(d['network']['drops_no_client_video_off_busy_work_queue_stale_send'])==h.host_stat(1)
(R/'logs/ws-frame.bin').write_bytes(payload)
(R/'logs/websocket-integration.json').write_text(json.dumps({'status':'PASS','tests':events,'sent':h.host_stat(0),'dropped':h.host_stat(1),'diagnostics':d,'scope':'Real loopback TCP HTTP upgrade and WebSocket bytes; actual candidate network functions, actual IDF upgrade dispatch block and WS frame encoder. HTTP parser/session scheduler adapted by host harness; no lwIP, RF, device or physical throughput verification.'},indent=2))
print(json.dumps(events,indent=2))
