# Current default: eight styles, 30 Hz HDMI and ESP32 streaming

See README.md and doc/styles8. Everything below is historical.

---

# Current default: fifteen-style P1/P2 (2026-10-25)

See README.md and doc/styles15/validation.md for the active project, build entry and fresh validation. Everything below is historical; the old 19-style default is superseded.

---

2026-10-22 当前离线候选：19款风格，原16款保持，新增素描/油画O3/点彩R3。
HDMI30Hz与原CNN结构/时钟不变；KEY3循环0..18。详见 doc/STYLES19_INTEGRATION.txt。
新下载文件在 outputs/styles19_hdmi30_20261022/，模型包在 network/styles19/parameters.bin。
本轮仅离线验证，未烧录/未JTAG下载、未训练、未提交Git；以下为此前版本历史记录。

<!-- MULTISTYLE_CURRENT_BEGIN -->
# 2026-10-21 当前 16 风格候选（未烧录、未提交）

当前源码以 15 款已选新风格加原彩绘玻璃组成 16 款；已取消虹彩不恢复。用户提及的 17 款数量仍待确认。
保留 480×270 CNN、22 层、冻结整数模型；KEY1 切换双窗口/风格全屏/原画全屏，KEY2 保持 OSD 开关，KEY3（A3/GPIOL_03，低有效）每次有效按压选择下一款风格。
两套完整参数 bank 后台加载，CRC32 校验后只在 CNN 作业边界提交；未准备好或 Flash 校验失败时继续计算旧模型。

最终隔离候选：`D:/work/CodexWork/2026-10-21/task-2/styles_slim2_20261021/`。
该候选综合 LUT 36529、FF 25918，布局 XLR 56411/60800、RAM 240/256、DSP 144/160。
布线及路由 CDC 通过；CNN 142.857 MHz setup/hold +0.303/+0.026 ns，全系统最差 +0.269/+0.026 ns。
内部无时钟/未约束/多时钟端点均为 0；21 个外部输入和 39 个输出未给同步 I/O 延迟，详见约束覆盖报告及 SPI 协议路由预算，不能理解成所有外部板级时序均已实测。
连续三帧逐层/逐像素比对通过；100 MHz 完成间隔 [6249024, 6251240]，最低持续 15.996826 fps。 总回归队列状态：`PASS`。
仿真包含 960×540 供图/写回、25% AXI 随机停顿、视频访存；CPU/摄像头/DDR PHY 和持续板上帧率仍须实测，显示刷新不计作 CNN 帧率。

`network/styles16/manifest.json` 记录确切选定图与模型身份；全部参数包 `parameters.bin` 为 256 KiB。
`parameters.hex` 是 RTL readmemh 字节文件，不是 Efinity 编程 HEX。Flash 计划区间为 0x400000–0x43FFFF，实际占用未核对，尚未向硬件写入。
原 `outflow/`、`outputs/` 的 BIT/HEX 均保留，不能误认成多风格新构建；新构建及验证证据在上述隔离目录 `src/work/glass_int8/`。
模型导出、Flash 引脚、状态寄存器和限制见 [多风格说明](doc/STYLE_SWITCH_CANDIDATE.txt)。

下方单风格 v6 及更早版本为历史记录；其中 KEY3 未使用、旧资源数及旧 BIT 路径不代表当前多风格候选。
<!-- MULTISTYLE_CURRENT_END -->

---

# 2026-10-21 Glass 单风格吞吐候选（未烧录、未提交）

本次保持原 glass_5 的 22 层网络、权重、量化规则及 480×270 CNN 分辨率，采用共享窗口、流水 MAC、行预取和弹性写回。
CNN 仍为 142.857 MHz，AXI/CPU 仍为 100 MHz。全尺寸连续三帧仿真逐层/逐像素通过；完成间隔为 [6248001, 6248513] 个 AXI 周期，最差 **16.003808 fps**。
此结果包含输入准备、CNN、缩放及 DDR 写回，条件为 25% 随机 AXI 停顿和背景视频负载；不代表板卡实测，真实 CPU 调度、摄像头供帧、DDR PHY 与长时间稳定性仍待上板验收。

