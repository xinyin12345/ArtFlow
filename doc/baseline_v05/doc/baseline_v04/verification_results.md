# ArtFlow v04 修改与验证结果

日期：2026-10-02。主工程：`D:/work/CodexWork/ArtFlow/v04`。

**开发与离线验证通过，可作为上板候选；30 分钟实板验收尚未执行。**

## 本版实现

在 v03 的事务安全三缓冲基础上加入左右各 960×540、垂直居中的双窗口；两侧使用同一完整帧，右窗口复用行 BRAM，不增加一次整帧 DDR 读取。新增按 FIFO 水位优先且最多连续服务同侧两次的 AXI 突发调度器，等待 B/RLAST 完成才切换读写。

保留 `CFG_DUAL_WINDOW=0` 的全屏二倍放大兼容模式。源文件变更见 [变更索引](changes_v03_to_v04.md)，设计约定见 [设计说明](v04_notes.md)。v03 来源指纹保存在 `baseline_v03/source_sha256.json`，交付打包工具逐文件核对 v03 未改。

## 实际仿真

工具：Questa Altera Starter FPGA Edition-64 2025.3（2025.09 Sep 15 2025）、Python 3.14。现有许可证实际运行成功，没有改动许可。原有 SystemVerilog 环境，非 UVM。

```powershell
python -B tools/run_v04.py --full --soak-frames 1000 --run-dir work/regression_final
```

最终完整运行 **72 项 PASS**：33 项正向 RTL、29 次 Python 抓帧比对、1 项配置夹具、9 项预期失败门禁。完整结果是一次修正后的全量运行，见 [机器摘要](verification/regression_summary.json)、[逐项列表](case_list.md)、[关键日志](verification/regression_evidence.log)。所有正向 RTL 末尾 Errors=0、Warnings=0，负向 PASS 表示预期错误被拒绝。

覆盖包括 4 Bayer 相位×2 输入顺序×2 VS 形式、三 bank 全命中、128-beat 与尾部短突发/4 KB 分段、五通道随机反压、AXI 长等待、B/R 错误、停流重启、捕获半帧截断及 W/R 事务中共同复位。正常输出每像素精确比对；压力期间只允许正确前缀后全黑，恢复后必须重新得到连续完整帧。

两组全分辨率均使用 2200×1125 时序和 1920×1080 有效区。高负载连续 3 帧与正常 30 fps 输入连续 6 帧均通过，每帧 2,073,600 像素；30 fps/60 Hz 重复完整帧是预期行为。仿真抓帧位于 Gamma 前，Gamma/test_pattern 分别单测。

1000 帧 endurance 使用 32×16 RAW/输出有效区、小 porch；模拟时间约 **0.014237 秒**。它验证大量连续帧切换、重复、三 bank 轮转与同帧双窗口，**不是 1800 秒硬件运行，也不是 108000 个实际 60 Hz 帧**。

初轮 `truncated_frame` 暴露了测试注入落在被跳过输入帧的问题；现改为在实际获得捕获许可的帧中截断，定向复测和最终全量均通过。最终同时增加右窗口像素错误、黑边污染的拒绝门禁。初轮失败日志保留在 `work/regression_v04/`，未混入最终通过摘要。

Questa 原生 smoke 另行实际验证，证据见 `verification/questa_native_smoke.log`；原生 full 未重复运行，复用同一正向用例注册表。配置检查及正常时序报告门禁的负向夹具另有复核日志。

## Efinity 与时序

