# 30Hz FPGA + WebSocket ESP32 队友交接（2026-10-26）

本目录是已实板显示完整画面的 30Hz 配对交付。KEY1 切三布局，KEY3 切 15 风格，WB=280/170/280。HDMI 为 1920×1080p30、74.25MHz、Htotal=2200、Vtotal=1125。不是 60Hz 版本。

**公开 Git 包暂不含最终 ESP app。** app 已原样集中在本地 `private/dist/esp32/artflow_wifi_stream.bin`；它内嵌热点密码，private 整目录被 Git 忽略。由负责人通过已确认的私下渠道交付，或取得明确的公开密码风险授权后另行处理。不要把旧 paired ZIP 中的 ESP 当作最终版本。不得为了脱敏修改已验收二进制或偷偷重编。

## 文件、版本与使用方式

|文件或基线|SHA256|用途|
|---|---|---|
|`fpga/ArtFlow.bit`（3340434 B）|7a3a0871530a8fed779fdfe53506fb74abbd6160c50e449252c3aeb67ba1fd30|30Hz 推流，JTAG 临时配置|
|`private/dist/esp32/artflow_wifi_stream.bin`（868208 B，本地）|b73af377e97f66b2656c07b0b30760564ec7466d260950ce6549ce3bb5dbf10e|最终 ESP app，diagnostic_version=3，build_id=websocket-20261026-v1|
|`esp32/bootloader/bootloader.bin`|110f4cc2898397f7c514fb18a2fc181795d3eb5bdb3b126c7e13921ca37606ed|匹配最终包，0x0|
|`esp32/partition_table/partition-table.bin`|5e71c3c890e04714daa03b21a0d23953a2dadf9fdf15eec02b886f7b6e9f8c81|匹配最终包，0x8000|
|主仓库 `bit/ArtFlow_styles15_p1p2_with_models.hex`|0c6e06b056a363671d8a1e34fb9bc43e34e8008667b63a46b2811786aa27a37f|用户确认 FPGA Flash 最后写入的非推流 15 风格镜像，本包不新增/改写它|
|原非推流 BIT（仅识别）|3edf836b23255f522da09efe3b1f1c141511f562a5c3ea567e93e68dd1238070|不能替代本目录 stream bit|
|现有模型（仅识别，不重新刷）|81b99fc11a2460669d672832d2fb3311319ee78edab25aed9c8ad44b0413b3da|Flash base=0x400000，length=245760 B|

`manifest.json` 是本次公开文件的实测长度/哈希；`provenance.json` 记录原路径。`evidence/fpga_original_manifest.json` 是历史完整构建记录，含未纳入本包的 HEX/模型引用，不是本包装箱清单。历史证据中的 hardware_programmed=false / offline 是当时离线构建状态；后来的用户实板确认见下文。

## 接线与电气边界

用户已导通确认 J28 与 J7 同号。FPGA master、ESP slave，3.3V 逻辑。

|J28/J7 针号|FPGA ball|方向（FPGA 视角）|ESP GPIO|信号|
|---|---|---|---|---|
|32|C5|输出|12|SCLK|
|34|A4|输出|11|MOSI|
|37|B3|输入|13|MISO|
|38|B5|输出|10|CS|
|39|C3|输入|9|READY|
|36|GND|公共地|GND|GND|

ESP 独立 USB 供电，不连接两板 3V3/5V。双方断电才改线，防单边上电反灌。不接 J6 配置 Flash（1.8V）。旧 bit 的引脚状态未知时应断开五根信号线；当前配对 stream bit 才使用上述接线。

## 上电、恢复 30Hz 与验收

