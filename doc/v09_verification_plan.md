# v09 验证计划、功能和用例映射

验证对象为当前实际 S8 网络集成，而非旧计划中尚未实现的通用四层网络。采用项目已有的自检 SystemVerilog / Python 模型框架，不为本次改动替换整个验证平台。

| 优先级 / 功能 | 激励与 checker | 用例 / 证据 |
|---|---|---|
| P0 输入缩小、Gamma、RGB 顺序 | 确定种子随机 XRGB；Python 独立逐像素公式；CNN 启动前核查 scratch | `run_v09.py` 32×28、64×44、960×540 |
| P0 冻结模型数值 | 真实乘加/量化 RTL；NumPy 冻结模型；全部 22 层每个 64-bit feature word 与地址核对 | 上述用例；不使用 performance_stubs |
| P0 边界/补齐/裁剪 | 14、22、270 行网络输入，反射补到 8 倍数，再裁剪 | 上述三种尺寸 |
| P0 放大及像素元数据 | Python half-pixel 四邻域公式；每个输出 XRGB 及 bit24 核对 | 上述用例 |
| P0 总线协议 | 独立随机 AR/AW/W/R/B 等待，12 周期首拍延迟；VALID 停顿稳定、WSTRB、RLAST/WLAST、对齐、4 KiB 边界断言 | `axi_memory_v09.sv`；源/目标基址偏移 0xFF0 |
| P0 帧发布屏障 | 缓存写回必须收 B；DRAIN 完成才允许放大；后处理完成才发布 | DMA 完成 checker、系统测试 |
| P0 AXI 错误 | 准备阶段 B/R、CNN 阶段 B/R 失败，期望 failed，不能进入成功发布 | `--fault 1/2/3/4`；原控制器错误计数测试 |
| P0 所有权与提前释放 | 摄像头持续运行、源帧/显示帧写保护断言；CNN 期间原画已释放；job_active 仍跟踪任务 | `run_v09_system.py` |
| P0 采集/显示仲裁 | 异步像素时钟、HDMI 时钟和 AXI 时钟；显示帧快照逐像素核对 | 系统测试；仅启动无源帧时允许 1 次欠载 |
| P0 中断调度 | APB arm/IRQ/W1C/rearm、延迟处理 IRQ、计数核对 | 系统测试、固件主机 ISR 测试 |
| P0 颜色流水 | 逐像素交替原画与风格标签、空白像素；1024 个 RGB 样本；从生产顶层提取标签流水 | `run_v09_color.py` |
| P0 真实 CPU/PLIC | 使用原厂生产 Sapphire CPU 与当前 BRAM 固件，启动/异常场景 | `run_v09_soc.py`；工具不可运行必须标明 |
| P0 实现完整性 | 源码/ROM/固件 hash，真实 Efinity 综合、布局布线、正常 SDC STA，现有视频/UI CDC 门禁 | `run_efinity.ps1`、`package_v09.py` |
| P1 连续帧重启 | 64×44 连续两次作业，每次从原画重新准备，不复用旧输出当输入 | `--width 64 --height 44 --frames 2` |
| P1 板级画质/帧率/长稳 | 左右画面、UART done/error、OSD CAP/PRC、照片/录像 | 用户上板后补录，仿真不代替板测 |

脚本输出实际 test/frame 数、比较像素与特征数量、源码和日志 SHA-256。当前没有生成 UVM 功能覆盖率或代码覆盖率数据库；上述检查通过不应写成“100% 覆盖”。独立核原有报告只作为模型来源和资源预算证据，不替代本次整机结果。
