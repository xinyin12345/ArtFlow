# Student U8 Optimized V2 整机吞吐优化

原工程：D:\work\FPGA\ArtFlow\ArtFlow。本次不暂存、不提交 Git，不自动下载板卡。

当前完整尺寸连续两帧为 6,394,066 / 6,389,790 个 100 MHz 墙钟周期，即 63.941 / 63.898 ms；保守仿真处理速度 15.639 FPS。最终签核与回归结果见 u8_optimization_results.md，发布状态以 outputs/student_u8_optimized/manifest.json 为准。此数值不是实板测量。

## 当前实现

- 活动核心为 rtl/cnn/student_u8/student_u8_flat.v，保持冻结的 19 层模型、U8/S12 编码、反射边界、同帧均值、残差舍入和 RGB nearest-even。
- 首层 RGB 3×3 tap 按行打包到现有 12 输入乘法通道，将九次 MAC 发射改为三次。原始四份 ROM 保留，新增 stem_packed_weights.mem 由冻结权重精确重排；无训练、重量化或系数改变。
- 量化由 4 通道分两次发射改为 8 通道并行；两个残差乘法用逻辑实现，避免 DSP 超限。下一组累加器初始化与上一组结果交接重叠。
- 上采样 DW 的相邻奇偶输出位置复用同一组源窗口，边界映射与运算保持不变。
- DDR 桥包含两组 256 字节读缓存，按工作区地址 bit 22 分组，避免源槽 2 与残差槽 0/1 交替替换。逐拍有效位允许所需数据到达后立即返回。
- 两组写合并缓冲与独立读/写状态机支持并发推进；写突发连续发送。写后读检查两组脏缓冲；最终发布仍等待所有 B 响应及读填充结束。
- 缩放器写突发改为连续流水，其 2×2 降采样、Gamma、双线性放大及 RGB 字节序不变。
- 输入 480×270，显示结果 960×540。6 MiB DDR 工作区为 0x01800000–0x01DFFFFF，最终 RGB 在槽 1 的 0x01A00000。
- CNN 为 142.857 MHz（7 ns），AXI/CPU 为 100 MHz。摄像头、HDMI、DDR、CPU 时钟及板级管脚配置保持原样。
- Efinity 2026.1.132 / Ti60F225 I3：XLR 55,606/60,800，RAM10 255/256，DSP 158/160；最差 setup +0.172 ns，hold +0.026 ns。视频、UI、CNN CDC 均通过。

## 验证与发布门禁

原包 189 项哈希不变；check_project_u8.py 检查冻结的各层配置、四份原始 ROM、首层权重排列及 MAC/行缓存/均值/统计模块。量化只允许通道复制与两个等价逻辑乘法映射。调度变化由独立整数模型逐层检查，不能仅凭综合成功发布。

- 完整尺寸两帧：每帧检查 782,400 次中间写入及地址、518,400 个最终显示像素。
- 相同访存条件：12 个 AXI 周期首拍延迟、25% 随机停顿，后台读约 256 MB/s、写约 64 MB/s。
- 小图回归：最小尺寸连续帧、不同随机图、60% 停顿、48 周期首拍延迟、非整数时钟比，以及四类 AXI B/R 错误。
- 独立 DDR 桥测试：10,000 条随机命令及定向写后读、部分写、缓存清除、阻塞 B 响应、提前读返回、并发读写、错误传播检查。
- 系统测试：相机采集、帧所有权、原图释放、AXI 仲裁、真实 CNN、显示输出与 APB IRQ，最终像素与独立 oracle 比对。
- 实现检查：资源容量、正常 setup/hold、全部 CDC、输入源码与位流哈希。

仿真使用 Questa 2025.3，许可证只允许单实例，所有仿真必须顺序运行。没有 UVM、代码覆盖率闭合或门级 SDF 声明。未改的独立 FIFO 复用源码哈希匹配的历史 Icarus 证据。生产 CPU/PLIC 长启动及实板 PRC FPS、长期稳定性仍需板上确认。

## 本机重复运行

默认 C:\Python314 没有 NumPy，数值回归使用已安装的共享运行时。

~~~powershell
$u8Python = 'C:\Users\20295\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
Set-Location 'D:\work\FPGA\ArtFlow\ArtFlow'
python -X utf8 -B tools/generate_u8_packed_weights.py
& $u8Python -X utf8 -B tools/run_u8_questa.py --width 960 --height 540 --frames 2 --tag opt_full
& $u8Python -X utf8 -B tools/run_u8_bridge.py
& $u8Python -X utf8 -B tools/run_u8_optimization_regression.py
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
python -X utf8 -B tools/test_firmware.py
python -X utf8 -B tools/package_u8_optimized.py
~~~

逐步成功后再运行下一步。完整仿真已经启动时，也可用 tools/run_u8_post_full.py 等待它完成，再顺序执行桥测试和短回归。发布脚本核对全部证据后生成 outputs/student_u8_optimized/ArtFlow_student_u8_optimized.bit/.hex，并同步 outflow/ArtFlow.bit/.hex。

## 保留与回退资料

本轮修改前源码和工作区差异位于 work/u8_optimization/baseline/；原 8.725 FPS U8 位流及证据保留在 outputs/student_u8_v2/。隔离的候选实现和筛选日志位于 work/u8_optimization/variants/ 和 work/u8_integration/opt_*/。第一次 8 通道量化综合消耗 162 个 DSP 的失败报告保留在 work/u8_optimization/dsp162_failure/；并行仿真触发单实例许可证限制的记录保留在 license_serialization/。这些不计入最终通过证据。

更早的 S8 位流、首次 U8 集成前快照和原模型集成包均保留。
