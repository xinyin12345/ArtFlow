# ArtFlow v03 修改与验证结果

日期：2026-10-02。完整工程目录：`D:\work\CodexWork\ArtFlow\v03`。

本版已完成 RTL 修改、11 项 RTL 仿真、8 次 Python 抓帧复核，以及 Efinity 综合、布局布线和比特流生成。当前验证范围内通过；没有烧录硬件，不将这些结果等同于实板验收。

## 版本与修改范围

基线为 Claude v03 提交 `febbada88b952e02fb269243e98c594f2ba82cbc`。修改保存在指定工程副本内，没有提交 Git，没有修改原 Claude 工程。收尾时观察到原 Claude 目录已另行推进至 `51c84ba`；本交付不包含该后续提交。

保留原 Bayer 2×2 合并与白平衡实现。新增 `rtl/video/rgb_frame_store.v`，由 `cam_fb_pipe.v` 接入，替换活动视频路径中的旧帧缓存控制器：

- 三 bank 由一个控制器统一分配；完整输入帧、全部数据及 B 响应成功后才发布。
- 读侧固定 bank，直到已接受的读事务完成；写侧避开最新完整帧和读侧占用帧。
- 帧同步不再复位 FIFO 或放弃 AXI 事务。AW 发出前保证整个突发已经缓存，反压时保持地址和数据稳定。
- 输入过载整帧丢弃，FIFO 溢出帧不发布；有界拥塞结束后恢复。
- 每批显示数据携带 32 位帧编号，跨帧迟到数据排空；输出欠载后本帧剩余区域置黑，下一帧重新对齐。
- 使用真实 1080p60 消隐参数，白平衡 G 统一为 255；增加动态多帧、逐像素、自检失败退出的回归。

`ArtFlow.xml` 已更新。旧控制器文件保留作参考；当前项目只复用旧目录中的 `DC_FIFO.v` 与 `rst_n_piple.v`。

## 功能仿真

工具：Questa Altera Starter FPGA Edition-64 2025.3、Python 3.14。执行命令：

```powershell
cd D:\work\CodexWork\ArtFlow\v03
python -B tools/run_v03.py --full
```

最终 `work/regression/summary.json` 为 PASS，包含 11 次 RTL 仿真和 8 次 Python 抓帧检查。不是 UVM 环境，UVM_ERROR/UVM_FATAL 计数不适用；各 RTL 用例最终日志 Errors=0、Warnings=0。

| 范围 | 结果与证据 |
|---|---|
| gamma、test_pattern、Bayer 单元 | PASS；Bayer 覆盖 4 相位、2 像素顺序、2 种 VS 形式 |
| 160×40 四相位 | PASS；每帧改变内容，每个有效像素比对，三个 bank 全内容检查 |
| 反向像素顺序＋帧头 VS 脉冲 | PASS；seed=17 |
| 320×96 压力测试 | PASS；seed=31，AW/W/B/R 分别注入 0.2/1.5/1/2 ms 停顿 |
| 16×8 短帧 | PASS；一帧仅 8 个 AXI 128 位字，覆盖短突发 |
| 1920×1080 全分辨率 | PASS；真实 2200×1125 总时序，连续 3 个动态输出帧各 2,073,600 像素，mismatch=0 |

压力用例实测：published=22、rejected=1、dropped=12、overflow=1、underflow=5；三个 bank 均被验证，恢复后连续 3 帧正确。计数证明该测试实际触发了丢帧和溢出恢复路径。underflow 包含启动期无完整帧的黑屏，不能解读为正常持续显示下的丢失率。

全分辨率用例实测：启动黑帧之后依次显示 variant 0、1、3；每帧 mismatch=0，三个 bank 均经过检查。允许跳过输入帧和重复最近完整帧，不承诺逐帧无损。

另在隔离目录 `work/negative_gate/` 将一个期望像素翻转 1 bit，仿真在发布 bank 检查处报 Fatal，回归程序正确拒绝该次运行。`work/negative_gate/summary.json` 记录的是“错误被成功检测”的 PASS，故意注入错误的日志不属于正式回归。

Questa 原生入口 `sim/run_v03.do smoke` 也实际通过：gamma、pattern、Bayer、一个端到端用例及 Python 抓帧复核。日志：`work/questa_entry.log`；详细输出：`work/questa_1790917571/`。原生入口的 full 模式没有另跑一遍；完整回归由 Python 入口完成。

## Efinity 实现结果

工具：Efinity 2026.1.132，器件 Ti60F225，时序模型 I3。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
```

MAP、interface、PNR、PGM 四阶段全部 PASS。这里的 PGM 是生成编程文件，没有下载到硬件。

| 指标 | 实测 |
|---|---:|
| XLR | 13,811 / 60,800（22.72%） |
| Memory blocks | 92 / 256（35.94%） |
| DSP | 6 / 160（3.75%） |
| 全局时钟 | 14 / 32 |
| 报告内最小 setup slack | +0.345 ns |
| 报告内最小 hold slack | +0.026 ns |
| core_clk 最大分析频率 / 目标 | 150.331 / 100 MHz |
| vid_clk_dvi2 最大分析频率 / 目标 | 182.448 / 74.25 MHz |
| hdmi_tx_slow_clk 最大分析频率 / 目标 | 258.598 / 148.5 MHz |

上述正裕量适用于工程现有约束下报告列出的路径。`ArtFlow.cdc.rpt` 未报告 synchronizer 警告，但这不等于完整的形式化 CDC 验证。

编译并非零警告：保留的顶层输出 `pll_inst4_RSTN` 未分配 core pin；另有原 IP 的未连接端口、复位输入绑常量等警告，控制台还有 `cannot find correct IV value`。本次未修改外围接口或许可证来掩盖这些警告。上板前仍须核对板级端口、DDR 校准与实际复位行为。

生成文件：

- `work/efinity_out/ArtFlow.hex`，2,280,546 字节。
- `work/efinity_out/ArtFlow.bit`，2,280,486 字节。
- 实现日志：`work/efinity_compile.log`。
- 时序、资源、CDC：`work/efinity_out/ArtFlow.timing.rpt`、`ArtFlow.place.rpt`、`ArtFlow.cdc.rpt`。

## 尚未验证的边界

- 实际 CSI RAW10 排列、Bayer 相位、DDR PHY、HDMI 显示器与上电色条切换，仍需实板确认。
- 未注入非零 BRESP/RRESP；未验证进行中 AXI 事务被全局复位中断的系统级行为。
- 未执行所有 Bayer 相位×像素顺序×VS 形式的端到端笛卡尔积；未量化 RTL 行、分支、翻转覆盖率。
- 当前是固定几何尺寸的视频通路。时钟关系、尺寸及增益应保持工程配置，不支持运行时任意切换。
- 数字仿真不能证明亚稳态概率或替代板级时序测量。

设计细节见 `doc/v03_notes.md`；验证计划、功能映射和用例表分别见 `doc/verification_plan.md`、`doc/feature_list.md`、`doc/case_list.md`。`doc/verified_files_sha256.json` 记录交付源码、配置及比特流指纹，便于确认后续是否发生变化。
