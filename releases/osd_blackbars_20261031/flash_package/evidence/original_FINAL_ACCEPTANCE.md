# ArtFlow OSD 最终离线验收

状态：**PASS，bit 可供用户手动上板验证**。生成时间（UTC）：2026-10-30T20:04:02.158959+00:00。
尚未做实板验收；未执行 JTAG、Flash 烧录、ESP 固件操作、Git 提交或推送。

## 文件与版本

- 独立候选：`D:\work\FPGA\ArtFlow\Process\osd_blackbars_20261030`
- bit 完整路径：`D:\work\FPGA\ArtFlow\Process\osd_blackbars_20261030\outputs\ArtFlow_osd_blackbars_20261030.bit`
- 大小：3,313,848 字节
- SHA256：`8ff3f2565d92b7f9e4092d06513b8cefbc771ae21a2bc81f1458ba0fc31d1e50`
- 主工程基线：`4473983390d7009be06fc6f5fdb5ad54fe4bce03`
- 源码快照：`2ff488897f6144d76218a43584ac846db34fd36de06d730af848950a8ecd36e6`，共 242 项实现输入。
- 1078 项主工程基线哈希、479 项模型相关文件再次核验一致；主工程、模型和原始 XML/SDC/periphery 约束未修改。
- 73 项设计入口及最终综合网表均排除手势实验；此前远程负责人已确认交接，现场只有本次构建负责。

## 最终资源与物理结果

| 项目 | 最终结果 | 相对主工程基线 |
|---|---:|---:|
| LUT4 | 38,530 | -191 |
| FF | 25,807 | +4 |
| ADD | 6,672 | +1 |
| SRL8 | 2,065 | 不变 |
| XLR | 58,112 / 60,800（95.58%） | -174 |
| RAM | 253 / 256（246 RAM10 + 7 DPRAM10） | 不变 |
| DSP | 144 / 160（143 DSP48 + 1 DSP12） | 不变 |
| 合法布线 | PASS，第 46 轮重叠数为 0 | 无未解决重叠 |
| 最终 setup 最小裕量 | +0.313 ns | 原始约束 |
| 最终 hold 最小裕量 | +0.026 ns | 原始约束 |

工具：Efinity 2026.1.132，器件 Ti60F225，I3 时序模型。
最终综合为 speed / 16 线程；PNR 为 TIMING_3、seed 2、placer effort 5、16 线程。
整机最终 STA 检查十个适用时钟的 setup/hold、所有报告边沿关系及负裕量；使用最终布线报告，未将 PLL 接口报告作为整机结果，也未放宽原始 SDC。
适用 CDC：video、CNN、UI、native return RAM 和新增 OSD 握手数据路径全部通过。
SPI/ESP 接口路径预算通过；外部线延迟、器件启动延迟等仍采用现有文档假设，需要实板确认。ESP 预算采用 wire=4 ns、launch=25 ns、setup margin=2 ns。

## 测试清单

**通过**

- 新版字库 13 帧、26,956,800 像素与独立金模完全一致，视频时序比较 27,027,156 周期。
- 13 帧哈希及 14 张预览 PNG 哈希与原 CAP/OUT 版本全部一致；没有重新上传预览。
- 真实 TMDS 输入 VS 上升沿计数：8 个窗口、30 项检查，覆盖宽 VS 单次计数、29/30/31、冻结时 OUT=30、停止 VS 时 OUT=0。
- FPS、UI、三种布局、8 风格顺序及标签、OSD 开关、冻结/创意控制、系统、SPI/WebSocket/浏览器协议回归均通过。未受源码变更影响的证据在逐项核对源码与报告哈希后复用。
- 系统回归记录一次启动下溢，与主基线一致；不是全程零下溢。
- 合法布局布线、最终 setup/hold、适用 CDC/接口路径检查、bit/hex 生成与哈希核验均通过。

**失败及恢复记录**

- 历史构建曾多次因拥塞自然失败；重复轨迹、策略切换和无效 NULL 参数导致的主动结束分别记录，未伪称自然失败。
- 所有现场保留在 `work/`，原因与路径见 `reports/local_attempt*_result.json`、`reports/compact_attempt*_result.json` 和接管记录。
- 最终交付版本无未解决的功能或物理门禁失败。

