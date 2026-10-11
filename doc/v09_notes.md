# ArtFlow v09 S8 CNN 上板候选版

本次在 `D:\work\FPGA\ArtFlow\ArtFlow` 原工程直接接入 `network` 中的冻结网络。初次生成候选时未提交；2026-10-12 按用户要求纳入 v09 候选版本提交，未自动下载板卡。最终构建与仿真结果见 `outputs/v09/manifest.json`；只有打包门禁通过后才生成该候选交付并更新 `outflow/ArtFlow.bit`。既有交付包的 `git_committed: false` 保留初次打包时的状态快照，提交不代表板级验收完成。

## 版本范围

网络来源为 `network/S8_480x270_Pipeline_v2_20261010/S8_480x270_Pipeline_v2`，包含 22 个执行层，W8 权重、U4 激活和 S8 残差，模型参数 SHA-256 为 `6414b936b8bbebf87a9177c05e014f46ead215493e8b3fd86d391ab6cf515c02`。RGB 输入输出为 U8；外部 480×270，内部反射补到 480×272，输出裁去补充行。

它与旧版本计划的 `3→8→8→8→3` 四层网络不同。本次优先复用用户提供且已有整数参考的训练结果，让右窗口实际运行该网络。没有另行训练四层模型，也没有把 S8 网络伪称为四层 INT8 网络。

| 原计划验收项 | 本次范围 |
|---|---|
| v08 卷积逐比特核对 | 核对实际 S8 网络全部 22 层特征写回及地址，另核对完整缩放链路 |
| v08 通用 CI/CO/并行度可配的 INT32 单层、8→8/24 MAC 独立综合 | 未新增此通用模块；复用冻结 S8 MAC（经原包边界审计的 S20 累加） |
| v09 风格网络上屏 | 接入训练权重、DDR 缓存桥、缩放、三缓冲及原有 RISC-V 中断调度 |
| v09 RISC-V/APB 动态装载权重 | 本候选使用位流初始化 ROM；CPU OCRAM 仍为 8 KiB，固件未塞入约 44 KiB 权重。运行时加载待后续实现 |
| v09 实时 ≥15 fps | 待整板测量；本候选仍为 100 MHz，不能依据独立核 150 MHz 的 17.4 fps 推算已达标 |
| v09 硬件固定图注入、固件读 DDR 校验和 | 当前以 RTL AXI 内存模型及 Python 全像素比对验证；板上注入/读回尚未实现 |

因此交付状态是 **v09 风格效果候选版**，不是 v08/v09 全部验收完成。后续性能优化、动态权重加载及板级验收需要单独闭环。

## 上板观察

1. 下载 `outputs/v09/ArtFlow_v09.bit`；同一镜像通过打包门禁后同步到 `outflow/ArtFlow.bit`。之前的 v07 镜像保留在 `outputs/v07/ArtFlow_v07.bit`。
2. 等待约 5 秒开机色条与相机配置；OSD 标题应为 `V09`。默认 DUAL：左侧原画，右侧 S8 风格结果。首个成功结果出现前右侧仍显示原画。
3. OSD 显示 `CAP FPS / PRC FPS`。PRC 统计成功写回并发布的完整处理帧，不是 HDMI 刷新率。网络耗时较长时左右显示的是不同时间的帧，这不是同帧对照。
4. 按键沿用：`key_i[1]` 为 DUAL → LEFT → RIGHT → BARS，`key_i[2]` 开关 OSD。LEFT/RIGHT 仍为原尺寸半屏窗口。
5. 串口 115200 8N1，启动信息 `ArtFlow v09 S8-CNN CAP-P1`。`status` 中 `accel done/skip/error/cycles` 为处理完成、跳过原画、错误帧和作业周期数；`irq` 是固件处理中断次数。error 应为 0，done/irq 持续增加。作业周期数除以 100,000,000 得秒数，包含准备、网络、缓存排空和放大。
6. 记录 60 秒 CAP/PRC 和两次 `status` 的计数差，检查 RGB、错行、撕裂、闪烁和运行温度。保存照片或视频后再决定是否提交。

相机 CAP-P1 时序、白平衡、按键、板级引脚、PLL 与 SDC 保留。原 `cam timing`、`cam baseline`、`cam init`、白平衡及状态命令继续可用。

APB 加速器页仍从控制基址 `0xF8100000` 的偏移 `0x80` 开始，ID 改为 `0x41524609`，0x84/0x88/0x8C 及 0x90～0xA8 的控制、状态、中断和统计偏移保持不变。0x88 的 source_locked 位在准备结束时提前清除，busy 在整个作业期间保持有效；不要把锁已释放误认为网络已完成。内部 job_active 独立跟踪当前任务。

## 数据路径和颜色定义

`960×540 XRGB8888 → 2×2 四像素平均 → 显示 Gamma LUT → RGB64 → S8 CNN → RGB64 → 双线性 2× 放大 → 带标记 XRGB8888 → 结果帧池 → 右窗口`。