1. 确认匹配 ESP 固件已装好、接线完成，使用支持 1080p30 的 HDMI 屏幕。另一块屏幕曾拒绝 30Hz，而独立 1080p60 彩条能亮，这不证明 stream 逻辑损坏。
2. 上电后用 Efinity Programmer 选择本包 `fpga/ArtFlow.bit` 做 **JTAG volatile configuration**。不要选择 Flash 编程或使用旧非推流 bit。JTAG 配置断电丢失；板上 Flash 上电运行非推流原版，因此不能宣称上电自动推流。
3. 手机加入 AP `ArtFlow-S3-Test-1025`，密码由负责人私下提供。选择保留“无互联网”连接，打开 http://192.168.4.1/ ，仅开一个页面。
4. 同时检查 `/api/status` 基础信息与 `/api/diagnostics` 新字段。确认 diagnostic_version=3、build_id=websocket-20261026-v1、network.registered=true。不能仅凭旧 status 字段断言烧了旧固件。
5. 默认 video off，先选 1 fps，再 enable。等待 3–5 秒录屏，保留画面和两个 JSON 区后 stop；不要要求三秒内完成截图。记录 complete_frames、sent 和各 drop 原因的前后差值。
6. 恢复到已验收 30Hz：停止视频；如无需更换 ESP 固件，只需在正确接线/供电条件下重新 JTAG 加载上述 hash 的 bit。若需要重装 ESP，执行下一节断电隔离流程，然后再 JTAG 加载。无需重刷模型，无新增 stream Flash 合并镜像。

默认关闭时 SPI 约 0.977MHz；enable 后实际 12.375MHz。fps 控制不改变 SPI 时钟。session echo 仅证明 FPGA 曾收到 STATUS/控制，不是 enable ACK；fpga_enable_ack_available=false 是能力说明，不是错误。TEST valid 本身不单独证明 MISO 正常。

## ESP 首装 / 仅更新 app（人工执行说明，本交接未执行）

ESP32-S3 rev0.2，物理 Flash 16MiB、PSRAM 8MiB，XMC JEDEC 20:7018。ESP-IDF 5.5.6、GCC 14.2.0、esptool 4.12.0，官方工具链。隔离 boot 的精确芯片 ID 兼容补丁是基于 issue 10999 调查的**本地补丁**，不是官方发布修复。

停止视频、关闭串口占用；两板断电，再断开五根信号线；ESP 单独 USB 连接后由队友枚举确认实际端口。COM17 仅为原机器示例，不能照抄。写入并独立 verify 后，两板断电恢复五线，再上电 JTAG 加载 stream。禁止 erase-all、eFuse/security 修改。此前用户取消备份，没有可靠可用于恢复的备份，勿使用残缺文件恢复。

先核验哈希，再将私下取得的 app 复制到 `esp32/artflow_wifi_stream.bin`（该路径也被 Git 忽略）。本目录中的 `print_flash_commands.py` 只打印命令，没有串口或进程调用，可供队友审查。参数 `--mode fresh --port COM17` 是首次装板，`--mode app-only --port COM17` 仅适用于已装匹配 boot/partition 的板。

以下 PowerShell 在 release 根目录人工执行；`$port` 必须改成已枚举确认端口。写入用 115200 和 stub 2，verify 单独使用 ROM no-stub。

```powershell
$py = 'C:\Espressif\tools\python\v5.5.6\venv\Scripts\python.exe'
$port = 'COM17' # 示例，必须核实
Set-Location .\esp32
# Fresh board: 完整 boot + partition + app
& $py -m esptool --chip esp32s3 --port $port --baud 115200 --stub-version 2 write_flash --flash_mode dio --flash_freq 40m --flash_size 16MB 0x0 bootloader/bootloader.bin 0x8000 partition_table/partition-table.bin 0x10000 artflow_wifi_stream.bin
& $py -m esptool --chip esp32s3 --port $port --baud 115200 --no-stub verify_flash 0x0 bootloader/bootloader.bin 0x8000 partition_table/partition-table.bin 0x10000 artflow_wifi_stream.bin
# App-only: 与上面二选一，仅已确认 boot/partition 匹配
& $py -m esptool --chip esp32s3 --port $port --baud 115200 --stub-version 2 write_flash --flash_mode dio --flash_freq 40m --flash_size 16MB 0x10000 artflow_wifi_stream.bin
& $py -m esptool --chip esp32s3 --port $port --baud 115200 --no-stub verify_flash 0x10000 artflow_wifi_stream.bin
```

