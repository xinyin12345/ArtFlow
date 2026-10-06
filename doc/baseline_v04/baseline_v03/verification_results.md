# ArtFlow v03 修改与验证结果

日期：2026-10-02。工程：D:/work/CodexWork/ArtFlow/v03，分支 v03。

本轮列出的 RTL 与验证问题已补齐。完整视频回归结合 gamma 定向修正复测，最终汇总 **65 项通过**，Efinity 综合、布局布线、比特流生成及 CDC 路由门禁通过。可以作为本轮上板验证候选；尚未烧录硬件，不能称为已完成实板验收的终版。

## 两版推进与 Git

| 阶段 | 内容与记录 |
|---|---|
| Claude 基线 | febbada，继承自目标工程 690d94a 的提交链 |
| 上一版 Codex | f6f2388：事务安全三缓冲、完整帧发布、黑屏/黑尾恢复、动态回归；当时报 11 RTL＋8 Python 复核及 Efinity 通过；其中 gamma 文件/X 检查的遗漏在本轮审计中更正，原始报告保存在该提交 |
| 本轮后续提交 | 保留三缓冲架构；补强 CDC/reset、参数约束、实际配置读取、严格画面判断、故障覆盖与正常帧率验证 |

目标 D:/work/FPGA/ArtFlow/ArtFlow 未修改，收尾检查仍为 690d94a、工作区干净。本轮未直接合入 Claude 的后续独立提交 a88c97d/51c84ba。合并完整提交链的步骤见 [merge_to_fpga.md](merge_to_fpga.md)。

## 问题与处理

1. **启动/压力期检查过宽**：无已发布帧时逐像素全黑；压力期和读错误只允许正确前缀＋全黑尾部，不能忽略任意错误。
2. **黄金文件 X/X 假通过**：Python 检查数量/范围，Verilog 显式检查 RAW/expected/actual 的 X/Z；缺失或 X 黄金文件必须失败。
3. **参数漂移**：从真实 ArtFlow_top.v 严格读取配置，Python golden、Bayer TB、端到端与 Questa 原生入口共用；歧义、缺失或不支持表达式直接失败。
4. **只有高负载输入**：增加真实 30 fps 输入→1080p60 输出，同时保留约 82.5 fps 高负载测试。
5. **帧身份/重复判断弱**：32 位绝对帧号、顺序与冻结上界；停流允许重复最后完整帧，重启必须更新。
6. **故障覆盖不足**：增加 AR 跨输出帧等待、BRESP/RRESP 错误、停流重启、半帧截断、W/R 事务中的共同全局复位及恢复。
7. **CDC/参数约束**：计数与 epoch 使用源端注册 Gray 编码及两级同步，完成 toggle 多一级同步；坏帧标志同步；复位异步断言/同步释放；几何/FIFO/地址位宽 guard；路由后检查所有 64 位跨域端点的预算。

完成计数在捕获开始清零时可能多位跳变，写侧只在完成通知后使用稳定最终值；它不是任意时刻都可用的跨域进度计数。全局复位测试同时复位 AXI 从机，不表示支持主机单独复位后接续旧事务。

## 实际仿真

工具：Questa Altera Starter FPGA Edition-64 2025.3、Python 3.14；现有许可实际完成仿真，未修改许可。非 UVM 环境，UVM_ERROR/UVM_FATAL 不适用。

```powershell
python -B tools/run_v03.py --full
```

[机器汇总](verification/regression_summary.json)：30 项正向 RTL 仿真、27 次 Python 抓帧复核、1 项配置夹具检查、7 项预期失败门禁，共 65 项 PASS。正向仿真日志 Errors=0、Warnings=0。[关键日志汇总](verification/regression_evidence.log) 保留每例的帧序、计数和 PASS/Fatal 证据；完整日志与向量位于 work/regression_v2/。

| 范围 | 实测 |
|---|---|
| Bayer/顺序/VS | 小分辨率全部 16 组合通过；Bayer 单测 32 帧、8192 像素 |
| full_high_load | 1920×1080，输出序列 0、1、3，连续 3 帧各 2,073,600 像素完全一致；banks=111 |
| full_30fps | 1920×1080，2 个启动黑帧后输出 0、0、1、1、2、2；连续 6 帧完全一致；更新 3 次、重复 3 次；banks=111 |
| stress_31 / stress_73 | 每例 published=38、rejected=1、dropped=12、overflow=1、黑尾=1；AR 等待分别 200039 / 200042 周期；恢复后连续 6 帧正确 |
| BRESP / RRESP | 分别触发 2 / 9 个错误响应；B 错误帧被拒绝，R 错误出现黑尾并恢复 |
| 停流 / 截断 / 复位 | 停流保留序列 9 后继续更新；半帧截断拒绝计数=1；写/读事务复位各触发 1 次并重新覆盖三个 bank |

underflow 计数包含启动时没有完整帧的黑屏，不能直接作为正常运行丢失率。允许丢过载输入帧及重复完整帧，不承诺逐帧无损。

