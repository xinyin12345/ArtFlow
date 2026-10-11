# ArtFlow v06 白平衡改善版

当前版本 `v06-white-balance`：黑电平校正、三通道默认增益 102/102/102（Q8.8）、1/2.2 显示 Gamma，功能为**改善白平衡**。
2026-10-11 用户确认视频正常、画质明显改善；此前“无信号”是显示器休眠。正式镜像为 `outflow/ArtFlow.bit`，与用户验证的 `ArtFlow_reference_color_trial.bit` 完全相同。
详见[白平衡改善版说明](doc/white_balance_improvement.md)及 `outputs/white_balance_improved/` 的版本清单。OSD 仍显示 V06。

在 Efinity 2026.1 中打开本目录 `ArtFlow.xml`。本版从 `D:\work\CodexWork\ArtFlow\v05` 继续开发，增加 OSD 字符、采集/输出 FPS、按键切换显示模式。v05 原工程保留。

- `key_i[1]`（GPIOR_22，封装 P14）：每次按下依次切换 **DUAL → LEFT → RIGHT → BARS → DUAL**。
- `key_i[2]`（GPIOR_21，封装 N14）：开关 OSD。两个按键均低有效，按下/释放各消抖 20 ms，长按只触发一次。
- 复位仍用 `i_arstn`（GPIOL_07）。复位后默认双窗口、OSD 开启。
- LEFT/RIGHT 保留对应的 960×540 原尺寸窗口，另一半为黑色；不放大、不改变 DDR 读写调度。BARS 为全屏八色条。
- OSD 第一行显示版本和当前模式；第二行 `CAP FPS` 是一秒内成功发布到 DDR 的完整采集帧数，`OUT FPS` 是 HDMI VS 帧数。二者不是同一指标。正常 1080p60 输出预期 OUT≈060；CAP 取决于真实相机和 DDR。
- 统计未完成第一个一秒窗口时显示 `---`，之后逐秒更新，并在下一次 VS 帧边界生效。停流后 CAP 在一个完整无事件窗口结束后显示 000；HDMI 可继续重复最近一帧。

保留 v05 的开机 300 帧色条、Sapphire RISC-V/I2C 摄像头初始化和 115200 8N1 串口白平衡命令。固件逻辑和硬件 ID 未改，固件文件仍名为 `artflow_v05.*`，这是主动保留的兼容版本标识；FPGA 镜像为 `ArtFlow_v06.bit/.hex`。

## 构建与验证

```powershell
cd D:\work\CodexWork\ArtFlow\v06
python -B tools/build_firmware.py
python -B tools/test_firmware.py
python -B tools/check_project_v06.py
python -B tools/run_v06.py --full
python -B tools/run_v06_chain.py
python -B tools/test_v06_gates.py
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
python -B tools/package_v06.py
python -B tools/verify_v06.py
```

逐步成功后再运行下一步；不要同时运行多个 Questa 回归。脚本默认使用本机 `D:\soft\Questa\questa_fse\win64` 和 Efinity `D:\soft\Efinity\2026.1`。固件构建器支持 `--gcc`；Efinity 入口支持 `-EfinityRoot`。仅 `run_v06.py` 不带 `--full` 时为新增功能单测，不能用于完整交付签核。`--soc` 可额外重跑生产 CPU 正常启动和 NACK 场景，固件等待时间不缩短。

本版实际通过项、未运行项和板级状态以 [验证结果](doc/verification_results.md) 为准。构建脚本生成镜像，不自动下载板卡。

源码压缩包可独立解压、构建与校验；重新签核打包要求相邻原始 v05 基线，以确认基线未改。`outputs/ArtFlow_v06_OSD_simulation.png` 是确定性仿真图案上四种模式前100行的拼图，标注的030/060为测试输入，不是实板测量。

资料：[设计说明](doc/v06_notes.md)、[验证计划](doc/verification_plan.md)、[功能映射](doc/feature_list.md)、[用例](doc/case_list.md)、[上板验收](doc/board_acceptance.md)。v05 说明及证据归档于 `doc/baseline_v05/`，不能视为 v06 实测结果。
