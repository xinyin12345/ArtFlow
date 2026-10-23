# ArtFlow：Flash 冷启动后 KEY3 无法切换风格的复盘

记录日期：2026-10-22（时间均为 UTC）。适用：Ti60F225、HDMI 30 Hz、19 款风格版本。

**结论：将位流生成选项 `spi_low_power_mode` 从 `on` 改成 `off`，只更新 Flash 配置区后，用户已确认真正断电重启后 KEY3 可以切换。原工程两个 XML 已于 2026-10-22 16:35:07 UTC 用户授权后同步为 `off`，消除了当前构建覆盖链重新引入 on 的已知风险。** 首次维护仅新增此文档；随后仅同步两处生成配置并更新本文，不修改 RTL、固件、模型，不编译、不再操作板卡，不提交 Git。

## 现象与证据链

1. 19 款配置及模型烧录后，独立整片读回、模型头部和 CRC 均通过，但冷启动后按 KEY3 画面不变。烧录校验通过只能说明存储内容正确，不能证明配置完成后的用户逻辑能够读取 Flash 模型。
2. KEY3 对应 A3 的只读采样捕获三次完整按下/松开（15:33:55、15:33:58、15:34:02 附近）。物理输入正常；本版 OSD 没有风格名称，不能以名称未变化判断按键无事件。
3. 临时 JTAG 加载只增加串口 status 打印的诊断版本后，用户确认画面可切换；串口观察到 requested、active、completed 编号一致地变化，加载错误为 0。打印本身不能解释或证明修复。
4. 将同一诊断版本持久写入后，用户完全断电约 5 秒、重新上电、不下载 BIT，仍无法切换。16:11:59 与 16:12:04 两次读取均为：

   ```text
   style[ac,b0]=0x00002040 0x00000000
   requested=2, active=0, completed=0
   loading=0, ready=0, load_errors=2
   CNN done: 1088 -> 1163; CNN errors=0
   ```

   请求已进入控制器，但两次模型加载被拒绝，旧风格 0 继续运行。`rtl/cnn/glass_int8/style_bank_controller.v:76` 将头部错误、读取长度不是 14480 字节、CRC 不符汇总为同一个错误计数；这些寄存器不能细分是哪种错误，也不能提供实际收到的 CRC 或 SPI 波形。
5. A 组保持 `on`；B 组仅改 `off`，使用相同布局布线 LBF、periphery、诊断固件、算法、时钟和 19 款模型。B 组于 16:26 完成配置写入和独立读回。16:29:08，用户按“完全断电约 5 秒、上电、不下载 BIT、画面恢复后按 KEY3”的指示反馈：**“可以切换了，将这个问题和解决方法记录下来”**。这是用户现场确认，未追加远程串口采样；不得编造 B 组冷启动后的寄存器值。

## 机制解释及证据边界

Efinity 安装文档 `D:\soft\Efinity\2026.1\doc\topics\cli-pgm-opts.html` 第 306–308 行说明，`spi_low_power_mode` 控制编程后将 Flash 置于低功耗状态。实际 Flash 多次识别为 Winbond `EF6017`、8 MiB；不能用原理图中另一型号标注替代实板身份。