七个负向用例分别注入缺失 gamma LUT、X 黄金文件、缺失黄金文件、启动非黑像素、压力期错误像素、冻结像素画面、非法尺寸；全部被指定 Fatal 拒绝。负向结果的 PASS 表示错误检测成功。

Questa 原生 do sim/run_v03.do smoke 也实际通过，包含配置检查、3 个单元、1 个端到端及抓帧复核：[原生日志](verification/questa_native_smoke.log)。原生 full 未另跑一遍；full 正向用例与 Python 共用注册表，负向门禁仅由 Python 批量入口运行。

### gamma 收尾修正与复测范围

初次完整运行中的 gamma 报告不能作为有效证据：相对 LUT 路径在 work/regression_v2 中找不到文件，旧检查器可能发生 X/X 假通过。现已将新旧 LUT 路径作为 TB 参数，由共享入口传入真实工程路径；增加未知值 Fatal，并让 Python/原生入口拒绝任何非预期仿真 Warning。

修正后实际重跑 Python smoke、Questa 原生 smoke 和缺失 gamma LUT 的反向用例，均通过：[复测摘要](verification/gamma_followup_summary.json)。最终 65 项汇总使用复测 gamma 替换初次无效结果，并新增 negative_gamma_missing；没有把它表述为一次重新执行的全量回归。视频 RTL、端到端 TB 与全分辨率运行时的 SHA-256 完全一致，因此未重复耗时的视频用例。上一版报告关于 gamma 零警告/有效通过的说法也由本段更正。

## Efinity 与 CDC

工具：Efinity 2026.1.132，Ti60F225，时序模型 I3。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
```

最终命令退出码 0；MAP、interface、PNR、PGM 及附加 CDC 门禁全部通过。[编译日志](verification/efinity_compile.log)、[资源](verification/resource.rpt)、[正常时序摘要](verification/timing_summary.rpt)。PGM 仅生成编程文件，未下载到板卡。

| 指标 | 实测 |
|---|---:|
| XLR | 14,127 / 60,800（23.24%） |
| Memory blocks | 92 / 256（35.94%） |
| DSP | 6 / 160（3.75%） |
| 全局时钟 | 14 / 32 |
| 正常约束报告内最小 setup / hold slack | +0.494 / +0.028 ns |
| core_clk 最大分析频率 / 目标 | 139.978 / 100 MHz |
| vid_clk_dvi2 最大分析频率 / 目标 | 186.428 / 74.25 MHz |
| hdmi_tx_slow_clk 最大分析频率 / 目标 | 284.010 / 148.5 MHz |
| 计数 / epoch 总线最大 skew | 0.363 / 0.381 ns |
| 64 位端点中最大慢角数据延迟 | 0.745 ns |

正常 setup/hold 签核使用原 ArtFlow.sdc。Efinity 在异步时钟组排除规则下省略 Gray 跨域路径，所以 CDC 审计另用自动生成的 SDC 副本，**只在审计副本去掉时钟组排除规则**，不用于正常时序结论，也不改变实现时的约束。

[CDC 摘要](verification/cdc_summary.json)、[skew 报告](verification/video_bus_skew.rpt)、[慢角延迟报告](verification/video_bus_delay.rpt) 证明两组各 32 位端点被覆盖，skew/数据延迟均满足 2.5 ns 门限。慢角报告每组有 31 个比较端点，另一个最短路径位作为 reference；门禁按 endpoint/reference 的并集检查完整 32 位。审计是路由后的预算门禁，不是布线器主动优化这些异步路径的保证。另以空端点、缺位、超预算报告做过拒绝测试：[门禁反向日志](verification/cdc_negative_gate.log)。

Efinity 原有警告仍存在，包括 pll_inst4_RSTN 未分配 core pin、原 IP 的未连接端口/复位绑常量及 cannot find correct IV value。未据此擅改外围接口或屏蔽警告。通用 synchronizer 报告无警告也不等于全工程 CDC 证明。

## 交付与边界

源码、脚本、摘要与报告提交 Git；报告副本统一为 UTF-8/LF 并去掉行末填充空格，原始输出仍在 work/。大型向量、缓存、PNG、完整运行目录和比特流留在忽略的 work/ 下。当前生成 ArtFlow.hex / ArtFlow.bit 位于 work/efinity_out/，合并后建议重新构建。[交付指纹](verified_files_sha256.json) 同时保存文本原始字节 SHA-256 与归一化 LF 的 SHA-256，便于区分跨目录 checkout 的 CRLF 差异。

本轮未覆盖板上 DDR 校准、真实 Bayer/像素排列、CSI/HDMI 电气行为、上电色条切换及长时间运行；未量化 RTL 行/分支/翻转覆盖率、形式化 CDC/亚稳态概率或 32 位计数回绕。当前固定尺寸、时钟关系和运行时配置约定见 [v03_notes.md](v03_notes.md)。
