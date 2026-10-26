from pathlib import Path
import json,hashlib,difflib,zipfile
R=Path('D:/work/FPGA/ArtFlow/Process/wifi_stream_websocket_20261026');S=R.parent/'wifi_stream_pipeline_20261026';O=R.parent/'wifi_stream_20261025';D=R/'dist/esp32'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(S/'dist/esp32/artflow_wifi_stream.bin')=='9f34d2951ba0aa059670a5f48b9a1870b9fd9a25e9d7493ee91787caa9cee2af'
assert sha(S/'esp-stream-pipeline-local.zip')=='e4e1ea055a1668bcf7fe4f7759916710e13284b1d5f7aabe5d4881640980510c'
assert sha(O/'dist/fpga/ArtFlow.bit')=='7a3a0871530a8fed779fdfe53506fb74abbd6160c50e449252c3aeb67ba1fd30'
assert sha(O/'wifi-stream-paired-local.zip')=='c18b9c61bf152ead66931809380f1a269a4aac8bd19837400b1d52168cc4a112'
old_diag=R.parent/'wifi_stream_diagnostics_20261025';assert sha(old_diag/'esp-stream-diagnostics-local.zip')=='5959d4c9487c0010d04ef5e79c0e93fdad52c1e2e4a5e758b8ec8e8d9e3c6ad1'
assert (D/'partition_table/partition-table.bin').read_bytes()==(S/'dist/esp32/partition_table/partition-table.bin').read_bytes()
for p in (R/'protocol').glob('*'):
 if p.is_file():assert p.read_bytes()==(S/'protocol'/p.name).read_bytes(),p
for p in (R/'esp32/bootloader_components').rglob('*'):
 if p.is_file():assert p.read_bytes()==(S/p.relative_to(R)).read_bytes()
