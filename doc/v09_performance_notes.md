# v09 独立 222.222 MHz CNN 性能候选

基线为 `5c2218cf6bc2fe10b4b30b76a74ab303d2e7b712`。本轮在原工程修改，按用户要求不提交 Git、不自动下载板卡。发布入口为 `tools/package_v09_perf.py`；只有全部门禁通过才生成 `outputs/v09_222mhz/ArtFlow_v09_222MHz.bit` 并更新 `outflow/ArtFlow.bit`。100 MHz 回退镜像保留在 `outputs/v09/ArtFlow_v09.bit`。

## 改动与取舍

- 在 MIPI_TX_PLL 的空闲输出增加 `cnn_clk`：相同 PLL、相同反馈、输出分频 9，对应 222.222 MHz。原 100 MHz core/AXI/CPU、DDR PHY、相机、HDMI 时钟和引脚保持原字节配置，门禁只允许新增这个输出及对应时钟组。外设生成工具的 `ArtFlow.pt.sdc` 也必须给出 4.5 ns。
- `artflow_cnn_accel` 包裹原 DMA，将准备、CNN、排空、放大移到 CNN 时钟域。5 个 AXI 通道、作业地址、完成事件分别经过队列。APB、中断、帧池所有权留在 100 MHz 域，`cycles` 继续记录 100 MHz 墙钟时间，包含跨域等待。
- 队列用注册 Gray 指针、两级同步器和注册输出。浅队列明确映射寄存器，保留 CNN 的 BRAM 预算。公共复位异步断言，高速域经三级寄存器同步释放；不提供在未清空 AXI 时单独复位某个队列的接口。
- 量化器在输入选择与宽乘法之间加一级流水；已有 C_REQ/C_B1 状态中预先寄存权重组基址与深度卷积输入，残差读增加 C_SADDR 地址寄存状态，切断地址计算到缓存命中与 ready 的组合长路径。W8 权重、U4/S8 激活、S20 累加、残差相加后舍入、最终 ties-to-even、反射边界及裁剪规则不变。原 network 包和三个 ROM 文件不变。
- 读 miss 的地址与待写缓冲行不同时，不再强制提前写回该行。读写同一行、写入更换行或最终排空仍强制写回，并等待 B 响应。减少输入/残差读引起的零散写 burst。
- 输入仍为 480×270、输出仍为 960×540，没有缩小图像、裁减层数、减少权重精度或重复旧帧计数。

## 验证与发布

200 MHz 初始实现的量化输入选择路径曾有 -0.675 ns setup 违例，加流水后闭合。222.222 MHz 探索中又发现 MAC 输入、权重寻址和残差读地址的长路径；寄存权重组基址、深度卷积输入并给残差读地址增加一级状态后，实验实现通过时序。所有失败中间产物均未发布，最终以主工程正常 `ArtFlow.sdc` 的 STA 为准。原视频 CDC、UI CDC、新 CNN CDC 分别保留独立报告；新增 CDC 检查必须覆盖所有跨域端点及同步器，不以时钟组切断路径当作通过。

完整尺寸性能测试实例化实际 100 MHz `artflow_axi_mux`，保持视频 burst 优先。后台每 400 周期发起 64×128-bit 读、每 1600 周期发起同长度写，对应约 256 MB/s 读与 64 MB/s 写；此外各 DDR 通道有 25% 随机等待，首拍延迟 12 周期。后台模型用于带宽争用压力，不替代真实相机/HDMI。小几何系统测试继续运行真实采集、帧池、显示、APB、IRQ 和全部 CNN 算术。

最终实际数字由打包脚本从日志提取到 `doc/v09_performance_results.md` 和交付 `manifest.json`。完整尺寸两帧每帧速度必须 >15 FPS，且后台读/写实际流量至少 250/62.5 MB/s，才能发布。仿真数值不等于板上稳定帧率。

复现顺序（使用带 NumPy 的 Python）：

```powershell
python -X utf8 -B tools/run_v09_questa.py --width 960 --height 540 --frames 2 --video-load 1
python -X utf8 -B tools/run_v09.py --width 64 --height 44 --frames 2 --video-load 1
python -X utf8 -B tools/run_v09.py --width 64 --height 44 --frames 3 --stall-pct 60 --rd-lat 48 --cnn-half-ns 2.7 --seed 143
python -X utf8 -B tools/run_v09.py --fault 1 --frames 2
python -X utf8 -B tools/run_v09.py --fault 2 --frames 2
python -X utf8 -B tools/run_v09.py --fault 3 --frames 2
python -X utf8 -B tools/run_v09.py --fault 4 --frames 2
python -X utf8 -B tools/run_v09_system.py
python -X utf8 -B tools/run_v09_cdc.py
python -X utf8 -B tools/run_v09_color.py
python -X utf8 -B tools/run_v09_control.py
python -X utf8 -B tools/run_v09_soc.py
python -X utf8 -B tools/test_firmware.py
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
python -X utf8 -B tools/package_v09_perf.py
```

完整尺寸用已安装 Questa 2025.3 四态仿真；其 DLL 在 Windows 沙箱内有启动错误，应在正常本机环境运行，不修改许可证。Questa 许可只允许一个同时运行实例，CPU 和 CNN 回归顺序执行。`run_v09_questa.py` 记录位于 `work/v09_perf/questa_960x540_c2.25_v1/`。`run_v09.py` 小图测试记录位于 `work/v09_perf/final/`。早期探索、旧源码仿真及失败实现不用于交付。原 `package_v09.py` 仅针对历史 100 MHz 基线，当前候选使用新入口。

## 上板观察

下载新文件后等待原开机流程。OSD 仍为 V09；右窗是风格结果，CAP/PRC 分别表示采集和处理完成帧率。按键与 115200 8N1 串口命令保持原样。

先确认 CAP 足够高，再看 PRC；间隔至少 60 秒两次执行 `status`，以 done 增量除以实际间隔确认平均处理帧率，同时观察每秒 PRC、IRQ 增长、error=0、画面是否错行、撕裂或闪烁。`cycles / 100000` 得毫秒，统计时间基准未改为 222.222 MHz。随后运行至少 30 分钟观察稳定性与温升。

本轮只解决性能路径和上板候选。动态 APB 权重加载、板上固定图/校验和及原 v08 通用 INT32 微基准仍按原记录待验收。

真实 Sapphire 补测已编译并进入生产固件的摄像头初始化，约九分钟后主动停止以释放单实例 Questa 许可，记录为 NOT_COMPLETED；不把这一启动观察当作完整 CPU/PLIC 回归通过。固件保持基线，上板联调仍待确认。原始中止证据位于 work/v09/soc_questa/。