工具：Efinity 2026.1.132；器件 Ti60F225；时序模型 I3。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
python -B tools/check_implementation.py
```

MAP、interface、PNR、PGM、正常时序门禁和 CDC 路由门禁均通过。PGM 只生成 bit/hex，未下载到板卡。

| 指标 | 实测 |
|---|---:|
| XLR | 14,078 / 60,800（23.15%） |
| Memory blocks | 92 / 256（35.94%） |
| DSP | 6 / 160（3.75%） |
| 全局时钟 | 14 / 32 |
| 正常报告内最小 setup / hold slack | +0.419 / +0.029 ns |
| core_clk 最大分析频率 / 目标 | 123.229 / 100 MHz |
| HDMI 像素域最大分析频率 / 目标 | 212.269 / 148.5 MHz |
| count / epoch 总线最大 skew | 0.416 / 0.421 ns |
| 64 位端点最大慢角数据延迟 | 0.735 ns（预算 2.5 ns） |

正常签核使用 `ArtFlow.sdc`。独立 CDC 审计副本只为展开异步 Gray 路径而去掉 clock-group 排除；检查 32+32 个端点，不用该副本声称正常 setup/hold 通过。报告见 `verification/ArtFlow.timing.rpt`、`verification/cdc_summary.json` 和 `verification/implementation_summary.json`。

继承的外围/IP 提示仍有 `pll_inst4_RSTN` 未分配 core pin、未连接端口/常量复位以及 `cannot find correct IV value`；未隐藏提示或擅改板级外围。正常 STA 与本次 Gray 审计不等于全工程形式化 CDC 证明。

## 交付与待验收

打开 `ArtFlow.xml`。当前构建文件在 `work/efinity_out/ArtFlow.bit`、`ArtFlow.hex`，交付副本在 `outputs/`。`outputs/v04_dual_window_capture.png` 为仿真抓帧；源代码和证据包为 `outputs/ArtFlow_v04_source_and_evidence.zip`。交付文件的 SHA-256 见 `verified_files_sha256.json`，执行 `python -B tools/verify_delivery.py --with-generated` 可复核。

**尚未完成：实板 30 分钟无撕裂/无显示断流验收。** 还需确认 DDR 校准、CSI/HDMI 电气、实际 Bayer 排列、开机色条切换和动态场景稳定性。操作和记录要求见 [实板验收](board_acceptance.md)。没有采集 RTL 行/分支/翻转覆盖率、32 位计数回绕或形式化 CDC 证明；不宣称覆盖率 100%。右窗目前为旁路，CNN/RISC-V 属于后续版本。

## 可核验事件计数

以下来自最终运行的原始日志。`underflow` 包含启动时尚无完整帧的黑屏，不能直接作为正常运行丢失率；压力用例中的黑尾是注入超出缓冲能力的故障所致。

### scheduler

```text
SCHEDULER writes=313 reads=319 urgent_w=126 urgent_r=125 forced_w=62 forced_r=62
```

### full_high_load

```text
COUNTERS published=5 rejected=0 dropped=0 overflow=0 underflow=1 banks=111 updates=3 repeats=0 black=1 tails=0 B_errors=0 R_errors=0 AR_stall=811 truncated=0 pauses=0 resets=0
```

### full_30fps

```text
COUNTERS published=4 rejected=0 dropped=0 overflow=0 underflow=2 banks=111 updates=3 repeats=3 black=2 tails=0 B_errors=0 R_errors=0 AR_stall=1471 truncated=0 pauses=0 resets=0
```

### stress_31

```text
COUNTERS published=20 rejected=1 dropped=30 overflow=1 underflow=13 banks=111 updates=7 repeats=0 black=8 tails=5 B_errors=0 R_errors=0 AR_stall=200029 truncated=0 pauses=0 resets=0
```

### stress_73

```text
COUNTERS published=19 rejected=1 dropped=31 overflow=1 underflow=13 banks=111 updates=7 repeats=0 black=8 tails=5 B_errors=0 R_errors=0 AR_stall=200041 truncated=0 pauses=0 resets=0
```

### truncated_frame

```text
COUNTERS published=32 rejected=1 dropped=2 overflow=0 underflow=1 banks=111 updates=6 repeats=0 black=1 tails=0 B_errors=0 R_errors=0 AR_stall=10 truncated=1 pauses=0 resets=0
```

### endurance

```text
COUNTERS published=2041 rejected=0 dropped=0 overflow=0 underflow=1 banks=111 updates=1000 repeats=0 black=1 tails=0 B_errors=0 R_errors=0 AR_stall=249 truncated=0 pauses=0 resets=0
```
