# ArtFlow v03 —— 2×2 合并 → 960×540 RGB 写入 DDR

## 数据流

```
CSI RX (RAW10, 4 像素/拍, i_mipi_rx_pclk 50 MHz)
  └─ bayer_bin2x2      2×2 Bayer 块 → 1 个 RGB 像素，1920×1080 → 960×540，带白平衡
      └─ frame_buffer  写 DDR（三缓冲，每帧 4 MB），XRGB8888 小端
          └─ data_tx   按 1080p 时序读出：960 像素/行 @ 74.25 MHz，每行重复 2 次（竖直 ×2）
              └─ 148.5 MHz 采样，每个像素保持 2 拍（水平 ×2）→ 1920×1080
                  └─ test_pattern → gamma_lut → HDMI（与 v02 相同）
```

v02 在 DDR 里存 RAW，读出来再 debayer（插值）；v03 在**写 DDR 之前**就合成 RGB，
DDR 里就是后面加速器要处理的 960×540 RGB 图，v07 的“读 DDR → 处理 → 写 DDR”可以直接接上。

## DDR 帧格式（v04~v07 都按这个来）

| 项 | 值 |
|---|---|
| 帧缓存 | 3 个，起始地址 `0x000000` / `0x400000` / `0x800000`（每帧 4 MB，4 KB 对齐） |
| 分辨率 | 960 × 540，无行填充，行跨度 3840 字节 |
| 像素 (x, y) 地址 | `bank + (y*960 + x) * 4` |
| 像素格式 | 32 bit 小端 `{8'h00, R, G, B}`：字节 0 = B，1 = G，2 = R，3 = 0 |
| 每帧字节数 | 2 073 600（= 129 600 个 128 bit 字，与 v02 RAW 帧**完全相同**，所以 AXI 突发切分/带宽与 v02 一样） |

## 2×2 合并算法（RTL 与 `tools/v03_golden.py` 逐位一致）

```
R8 = min(255, (R10          * gain_r) >> 10)
G8 = min(255, ((Gr10+Gb10)  * gain_g) >> 11)      // 两个 G 取平均，在乘增益时一起做，不丢精度
B8 = min(255, (B10          * gain_b) >> 10)      // gain 为 Q8.8，256 = 1.0
```
用 CSI 的完整 10 bit 计算（v02 只用了高 8 bit）。

## 改动一览

| 文件 | 改动 |
|---|---|
| `rtl/video/bayer_bin2x2.v` | **新**：2×2 合并 + 白平衡。可配 Bayer 相位、CSI 像素顺序；行内 `valid` 允许断续；vs 高/低有效/脉冲都能对齐 |
| `rtl/video/cam_fb_pipe.v` | **新**：视频主通路（合并 + frame_buffer + 2 倍放大）。**顶层和仿真例化同一个模块** |
| `rtl/frame_buffer/ser2par_64_128_v1.v` | **新**：64→128 bit 打包，低位在前（像素 n 在字节 4n） |
| `rtl/frame_buffer/vid_rx_align_v1.v` | 增加 `I_VID_WIDTH == 64` 分支 |
| `rtl/frame_buffer/par2ser_128_32_v1.v` | **修 2 个旧 bug**（见下）；新增 `LSB_FIRST` |
| `rtl/frame_buffer/par2ser_parse.v` | 透传 `LSB_FIRST` |
| `rtl/frame_buffer/data_tx.v` | 新增 `V_REPEAT`：=2 时偶数行读 FIFO 并存行缓存，奇数行重放（默认 1 = 旧行为） |
| `rtl/frame_buffer/bank_switch.v` `ddr_buffer.v` `frame_buffer.v` | 新增 `BANK_BYTES`（帧缓存固定大小）；`FB_NUM` 原来没有传下去，现在传了（值不变，仍是 3） |
| `rtl/ArtFlow_top.v` | `frame_buffer`+`debayer`+HDMI 两像素拼接 → 一个 `cam_fb_pipe`；`CFG_SWAP_RB` → `CFG_BAYER`；新增 `CFG_PIX_REV`；`CFG_PATTERN` 改回 2 |
| `ArtFlow.xml` | 去掉 debayer 4 个文件，加入 3 个新文件 |
| `_archive/v03_debayer/` | 原 `rtl/debayer/` 整个目录（不再参与编译） |
| `sim/tb_bayer_bin2x2.v` `sim/tb_v03_pipe.sv` `sim/axi_mem_model.sv` `sim/run_v03.do` | **新**：仿真 |
| `tools/v03_golden.py` | **新**：黄金模型 / 测试图生成 / 抓帧比对并出 PNG（纯 Python） |

