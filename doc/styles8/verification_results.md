# 8 风格 30 Hz 推流版：离线验证结果

状态：离线验证通过，尚未进行本版本上板验收。时间：2026-10-29T17:55:44.482506+00:00。

## 模型映射与清理

|新编号|原 15 风格编号|风格|
|---|---|---|
|00|00|原彩绘玻璃|
|01|05|素描|
|02|01|油画|
|03|03|油画星空|
|04|02|复古网点漫画|
|05|14|沙画|
|06|07|水墨画|
|07|08|富彩粗刀版画|

每个保留模型的 14448 字节权重载荷、原模型 SHA256 和 CRC32 均保留。AFSM 头仅修改槽位 ID。模型包从 245760 字节缩至 131072 字节，减少 114688 字节（46.67%）；8 个 16 KiB 槽覆盖 0x400000–0x41FFFF。

当前运行包去除 papercut/popart/vermilion_ink/mosaic/woodcut/fauve/cel 七个槽位。顶层、管线、加速器和加载器的默认风格数量为 8；索引状态从 5 位收窄到 3 位，诊断接口仍保持 5 位。移除不再使用的独立非推流 physical 构建函数，现有入口统一到包含推流审计的构建流程。构建/回归入口更名为 styles8，历史产物和不可变溯源数据保留。

实际 CPU 无风格循环，OSD 无风格名称表；已有编号诊断按新映射解释。保留 30 Hz HDMI、三态布局、OSD、WB 280/170/280、freeze/pair/blend/curtain/window/live、原诊断和 ESP32 推流。未修改 CNN 算法、时钟、约束或独立 60 Hz Process 工程。布局种子最终为 2，placer_effort_level=5，策略保持 TIMING_3；最初 seed 2 在剩余 9 条拥塞冲突处失败，seed 3 在 2414 条冲突处不再收敛，失败日志均保留于 evidence/styles8_attempt_seed*。

## 实际执行的验证

- 模型包：由固定 SHA256 的 source19 独立重建；逐槽检查映射、地址、头、载荷 SHA256、CRC32 和 FF 填充；六类损坏/截断/重排输入全部拒绝。
- 真实固件构建：RISC-V 镜像 8016 字节，保留 1 KiB 栈和 164 条相机表项；console/i2c/camera/commands 四组 native C 测试通过。
- 八组 RTL：style_crc、style_cycle、pair_control、system、lease、timeout、fifo、fifo_stagger 均通过，最终日志零错误、零警告。包括 00–07 全循环与回绕、每次 668 次参数写入、按键毛刺、快速替换、任务边界提交、非法头/编号 8、CRC、缺失 Flash 与恢复；36 个控制场景、22 个 lease 场景以及两组六种 FIFO 参数/时钟组合。
- 修复原系统测试的七个未连接推流输出和写死的 dump 路径，使用本次目录，文件打开失败现在直接失败；测试转储已真实生成。
- 流协议：12 类 C 接收场景；RTL SPI 到真实 C 接收器，两帧/28800 个像素逐一比对；READY 超时、坏 MISO CRC、慢从机、取消、源错误和复位恢复通过。
- 50 个异步复位位置、11 类显示采样/标签/坐标/错误条件通过；共享邮箱、代次回绕、真实 ESP 诊断、WebSocket TCP loopback、实际网页解码与重连测试通过。
- Efinity 2026.1.132：实际 map/interface/P&R/STA/pgm 全部完成。Questa Altera Starter 2025.3 实际编译与仿真通过。未修复或更改许可证、未安装工具。
- 原时钟 routed setup/hold、视频总线、CNN FIFO/lease、UI/复位链、模型 SPI、7 个原生 return RAM 和推流 IO 路径审计通过；五类伪造/缺位/超预算 CDC 报告被拒绝。
- 厂商工具生成合并 HEX，再独立校验全部 4325376 字节：配置区与新 HEX 相同，中间全 FF，模型区与 8 风格 BIN 完全相同，报告地址/长度正确。

## 资源与时序

最终 XLR 58286/60800；Memory 253/256；DSP 144/160。
全时钟最小 setup slack：0.257 ns；最小 hold slack：0.026 ns。

综合 FF 从 25860 降至 25803，但 LUT 从 38376 增至 38721；原推流版 XLR 为 57981。本次不宣称整体 FPGA 面积下降。353 条综合警告已与原推流版对比；352 条标准化后相同，剩余一条是原计数器 6→5 位截断变为 4→3 位截断，属于已通过完整循环验证的索引取模。详细证据见发布包的 map_warning_comparison.json。

推流外部往返预算 33.462 ns，现有预算上限 53.872053872053876 ns。外部线延迟/ESP 输出延迟假设仍需要实板确认，不能把该条件检查当作板级时序实测。

## 交付文件

目录：`releases/styles8_stream30_20261030/`。

|文件|SHA256|
|---|---|
|`ArtFlow_styles8_stream30.bit`|`44f307f59ad21eb408e5fe217db5714a6b0feb6efa6dcfc7b1495dba93c93617`|
|`ArtFlow_styles8_stream30.hex`|`5a7ede72a24c1f4470428c1cff61f317fe52ac2cb81a5e37658bc146466df12d`|
|`ArtFlow_styles8_stream30_with_models.hex`|`df2fe5f96bbea1c0b0048e05083a6411e4c2cd28dc387b638f0ef8c0147d25ae`|
|`models8_parameters.bin`|`2cdef6557e3c4b693d383ec039343dc3b1066b2c39921cf619b458266aa50c09`|

`models8_parameters.hex` 是模型仿真字节文件，不是单独的 Efinity 配置镜像。新 8 风格 BIT 必须配套新模型包；不应配旧 15 风格模型。现有 15 风格回退文件未覆盖，已有 ESP 应用无需因本次模型编号精简而重烧。

## 证据与边界

完整证据位于发布目录 `evidence/`，包括源码快照、8 组 RTL 日志、固件/流测试回执、最终时序/资源报告和 CDC 摘要；`manifest.json` 记录其 SHA256。工作目录 `work/styles8/` 保留完整 native 工具输出。

测试为 directed 仿真与实际离线构建，不报告未经测量的覆盖率。系统回归使用 CNN 事务替身；本次没有新做完整 CNN 数值推理或 CPU boot 仿真，保留模型算术依据是权重载荷与相关算术 RTL 字节不变。没有打开串口，没有 JTAG 下载，没有写 FPGA/ESP Flash。需用户上板确认八风格画面/顺序、HDMI 三态、交互、手机推流、断电启动与长时稳定性。
