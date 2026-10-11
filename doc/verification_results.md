# ArtFlow v06 验证结果

## 当前版本：2026-10-11 白平衡改善版

`v06-white-balance` 的相同 bit 已由用户上板确认：视频正常，画质比此前明显改善。先前“无信号”反馈已由用户更正为显示器休眠。
当前镜像 SHA256 为 `9e962696cb479fc9d9dae560be25e2fb5625b5b69c59a6d6f4ba97dcf2d535d0`，setup/hold 最小裕量为 0.369/0.026 ns。
本版源码、仿真、固件、CDC 和实板范围见[白平衡改善说明](white_balance_improvement.md)及 `white_balance/`；下文是 2026-10-06 的历史验证，不能作为当前镜像清单。

## 2026-10-06 历史版本

日期：2026-10-06。结论：**离线功能、继承回归及 FPGA 全实现 PASS；实板 NOT_RUN**。

主工程 `D:\work\CodexWork\ArtFlow\v06`。原 v05 的190个源/配置/工具基线文件哈希未变。工程保留 v05 的 RISC-V 摄像头初始化和串口白平衡，新增 OSD、CAP/OUT FPS、按键四模式和 OSD 开关。

## 实际执行

| 项目 | 实际结果 | 证据 |
|---|---|---|
| 按键/UI 单测 | 12项自检 PASS：抖动、长按、稳定释放、四模式回绕、帧提交、OSD、复位 | verification/v06/tb_v06_ui.log |
| FPS 单测 | 4个独立采样窗口 PASS：CDC事件模型、BCD进位、999饱和、空窗/复位 | verification/v06/tb_v06_fps.log |
| OSD 单测 | 9帧、1728000个像素全部匹配Python参考；同步逐周期检查，零仿真Error/Warning | verification/v06/summary.json、osd_pixels.hex |
| 全1080p Gamma→OSD | 4帧、8294400有效像素；8214373个含消隐的非OSD周期逐值比对，所有同步周期及帧原子性检查 PASS | verification/chain/chain.log |
| 继承控制面 | 真实I2C、Bayer首像素、camera gate、APB三组时钟，6组RTL仿真 PASS | verification/inherited/summary.json |
| 继承视频全量 | 72项 PASS：33个正向RTL、29次Python像素比较、1配置检查、9个预期失败门禁；含1080p高负载/30fps/1000小帧 | verification/video/summary.json |
| 固件主机测试 | 5组 PASS：console、I2C、camera、dispatch、ROM | ../outputs/firmware/host_tests.json |
| 固件构建 | 5824字节镜像，BSS32字节，保留1KiB栈；四路8KiB BRAM映像检查通过 | ../outputs/firmware/build_manifest.json |
| FPGA完整实现 | 综合/接口/布局布线/bit/hex PASS；当前源码与实现输入快照一致 | verification/efinity_compile.log、implementation_summary.json |
| CDC | 继承32+32+48端点总线审计及新增三个单比特同步链审计 PASS | verification/video_cdc_summary.json、ui_cdc_summary.json |
| 门禁工具自测 | v06 7个故意错误均被拒绝；继承CDC解析6测试及负setup/hold等实现检查通过 | verification/gate_tests.json、video_cdc_gate_tests.log、implementation_gate_tests.log |

新用例为确定性激励；继承随机种子逐项保存在视频汇总中。完整1080p串联台的OSD面板区域由OSD单测逐像素覆盖；不能把两个台的像素计数相加称作不同实板帧。

## 时序与资源

正常 `ArtFlow.sdc`：最小 setup **+0.418 ns**，hold **+0.026 ns**。不能以移除异步时钟组的 CDC 审计报告代替正常 STA。

| 资源 | v05历史基线 | v06本次实现 |
|---|---:|---:|
| XLR | 20464 / 60800 (33.66%) | 20953 / 60800 (34.46%) |
| Memory Block | 118 / 256 (46.09%) | 119 / 256 (46.48%) |
| DSP | 10 / 160 (6.25%) | 10 / 160 (6.25%) |
| GBUF | 13 / 32 (40.62%) | 13 / 32 (40.62%) |

继承CDC：capture_words Gray最大skew0.511ns/数据延迟0.806ns；display_epoch Gray 0.411/0.699ns，预算均2.5ns。增益mailbox 0.585/0.874ns，预算20ns。新增mode、osd、capture同步链各有两个实际触发器；第二级setup +6.286ns、hold +0.109ns，正常时序没有被异步例外意外切除。

新增字库用1个BRAM；v06共增加489个XLR。GPIO实现报告确认模式键P14/GPIOR_22、OSD键N14/GPIOR_21，3.3V LVCMOS；原复位GPIOL_07保留。

Efinity仍有继承DDR/CSI/SoC位宽、常量化、未用端口等警告，以及既有未分配 `pll_inst4_RSTN`。加密/认证关闭时工具仍输出 `cannot find correct IV value`。原文保留在实现日志/ArtFlow.warn.log，**不宣称全工程零警告**。新增正向RTL仿真均为零Error/Warning。

## 工具与范围

- Efinity 2026.1.132，Ti60F225 I3；完整map/interface/pnr/pgm实际返回PASS。
- Questa Altera Starter FPGA Edition 2025.3 (2025.09)，本机原生RTL仿真实际执行成功。沿用原工程环境，没有使用VCS/Verdi/UVM，未修改任何授权文件或服务。
- Python 3.14.4；RISC-V GCC 13.4.0；主机MSYS2 GCC 16.1.0。Efinity子工具用自带Python3.11。
- 代码行/分支/翻转、SVA/功能covergroup覆盖率未采集，不宣称100%。功能点由定向检查映射，不等同于覆盖率数据库闭合。
- 生产CPU正常启动/NACK的长仿真本轮未重跑；v05历史结果仅作基线。固件源码/SoC RTL未变，生产bin的SHA256与v05逐字节一致，控制面及真实I2C外设本轮已重跑。
- CSI物理输入到TMDS串行输出的整芯片仿真未执行；串联台覆盖Gamma输入至OSD输出，综合实现包含真实顶层和DVI编码器。
- **板卡下载、真实按键、电气UART/I2C、实际FPS、HDMI观察和30分钟实板运行均NOT_RUN**。1000小尺寸仿真帧不是30分钟实板运行。按 `board_acceptance.md` 继续验收。
- OSD预览图源自确定性仿真，030/060是测试输入，不能作为实板帧率证据。

## 镜像 SHA256

- ArtFlow_v06.bit: `3a62bc40dcaab259a1a0cae9d387a3074b1556e78214abceff0811f502ec523c`
- ArtFlow_v06.hex: `7bcfa3a4176eaaf383104a782761869c2f97a6e894f36a894eca8e3fbc9394f9`
- 兼容v05固件bin: `83e4191574f1c5f33f7c37ddabc75d94d6a2bdc86b9b9299f1c1d4c90d7d0b10`

最终交付清单为 `verified_files_sha256.json`；`python -B tools/verify_v06.py` 可独立核验压缩包内容和源码/证据对应关系。