## 仿真（“先仿真逐像素比对”）

```
cd sim
do run_v03.do          # 快速回归，约 1 分钟
do run_v03.do full     # 再加 1920×1080 全分辨率端到端（本机约 5 分钟）
```

| 测试 | 内容 | 结果 |
|---|---|---|
| `tb_gamma_lut` / `tb_test_pattern` | v02 回归 | PASS |
| `tb_bayer_bin2x2` | 4 种 Bayer 相位 × 2 种 CSI 像素顺序 × 2 种 vs 形式，行内 ~25% 随机空拍，逐像素对黄金模型 | PASS（8192 像素） |
| `tb_v03_pipe` 160×40 | 摄像头模型 → **cam_fb_pipe（上板同一份 RTL）** → AXI 内存模型（20% 随机反压）→ HDMI 口逐像素比对；同时直接检查 3 个 DDR 帧缓存的内容和格式；AXI 协议检查（4 KB 边界、wlast、放弃突发） | 4 种相位全部 PASS |
| `tb_v03_pipe` 1920×1080 | 同上，全分辨率；另用 Python 对抓到的整帧再独立比对一次 | PASS：从第 2 个输出帧起连续 3 帧 2 073 600 像素全部一致；3 个 DDR 帧缓存各 518 400 像素全部正确；4798 次写突发 / 4052 次读突发无协议错误 |

`tools/v03_golden.py check` 会把抓到的帧存成 `sim/<prefix>_cap.png`，期望图 `sim/<prefix>_exp_up.png`，
不一致时另存 `sim/<prefix>_diff.png`（红点 = 错误像素）。

## 仿真中发现并修复的旧代码问题

1. **`par2ser_128_32_v1` 输出切片错 1 位**：`rx_data[127:127-VID_WIDTH]` 是 33 bit，赋给 32 bit 后取到的是 `[126:95]`。
   v02 没用到 32 bit 读出，所以之前没暴露。
2. **每帧最后 2 个像素丢失**：拆包状态机输出第 3 个像素时要求读 FIFO 里已经有“下一个字”（预取）。
   帧的最后一个字没有下一个字 → 卡住 → 显示 FIFO 少 2 个像素，右下角出现错像素。
   v02 用的 `par2ser_128_16_v1` 结构相同（最后 4 个 RAW 像素错），v03 已不再使用它。

## 仿真中发现、**留到 v04** 处理的问题（v04 就是“帧管理 + 仲裁 + 30 分钟稳定性”）

1. **帧消隐太短会让写通道永久卡死**：`ddr_wr_buffer` 在新帧开始时直接复位写 FIFO 和状态机，
   如果上一帧最后一个突发还没写完，就会**中途放弃 AXI 写突发**（违反协议），DDR 控制器会一直等数据 → 之后不再写任何帧（画面冻结）。
   真实传感器帧消隐是毫秒级，远大于排空时间（约 2 µs），正常不会触发；但 DDR 被读侧长时间占用时有风险。
   仿真里把帧消隐缩到 1 µs 可以稳定复现，`axi_mem_model` 会报 `master abandoned write burst`。
