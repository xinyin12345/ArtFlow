ArtFlow v06 FIX1：SW0 之后 CSI 帧同步丢失的候选修复
日期：2026-10-07

结论与证据
1. 日志中 SW0 后重新出现启动横幅，确认它触发了整机复位。
2. 故障时 raw256 从 512313 增到 649236，而 vs_edges=0、bin256=0、所有写计数为 0。
   原始有效数据仍到达，但没有 CSI VS 边沿，所以采集门控在等待帧边界。
3. 后来 vs_edges=1，axi_aw=1013、w=129600、b=1013，published=1。
   129600 个 128-bit 写拍恰好是一帧 960x540x32-bit，全部写响应已返回。
   结合 CAP=000 和移动摄像头也不变，说明画面停在唯一发布的一帧。
   这些计数不能证明该帧的每个像素或 CSI 包内容正确。
4. status 在本固件中只读状态，不会初始化相机或切换视频模式。
   “发送 status 后出现一帧”不能证明 status 导致故障/恢复。
   ERR syntax 是输入命令解析错误，与 VS 消失不是同一层问题。
5. I2C 的 164 个寄存器初始化及指定寄存器读回成功，只证明相机控制面完成，
   不能证明 CSI 包解析或行帧同步正常。旧版 cam init 没有复位 CSI 和物理 RX FIFO。

FIX1 修改
- 四条 cam_d0/1/2/3_RST 从固定 0 改为有效的接收侧复位。
- SW0、PLL 未锁定、SoC reset 和软件 CAMERA_RESET 共同覆盖接收侧复位。
- 异步断言复位，按 core -> HS byte -> pixel 顺序通过各自三个时钟边沿释放。
  core 与硬件 FIFO 可以在 HS 时钟未出现时先释放，避免等待它自己才能启用的时钟。
  时钟在正常 HS 数据包之间暂停不会重新触发复位。
- cam init 现在会同时复位并重启传感器、RX FIFO、CSI；DDR/帧缓存继续按现有
  中止与事务收尾逻辑工作。没有增加“伪造正常帧同步”或自动重复初始化的机制。
- 启动标识改为 ArtFlow v06 FIX1 Sapphire RV32IM；保留 DIAG1 的 status 计数。

保留的用户设置
R/G/B=280/230/350，Bayer=BGGR，CFG_PATTERN=0，接口引脚和 MIPI 静态延时原值。
ArtFlow.xml、ArtFlow.peri.xml、ArtFlow.sdc 与你当前工程逐字节一致。
原工程 D:\work\FPGA\ArtFlow\ArtFlow，以及原 v06/DIAG1 均未覆盖。
FIX1 源工程位于 D:\work\CodexWork\ArtFlow\v06\work\sw0_diagnosis\fix1_project。

先执行这组上板操作：无需替换源码或重新编译
1. 保留此前下载的 bit，作为回退文件。打开串口文本日志，115200、8N1、无流控。
2. 在 Efinity Programmer 按原来的 JTAG 方式下载 ArtFlow_v06_FIX1.bit。
   这是临时 FPGA 配置；本轮不需要烧写 Flash。
3. 确认串口横幅是 ArtFlow v06 FIX1 Sapphire RV32IM，而不是 DIAG1。
   等待 READY 和图像稳定。移动/遮挡摄像头，确认左右窗口均实时更新。
4. 连续执行两次 status，中间间隔 3 秒。应看到 vs_edges、raw256、bin256、
   published 持续增加，CAP 恢复非零且接近原正常值，OUT 维持约 60。
   vs_edges 是“任意 VS 边沿”计数，不等于帧数。多行 status 也不是原子快照。
5. 测 SW0：按下约 0.2~1 秒后释放，等 READY，再等 3 秒，观察动态画面并记录 status。
   重复 20 次，交替短按/长按；每次都应完成重启并恢复动态图像。
   SW0 在当前工程中是整机复位输入；它不是 key_mode_n 模式切换输入。
6. 测 cam init：图像正常时执行一次，等 OK 后至少 3 秒，检查动态画面与两次 status。
   重复 5 次。初始化期间可以短暂停在上一帧，成功之后必须恢复连续更新。
7. 若再次黑屏/冻结，不要继续按 SW0。先保留相隔 3 秒的两次 status，
   再只执行一次 cam init，等 3 秒后发送 status，再隔 3 秒再发送 status。
   发回完整串口文本和“cam init 前后是否恢复动态”，不要只截最后一行。
8. 若画面已经实时更新、published 持续增加，但仍偏紫，再单独排查颜色通道与
   Bayer/行对齐。当前不要用反复调白平衡掩盖帧同步问题。
9. 回退时重新 JTAG 下载之前保留的 bit，无需回滚源码。

需要自己编译时
源码 ZIP 是完整独立工程，包括当前已生成的四个固件 BRAM 初始化文件。
可在原 ArtFlow 下解压到新的明确命名子目录，比如
D:\work\FPGA\ArtFlow\ArtFlow_FIX1
避免把 ZIP 直接覆盖到已有工程；这样可以随时用原工程做对照。
用 Efinity 打开解压后的 ArtFlow.xml，执行完整 Compile，然后下载新生成的 bit。
若通过 GUI 编译，GUI 可能再次重排 XML；随包保存的原始 XML 字节没有变化。
按当前命令行工具链复现时，在解压目录依次执行（每步成功再继续）：
  python -B tools/build_firmware.py
  python -B tools/test_firmware.py --cc C:\msys64\ucrt64\bin\gcc.exe
  python -B tools/run_csi_reset.py
  python -B tools/run_video_diag.py
  python -B tools/run_v05.py --control-only
  python -B tools/run_v04.py
  python -B tools/run_v06.py
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
命令行 bit 位于 work\efinity_out\ArtFlow.bit。
run_efinity 会验证 Efinity 重排前后 XML 的语义一致，再恢复原排版字节。
不应使用原版 verify_v06/package_v06 的原始版本哈希来认证 FIX1 变体。
只替换 main.c 不会更新 FPGA 内已嵌入的固件；修改固件后须重新生成四个 BRAM
文件并重新编译 bit。已提供的 FIX1.bit 已经包含对应固件，不需额外烧软件。

验证范围与限制
通过：新增三组时钟复位测试（每组 88 次断言）；相机重启期间实际 Bayer/帧缓存/
AXI 仿真及 64 像素核对；诊断跨域、控制面、原有视频、OSD/FPS/按键测试；
固件编译和 4 组主机测试；Efinity 综合、布局布线、bit 生成、普通时序和同步链检查。
普通 setup 最小余量 +0.459 ns，hold +0.026 ns。
未执行：真实开发板 FIX1 故障复现/修复验收、物理 D-PHY/模拟电路故障仿真、
新增完整 1080p 长时间采集仿真、新增真实 Sapphire 启动测试。
测试中的 CSI 输出复位行为是边界模型，不是对加密 CSI IP 或物理接收器的验证。
目前已修正代码中确定存在的复位缺口；“这就是全部硬件根因”仍是待上板验证的推断。
这批日志不足以确定偏紫的独立根因，需先确认连续采集恢复。

依据
Efinix MIPI CSI-2 RX Core User Guide v3.2，第 18 页 Reset Sequence and Initialization：
https://www.efinixinc.com/docs/mipi-csi2-rx-core-ug-v3.2.pdf
Efinix 官方示例的 RX 数据 lane RST 随系统复位断言，而不是一直固定为 0：
https://github.com/Efinix-Inc/tinyml/blob/main/tinyml_vision/Ti60F225_mobilenetv1_person_detect_demo/edge_vision_soc.v
