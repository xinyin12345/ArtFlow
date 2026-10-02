# v03 用例表

工具：Questa Altera Starter FPGA Edition-64 2025.3，Python 3.14。执行 python -B tools/run_v03.py --full。默认输出 work/regression_v2/。

| 用例 | 输入尺寸 | seed | 验证重点 |
|---|---|---:|---|
| config | Python 配置夹具 | — | 实际配置加载；增益传播；注释/缺失/重复/表达式/溢出/几何拒绝 |
| gamma / pattern / bayer | 单元 | 各 1 | 原单元自检；Bayer 4 相位×2 顺序×2 VS |
| small_p{0..3}_r{0..1}_v{0..1} | 160×40 | 1..16 | 16 种完整组合，动态帧、三 bank 和全部有效像素 |
| stress_31 / stress_73 | 320×96 | 31 / 73 | AW 0.2ms、W 1.5ms、B 1ms、AR 2ms、R 2ms；丢帧/溢出/拒绝/恢复 |
| short_burst | 16×8 | 7 | 每帧仅 8 个 128 位 AXI 字 |
| bresp_error | 160×40 | 102 | 至少 2 个非零 B 响应，拒绝坏帧 |
| rresp_error | 160×40 | 103 | 至少 8 个非零 R 响应，黑尾后恢复 |
| camera_stop_restart | 160×40 | 104 | 停止后稳定重复 5 帧，重启至少 2 次更新 |
| truncated_frame | 160×40 | 105 | 半帧截断必须被拒绝 |
| reset_during_write | 160×40 | 106 | W 事务期间全局复位 |
| reset_during_read | 160×40 | 107 | 未到 RLAST 时全局复位 |
| full_high_load | 1920×1080 | 1 | 约 82.5 fps 摄像头，1080p60，连续 3 个正确输出帧 |
| full_30fps | 1920×1080 | 17 | 摄像头周期误差不超过 3%，1080p60，连续 7 个正确输出帧，必须出现重复 |

full 共 30 项正向 RTL 仿真、27 次 Python 抓帧复核、1 项配置夹具检查。普通回归不含 2 个 full 用例及其抓帧检查。smoke 为 config、3 个单元、1 个端到端及其抓帧。

## 负向门禁

Python 普通/full 回归另外运行 7 项：negative_gamma_missing、negative_x_vector、negative_missing_vector、negative_startup、negative_stress、negative_frozen、negative_geometry。PASS 表示预定错误被 Fatal 拒绝，不表示错误日志本身是正常仿真。Bayer 文件的两项仅修改临时生成的 golden，并在 finally 中恢复；后三种画面错误注入检查器观察值，不改变交付 RTL。

原生 do sim/run_v03.do full/smoke 使用同一个正向用例表。负向门禁由 Python 批量入口执行，原生入口不重复运行负向用例。实际执行范围、耗时与结果见 verification_results.md 和 verification/regression_summary.json。