old=(S/'esp32/main/main.c').read_text();new=(R/'esp32/main/main.c').read_text();start='// IDF 5.5.6 invokes completion';end='static void spi_task('
assert old[old.index(start):old.index(end)]==new[new.index(start):new.index(end)]
def config(p):return {x.split('=',1)[0]:x.split('=',1)[1] for x in p.read_text().splitlines() if x.startswith('CONFIG_') and '=' in x}
a=config(S/'esp32/sdkconfig');b=config(R/'esp32/sdkconfig');delta={k:[a.get(k),b.get(k)] for k in a.keys()|b.keys() if a.get(k)!=b.get(k)}
assert delta=={'CONFIG_HTTPD_WS_POST_HANDSHAKE_CB_SUPPORT':[None,'y']},delta
diff=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='pipeline/main.c',tofile='websocket/main.c'));(R/'logs/network-source.diff').write_text(diff,encoding='utf-8')
sdk=Path('D:/Espressif/v5.5.6/esp-idf/components/esp_http_server/src');proof={'idf':'5.5.6','source_sha256':{n:sha(sdk/n) for n in ['httpd_uri.c','httpd_ws.c','httpd_sess.c','httpd_txrx.c']},'root_cause':'httpd_uri.c:339-365 successful WS upgrade calls optional post-handshake callback then returns without invoking uri->handler; previous app only registered ws_fd in handler GET branch','fix':'Enable official post-handshake callback; register only after valid WS session; close callback unregisters and closes socket','additional_send_evidence':'httpd_ws.c:411-466 calls session send_fn once for header and once for payload; send override completes short positive writes before successful return','config_delta':delta,'pipeline_callbacks_queue_helper_byte_identical':True,'protocol_all_files_identical':True}
(R/'logs/httpd-source-review.json').write_text(json.dumps(proof,indent=2))
readme=r'''# WebSocket 修复候选 websocket-20261026-v1

已离线编译、回环集成验证，未烧录、访问 COM/JTAG/设备 WiFi 或操作 FPGA。原 pipeline-v1、诊断版、流媒体版与旧 ZIP/FPGA bit 保留且已核对哈希。

## 已确认的故障和改动

本机官方 IDF 5.5.6 httpd_uri.c 第 339–365 行在成功 WebSocket 握手后直接返回，不调用普通 URI handler。旧程序只在 handler 的 GET 分支登记 ws_fd，因此浏览器握手成功并显示“已连接”，ESP 仍认为没有客户端，完整帧在进入发送队列前全部丢弃。这与实板 complete_frames=network_dropped、sent=last_epoch=0 一致，且已离线复现。
改为启用 CONFIG_HTTPD_WS_POST_HANDSHAKE_CB_SUPPORT=y，并在官方握手后回调登记。GET 路由本身保留；普通未升级的 /ws 请求拒绝。关闭回调负责取消登记并关闭 socket，断连后视频关闭；拒绝额外客户端不会清除当前客户端。发送任务绑定提交时的 fd 和连接代次，停止或重连后旧任务只丢弃/释放自身缓冲，不误发给新连接。
另核查到 IDF WebSocket 编码器对 send_fn 的短正返回不自行补全。只为升级后的 WS 会话设置 send override，循环补全短写，零/错误/超时失败关闭会话。每次 header/payload 回调使用 1 秒软件期限，底层 send_wait_timeout 仍为 1 秒；一次阻塞 send 可能跨过软件期限，不能称严格 1 秒墙钟上限。SPI 任务不执行 socket send，不引入全帧新分配；仍保留两帧邮箱，慢消费者丢新整帧。
接收流水化/READY 回调与 queue_slot 函数逐字节一致；protocol 下全部文件一致。SPI 引脚、速率、模式、默认 video off、XMC 补丁、图像尺寸/协议、FPGA bit 均不改。sdkconfig 唯一有效配置变化是打开上述官方回调选项。

实板已有证据为 17 BEGIN、15 END、2 CANCEL；两次 CANCEL 原因未确认，不能说 FIFO 已彻底根治。本候选只针对完整帧全部网络丢弃的已确认缺陷。

## 接口及计数

http://192.168.4.1/ 为主页。
http://192.168.4.1/api/status 保留既有字段。
http://192.168.4.1/api/diagnostics 新增 network 对象，应有 diagnostic_version=3、build_id="websocket-20261026-v1"。不要在 /api/status 查新诊断字段。
network.registered 表示应用已登记 WS；client_fd/generation 标识本地连接，registrations/unregistrations/extra_clients_rejected 为累计事件，send_attempts 表示发送工作已通过当前客户端和启用条件，last_send_error 仅是最近失败码，成功不自动清零。
network.drops_no_client_video_off_busy_work_queue_stale_send 六项按顺序是：无登记客户端、视频关闭、发送缓冲忙、HTTP 工作排队失败、排队后停止/连接代次改变、socket/WS发送失败。分类互斥，合计等于 network_dropped。无客户端优先于视频关闭；停止后的尾帧正常可能计 video_off 或 stale。
complete_frames：通过 SPI 整帧 CRC 的完整帧；network_dropped：没有交给本次客户端完整发送的帧；sent：完整 WebSocket 字节已由本地 socket API 接受，不代表手机已绘制或 ACK；last_epoch：仍按原逻辑在成功取得发送邮箱时更新，不是浏览器确认。队列失败也可能留下已更新的 last_epoch。
此前“15 complete/15 dropped/0 sent/0 epoch”通过源码可对应无客户端入口分支；新分类用于避免后续误判。旧 rearm_software_us 仍为软件回调间隔，不是精确管脚波形。

## 可执行验证和边界

tests/run_websocket.py：仅使用 127.0.0.1 的真实 TCP 连接，发送/核验 HTTP Upgrade 和 101 响应；编译执行实际候选网络函数、官方 IDF 升级分支和 WebSocket 编码器。验证旧握手成功但未登记的故障、新登记与 28832 字节完整 WS 帧、强制每次短写 113 字节、慢消费者邮箱不覆盖、第二客户端拒绝、停止、同 fd 新代次、队列失败、发送失败、断连重连与恢复。HTTP 请求解析/会话调度由宿主适配器代替，不能声称完整 lwIP/FreeRTOS/RF 或实板性能已验证。
tests/browser_test.js：用交付网页的真实解码器处理从回环收到的帧，CRC、RGB565→RGBA、重复/坏帧、断连/重连、停后迟到帧、恢复和超时清图测试通过。
tests/run_diagnostics.py：14 类拒收测试及原 12 场景对旧接收器的计数/输出字节比较通过。
logs/websocket-integration.json、browser-tests.log、diagnostics-tests.json、httpd-source-review.json、network-source.diff、build.log 和 dist/esp32/manifest.json 为证据。
编译：esp32/Build.ps1。测试：python tests/run_websocket.py；python tests/run_diagnostics.py；node tests/browser_test.js。包清单生成：python scripts/package_websocket.py。只改变当前进程环境，不改共享 SDK。

## 手动只刷应用（以下命令未由本任务执行）

分区表与已安装的配套 pipeline/诊断版逐字节一致，factory 位于 0x10000、大小 0x200000。复用当前兼容 boot/分区即可，不需要更新 FPGA、bootloader 或模型。保留备份。端口 COM17 为之前用户确认值，当前使用前由用户核实。
仍遵守已确认的断电接线流程：停止视频、关闭串口工具、两板断电再断开五根信号线；ESP 单独供电刷写。不要热拔信号或单侧反灌。刷后两板断电接回、再上电并重新加载原临时 FPGA stream bit，不能将临时 JTAG 状态当断电后仍保留。

```powershell
cd D:\work\FPGA\ArtFlow\Process\wifi_stream_websocket_20261026\esp32
. .\Activate.ps1
$py = "$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe"
cd ..\dist\esp32
& $py -m esptool --chip esp32s3 --port COM17 --baud 115200 write_flash --flash_mode dio --flash_freq 40m --flash_size 16MB 0x10000 artflow_wifi_stream.bin
& $py -m esptool --chip esp32s3 --port COM17 --baud 115200 verify_flash 0x10000 artflow_wifi_stream.bin
```

## 一次验收

连接本地 ArtFlow-S3-Test-1025，刷新主页，确认 diagnostics 版本 3/build_id、network.registered=true、registrations>=1，视频默认 false。只保留一个浏览器页面，避免额外 WS 客户端干扰。
HDMI 原图+风格双窗口正常后，启用 1 fps 一次，约 3–5 秒内观察手机是否显示真实连续风格图。启用期间保存 /api/status 与 /api/diagnostics，随后停止。预期 complete_frames、send_attempts、sent 增长，no_client 不继续增加；实际画面和帧号变化才是手机显示证据。
若仍黑屏：保留 network 分类及 send_attempts/sent 与网页提示，不反复改硬件；registered=false 指向登记/断连，send_attempts=0 指向入口门控，send 错误指向 socket，sent增长但页面无图才转查浏览器解码。允许停止尾部 CANCEL，不能未经证据归因。

官方 ESP-IDF 5.5.6 / GCC 14.2.0 / esptool 4.12.0；应用 16MB、DIO40MHz、最低芯片 revision0.0，镜像校验有效。新构建 boot 含时间/路径变化，不冒称旧实板验证镜像；本操作建议只刷应用。
ZIP 含本地热点凭据，勿公开上传。本候选尚无实板修复成功证据。
'''
(R/'README.md').write_text(readme,encoding='utf-8')
files=[R/'README.md',R/'scripts/package_esp.py',R/'scripts/package_websocket.py']
for folder in ['esp32','protocol','tests','dist','logs']:
 for p in (R/folder).rglob('*'):
  if p.is_file() and not any(x in ['build','build-xmc','__pycache__'] for x in p.relative_to(R).parts):files.append(p)
m={'status':'PASS_OFFLINE_ONLY','build_id':'websocket-20261026-v1','hardware_tested':False,'app_bytes':(D/'artflow_wifi_stream.bin').stat().st_size,'app_sha256':sha(D/'artflow_wifi_stream.bin'),'partition_exact_match':True,'config_delta':delta,'prior_deliverables_hashes_verified':True,'pipeline_callbacks_queue_helper_unchanged':True,'files':{str(p.relative_to(R)):sha(p) for p in files}}
(R/'MANIFEST.json').write_text(json.dumps(m,indent=2))
z=R/'esp-stream-websocket-local.zip'
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as out:
 for p in files+[R/'MANIFEST.json']:out.write(p,p.relative_to(R))
with zipfile.ZipFile(z) as out:
 assert out.testzip() is None
 for n,h in m['files'].items():assert hashlib.sha256(out.read(n.replace(chr(92),'/'))).hexdigest()==h
print(json.dumps({'app_bytes':m['app_bytes'],'app_sha256':m['app_sha256'],'zip_bytes':z.stat().st_size,'zip_sha256':sha(z),'boot_sha256':sha(D/'bootloader/bootloader.bin'),'partition_sha256':sha(D/'partition_table/partition-table.bin')},indent=2))
