# ArtFlow v02 —— 删调试核 / Gamma 改 ROM 查表 / 色条确认 R/B

## 改动一览

| 文件 | 改动 |
|---|---|
| `rtl/ArtFlow_top.v` | 删除 `debug_edb_top` 实例和 11 个 `jtag_inst1_*` 端口；VIO 的 `r/g/b_gain`、`gamma_sel` 改为顶部 `CFG_*` 常量；新增 `test_pattern` 实例；Gamma 换成 `gamma_lut`；HDMI 编码器入口去掉 `gamma_sel` 选择；LED1 = 色条指示，LED2/3 拉低 |
| `rtl/gamma_conrrection/gamma_lut.v` | **新**：3 块 256x8 ROM（BRAM）同步查表，固定 2 拍延迟，带 `i_bypass` |
| `rtl/gamma_conrrection/gamma_2p2_8b.mem` | **新**：由 `2P2.mem` 转换，与旧模块 8bit 模式逐位等价 |
| `rtl/gamma_conrrection/gamma_inv2p2_8b.mem` | **新**：`x^(1/2.2)` 提亮曲线（标准编码方向），备用 |
| `rtl/video/test_pattern.v` | **新**：复用现有时序叠加色条 |
| `sim/tb_gamma_lut.v` `sim/tb_test_pattern.v` `sim/run_v02.do` | **新**：自检仿真 |
| `tools/gen_gamma_lut.py` | **新**：生成 256x8 Gamma 表 |
| `ArtFlow.xml` | 去掉 `debug_top.v`、换入新文件；Debugger 自动插入关闭（`auto_instantiation=off`） |
| `ArtFlow.peri.xml` | 删除 `JTAG_USER1` 块 |
| `ArtFlow.sdc` | 注释掉所有 `jtag_inst1_*` 约束 |
| `_archive/v01_debug/` | `debug_top.v`、`debug.json`、`debug_profile.wizard.json` 移到这里（不再参与编译） |

## 为什么旧 Gamma 要换

旧 `gamma_correction.v` 每拍从 BRAM 读一项，写进 `reg [9:0] r_gamma_2P[0:1023]`
（寄存器数组，约 10240 个 FF），再用三个 1024 选 1 的大 MUX 查表：
资源浪费严重，且上电后前 ~1026 拍表还没拷满。新模块直接用 BRAM 同步读，只占 3 块 BRAM。

## R/B 通道的来龙去脉

v01 里 HDMI 编码器入口：

```
gamma_sel=1 : i_bdata <- gamma_bdata   （正常）
gamma_sel=0 : i_bdata <- hdmi_tx_rdata （R/B 交叉！）
```

VIO 初值 `gamma_sel=0`，所以 v01 平时看到的画面走的是“交叉”那条路。
v02 把交叉挪到唯一一处 —— debayer 之后的 `CFG_SWAP_RB`（默认 1，保持 v01 画面），
编码器入口改为直连。这样：

* **色条**插在 SWAP 之后、编码器之前 → 只验证“输出链路”（编码器/HDMI 线/显示器）；
* **红色实物**验证“输入链路”（Sensor Bayer 排列 / debayer）→ 决定 `CFG_SWAP_RB`。

## 上板检查步骤

1. ModelSim：`cd sim` → `do run_v02.do`，两个测试都打印 `PASS`。
2. Efinity 全编译，看资源报告：
   * 不再有 `edb_top` / `debug_*` 层级；
   * BRAM 比 v01 多 3 块（gamma），FF 应该比 v01 少一万左右；
   * 时序全部满足（`hdmi_tx_slow_clk` 148.5 MHz）。
3. 烧录，上电：
   * 约 5 秒色条，**LED1 亮**。从左到右应为：白 黄 青 绿 品红 红 蓝 黑；
     下 1/3：**红 | 绿 | 蓝**。
     - 左下是蓝、右下是红 → 编码器通道接反，告诉我，改编码器入口；
     - 顺序正确 → 输出链路没问题。
   * 5 秒后 LED1 灭，切到摄像头。拿一个**红色物体**对准镜头：
     - 显示红色 → `CFG_SWAP_RB=1` 正确，v02 完成；
     - 显示蓝色 → 把 `CFG_SWAP_RB` 改成 `1'b0` 重新编译。
4. （可选）把 `CFG_GAMMA_EN` 改为 1 看 Gamma 效果；
   `2P2` 曲线会**变暗**，如果想提亮，把 `LUT_FILE` 换成 `gamma_inv2p2_8b.mem`。

## 配置常量（`ArtFlow_top.v` 顶部）

| 常量 | 默认 | 说明 |
|---|---|---|
| `CFG_R_GAIN / G / B` | `0x118 / 0xFF / 0x15E` | 白平衡 Q8.8，取 v01 VIO 初值 |
| `CFG_GAMMA_EN` | 0 | 1 = 查表 |
| `CFG_SWAP_RB` | 1 | debayer 输出 R/B 互换 |
| `CFG_PATTERN` | 2 | 0 摄像头 / 1 常显色条 / 2 上电 5 s 色条 |

v05 上 Sapphire SoC 后，这些常量改成 APB 寄存器，由 RISC-V 串口调节。
