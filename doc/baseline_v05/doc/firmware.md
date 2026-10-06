# v05 Sapphire 固件与串口操作

本固件把 v04 的 SC431HAI 初始化移交给 Sapphire RISC-V CPU，并提供串口白平衡控制。CPU 从 FPGA 内的 8 KiB OCRAM 自动启动，不需要先通过 JTAG 下载程序，也不访问视频 DDR。

## 构建与文件

在 `D:\work\CodexWork\ArtFlow\v05` 运行：

```powershell
python tools\build_firmware.py
python tools\test_firmware.py
```

默认交叉编译器为 `D:\soft\Efinity\efinity-riscv-ide-2026.1\toolchain\bin\riscv-none-elf-gcc.exe`；可通过 `--gcc` 或 `RISCV_GCC` 指定其他安装。主机测试使用 `gcc`，可通过 `--cc` 或 `HOST_CC` 指定。脚本仅使用 Python 标准库，不依赖 pip 包、IDE 工程或 libc。

`outputs/firmware/` 包含 ELF、连续二进制映像、链接 map、反汇编、符号表、构建日志、源文件 SHA-256 清单和主机测试结果。编译中间文件、逐函数栈用量 `.su` 位于 `work/firmware/`。

构建脚本自动更新以下四个 FPGA 初始化文件：

```text
ip/sapphire_soc/EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol0.bin
ip/sapphire_soc/EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol1.bin
ip/sapphire_soc/EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol2.bin
ip/sapphire_soc/EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol3.bin
```

每个文件是 2048 行 8 位二进制文本，供 `$readmemb` 使用；`symbol0` 是一个 32 位小端字的最低字节。脚本会从四个文件重组全部 8192 字节并检查与原始映像一致。**改动固件后，必须重新生成 FPGA 配置文件才能更新上电固件。** 四个 `.bin` 不是四个独立可执行程序，也不能互换顺序。

当前固件为 5824 字节代码/只读数据和 32 字节 BSS；链接器强制额外保留 1024 字节栈，超过 OCRAM 容量直接报错。ISA 为 `rv32im_zicsr_zifencei`、ABI 为 `ilp32`，不生成压缩指令、原子扩展或浮点指令。启动地址、栈和所有软件数据均在 `0xf9000000..0xf9001fff`。

## 地址与时钟

地址来自导入的 demo10 **实际生成 RTL**，并与对应 BSP 寄存器协议核对。demo10 的旧 `settings.json` 含另一套 UART/I2C 地址，不能作为软件配置依据。

| 资源 | 地址/配置 |
| --- | --- |
| OCRAM / reset PC | `0xf9000000`，8192 字节 |
| UART0 | `0xf8010000` |
| I2C0 | `0xf8016000` |
| ArtFlow 控制 APB | `0xf8100000` |
| CLINT `mtime` 低 32 位 | `0xf8b0bff8` |
| CPU / 外设 / `mtime` | 100 MHz |
| UART | 115200 baud、8 数据位、无校验、1 停止位、无流控 |
| 摄像头 I2C | 7 位地址 `0x30`，线上写地址 `0x60`、读地址 `0x61`；目标 100 kHz |

所有超时使用 CLINT 计数，不依赖未开放的 `mcycle` CSR；无符号时间差支持低 32 位计数在约 42.95 秒处回绕。UART 分频器使用该 IP 的 8 倍采样配置。修改时钟必须同步修改 `firmware/include/platform.h`，然后重建固件与 FPGA 配置。

## 上电摄像头初始化

上电后串口输出版本标识和 `BUSY camera initialization`。固件拉住摄像头复位 20 ms，释放后等待 50 ms，然后执行 v04 ROM 的全部 **164 条**寄存器写入。`camera_table.h` 由保存的 v04 ROM 自动提取，排除其中注释掉的其他传感器示例；寄存器顺序、数值、增益、裁剪和翻转配置保持一致。

