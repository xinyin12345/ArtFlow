# ArtFlow v07 加速器外壳：待上板验收

在用户指定的 `D:\work\FPGA\ArtFlow\ArtFlow` 原工程直接推进。2026-10-11 生成上板测试版时未提交；2026-10-12 按用户指示纳入 v07 版本提交。提交不代表板级验收通过。
保留 v06 的白平衡、Gamma、CAP-P1 摄像头时序及按键位置。不是神经网络风格化版本。

## 本次生成结果（2026-10-11）

对应 `ArtFlow_v07.bit` 的 SHA-256：`2a1fb36d718e34769c76c4f972997546cfdcb30244dea516f4a1c0c2a89d348b`。

| 项目 | 结果 |
|---|---|
| 960×540 DMA 像素校验 | 518,400 像素与 Python 整数模型一致；含随机 AXI 等待 |
| 单帧模拟周期 | 1,155,559 cycles，按 100 MHz 为 11.556 ms；这是独立 DMA 仿真，不是板级帧率 |
| 缩小几何系统测试 | 20 帧采集，16 帧处理 / APB 中断确认，4 帧主动跳过；6,144 个处理像素与 Python 一致，29,184 个显示像素核对通过 |
| 显示欠载 | 首次显示时尚无完整原画，计数 1；后续测试区间没有新增欠载 |
| 异常与所有权 | AXI R/B 错误、4 KiB burst 边界、等待期间信号稳定、源帧及显示帧防覆盖检查通过 |
| 固件主机测试 | 四组通过，包含 C5 中断处理中的 ACK → rearm 顺序及 PLIC complete 检查 |
| 完整工程实现 | Efinity 综合、布局布线、位流生成及正常时序检查通过；setup +0.397 ns / hold +0.026 ns |
| 综合资源 | LUT4 14,682；FF 10,964；ADD 2,937；DSP48 12；RAM10 147；SRL8 1,148 |
| 验收状态 | 上板测试候选版；真实 CPU 中断执行、CAP/PRC 实测和长时间画面稳定性待确认 |

RTL 回归汇总为 `PASS_WITH_TOOL_LIMITATIONS`：各 VVP 测试正常执行结束，Icarus 编译进程的退出异常单独记录。系统测试用 APB 驱动模拟固件访问，不能代替真实 Sapphire CPU / PLIC 联调。详细工具限制见下文。

## 上板观察

1. 下载 `outputs/v07/ArtFlow_v07.bit`，等待原有开机色条结束和相机初始化。原工程默认下载位置 `outflow/ArtFlow.bit` 已同步为同一份 v07 位流；本次没有执行硬件下载。
2. OSD 标题应为 **V07**；默认 DUAL 左侧原画、右侧降采样再放大的画面。
3. 第二行显示 **CAP FPS / PRC FPS**，后者只统计成功写入并发布的处理帧，目标接近 30。首秒显示 `---`。
4. 对着文字、斜线、棋盘格观察：右边应略平滑，整体位置及 RGB 通道应正确。移动物体检查错行、撕裂及黑屏。
5. `key_i[1]` 仍为 DUAL → LEFT → RIGHT → BARS；LEFT/RIGHT 保持原尺寸半屏。`key_i[2]` 开关 OSD。
6. 串口仍为 115200 8N1。执行 `status`：`accel done/skip/error/cycles=` 依次为成功帧、跳过的已发布原画、错误帧、最近/当前作业周期数；`irq=` 是固件中断处理次数。正常运行 done 和 irq 应持续增加，error 应为 0。
7. 记录至少 1 分钟的 CAP/PRC、串口计数和上板照片。板级结果尚未填写，不能把仿真帧率当作实测。

出现问题时可恢复 `outputs/capture_fps_p1/ArtFlow_capture_fps_p1.bit`；本次修改前的 outflow 镜像另保存于 `work/v07/baseline/outflow/`。

## 数据路径及所有权

`rgb_frame_store_v07` 保留采集 FIFO 和完整帧发布协议；增加加速器源帧锁及原画池无空闲时的等待。右窗口独立从结果池读取，不再重放左侧行缓存。左右源地址只在显示 epoch 边界锁存。第一次结果发布前，右侧回退显示原画。

`artflow_axi_mux` 在 burst 边界优先服务视频；读、写通道独立仲裁。AxVALID 一旦选择就保持到握手，写所有权保持到 B，读所有权保持到 RLAST。显示流沿用原来的完整 burst FIFO 空间预留。

`artflow_accel_dma` 顺序读两行原画，2×2 平均得到低分辨率行，直通后双线性放大，完整输出行缓存后写 DDR。它只使用行 RAM，没有片上整帧缓存。所有 burst 按 4 KiB 边界和行尾裁剪；RRESP/BRESP 错误会使整个结果帧失效，旧的已发布结果保持可见。

内存单位是字节，XRGB8888，每个 128 bit AXI beat 包含 4 像素，低位像素先出。

| 帧池 | 三个 bank 起始地址 | 单 bank 预留 |
|---|---|---|
| 原画 | 0x00000000 / 0x00400000 / 0x00800000 | 4 MiB |
| 结果 | 0x00C00000 / 0x01000000 / 0x01400000 | 4 MiB |