原最终 README 的 app 命令未显式带 stub2/no-stub；这里按已验证安全约定补全。esptool 4.12.0 的 `--stub-version` 是隐藏参数，普通 help 不展示，已检查本机解析器接受此参数。不执行任何上述烧录命令。

## 调试时间线与故障分类

|阶段|现象/证据|结论与处理|
|---|---|---|
|初始 ESP bring-up|header=2MB，detected=16MB|是镜像头配置差异，不是硬件只有 2MB；核对 DIO/40MHz/16MB|
|XMC boot 兼容|写入和独立 ROM verify 成功仍启动失败|按精确 ID 使用隔离 boot 本地兼容补丁；不要误判为写入失败或反复擦全片|
|基础 Wi-Fi 彩条|手机显示合成图|只验证 Wi-Fi 网页链路，不代表 FPGA 摄像头图像已进入 ESP|
|旧串行单事务接收|模拟约 15 个 DATA 后 CANCEL；FPGA 8KiB FIFO 取消|ESP pipeline 双 DMA 提前 queue 改善 READY/rearm；不应把所有 CANCEL 归零当作已有事实|
|pipeline 实板|17 BEGIN / 15 END / 2 CANCEL；15 complete 但 dropped 同增、sent=0|SPI 已收到完整帧，网络另有问题；剩余 CANCEL 原因未定|
|WebSocket 修复|IDF 5.5.6 成功握手后不调用普通 URI handler，ws_fd 未登记|最终启用 post-handshake callback 注册会话；诊断版本 3；完整 WS 帧为 28832 B|
|最终目视|用户 2026-10-26 02:18 UTC+8 确认手机可看完整画面|证明配对显示成功；并非一分钟运动/长期稳定或 >=15FPS 验收|
|固定输入诊断|静图 CRC 1317cb88 / 085c4038 稳定，done 4117→4996 无错|只证明固定条件确定性，不证明摄像头是抖动唯一原因；诊断 bit 不在交付内|
|60Hz 分支|独立彩条可亮；完整 60Hz 尚未 route 成功|用户已取消，排除交付，不恢复开发|

完整 160×90 RGB565 为 28800 B，29 DATA（28×1024+128）再 END。BEGIN/CANCEL 增长而 END=0 表示不完整帧；complete 增长表示通过 SPI 整帧 CRC。若 network dropped 随 complete 增长且 sent=0，先看 registered 和 drop 分类，不假定任何黑屏都是握手故障。

registered=false 查注册/断线；send_attempts=0 查发送前门控；send 错误查 socket；sent 增长仍无图则查浏览器接收/解码。sent 只表示本地 socket API 接收字节，不是手机绘制 ACK；last_epoch 也不是显示确认。历史 zero bit length errors 要看增量，不能当 CRC；rearm_software_us 是 callback 间隔，不是精确管脚波形。

## 源码与构建说明

`source/fpga_project/fpga` 取自 wifi_stream_20261025 实际推流工程，169 项 implementation_source_sha256 与原证据全部匹配，工程 XML 中所有 design_file 均存在。同一组签核文件已整合到主仓库根目录，根 ArtFlow.xml 现对应 stream；板上 Flash 未改。附原约束、外围 XML、脚本和时序证据，Efinity 2026.1.132 / Ti60F225 I3。历史最小 setup=0.165ns、hold=0.026ns，外部 IO 仍为条件性约束结论，不等同新硬件测试。

在独立副本审查工具路径后，原流程为 `BuildFPGA.ps1 -Phase Tests`、`-Phase Map`、`-Phase Physical`；脚本引用 C:\Python314、Node、Efinity 安装位置和既有报告，移机需适配并补齐生成依赖。本次只保存源身份与现有证据，未运行 FPGA 构建，也不承诺移机一键重建或 bit 逐字节一致。不要在主仓库旧 RTL 上运行这些指令，也不要复用 60Hz 工程。