**未执行**

- 实板画质、真实摄像头 CAP 速率、真实 HDMI OUT 速率、长时间稳定性与外部 SPI 电气裕量。
- JTAG、Flash 或 ESP 烧录；Git 提交与推送。

## 与主工程的差异

OSD 移入双窗口上下空区：ARTFLOW 标题、当前模式、ORIGINAL 与真实已发布风格名；下方仅 CAP/OUT 和进度条、8 项风格选择高亮。保留左右 960×540 图像、1080p30、74.25 MHz HDMI、8 风格/模型、推流、按键/UART、冻结及创意功能。
OUT 统计最终 OSD 输出接入 TMDS 的 VS 上升沿，按独立一秒窗口计数；不是 PRC 改名或写死 30。内部 PRC 诊断语义保留。CAP 与 OUT 刻度目标均为 30；CAP 的 30 是基线目标，不是实测保证。
字体仍是 8×8，正文 32 像素、标题 64 像素。利用三列恒零将字库无损组织成单块 2048×5 RAM，以对齐字符组替换地址加法；配色寄存器使用 3 位索引。两级流水和显示像素完全一致，没有 alpha 混合。全屏模式仅紧凑 HUD，不缩小全屏画面。
风格与当前读帧通过保持数据的 request/acknowledge 邮箱关联，避免显示请求中的风格名。

修改的已有 RTL/字库：

- `rtl/ArtFlow_top.v`
- `rtl/accel/artflow_accel_ctrl.v`
- `rtl/video/artflow_osd.v`
- `rtl/video/artflow_ui.v`
- `rtl/video/cam_fb_pipe_v09.v`
- `rtl/video/osd_font.mem`
- `rtl/video/rgb_frame_store_v07.v`

新增实现数据：`rtl/video/osd_text_rows.mem`；另有测试、构建、审计脚本及报告。
完整补丁：`outputs/osd_source_changes_verified.patch`；文件差异：`reports/source_diff.json`。
候选内原有复制的未跟踪手势文件不属于本次综合。

## 手动上板步骤

1. 用 PowerShell `Get-FileHash -Algorithm SHA256 'D:\work\FPGA\ArtFlow\Process\osd_blackbars_20261030\outputs\ArtFlow_osd_blackbars_20261030.bit'` 核对上述 SHA256，再由你使用原有 Efinity 流程手动加载此 bit。
2. 等待 DDR/摄像头/模型初始化。双窗口检查标题、模式、左右标签、上下黑边、清晰字形、CAP/OUT 及进度条；图像区域仍约 y=270～809。
3. KEY3 依次检查玻璃、素描、油画、星空、网点、沙画、水墨、富彩粗刀版画，确认右侧标签与已显示图像及高亮一致；也检查原 UART 操作。
4. KEY1 切换双窗口、风格全屏、原图全屏；KEY2 关闭/打开 OSD。检查全屏不缩小、关闭后无装饰残留。
5. 用原操作冻结/解冻与切换创意功能，确认图像行为保持原样；冻结但 HDMI 持续输出时 OUT 应继续统计。正常输出目标为约 30，CAP 观察实际抓取结果。
6. 用现有 ESP/浏览器推流流程检查连续画面、风格切换与恢复；无需改变 ESP 固件。记录 UART 诊断及任何启动后新增下溢。

VS 停止而像素时钟继续运行时，RTL 公开计数在完整空窗口后归零，无需下一帧；像素时钟或 HDMI 光栅停止时，屏幕无法刷新。该性质已在仿真验证，不应解释为断掉 HDMI 时钟后屏幕还能显示新状态。
预览是 RTL 测试图与测试计数，不是实板画面或实测性能。

## 可追溯证据

- `reports/regression_complete.json`：功能回归及逐项报告哈希。
- `reports/physical_gate.json`：最终时序/CDC门禁、源码快照和功能报告绑定。
- `reports/normal_routed_timing.rpt`、`work/osd_impl/*_summary.json`：真实最终时序与各审计结果。
- `reports/delivery.json`：bit/hex 大小、SHA256 与物理门禁。
- `outputs/release_manifest.json`：源码、模型、原始约束、构建脚本、最终网表/布局/布线/时序/CDC证据和交付文件的 SHA256 清单。
