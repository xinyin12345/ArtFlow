# v05 验证计划

本版验证目标为 Sapphire RISC-V 控制面上线：固件从片内 RAM 启动，通过 I2C 配置摄像头，通过 UART 修改白平衡；v04 的三缓冲、AXI 仲裁、双窗口及像素结果保持正确。计划与实际结果分开，执行状态以 `doc/verification_results.md` 和对应原始日志为准。

## 控制寄存器与跨域原子提交

`sim/tb_artflow_control.sv` 直接实例化 `artflow_control` 和真实 `bayer_bin2x2`，不以软件模型替代 RTL。默认 APB 为 100 MHz、像素为 50 MHz；同一刺激还使用 `CORE_HALF/PIXEL_HALF=7/11` 和 `11/7` 两组非整数倍频率关系，检查请求、确认及快照在两种快慢方向均正常工作。

检查内容包括：ID/默认值；APB setup 无副作用；非法/未对齐地址、只读写、增益溢出及非法 CAMERA/COMMIT 返回 PSLVERROR；0 和 1024 的合法边界；CAMERA 复位/已配置互斥；DDR 校准状态同步；上电无视频时提交；busy 时影子仍可写、在途快照保持不变、重复提交报错；busy 清零与 ACTIVE 镜像一致。

帧安全检查使用真实 Bayer 输出逐像素比对：长行间空白不得触发提交；VS 脉冲和整帧有效电平；VS 紧接末尾有效 RAW 时尾像素保持旧增益；VS 与第一像素同拍时推迟提交；摄像头停在帧中时 busy 保持；共同系统复位取消在途请求并恢复三色默认值。控制单元不能独立证明所有 CDC 亚稳态行为，布线后静态约束审计必须另行通过。

## 摄像头停止和重新初始化

顶层通过 `artflow_camera_gate` 将已同步的 camera_ready 和 CSI VS/HS/valid/data 转成统一延迟一拍的采集输入。ready 下降必须产生一次合成 VS 边沿，明确截断未完成帧；ready 恢复后必须等到真实新 VS 边沿，不能把复位前后的有效数据拼成一帧。`artflow_control` 和 `cam_fb_pipe` 必须连接同一组门控后的采集信号，使增益提交窗口与实际进入 Bayer 的数据一致。

`sim/tb_camera_gate.sv` 使用真实 Bayer、三缓冲、AXI 调度器和独立反压存储器模型。定向构造半帧已采集且 AXI B 响应被阻塞、传感器没有 FE 并保持 VS 电平、ready 下降、ready 再上升后继续发送整帧数据但没有新边沿、最后真实新帧恢复。必须检查：合成截断恰好一次、disabled 的原始 VS 变化不向下游泄漏、半帧被拒绝、已接受 AXI 仍完成、无边界续流不能接收或发布、恢复后的两帧共 64 个 DDR 像素逐一匹配相应空间图案。

此测试不通过复位 DDR/FIFO 规避问题。已经完整接收的旧帧允许正常完成；只拒绝尚未完整捕获的旧帧。合成 VS 与最后已接收数据同走 Bayer 的时序流水线，不能提前破坏其尾像素。完整行为及接口见 `camera_gate.md`。

## VS 与首个 Bayer 输入同拍

`sim/tb_bayer_first_pixel.sv` 用随行、列和帧变化的 RAW 图案测试 v05 首字修正，避免恒色测试掩盖列 0 被覆盖。VS 与有效 RAW 同拍时，该字必须写入新偶数行列 0，下一字写列 1，且旧奇数行已进入后续流水线的尾像素不受影响。

遍历四种 Bayer 相位、两种输入像素顺序，各组合检查两个相邻且帧头与首字同拍的帧，以及一个常规 VS 先于数据的帧，共 24 帧、768 个输出像素。输出队列逐像素严格比较，并检查每组结束时没有缺失或多余像素。此修正改变真实视频核心，必须在新定向用例后重新运行全部 v04 视频回归及 Efinity 实现，旧核心的历史 PASS 不能直接代表本版修正后的结果。

## 实际 CPU、I2C 与 UART

`sim/tb_sapphire_i2c.sv` 直接实例化厂商 `BmbI2cCtrl`，先证明 STOP 会清除 RX LISTEN、旧顺序的第二笔地址 ACK 不会置 valid，再验证修复后的连续写入及重复 START 读回。它通过总线寄存器驱动实际外设，不替代后续 CPU 执行生产固件的测试。

