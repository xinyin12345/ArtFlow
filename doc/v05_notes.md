# v05 设计与迁移说明

## 范围

路线图 v05：Sapphire SoC 上线，RISC-V 通过 I2C 配置摄像头，通过串口调白平衡。本版保留 v04 的视频数据面，将原来固定于顶层的 RGB 增益接到 APB 控制寄存器；原 RTL 摄像头自动配置器退出活动工程。

```text
片上 8 KiB RAM → Sapphire RV32IM @100 MHz
                  ├─ UART0 → 板载串口 → 命令/状态
                  ├─ I2C0  → SC431HAI → RAW10 CSI
                  └─ APB0  → shadow RGB → snapshot/req/ack → 帧边界 active RGB
CSI → 2×2 Bayer + 白平衡 → 960×540 RGB → 三缓冲 DDR → 左右窗口 → Gamma → HDMI
```

CPU 不访问视频 DDR。片上 RAM 同时容纳程序、常量、BSS 和栈；启动不依赖 SPI 软件镜像或外接调试器。JTAG 和 SPI 未引出。CPU 的 AXI-A 接口接错误响应从机，意外访问以 DECERR 结束，不能访问图像 DDR。

## 官方资料来源

SoC 来自 `E:\Work\FPGA\Efinity\Ti60F225_DemoBoard_v4完整资料包\Ti60F225_DemoBoard_v4\10_Ti60f225_sc431hai2hdmi_demo\Ti60f225_sc431hai2hdmi_v1\ip\sapphire_soc`。厂商生成版本 2.2.9；CPU 加密块原样保留。综合与 ModelSim 使用对应厂商变体，只调整四路 RAM 初始化路径。来源配置、哈希和旧镜像在 `ip/sapphire_soc/provenance/`，旧镜像不会进入 v05 构建。

资料中的 `settings.json` 是陈旧配置，地址与生成实现不符。实际地址依据 `soc_config` 和网表解码核验：

| 模块 | 地址/设置 |
|---|---|
| UART0 | `0xf8010000` |
| I2C0 | `0xf8016000` |
| 用户 APB0 | `0xf8100000`，64 KiB |
| OCRAM / 启动 PC | `0xf9000000`，8 KiB |
| CLINT mtime | `0xf8b0bff8`，100 MHz |
| CPU / 总线 | 100 MHz，RV32IM，无压缩指令 |

UART 引脚由官方 demo08 和 demo17 交叉核对：RX=`GPIOL_02`、TX=`GPIOR_28`，3.3 V LVCMOS。它们不占用 v04 的 LED 引脚。I2C 保持原摄像头引脚，仅改变其驱动源：OUT 固定 0，OE=1 拉低，OE=0 释放，复位时释放总线。

## 帧一致性与复位

三个 16 位影子寄存器分别写入，写 COMMIT 后整组复制到 mailbox，直到像素域确认之前 mailbox 不再变化。请求和确认各经两级同步。像素域只在 VS 边界打开的消隐窗口内、输入无效且流水线排空后更新三色增益；普通行消隐不会应用新参数。源域收到确认后同拍清 busy 并更新 active 读回镜像。详见寄存器文档。

摄像头配置成功后，ready 经两级同步进入摄像头输入门控。ready 下降时产生一个明确的帧边界，终止旧半帧；重新使能后等待真实 CSI 帧边界，再放行 RAW。这样即使传感器复位时遗漏 Frame End、VS 保持原电平，也不会将旧帧与新帧拼接。VS/HS/valid/data 同时寄存一拍，控制器与 Bayer 观察相同的输入边界。配置失败会保持摄像头复位，串口仍可查询和重试。`cam off`/`cam init` 不重置 mailbox、FIFO 或 AXI 事务；截断帧沿用原事务排空逻辑拒绝发布，显示可保留最后完整帧。

本版只支持由外部复位/PLL 解锁产生的共同系统复位，新增的 CPU、APB 和像素控制端点共同异步复位并同步释放。没有独立 CPU/debug 复位操作入口，不能据此宣称独立 CPU 复位时视频事务恢复已经验证。

## 与 v04 的文件关系

主工程位于用户指定的 `D:\work\CodexWork\ArtFlow\v05`。复制 v04 的 RTL、CSI IP、仿真、工具和工程文件；没有复制其工作缓存或历史 bitstream。v04 文档归档在 `doc/baseline_v04/`，148 个基线源文件哈希用于核对 v04 未改。

新增 `rtl/control/`、`firmware/`、`ip/sapphire_soc/` 以及控制/SoC 仿真。顶层、工程源列表、外围 UART 和 SDC 随之更新。保留旧 I2C ROM 作为 164 条摄像头寄存器表的唯一输入，构建时生成 C 表；其旧自动配置模块不在综合源列表中。

本版没有加入 v06 OSD、v07 加速器、v08 卷积或自动白平衡算法。串口控制的是已有 ISP 的三通道手动增益。
