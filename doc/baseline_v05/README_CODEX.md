# ArtFlow v05

在 Efinity 中打开本目录 `ArtFlow.xml`。本版由相邻的 v04 复制并继续开发，接入真实 Sapphire RV32IM SoC：RISC-V 从片上 RAM 自启动，通过 I2C 初始化 SC431HAI，通过 UART 修改白平衡。v04 的三缓冲、左右双窗口、AXI 调度和 Gamma 通路继续使用。

- [设计与来源](doc/v05_notes.md)
- [串口及固件](doc/firmware.md)、[控制寄存器](doc/control_registers.md)
- [实际验证结果](doc/verification_results.md)
- [验证计划](doc/verification_plan.md)、[功能映射](doc/feature_list.md)
- [上板验收](doc/board_acceptance.md)

```powershell
cd D:\work\CodexWork\ArtFlow\v05
python -B tools/build_firmware.py
python -B tools/test_firmware.py *> work/firmware_tests.log
python -B tools/run_v05.py --full --run-dir work/regression_v05
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
python -B tools/test_video_cdc_gate.py *> work/cdc_gate_tests.log
python -B tools/test_implementation_gate.py *> work/implementation_gate_tests.log
python -B tools/test_v04_evidence.py *> work/v04_evidence_tests.log
python -B tools/test_delivery_gates.py *> work/delivery_gate_isolated_tests.log
python -B tools/package_v05.py --control-run work/regression_v05 --soc-run work/regression_v05 --video-run work/regression_v05/video
python -B tools/verify_delivery.py --with-generated
```

每步成功后再执行下一步。最后四项快速测试检查验证工具自身的失败门禁；它们不启动 EDA，也不能替代前面的 RTL 和实现结果。

UART 为 **115200、8 数据位、无校验、1 停止位、无流控**。等待 `READY; type help` 后输入命令，每条命令收到应答再发下一条：

```text
status
wb 256 256 256
wb 280 255 350
defaults
cam off
cam init
help
```

增益使用 Q8.8 十进制整数，256 表示 1 倍，允许 0～1024。三色一起提交，在摄像头安全帧边界生效；`OK wb applied` 表示收到像素域确认，`PENDING` 表示尚未确认。命令不会改变分辨率、Gamma 或双窗口布局。两窗口仍显示同一帧。

固件输出在 `outputs/firmware/`；四路 BRAM 初始化文件位于 `ip/sapphire_soc/`，由构建脚本生成并自动用于比特流。FPGA 编译文件在 `work/efinity_out/ArtFlow.bit` 和 `ArtFlow.hex`。`run_efinity.ps1` 会先重建固件并检查输入指纹，只生成文件，不下载板卡。

Questa 单独入口：`python -B tools/run_v05.py --control-only`、`--soc-only`。运行前将 Questa 的 `win64` 目录加入 PATH。SoC 仿真使用厂商 ModelSim 加密变体和同一份生产固件，保留真实启动延时，运行可能需要数十分钟；不要同时运行多个 Questa 回归。`tools/run_v04.py` 在 v05 内仅负责沿用的视频回归。历史 v04 报告均位于 `doc/baseline_v04/`，不能当作 v05 的验证结果。实际通过项及上板状态以本版验证结果为准。

从压缩包独立解压后可构建和仿真；重新打包会要求相邻的原始 v04 目录，以验证基线未被修改。随包证据和文件完整性可直接运行 `python -B tools/verify_delivery.py` 检查。