摄像头 DDR 格式为 `0x00RRGGBB`。准备阶段使用 `(a+b+c+d+2)>>2`，各通道再查原显示 Gamma LUT，网络 64 位字低三字节依次 R、G、B，其余为 0。该顺序是本次明确的输入合同：先在线性帧缓冲上平均，再转显示域；不声称与未知训练预处理顺序完全相同。

网络原有权重、量化、反射边界、残差舍入规则全部不变。`rtl/cnn/s8_shared_flat.v` 只替换 ROM 文件的相对路径；三个 `.mem` 文件与原包逐文件校验相等。其原始网络源与导出参数保留在 `network`。

放大采用 half-pixel、align_corners=false，边界 clamp，水平/垂直权重为 1/4、3/4，最后 `(sum+8)>>4`。结果以 `0x01RRGGBB` 存入 DDR：bit24 是“已经处于显示域”的像素元数据，通过现有 FIFO 与像素一起传输；显示时据此旁路 Gamma。原画高字节仍为 0，继续使用原 Gamma。标记同步经过色条及 Gamma 两拍流水，避免窗口交界处错一两个像素。BARS/开机色条保持原行为。

## DDR 地址和所有权

| 用途 | 起始地址 | 范围 |
|---|---|---|
| 原画 3 bank | 0 / 0x00400000 / 0x00800000 | 每 bank 4 MiB |
| 结果 3 bank | 0x00C00000 / 0x01000000 / 0x01400000 | 每 bank 4 MiB |
| CNN scratch slot 0 | 0x01800000 | 2 MiB |
| CNN scratch slot 1 | 0x01A00000 | 2 MiB |
| CNN scratch slot 2 | 0x01C00000 | 2 MiB |

网络局部 0/2/4 MiB 地址统一加 0x01800000，绝不与视频池重叠。最大已用 scratch 特征小于每槽 2 MiB。一次仅运行一项网络作业，scratch 无需三缓冲。

准备 DMA 完成且全部 B 响应成功后释放原画锁，随后 CNN 只访问私有 scratch，允许采集继续。结果仍须等网络写缓存排空、后处理全部 AXI B 成功后才发布；显示仅在原有 epoch 边界切换结果地址。错误帧触发完成中断并计 error，不替换之前的有效结果。总线永久无响应时仍会等待，当前没有新增 AXI 超时/强制取消功能。

`artflow_cnn_bridge` 使用一个 256 字节读缓存和一个 256 字节写合并缓冲；外部为对齐的 16-beat、128-bit AXI INCR。读未命中、必要的读后写相关及缓冲换行触发写回；`DRAIN` 状态等待最后 B 响应，形成结果发布屏障。保持原有视频 burst 优先的 AXI 仲裁，无新时钟域。

## 构建和复现

需要 Python 3.10+、NumPy、Icarus、Efinity 2026.1 和原工程 RISC-V 工具链。`run_v09.py` / `run_v09_system.py` 使用 NumPy；普通默认 `python` 若无 NumPy，使用已安装带 NumPy 的解释器。

```powershell
python -X utf8 -B tools/build_firmware.py
python -X utf8 -B tools/test_firmware.py
python -X utf8 -B tools/run_v09.py --width 64 --height 44 --frames 2
python -X utf8 -B tools/run_v09.py --width 960 --height 540 --frames 1
python -X utf8 -B tools/run_v09.py --fault 1 --frames 1
python -X utf8 -B tools/run_v09.py --fault 2 --frames 1
python -X utf8 -B tools/run_v09.py --fault 3 --frames 1
python -X utf8 -B tools/run_v09.py --fault 4 --frames 1
python -X utf8 -B tools/run_v09_system.py
python -X utf8 -B tools/run_v09_color.py
python -X utf8 -B tools/run_v09_control.py
python -X utf8 -B tools/run_v09_soc.py
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
python -X utf8 -B tools/package_v09.py
```

原 v07 RTL 与镜像保留供回归和恢复；主工程构建门禁已切换为 `check_project_v09.py`。v07 的旧打包脚本不适用于当前 v09 主工程。

Questa 在当前环境出现 WinError 623，真实 Sapphire CPU/PLIC 测试需在可运行的本机 Questa 或板上继续确认。现有固件主机测试和 APB 驱动系统测试不等同于真实 CPU 仿真。Icarus 的编译后退出故障单列为工具限制；只有全新 VVP 产物正常执行、逐项 scoreboard 通过才记 RTL 测试通过。

## 本次调试记录

- 初次综合将缩放模块输出行缓存的两个独立数组写端口展开为寄存器，导致逻辑超限；改为显式地址/数据复用的单写端口后恢复 BRAM 推断。没有放宽时序约束或添加假路径。
- 复用原网络 ROM，避免改变其训练结果；增加字节顺序适配及显示域标记，避免 R/B 颠倒或二次 Gamma。
- 提前释放已完成输入搬运的原画 bank，并用独立 job_active 跟踪作业直至发布，防止提前释放导致完成事件丢失。
- 中间失败或中止的构建不用于交付。最终数字与工具日志哈希由打包脚本写入 manifest。
