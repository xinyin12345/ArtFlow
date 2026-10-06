# ArtFlow v05 验证结果

执行日期：2026-10-02～2026-10-03。结论：**离线开发与验证 PASS；实板 NOT_RUN**。主工程为 `D:\work\CodexWork\ArtFlow\v05`；148 个 v04 基线源文件哈希保持不变。

## 实际执行结果

| 层级 | 结果 | 实际证据 |
|---|---|---|
| 固件构建 | PASS | RV32IM、8 KiB OCRAM，镜像 5824 字节，BSS 32 字节，另保留 1024 字节栈；四路 RAM 与二进制逐字节重组一致 |
| 主机 C 测试 | 5 组 PASS | 命令解析、I2C、摄像头顺序/失败隔离、命令调度/UART 错误、原始 ROM 一致性 |
| 真实 I2C 外设 RTL | PASS | 复现旧 STOP 清 LISTEN 问题；修复后连续两写及重复 START 读回正确 |
| 控制面 RTL | 3 组时钟 PASS | 每组 132 次 APB 检查、20 个真实 Bayer 输出像素；原子提交、帧边界、异常访问和复位 |
| Bayer 首像素 | PASS | 24 个变化图案帧、768 个像素；四相位×两顺序，含 VS 与首字同拍 |
| 摄像头重启门控 | PASS | 半帧中断、缺 FE/VS 停高、未完成 AXI 排空、等待新边界；恢复后 64 个 DDR 像素逐个比对 |
| 生产 CPU 正常启动 | PASS | 厂商 Sapphire RTL 执行同一生产固件，164 条 I2C 写入顺序和值完全匹配原 ROM，5 条读回；UART READY、wb 命令、OK 应答和像素域增益更新 |
| 生产 CPU 传感器 NACK | PASS | 地址 NACK 后错误回报、相机保持复位且不 ready，默认增益保留，UART help 可用 |
| 继承视频完整回归 | 72 项 PASS | 33 个正向 RTL 用例、29 次 Python 帧比较、1 个配置检查、9 个预期失败门禁；包括 1080p 高负载、30 fps 采集、1000 小尺寸输出帧 |
| Efinity 全实现 | PASS | 综合、接口生成、布局布线和 bit/hex 生成；正常 SDC setup/hold 与独立 CDC 路由审计通过 |

原始日志和 JSON 汇总保存在 [verification/](verification/)，生产 ELF/bin/map/dis 和主机测试在 `outputs/firmware/`。完整用例条件见 [case_list.md](case_list.md)。实际 CPU 仿真未缩短生产固件的 20 ms 复位及 50 ms 启动等待。

## 时序、CDC 与资源

正常 `ArtFlow.sdc` 最小 setup slack 为 **+0.490 ns**，最小 hold slack 为 **+0.026 ns**。CDC 审计使用另一个移除异步分组的审计 SDC，不能拿该报告代替正常 STA。

| 跨域总线 | 端点 | 最大 skew | 最大 Clock-to-Q + 数据延迟 | 预算 |
|---|---:|---:|---:|---:|
| capture_words Gray → count_meta | 32 | 0.452 ns | 0.744 ns | 2.5 ns |
| display_epoch Gray → epoch_meta | 32 | 0.426 ns | 0.713 ns | 2.5 ns |
| RGB mailbox → active gains | 48 | 0.503 ns | 0.789 ns | 20 ns |

布局报告：XLR **20464/60800（33.66%）**，Memory Block **118/256（46.09%）**，DSP **10/160（6.25%）**，GBUF **13/32（40.62%）**。数据对应随包的 place、timing、bus_skew 和 bus_delay 报告。

实现流程有既有 DDR/HDMI/CSI 代码和厂商 SoC 的参数、位宽、未使用端口及逻辑优化警告，不能表述为“全工程零警告”。本次综合末段警告原文在 `verification/efinity_warnings_final.log`；包括未使用的 `pll_inst4_RSTN` 和厂商 CPU cache 控制输入常量化。工具还输出 `cannot find correct IV value`，当前工程的 bitstream encryption/auth 均关闭。所有实施阶段返回 PASS，新增控制/SoC 正向仿真则要求零 Error/Warning。

## 本次修复并回归的问题

1. 实际 I2C STOP/DROP 清除 RX LISTEN：每次 START 完成后重新启用，避免第二条寄存器配置失败。真实外设台先复现旧行为，再验证修复。
2. I2C 寄存器实际位宽比通用 BSP 假设小：硬件超时改为 10 ms、数据建立时间 500 ns，防止计数值静默截断。
3. 传感器在半帧复位且没有 FE 时可能拼接旧/新帧：新增 camera gate，中止旧半帧并等待真实新帧边界，保留 AXI 事务排空。
4. VS 与首 RAW 同拍时 Bayer 首列可能覆盖：修正首字写入与列推进，增加变化图案逐像素验证。
5. 验证入口和打包门禁防止旧 PASS、旧 bit 或不完整视频用例集误签；源码、固件、日志、实现快照和交付文件均可用 SHA-256 核验。

## 明确未执行的项目

实板下载、真实 UART/I2C 电气、摄像头图像、HDMI 观察及 30 分钟连续运行全部 **NOT_RUN**，见 [board_acceptance.md](board_acceptance.md)。1000 个小尺寸仿真帧不等于 30 分钟实板稳定性。未做完整 CSI 电气到 HDMI 串行输出的整机数字仿真；视频抓帧位于 Gamma 前，Gamma 有独立查表测试。未采集 RTL 行/分支/翻转覆盖率，不宣称 100% 覆盖率。独立 CPU/debug 复位没有本版入口，不能宣称支持该恢复场景。

## 交付镜像 SHA-256

| 文件 | SHA-256 |
|---|---|
| 固件 bin | `83e4191574f1c5f33f7c37ddabc75d94d6a2bdc86b9b9299f1c1d4c90d7d0b10` |
| ArtFlow_v05.bit | `32424c8ec8c4c5ba5012b20fe15cdd815f19ed21cc17abfe536a6988f515acd9` |
| ArtFlow_v05.hex | `57327ac87f44e7277a96f9ec847cb91c8fc59bd4ba273d9cc5b61461954a152d` |

构建与复现入口见 [README_CODEX.md](../README_CODEX.md)。最终文件清单在 `doc/verified_files_sha256.json`，执行 `python -B tools/verify_delivery.py --with-generated` 检查项目及本机构建输出；解压包内执行不带 `--with-generated` 的版本检查随包内容。