`sim/tb_soc_boot.sv` 执行厂商 Sapphire RISC-V RTL与本版生产固件 RAM 内容，实例化 `artflow_soc`、`artflow_control` 和引脚级 I2C 传感器模型，通过串行位流发送 UART 命令。成功场景检查 164 条摄像头寄存器写入的顺序与值、5 次关键寄存器回读、READY 时机、115200 8N1 串口响应、白平衡命令的 APB 写入和目标时钟域生效。`+SENSOR_NACK` 场景检查真实 CPU 报错、保持摄像头复位和默认增益、继续响应 UART help。具体执行结论以最终 bench 和日志记录，不能用 APB 单测或主机 C 测试替代 CPU 启动证据。

此模型验证数字协议及固件行为，不能证明摄像头电气、板卡跳线、真实传感器型号或实际 RAW 图像。CPU bench 使用合成像素边界验证增益提交；摄像头重启后的真实像素管线由独立 `tb_camera_gate` 覆盖，并未与完整 CPU、CSI 接收器和 HDMI 编码器串成同一个全顶层仿真。总线超时、UART 非法命令等主机 C 测试覆盖的分支，也应明确区别于真实 CPU RTL 中的执行证据。

## 继承 v04 视频回归

`tools/run_v05.py --full` 应串行运行新控制面测试和 `tools/run_v04.py --full --soak-frames 1000`。v04 用例继续覆盖四种 Bayer 相位、两种像素顺序、两种 VS、Gamma、测试图、AXI 调度公平性、随机反压、短突发、B/RRESP 错误、停流恢复、截断帧、读写中共同复位、传统全屏、1080p 高负载及 30 fps。

三缓冲检查每个 bank 的发布、写响应和读 RLAST 生命周期，要求三个 bank 全部命中；左右两窗与同一源帧黄金图逐像素一致，黑边、冻结、倒退和错行都应失败。所有正常用例不得出现异常黑尾；故障用例只允许定义的前缀/全黑退化，并要求恢复完整帧。保留故意损坏黄金数据、窗口、边框与非法几何等反向门禁，证明检查器确实能发现错误。

1000 个小尺寸输出帧验证持续轮转，不等价于真实 1080p 连续运行 30 分钟。抓帧位于 Gamma 之前；未把 CSI 电气、Gamma、HDMI 编码器和串行器连成完整顶层数字仿真。

## 实现与 CDC 门禁

全工程执行 Efinity 综合、接口生成、布局布线和比特流；正常 `ArtFlow.sdc` 的活动时钟 setup/hold 必须满足门禁。CDC 使用只用于布线审计的 SDC 副本移除时钟分组，不能用该副本替代正常 STA 签核。

| 路径 | 完整端点 | skew / 数据延迟预算 |
| --- | --- | --- |
| capture_words Gray → count_meta | 32 | 2.5 ns |
| display_epoch Gray → epoch_meta | 32 | 2.5 ns |
| mailbox RGB → active gain RGB | 48（三色各 16） | 20 ns |

`tools/check_video_cdc.tcl` 检查实际网表单元数量；Python 门禁按三组精确约束解析报告，并检查慢角全部端点与 reference 并集、源/目标位对应、每组预算、skew slack、相对延迟以及 Clock-to-Q 加数据路径延迟。缺失任何端点或任一预算违规均失败。`tools/test_video_cdc_gate.py` 是合成报告反向夹具，不属于布线证据。

## 通过条件与边界

正向仿真要求退出码 0、最终 PASS、无未解释的 Error/Fatal/FAIL；Warning 必须记录并审查。指定反向用例必须出现对应 Fatal。保存日志、固件、源码和 RAM 内容 SHA-256；报告范围明确区分控制单元、真实 CPU 集成、视频回归、实现时序与实板。

`test_v04_evidence.py` 检查中断/异常/仅生成 Tcl 不能沿用旧 PASS；`test_delivery_gates.py` 用隔离文件夹验证旧 bit、过期输入快照、缺失或重复用例、耐久帧数不足、日志/截图改动与缺失哈希均会被拒绝。这些是验证工具自测，不运行 EDA，不计入视频的 72 项功能回归。打包必须绑定本次实现输入快照和生成的 bit/hex，视频必须包含完整注册用例集合及至少 1000 个耐久输出帧。

v05 只支持板级 `w_arstn` 共同系统复位。独立 CPU/debug reset 没有物理或固件入口，未验证其与保留视频事务的协同恢复。CAMERA.reset 属于传感器控制，不复位控制 mailbox 或单独清 DDR/FIFO。实板 30 分钟、I2C 电气与 UART 交互必须在真实硬件单独验收；未执行前保持 NOT_RUN。未采集 RTL 行/分支/翻转覆盖率，不报告 100% 覆盖率。