一个 960×540 帧实际使用 2,073,600 字节。源帧持有到该次任务完全结束；结果必须收齐所有成功 B 响应后才发布。三缓冲不足时等待/跳帧，不覆盖正在使用的帧。

## 固定点定义

- 降采样各通道：`(p00+p01+p10+p11+2)>>2`。
- 放大采用 half-pixel、`align_corners=false` 坐标：`u=(x+0.5)/2-0.5`，边缘 clamp。
- 水平和垂直权重为 1/4、3/4；中间不截断，四邻域加权和最终 `(sum+8)>>4`。
- 参考模型：`tools/v07_reference.py`。当前缩放在原有显示 Gamma 之前执行，保留原来的颜色处理顺序。

## APB 与 C5

保留旧控制页和 ID `0x41524605`，新增偏移 0x80 页，均相对 `0xF8100000`。

| 偏移 | 含义 |
|---|---|
| 0x80 | v07 标识 0x41524607，只读 |
| 0x84 | bit0 arm，bit1 IRQ enable；写 3 等待并启动下一个新原画 |
| 0x88 | bit0 busy，bit1 armed，bit2 IRQ pending，bit3 源帧锁，bit4 有效结果 |
| 0x8C | IRQ pending；写 1 清除 |
| 0x90 / 0x94 / 0x98 | 成功数 / 跳过数 / AXI 错误帧数 |
| 0x9C | 100 MHz 作业周期数 |
| 0xA0 / 0xA4 / 0xA8 | 最近领取原画序号 / 已发布结果源序号 / 启动次数 |

视频链路沿用约 0.9 秒的上电延迟。加速器 APB 的 PREADY 在本地同步复位释放前保持低，CPU 的早期访问会等待，启动请求不会被复位吞掉。DMA/仲裁/控制器在 core_clk 同步释放复位，PRC 计数器使用 HDMI 域的同步复位。

PLIC 基址 `0xF8C00000`，`userInterruptA` 对应源 16；priority=1、context0 enable bit16、threshold=0。固件启动时 arm 一次；中断中 claim → W1C → rearm → complete。trap 保存全部 caller-saved 寄存器，并以 `mret` 恢复。未识别的异常仍进入原有 fatal 分支。

固件仍使用原有 8 KiB OCRAM及兼容文件名 `artflow_v05.*`，保留 1 KiB 栈。相机寄存器表改为 packed 3 字节条目、编译使用 `-Oz`。为留出 ISR 空间，旧诊断输出改为 `diag_v2[38..64]` 的 12 个十六进制值，依次是 VS、RAW256、BIN256、AW、W、B、STATE、FIFO、WRITTEN、COMPLETE、PUBLISHED、REJECTED。

## 验证边界与复现

```
python -X utf8 -B tools/build_firmware.py
python -X utf8 -B tools/test_firmware.py
python -X utf8 -B tools/run_v07.py --full
python -X utf8 -B tools/run_v07_soc.py
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
python -X utf8 -B tools/package_v07.py
```

当前执行环境无法启动 Questa（WinError 623，记录为 `TOOL_BLOCKED`）。生产 Sapphire CPU 有厂家保护块，只能使用兼容的厂商模拟器；`run_v07_soc.py` 保留真实 CPU/PLIC 测试，未以替代 CPU 声称通过。C5 已做固件主机测试、APB/IRQ 控制器 RTL 测试和生成网表连线检查，实际 CPU 中断执行仍需要可运行的本机 Questa 或上板确认。

开放 RTL 使用工程 `work/v07/tools/` 下的官方 MSYS2 Icarus Verilog。部分编译进程在完成 VVP 输出后退出异常，日志明确标记 `EMITTED_WITH_EXIT_FAULT`；后续 VVP 必须以退出码 0 完成独立逐像素/协议检查。此限制保存在回归 summary 中，不计作编译器正常通过。完整顶层综合、布局布线、位流生成及 STA 使用 Efinity。

`DC_FIFO` 中的 GrayDecode 改为等价连续 XOR 链，避免某些事件仿真器对“初始为 0 且未变化”的指针不触发组合过程、导致 FIFO 计数为 X。FIFO 协议和存储结构未改变。

Efinity 的器件数据库读取在沙箱下需要可遍历的本地副本，运行时位于 `work/v07/efinity_pt`。工具安装及许可证未修改。`work/implementation_summary.json`、`work/ui_cdc_summary.json`、`work/v07/regression/summary.json` 是本次实际结果，旧 v06 报告不代表 v07 验证。

## network 后续接入

新增的 S8 独立核按其现有资料保留。本版没有把它加入综合，也没有改权重或参数。该核的 64 bit 逻辑 DDR 口、8 字节 RGB 输入步长、内部工作区和本工程 128 bit AXI/XRGB8888 不同；v08/v09 接入时必须增加格式/总线适配并避免工作区与这六个帧 bank 重叠。不能直接把其局部 0/2/4 MiB 地址接到本工程 DDR。