本地 `E:\Work\FPGA\Efinity\摄像头SC431HAI_数据手册_V1.1.pdf` 第 8 页图 1-3 规定，XSHUTDN 释放至 I2C 初始配置的 T4 至少为 4 ms；本版的 50 ms 满足此间隔。20 ms 复位保持是软件策略。数字仿真不模拟电源轨或传感器模拟上电，实际电源与复位仍需上板核对。

每个事务依次发送设备地址、16 位寄存器地址高/低字节和 8 位数据，每个字节检查从设备 ACK。随后以 repeated START 单字节读回：

| 寄存器 | 预期值 | 用途 |
| --- | --- | --- |
| `0x3208`, `0x3209` | `0x07`, `0x80` | 输出宽度 1920 |
| `0x320a`, `0x320b` | `0x04`, `0x38` | 输出高度 1080 |
| `0x0100` | `0x01` | Streaming 开启 |

全部写入与读回通过后，才设置 APB `CAMERA.configured`。正常串口输出：

```text
ArtFlow v05 Sapphire RV32IM; UART 115200 8N1
BUSY camera initialization
OK camera 164 registers verified 1920x1080
READY; type help
```

读回确认的是 I2C 配置状态；视频 DDR 校准、MIPI 数据、显示完整性和白平衡实际画面仍需结合顶层仿真及板上验收。固件没有凭空假定芯片 ID，也没有额外修改传感器内部白平衡算法。

出现 NACK、掉线、总线异常或读回不匹配时，打印失败类型、表项索引、寄存器地址，保持摄像头复位并关闭采集就绪标志；串口继续可用。示例：

```text
ERR camera NACK index=0 reg=0x00000100; sensor held reset; use cam init
READY; type help
```

软件每个 I2C 阶段最多等待 20 ms，硬件另配置 10 ms 不活动超时。该生成版本的硬件 timeout 为 20 位、data setup 为 6 位，固件分别写入 `999999`（10 ms）和 `49`（500 ns），并用编译期断言防止数值被静默截断。该 IP 在 STOP/DROP 后自动清除 RX_ACK/RX_DATA 的 LISTEN；固件在每次 START 完成后重新使能两个接收监听，保证第二笔及后续事务仍能观察到 ACK.valid。失败后执行有界 STOP、DROP、清空发送/接收状态、RECOVER、最终 DROP；不会无限等待 ACK。恢复接线或摄像头供电后，输入 `cam init` 从硬复位重新执行完整初始化，不从失败的中间位置接续。

## 串口命令

命令均区分大小写。使用 ASCII，小写关键字，以 CR、LF 或 CRLF 结束；每行最多 63 字符，支持退格。等待当前命令响应后再发送下一条，尤其是 `cam init` 和 `wb`。

| 命令 | 行为 |
| --- | --- |
| `help` | 显示语法与范围 |
| `status` | 读取状态、camera 控制、已生效及 shadow RGB，显示最近摄像头结果、UART 发送丢弃与接收错误计数 |
| `wb 280 255 350` | 把 R/G/B 三个 ISP 白平衡增益整体提交 |
| `defaults` | 提交 v04 默认值 R=280、G=255、B=350 |
| `cam init` | 完整硬复位、164 条 I2C 配置、5 个读回验证 |
| `cam off` | 拉住摄像头复位并清除 configured |

白平衡值采用 **Q8.8 无符号整数**，`256` 为 1.0 倍；允许 `0..1024`（0..4.0 倍），不接受负号、正号、小数、十六进制、超过 4 位的数字、缺少参数或额外参数。例如 `wb 320 256 384` 对应 R=1.25、G=1.0、B=1.5。这里调节的是 FPGA ISP 的 R/G/B 增益，保持摄像头寄存器表不变。

固件先检查 `STATUS.busy`，随后写入三个 shadow，再写 `COMMIT=1`。RTL 在摄像头安全帧边界整体生效并返回 ACK；只有 busy 清零且 active 三色读回匹配，串口才回复 `OK wb applied`。250 ms 内没有帧 ACK 时回复 `PENDING wb; no frame acknowledgement`，该提交继续有效等待；后续 `wb` 在 busy 期间被拒绝，不覆盖待生效快照。用 `status` 检查 busy 和 active。摄像头断开或停流时出现 PENDING 是可诊断状态，不代表参数已应用。