现有 `rtl/cnn/glass_int8/style_spi_reader.v:30` 直接发送 `03h + 24-bit address`，没有 `ABh` 退出深度掉电及其等待步骤。Winbond W25Q64FW Rev N 资料第 21 页列出 EF/6017，第 56–57 页说明深度掉电下的 ABh 唤醒及 CS 高电平等待要求。资料：[制造商数据手册的 RS 镜像](https://docs.rs-online.com/9bfc/0900766b81704060.pdf)。具体封装/硅版本没有通过芯片丝印独立确认。

“配置后 Flash 进入低功耗，而用户读取器没有唤醒”的解释与 JTAG/冷启动差异、加载错误、以及单变量 off 后恢复一致，A/B 结果支持该配置问题。**没有直接捕获 SPI 休眠命令或波形，不声称测到了休眠状态。** 本次未增加 ABh RTL 状态机，也未关闭模型校验或改变 bank 原子提交规则。

## B 组生成与烧录核验

工作根目录 `W = D:\work\CodexWork\2026-10-21\task-2`（下列缩写仅便于阅读）。

- 生成脚本：`W\style_switch_diagnosis_20261022\generate_lowpower_off.py`。其 `opts` 显式传入 `--spi_low_power_mode=off`，调用已安装的 `efx_pgm.exe`，直接复用已布线 `diagnostic_lane3.lbf`、`ArtFlow.lpf`、`ArtFlow_or.ini`；没有重新综合/布线。
- 独立 XML：`W\style_switch_diagnosis_20261022\lowpower_off_bitstream\ArtFlow_glass_lowpower_off.xml`。它是 B 组生成时的独立设置记录；原工程 XML 当时未同步，现已按下文记录另行同步。
- 审计：同目录 `manifest.json` 和 `generation.log`。源 LBF、periphery、固件哈希保持一致；解码后的 Flash HEX 除 10 个生成时间字节外，只有偏移 367 的 1 个字节变化。JTAG BIT 除时间字段外相同，故仅替换 JTAG BIT 不能验证 Flash 启动路径的此项设置，必须使用配套 active-mode Flash HEX。
- 目标 FPGA ID `0x10660A79`；Flash `EF6017`，8 MiB。部署前两份完整读回一致，且与已核验的 A 组相同；擦写前第三次完整读取再次相同。
- 实际配置数据 `0x000000–0x10CB15`，1,100,566 字节；必要擦除范围 `0x000000–0x10CFFF`，末扇区尾部 1,258 字节按备份保留。未整片擦除。
- 模型 `0x400000–0x44BFFF`，311,296 字节：未重写。独立完整 8 MiB 读回中，配置差异、模型差异、全部非目标区差异均为 0，19 项头部/CRC 全通过。
- 官方工具首次内部校验失败并自动重试一次，随后成功；无手动重复擦写。最终依据独立完整读回确认成功，而不是仅依据工具成功提示。

### 精确产物、备份与报告路径

有效 B 组配置（不要误选旧 `outputs/styles19_hdmi30_20261022` 的 on 版）：

```text
D:\work\CodexWork\2026-10-21\task-2\style_switch_diagnosis_20261022\lowpower_off_bitstream\ArtFlow.bit
D:\work\CodexWork\2026-10-21\task-2\style_switch_diagnosis_20261022\lowpower_off_bitstream\ArtFlow.hex
```

文件 SHA-256：

```text
BIT: 8ca91b1aa2dd0f7b876112865faffcf4201c2e476cee4317c6d36101cb5687ad
HEX: 2350b9b7ed482c8207f81049e770ff94c86ff15b529843ede45fdb77ee89d3ae
```

完整可恢复 A 组备份、B 组读回及部署记录：

```text
D:\work\CodexWork\2026-10-21\task-2\flash_lowpower_off_20261022\before_full_8MiB.bin
D:\work\CodexWork\2026-10-21\task-2\flash_lowpower_off_20261022\before_full_8MiB.hex
D:\work\CodexWork\2026-10-21\task-2\flash_lowpower_off_20261022\before_full_confirm.hex
D:\work\CodexWork\2026-10-21\task-2\flash_lowpower_off_20261022\after_full_8MiB.bin
D:\work\CodexWork\2026-10-21\task-2\flash_lowpower_off_20261022\DEPLOYMENT_RESULT.json
D:\work\CodexWork\2026-10-21\task-2\flash_lowpower_off_20261022\readback_verification.json
D:\work\CodexWork\2026-10-21\task-2\flash_lowpower_off_20261022\program_configuration.log
```

备份整片 SHA-256：`5d113abcf9a469bb59a61c1ed8f9ee087f9b6eef5460b2af3807628dc603285c`。
B 组整片读回 SHA-256：`59f2a45c638927793be1e062bd1a45d7e11beebf8fefb61050cf09706ed2b1d4`。
部署报告保留当时 `COLD_BOOT_PENDING` 的历史状态；后续用户冷启动成功确认记录于本文，不篡改原始报告。

A 组原始诊断证据均在 `D:\work\CodexWork\2026-10-21\task-2\style_switch_diagnosis_20261022\`：`key3_user_window.jsonl`、`diagnostic_uart_window.log`、`SWITCH_RECOVERY_OBSERVATION.json`、`cold_failure_uart_status.log`、`COLD_BOOT_FAILURE_RESULT.json`、`COLD_BOOT_FAILURE_ANALYSIS.txt`。A 组配置保存在其 `diagnostic_bitstream\ArtFlow.bit/.hex`。旧分析的“未修复”是当时状态，须结合本文后续 A/B 结果阅读。

## 防止重构建回归：源配置已同步

首次只读核查时两份 XML 均为 on。用户于 2026-10-22 16:35:07 UTC 明确要求“更改配置”（消息 Sentinel_0512eb845a2c8191a8c613e1ddd51a04），随后仅修改以下两处参数；原文件已备份，保留所有其他字节及未提交修改：

| 文件 | 当前实际状态 | 已完成修改或构建行为 |
|---|---|---|
| `ArtFlow.xml:153` | 参数 `spi_low_power_mode` 的 `value="off"` | 已由 on 改为 off，仅此一处 |
| `ArtFlow_glass.xml:153` | 同样为 `off` | 已由 on 改为 off，仅此一处 |
| `tools/run_efinity.ps1:6–9` | glass 路径转入 `run_glass_efinity.ps1` | 保留现有路由；核对输入 XML |
| `tools/run_glass_efinity.ps1:17–22` | 识别 glass 工程后，将主 XML 复制覆盖 glass XML，再保存此时快照 | 两份现均为 off，因此此覆盖链保持 off；脚本未改 |

已验证两份 XML 语法有效、该参数各仅一项且均为 off；逐字节验证 XML 的唯一差异为该 value，现有复制及快照恢复路径不会从这两份文件重新引入 on。备份、完整差异及哈希回执位于 `D:\work\CodexWork\2026-10-21\task-2\flash_lowpower_off_20261022\source_config_sync\`。未运行构建，现有 BIT/HEX 不因此自动更新。未来生成时仍须核对最终实际 `efx_pgm` 选项为 off，再独立保存并检查配套 BIT/HEX。单靠文件名、新时间戳或 JTAG 运行成功不能证明 active Flash HEX 使用 off。

当前已部署诊断固件额外打印 `style[ac,b0]`，可以区分请求、加载、应用和错误路径，应保留其排障价值。原工程 `firmware/src/main.c` 尚无这一打印；诊断固件源在隔离目录 `style_switch_diagnosis_20261022\diagnostic_src\firmware\src\main.c`，本次未回写。未来重构建若要保留诊断，需单独审查同步，不能误认为原工程已包含。

## 维护和验收边界

- KEY1 为三态显示，KEY2 为 OSD，KEY3 为风格切换。只写 FPGA BIT 不会自动写入外部模型；`network/styles19/parameters.hex` 是仿真字节文件，不是 FPGA 配置 HEX。
- 再次烧录前重新确认目标、备份、实际配置长度和擦除边界；保留模型及非目标数据，不凭本文旧地址直接覆盖未知内容。
- 写入校验、JTAG 运行、Flash 真正冷启动、物理按键/图像变化是四项不同证据。本次最后一项冷启动恢复来自用户现场确认，没有再操作板卡。
- 尚未完成逐项覆盖全部 19 款、明确捕获 15→16 与 18→0 边界、重复冷启动及长期稳定性验收。此次结果不构成严格持续大于 15 fps 的新性能证明。
- 本次没有更改 RTL/算法/时钟/模型，没有额外板卡操作，没有提交或推送 Git。两份主构建配置现已同步 off，但尚未重新构建；历史隔离副本和旧生成产物并未批量修改，复用旧模板或旧 on 版 HEX 仍可能重现问题。
