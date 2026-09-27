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
2. Efinity 全编译，看资源报告（以实际报告为准）：
   * 不再有 `edb_top` / `debug_*` 层级；
   * `inst_gamma_lut` 的资源取决于 `CFG_GAMMA_EN`：
     - 默认 0（旁路）：`i_bypass` 为常量，ROM 被综合优化掉 —— 实测约 54 FF、0 RAM；
     - 改为 1：实测约 30 FF、3 RAM（每通道一块 256x8 ROM）；
   * v01 的 gamma 由 VIO 运行时选择，1024x10 寄存器数组无法被优化，v02 的 FF 应明显少于 v01，具体差值以两版报告对比为准；
   * 时序全部满足（`hdmi_tx_slow_clk` 148.5 MHz）——注意这只代表报告实际分析到的路径满足约束。
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

## 补充：删除 MIPI DSI 屏相关内容（不再使用 DSI 屏，只走 HDMI）

v01 里 DSI 其实只剩空壳：控制器和面板初始化都没有例化，只有端口、复位和 LCD 上电脚。本次全部清掉：

| 位置 | 删除内容 |
|---|---|
| `rtl/ArtFlow_top.v` | 全部 `mipi_dp_*` 端口、`i_mipi_tx_pclk`、`LCD_POWER`、`LCD_RST_P`；`mipi_dsi_tx_pll_RSTN`；空置的 `w_axi_*` 配置总线、`r_rst_cnt/axi_rst_n`、恒为 1 的 `w_confdone`；旧色条的 `hs/vs/de/rgb_*`、`video_*` 线网与注释掉的 `color_bar` 例化 |
| `ArtFlow.peri.xml` | 5 个 MIPI DPHY TX 块（clk、data0~3）；`LCD_POWER`、`LCD_RST_P` 管脚；`MIPI_TX_PLL` 的 `i_mipi_txc_sclk / i_mipi_txd_sclk / i_mipi_tx_pclk` 三路输出 |
| `ArtFlow.sdc` | 上述 3 个时钟的 `create_clock`、时钟组里的 `i_mipi_tx_pclk`、20 条 `mipi_dp_*` 输出延时 |
| `ArtFlow.xml` | 移出 `panel_config.v`、`color_bar_rgb.v`（均未例化） |
| `_archive/v02_dsi/` | 移入 `rtl/mipi_config/`、`rtl/efx_dsi_tx.sv`、`ip/dsi_tx/`、`Panel_1080p_reg.mem`、`color_bar_rgb.v` |

**注意**
* `MIPI_TX_PLL` 本身保留（名字不变）：它还输出 `core_clk`（100 MHz，DDR/AXI/CSI 在用），锁定信号 `i_pll_locked` 也参与全局复位。只删了 DSI 用的三路输出，VCO 设置没动。
* 摄像头（CSI RX）的 5 个 DPHY RX 块完全没动。
* `LCD_POWER` / `LCD_RST_P` 删除后这两个管脚不再被驱动（工程开了 `io_weak_pullup`，会弱上拉）。如果板上仍插着 DSI 屏且不希望它上电，可以再把 `LCD_POWER` 加回来并固定输出 0。
* 改完 peri.xml 后，建议在 Efinity 里用 Interface Designer 打开一次，确认没有报错，再点一次 “Generate Efinity Constraint Files”。

## 补充：约束清理（第三次提交）

* `ArtFlow.sdc`：删除 v01 自动插入调试核遗留的 14 条 `jtag_inst2_autodbg_*` 输入/输出延时（时钟不存在，PnR 已忽略），以及 inst1/inst2 的全部 JTAG 注释模板。
* `ArtFlow.sdc`：`CLK_25M` 的 `create_clock -period <USER_PERIOD>` 占位符改为 `-period 40.000 -name CLK_25M`（25 MHz）。
* `ArtFlow.peri.xml` + `ArtFlow.sdc`：删除 RTL 中不存在的 `ddr_addr[14]`、`ddr_addr[15]` 两个管脚及其 4 条输出延时；`ddr_addr` 总线改为 `[13:0]`，与 `ROW_WIDTH=14` 一致。
  这两个管脚之前在 RTL 中本就没有连接，删除后作为未用 IO 处理（工程开启了 `io_weak_pullup`），行为与 v01 相同。
* 旧的 `outflow/` 编译产物（2026-09-24）早于 v02 修改，不能用于验收 v02。

## v02 剩余待验收项

| # | 待验收 | 验收方式 | 通过标准 |
|---|---|---|---|
| 1 | 仿真 | ModelSim：`cd sim` → `do run_v02.do` | 两个测试均打印 `PASS` |
| 2 | 约束/工程文件 | Interface Designer 打开 peri.xml → 检查无报错 → Generate Efinity Constraint Files；然后全编译 | 无 peri 报错；编译日志不再出现 `jtag_inst2_autodbg`、`<USER_PERIOD>`、`ddr_addr[14/15]` 相关警告；时序满足 |
| 3 | Gamma ROM 可启用 | `CFG_GAMMA_EN=1` 完整编译 → 查资源 → 烧录 | `inst_gamma_lut` 占 3 块 RAM；画面有明显 Gamma 效果且无花屏/错位 |
| 4 | 输出链路 R/B | 默认配置编译烧录，上电约 5 s 色条（LED1 亮） | 上 2/3 从左到右：白 黄 青 绿 品红 红 蓝 黑；下 1/3：红 \| 绿 \| 蓝 |
| 5 | 输入链路 R/B | 色条结束（LED1 灭）后用摄像头拍红色物体 | 显示为红色；若为蓝色，`CFG_SWAP_RB` 改 `1'b0` 重编重测 |
| 6 | 基本稳定性 | 连续运行 ≥10 min | 无花屏、无断流，LED0 持续闪烁（DDR 校准正常） |

以上全部通过后，再决定交付默认 `CFG_GAMMA_EN`，并把本表更新为“已验收”。