接收 FIFO 溢出、UART 帧错误或 break 会使当前行整体丢弃，直到下一个换行；超长行、NUL 和非 ASCII 字节同样丢弃。不会把一条损坏命令的有效前缀执行成白平衡写入。重新发送完整命令即可。

### 控制寄存器

以下偏移相对于 `0xf8100000`；详细 RTL 定义见 `rtl/control/artflow_control.v`。

| 偏移 | 含义 |
| --- | --- |
| `0x00` | ID=`0x41524605` |
| `0x04` | bit0=WB busy；bit1=同步后的 DDR cal_done；bit2=camera ready；bit3=camera reset |
| `0x10/0x14/0x18` | R/G/B shadow |
| `0x1c` | 写 1 提交；读 busy |
| `0x20/0x24/0x28` | R/G/B active 确认镜像 |
| `0x30` | bit0=摄像头复位（1=复位）；bit1=configured；合法写值为 0、1、2 |

若 ID 不匹配，固件保留 `help` 并拒绝硬件控制，不向未知寄存器映射写摄像头或白平衡参数。异常 trap 会记录 `trap_cause`、`trap_pc`、`trap_value` 并输出 `FATAL`，便于 JTAG 定位；固件不会在异常后继续配置。

## 验证证据与范围

`tools/test_firmware.py` 编译真实 C 源码，通过 MMIO 边界模型验证：

- 命令合法输入、21 类非法语法、边界增益、CRLF、退格、超长行、嵌入 NUL 和全部非 ASCII 字节；
- I2C 实际发送字节顺序、连续 STOP 分隔的读/写事务、STOP/DROP 清监听后的重新使能、repeated START、四个发送字节的 NACK、缺 ACK、START 丢弃、STOP 卡住、计时回绕、有界恢复及恢复后重试；
- 164 条写入顺序、在每个表项注入失败、每个读回超时与不匹配，检查 configured 仅在完全成功后置位；
- 串口命令到 APB 写入顺序、busy 拒绝、PENDING/已生效区分、非法命令无写入、ID 错误拒绝、UART 错误整行丢弃和重发恢复；
- v05 保存的摄像头 ROM 与 v04 的 SHA-256 完全一致。

主机模型不代替真实 Sapphire 指令执行与外设 RTL 联合仿真；联合仿真与板级验收结果由项目总验证记录单独给出。固件构建清单包含本次二进制和所有软件源文件散列，可与 FPGA 使用的四路初始化文件对应。

`outputs/firmware/host_test_source_sha256.json` 保存测试通过时的全部固件 C/头文件/汇编/链接脚本及测试运行器散列。交付检查可据此拒绝“测试通过后代码又修改”的陈旧结果。

## 资料来源

- `E:\Work\FPGA\Efinity\Ti60F225_DemoBoard_v4完整资料包\Ti60F225_DemoBoard_v4\10_Ti60f225_sc431hai2hdmi_demo\Ti60f225_sc431hai2hdmi_v1\ip\sapphire_soc\sapphire_soc.v`：实际 SoC 地址、CLINT、UART 错误位、I2C clear-on-read/命令接口及 OCRAM 字节分路。
- 同资料包 `08_ti60f225_soc_demo\09_Ti60F225_co_debug_demo\par\ddr_demo_ti60\embedded_sw\soc\software\standalone\driver\i2c.h`、`uart.h` 及 `i2c\i2cMasterDemo`：Efinix BSP 寄存器协议和时序配置方法。v05 使用独立实现并补充有界等待/错误返回，没有沿用样例中的无限等待 ACK。
- ArtFlow v04 `rtl/cam_i2c_ctrl/i2c/i2c_master_reg_rom.v`：SC431HAI 已有寄存器序列。v05 保留原文件作为可核对的配置来源。