2. **上电头几帧显示未初始化的 DDR**：`frame_stable`（连续 3 帧）后读侧就开始出图，
   但第一帧完整写入之前读到的是 DDR 原有内容（仿真中前 3 个输出帧是 `DEADBEEF`，从第 4 帧起逐像素正确）。上板表现为色条结束后闪一下花屏。
3. `bank_switch` 三缓冲：读、写切换请求同一拍到达时，读切换被 `else if` 吃掉（本帧重复显示上一帧，不撕裂，但会丢一次更新）。
4. `frame_info_det` 的 `frame_stable` 实际上只判断“收到过 3 帧”，并没有比较帧长（`frame_len_d0 <= frame_end_r0` 恒为 1）。

## 上板步骤

1. `cd sim` → `do run_v03.do`，全部 PASS。
2. Efinity 全编译（`ArtFlow.xml` 已更新），检查：
   * 时序：`i_mipi_rx_pclk`（合并模块在这个域，6 个乘法器）、`vid_clk_dvi2`（读出行缓存）、`hdmi_tx_slow_clk` 全部满足；
   * 资源：新增 `u_video_pipe/u_bin` 行缓存（480×40 bit）和 `u_data_tx` 行缓存（960×32 bit），删掉了原 debayer 的行缓存和插值逻辑，总量应与 v02 接近——以报告为准。
3. 烧录，上电：约 5 s 色条（LED1 亮）→ 摄像头画面，全屏显示（960×540 放大 2 倍，比 v02 略软，属正常）。
4. **判定 Bayer 相位 `CFG_BAYER`**（v03 唯一需要上板确认的参数）：拿一个红色物体和一个绿色物体（或绿植）对准镜头。

   | 现象 | 调整 |
   |---|---|
   | 颜色正常 | 保持 |
   | 红 ↔ 蓝 互换，绿色正常 | `0↔3` 或 `1↔2`（等价于 v02 的 `CFG_SWAP_RB` 翻转） |
   | 红色物体显示成绿色、绿色物体显示成品红 | `0↔1` 或 `2↔3`；仍不对再试另外两个值 |

   4 个值最多编译 4 次一定能试出来。传感器寄存器里开了镜像+翻转（`0x3221=0x66`），Y 起点为奇数（5），
   所以没有办法离线确定相位，默认值 `0`（RGGB）是按 v01 画面推测的。
5. **判定像素顺序 `CFG_PIX_REV`**（先做完第 4 步，颜色正常后再看）：看竖直的细边（门框、文字）。
   如果边缘出现以 4 个显示像素为周期的“锯齿/梳齿”（相邻两个合并像素左右对调了），
   把 `CFG_PIX_REV` 改成 1，**同时**把 `CFG_BAYER` 的 bit0 翻转（`0↔1`、`2↔3`）——
   像素顺序反了会同时让列相位反一次，第 4 步其实是用 bit0 把颜色“凑对”了。
   （按 Efinix CSI RX 手册 `pixel_data[9:0]` 是靠左的像素，默认 0。）
6. 稳定性：连续运行 ≥ 10 分钟，LED0 持续闪烁，无冻结、无断流。30 分钟无撕裂留给 v04。

## 配置常量（`ArtFlow_top.v` 顶部）

| 常量 | 默认 | 说明 |
|---|---|---|
| `CFG_R_GAIN / G / B` | `0x118 / 0xFF / 0x15E` | 白平衡 Q8.8，现在在合并时以 10 bit 精度相乘 |
| `CFG_GAMMA_EN` | 1 | 1 = 查表 |
| `CFG_BAYER` | 0 | 0 RGGB / 1 GRBG / 2 GBRG / 3 BGGR |
| `CFG_PIX_REV` | 0 | CSI 像素顺序 |
| `CFG_PATTERN` | 2 | 0 摄像头 / 1 常显色条 / 2 上电 5 s 色条再切摄像头 |