`source/esp_project` 取自最终 websocket 目录。源码不含 wifi_credentials.h / WIFI_LOCAL.txt，需负责人安全提供原凭据头文件到 `esp32/main/` 后才是原配套输入；不要凭空生成密码。`Activate.ps1` 通过官方 EIM profile 设置仅当前进程环境，队友需调整安装路径；`Build.ps1` 调用 `idf.py -B build-xmc build`。本地 bootloader_components 和 main/xmc_compat 保留原补丁。重建产物时间/路径可变，必须重新核对身份并另行验收，不能覆盖原已验证 app。

离线验证入口在 tests（WebSocket、diagnostics、browser）；本包保留历史结果，并在 evidence/integration 保存本次重新执行的定向根工程与最终 ESP 离线结果。安全包校验入口 `python verify_release.py` 只读本地文件，检查公开 manifest。`provenance.json` 的绝对路径用于追溯，不要求队友机器存在该路径。

## 团队交接 checklist

- [ ] 核对 manifest、FPGA/app hash 与诊断 build_id；从负责人取得含密码的原 app/凭据，勿公开上传。
- [ ] 核对电平、六线表和供电；换线先双断电，刷 ESP 前断五信号。
- [ ] 新板完整 boot/partition/app；更新板先确认已有 boot/partition；写和 verify 分开。
- [ ] 使用支持 30Hz 屏幕，重新 JTAG 加载 stream；不重刷模型、不生成合并 Flash。
- [ ] 一个网页、1fps、wait 3–5 秒，录画面及两个 JSON 区，stop；记计数增量。
- [ ] 后续补一分钟运动和稳定性验证，分档验证 fps；失败保留症状/版本/计数/时间，按层归因。

## 敏感文件与发布状态

仓库 origin=https://github.com/xinyin12345/ArtFlow.git，public，master；整理前本地和远端均为 04d865eaaa538f422d289a594a326dd00ed5fca4，工作区干净。密码精确字节扫描命中最终源码凭据文件、app BIN、ELF、静态库/对象以及 ZIP 内条目；这些敏感类别未纳入公开清单。公开清单做已知密码精确匹配和常见 token/private-key 模式检查，不能声称穷尽所有未知秘密。

不提交 private、app、ELF/MAP/ZIP、编译缓存。若以后要公开现有 app，必须单独确认向这个公开仓库暴露内嵌密码的风险；若改密码重编，则是新候选固件，需重新验收。本次不擅自改密。主仓库其他已有文件/历史不属于本次全历史秘密审计范围。


## 本次根工程整合验证记录

根目录 169 项签核源全部匹配；13 项签核输入相对原 master 有变化（部分只有换行差异）。新建根 BuildStream.ps1：Check、Tests、EspTests、OriginalTests、Map、Physical；后三项长流程本次未运行。未来重建在独立干净副本中依次 Tests、EspTests、OriginalTests、Map、Physical，工具路径按本机安装调整。已有 work 产物或锁会停止流程，不自动清理。

本次执行 Tests：12 种 C 协议向量、RTL SPI 完整帧/CRC/取消/复位恢复、2 帧 RTL→C 与 28800 像素核对、50 个异步复位位置、11 类 tap 选择/坐标/tag/error；全部通过。tap 为局部强制信号测试，52 条端口未连接警告，零错误，不能当完整视频系统回归。本次 EspTests：14 类诊断与 12 个旧场景字节一致、6 组真实 loopback WebSocket 场景和最终网页解码/断连/停止恢复均通过。重新校验当前测试源绑定通过。

首轮根 Tests 缺协议向量导致 watchdog，已修正入口先生成向量后重跑通过；ESP diagnostics 首轮保留旧相邻目录名，已改为本包 fpga_project 后通过。仅测试脚本路径适配，应用/RTL 签核内容未改。原主仓库较强构建锁、证据绑定与工具环境覆盖予以保留。未经综合/P&R/实板再验证，不声称整合后新 build 通过。

`provenance.json` 保留复制来源 hash；测试脚本路径适配后的当前 hash 见 manifest.json。private app 未改，hash 仍匹配；公开 Git 包仍需另行安全取得 app 才能首装。

签核源保留原始空白字节，git diff --check 在原外围 XML/IP 版权头及旧工具 EOF 上报告既有空白；为保持源 hash 未格式化这些文件。