- KEY1：默认左右各 960×540 双窗口 → 风格 1920×1080 全屏 → 原画全屏 → 双窗口；帧边界提交，长按只触发一次。
- KEY2：OSD 默认开启，可关闭；字号、位置和诊断内容保持在最终 1080p 坐标。KEY3 本轮未使用，留给未来风格切换。
- 按键沿用原工程 P14/GPIOR_22、N14/GPIOR_21；依据 260920 硬件说明及官方按键示例。较早原理图标注有差异，详见独立报告；实体键尚未实测。
- 摄像头仅保留 P1 与初始化/恢复；白平衡及完整诊断保留。`cam baseline` 已移除，保留 `cam init/off/timing`、`wb`、`defaults`、`status`、`help`。
- 同结构模型仍可重新导出 ROM 并构建，使用 `tools/generate_glass_int8.py` 和 `tools/pack_glass_pipeline_weights.py`。本轮未接入其他风格，未增加运行时权重切换。

最终实现：LUT 37707、FF 25090、XLR 55453/60800、RAM10 230/256、DSP 138/160；CNN setup/hold +0.201/+0.027 ns，全设计最小 +0.120/+0.026 ns，CDC 检查通过。
约束覆盖检查 no_clock=0、unconstrained_internal_endpoints=0、multiple_clock=0；仍有 19 个输入和 34 个输出没有同步 I/O delay，外部接口验证边界在报告中明确列出。
资源比原版增加；旧 UI/P1 分支精简不等于整机资源净下降。

本轮证据和新 BIT/HEX 均在独立目录：
`D:/work/CodexWork/2026-10-21/task-2/glass15_20261021/`。
报告：`reports/ArtFlow_glass15_validation_20261021.txt`；差异/回退清单：`reports/application_receipt.json` 和 `baseline/`；连续验收：`src/work/glass_int8/pipeline_v6_full_continuous_960x540_example/summary.json`。
原工程 `outflow/`、`outputs/` 内旧 BIT/HEX 未替换；不要将其误认为本轮候选。没有烧录，没有 Git commit/push。

以下保留历史版本记录，其“当前”与“未实施”等描述仅对应记录当时状态。

---

# ArtFlow Glass INT8 上板基线（3–4 FPS）

当前主工程使用 glass_5 第 20 轮 22 层 INT8 模型，原始权重与整数计算规则保持不变。
2026-10-19 用户确认模型已在板上运行，风格化帧率约 3–4 FPS。本次将该状态纳入 Git，作为后续 15 FPS 优化的回退基线；尚未实施本轮吞吐优化。
480×270 输入，960×540 显示；CNN 142.857 MHz。实际布局布线 XLR 37,514/60,800、RAM10 227/256、DSP 125/160；正常时序和全部 CDC 通过。
完整尺寸两帧逐层/逐像素仿真通过，保守仿真处理速度 3.836 FPS。
位流：outputs/glass_int8/ArtFlow_glass_int8.bit；当前 outflow/ArtFlow.bit 与其一致。
固化回退包：outputs/glass_int8_baseline_3to4fps/。位流和 HEX 的 SHA256 见 doc/glass_int8_baseline.json；构建产物仍按工程规则不纳入 Git。
构建入口：tools/run_efinity.ps1 或 tools/run_glass_efinity.ps1；详情：doc/glass_int8_results.txt。
原 U8 文件保留，Glass 集成前的配置与位流备份位于 work/glass_int8/baseline/。本条上板结果来自用户反馈，未执行长期稳定性测试。

<!-- GLASS_TRIAL_END -->

# ArtFlow Student U8 整机吞吐优化（未提交）

当前工程保持原 U8 模型数值与画面结果，采用双读缓存、读写并行桥、首层 tap 打包、8 通道量化和上采样窗口复用。
完整尺寸连续两帧仿真保守值为 **15.639 FPS**，原版为 8.725 FPS；此为相同 DDR/视频竞争条件下的仿真结果，实板 PRC FPS 待测。
输入 480×270，输出 960×540；CNN 142.857 MHz，AXI/CPU 100 MHz。XLR 55,606/60,800，RAM10 255/256，DSP 158/160；布局布线、正常时序及全部 CDC 已通过。
构建入口为 tools/run_efinity.ps1，发布入口为 tools/package_u8_optimized.py。最终回归与发布状态以 outputs/student_u8_optimized/manifest.json 为准；说明与复现命令见 doc/u8_integration.md 和 doc/u8_optimization_results.md。
新位流发布后同步 outflow/ArtFlow.bit；旧 U8 位流保留在 outputs/student_u8_v2/，本轮修改前源码保留在 work/u8_optimization/baseline/。本轮不提交 Git，不自动下载板卡。
以下为保留的历史版本说明。

