# v03 验证计划

目标：固定尺寸 RGB 通路的完整帧发布、bank 所有权、动态画面更新及故障恢复。最新版结果见 [verification_results.md](verification_results.md)。

## 验证边界

端到端使用实际 cam_fb_pipe RTL，CSI 输入与 DDR 使用事务模型；gamma/test_pattern 独立单测。DDR PHY、CSI 电气接口、HDMI 接收器及板上色条切换需实板验证。不是 UVM 环境，不使用 UVM_ERROR/UVM_FATAL 指标。

## 检查方法

- 顶层 ArtFlow_top.v 是尺寸、porch、增益、Bayer 相位与顺序的唯一配置源。Python 和 Questa 原生入口共用 run_v03.py 的用例表，参数读取失败不回退默认值。
- RAW 每帧变化；前 8 个合并像素编码 32 位绝对输入帧号，余下使用 8 种图案。检查器通过捕获/发布/读出事件关联帧身份，再逐像素比较输出。它是结合内部元数据和外部像素的 scoreboard，并非纯黑盒。
- 启动期无已发布帧时，每个有效像素必须为黑且无 X。正常运行不允许错误像素；压力/RRESP 故障只允许“正确前缀＋全黑尾部”，黑尾开始后禁止恢复非黑。
- 帧号不可倒退；有更新已发布时不得连续超过 3 个输出帧停留在旧帧。摄像头停止后允许持续重复最新完整帧，重启后必须恢复更新。
- 每次发布逐字检查整个 DDR bank，三 bank 必须全部命中。检查 B 前不发布、RLAST 前不释放、读写 bank 不相撞、单通道 outstanding 范围。
- AXI 五通道随机反压，另注入 AW/W/B/AR/R 长停顿、BRESP/RRESP 错误、截断、停流及事务中系统复位。全局复位同时复位 DUT 和 AXI 从机；不模拟“主机单独复位后从机继续旧事务”。
- 小分辨率执行 4 相位×2 顺序×2 VS 形式全部 16 组合。全分辨率使用真实 2200×1125 输出时序，分别测试高负载输入及 30 fps 输入到 60 Hz 输出。
- 负向门禁验证缺失/X 黄金文件、启动非黑、压力期错误像素、冻结画面和非法几何参数会触发 Fatal。
- CDC：完成 toggle 比计数/坏帧标志多一级同步；仿真断言完成可见时元数据一致。Efinity 正常约束下做综合/布局布线；另以只用于 CDC 审计的 SDC 展开 Gray 跨域路径，强制 32+32 端点、skew 和数据延迟不超过 2.5 ns。

## 通过条件

正向用例要求退出码为零、无 Warning/Error/Fatal/FAIL、存在最终 PASS，并完成全部 scoreboard/故障触发门禁。负向用例必须出现指定 Fatal 且不能有最终 PASS。完整结果保存在 work/regression_v2/summary.json，并将摘要纳入 Git。

功能映射与用例见 [feature_list.md](feature_list.md)、[case_list.md](case_list.md)。未采集行/分支/翻转等覆盖率，不声称覆盖率 100%；有限时长的恢复测试不等于长时间硬件稳定性验收。