---

# ArtFlow v09 222.222 MHz 性能候选（未提交）

当前工作区在提交 5c2218c 上优化：CNN 使用独立 222.222 MHz 时钟，AXI/CPU 保持 100 MHz，增加跨时钟缓冲和量化流水，减少无关 DDR 写回。网络权重、480×270 处理尺寸及 960×540 输出保持不变。

构建入口为 tools/run_efinity.ps1；性能交付入口为 tools/package_v09_perf.py。全部验证通过后生成 outputs/v09_222mhz/ArtFlow_v09_222MHz.bit，并同步 outflow/ArtFlow.bit；是否发布及实际数字以该目录 manifest.json 为准。详见 [性能说明](doc/v09_performance_notes.md) 和 [验证计划](doc/v09_performance_verification_plan.md)。原 100 MHz 位流保留在 outputs/v09/。

Git 本轮不提交；板上 PRC FPS 与长期稳定性待用户确认。

---

以下是提交 5c2218c 的历史基线记录，其时钟及验证状态不代表当前性能候选。

# ArtFlow v09 S8 CNN 风格效果候选版

当前原工程已接入 network 中的完整 22 层 W8/A4/S8 网络，2026-10-12 按用户要求纳入 v09 候选版本提交，板级验收仍待确认。右窗口执行实际训练模型；保持原板级时钟、相机 CAP-P1、白平衡、按键及中断调度。

候选镜像由 tools/package_v09.py 在逐比特仿真、综合、布局布线、正常时序和 CDC 门禁通过后发布至 outputs/v09/ArtFlow_v09.bit，并同步 outflow/ArtFlow.bit。是否已生成以 outputs/v09/manifest.json 为准。详见 [v09 说明](doc/v09_notes.md) 和 [验证计划](doc/v09_verification_plan.md)。

这是风格效果预览候选，不代表原计划 v08/v09 的全部验收完成：当前使用固定 ROM 权重、100 MHz 核心，≥15 fps、动态 APB 权重加载和板级测试仍待完成。原 v07 镜像保留在 outputs/v07/。

---

以下为历史版本说明，不代表当前候选验收。

# ArtFlow v07 加速器外壳（待上板验收）

当前主工程在原目录推进至 v07，保留白平衡改善及 CAP-P1 相机配置。右窗口改为 DDR 降采样/双线性放大后的结果；OSD 为 V07、CAP FPS / PRC FPS。新增网络资料保留，当前不执行 CNN。

上板镜像：`outputs/v07/ArtFlow_v07.bit`；通过构建门禁后同一镜像同步到 `outflow/ArtFlow.bit`。详细的按键、串口、地址分配、验证结果与限制见 [v07 说明](doc/v07_notes.md) 和 `outputs/v07/manifest.json`。2026-10-12 按用户指示纳入 v07 版本提交；尚未记录实板验收结果。

构建入口：`tools/run_efinity.ps1`；RTL 回归：`tools/run_v07.py --full`；真实 Sapphire/PLIC 回归：`tools/run_v07_soc.py`（需要本机 Questa，当前沙箱不能启动）。本版尚不声称完成板级或生产 CPU 中断仿真验收。

---

以下保留 v06 历史说明，其路径和验证状态不代表 v07 当前验收。

# ArtFlow v06 白平衡改善与 CAP 30 fps

> 当前版本包含 **CAP-P1 相机帧率改进，已实板验证 CAP 稳定显示 30 fps**。60 秒串口计数得到完整帧发布率从 12.6333 提升到 30.0667 fps，CSI/RAW/BIN/DDR 计数一致，测量期间无新增拒帧。P1 默认设置 SC431HAI VTS=1500、曝光=2989 半行；`cam timing` 读回参数，`cam baseline` 恢复原相机配置，`cam init` 返回 P1。验证镜像为 `outputs/capture_fps_p1/ArtFlow_capture_fps_p1.bit`，并同步到 `outflow/ArtFlow.bit`。配置、验证边界、原始串口计数与对照步骤见 [CAP-P1 说明](doc/capture_fps_p1.txt)。

基础版本 `v06-white-balance`：黑电平校正、三通道默认增益 102/102/102（Q8.8）、1/2.2 显示 Gamma，功能为**改善白平衡**，CAP-P1 保留这些画质设置。
2026-10-11 用户确认白平衡版视频正常、画质明显改善；此前“无信号”是显示器休眠。白平衡版原交付包保留在 `outputs/white_balance_improved/`；当前 `outflow/ArtFlow.bit` 已更新为上述 CAP-P1 镜像。
详见[白平衡改善版说明](doc/white_balance_improvement.md)及 `outputs/white_balance_improved/` 的版本清单。OSD 仍显示 V06。

在 Efinity 2026.1 中打开本目录 `ArtFlow.xml`。本版从 `D:\work\CodexWork\ArtFlow\v05` 继续开发，增加 OSD 字符、采集/输出 FPS、按键切换显示模式。v05 原工程保留。

- `key_i[1]`（GPIOR_22，封装 P14）：每次按下依次切换 **DUAL → LEFT → RIGHT → BARS → DUAL**。
- `key_i[2]`（GPIOR_21，封装 N14）：开关 OSD。两个按键均低有效，按下/释放各消抖 20 ms，长按只触发一次。
- 复位仍用 `i_arstn`（GPIOL_07）。复位后默认双窗口、OSD 开启。
- LEFT/RIGHT 保留对应的 960×540 原尺寸窗口，另一半为黑色；不放大、不改变 DDR 读写调度。BARS 为全屏八色条。
- OSD 第一行显示版本和当前模式；第二行 `CAP FPS` 是一秒内成功发布到 DDR 的完整采集帧数，`OUT FPS` 是 HDMI VS 帧数。二者不是同一指标。正常 1080p60 输出预期 OUT≈060；CAP 取决于真实相机和 DDR。
- 统计未完成第一个一秒窗口时显示 `---`，之后逐秒更新，并在下一次 VS 帧边界生效。停流后 CAP 在一个完整无事件窗口结束后显示 000；HDMI 可继续重复最近一帧。

保留 v05 的开机 300 帧色条、Sapphire RISC-V/I2C 摄像头初始化和 115200 8N1 串口白平衡命令。固件逻辑和硬件 ID 未改，固件文件仍名为 `artflow_v05.*`，这是主动保留的兼容版本标识；FPGA 镜像为 `ArtFlow_v06.bit/.hex`。

## 构建与验证

```powershell
cd D:\work\CodexWork\ArtFlow\v06
python -B tools/build_firmware.py
python -B tools/test_firmware.py
python -B tools/check_project_v06.py
python -B tools/run_v06.py --full
python -B tools/run_v06_chain.py
python -B tools/test_v06_gates.py
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
python -B tools/package_v06.py
python -B tools/verify_v06.py
```

逐步成功后再运行下一步；不要同时运行多个 Questa 回归。脚本默认使用本机 `D:\soft\Questa\questa_fse\win64` 和 Efinity `D:\soft\Efinity\2026.1`。固件构建器支持 `--gcc`；Efinity 入口支持 `-EfinityRoot`。仅 `run_v06.py` 不带 `--full` 时为新增功能单测，不能用于完整交付签核。`--soc` 可额外重跑生产 CPU 正常启动和 NACK 场景，固件等待时间不缩短。

本版实际通过项、未运行项和板级状态以 [验证结果](doc/verification_results.md) 为准。构建脚本生成镜像，不自动下载板卡。

源码压缩包可独立解压、构建与校验；重新签核打包要求相邻原始 v05 基线，以确认基线未改。`outputs/ArtFlow_v06_OSD_simulation.png` 是确定性仿真图案上四种模式前100行的拼图，标注的030/060为测试输入，不是实板测量。

资料：[设计说明](doc/v06_notes.md)、[验证计划](doc/verification_plan.md)、[功能映射](doc/feature_list.md)、[用例](doc/case_list.md)、[上板验收](doc/board_acceptance.md)。v05 说明及证据归档于 `doc/baseline_v05/`，不能视为 v06 实测结果。

首次 U8 集成的历史兼容性调整（当前吞吐优化以文首说明为准）：将 line_waddr 的声明移至 prefetch_response 之后；三组小系数 ROM 使用 syn_romstyle="logic"；所有表达式不变，门禁逐字验证声明顺序、ROM 路径与属性调整。综合启用仅同步逻辑的 seq_opt，retiming 保持关闭。
