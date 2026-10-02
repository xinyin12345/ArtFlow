# v03 用例表

工具：Questa Altera Starter FPGA Edition-64 2025.3；Python 3.14。不是 UVM 测试环境，UVM_ERROR/UVM_FATAL 指标不适用。

| 用例 | 尺寸 | seed | 重点 |
|---|---|---:|---|
| gamma | 单元 | 1 | 原 gamma 回归 |
| pattern | 单元 | 1 | 原色条回归 |
| bayer | 64×16 | 1 | 32 帧、8192 像素、相位/顺序/同步形式 |
| small_p0..3 | 160×40 | 各 1 | 四相位、动态帧、随机空拍/反压 |
| reverse_pulse | 160×40 | 17 | 反向像素顺序＋帧头 VS 脉冲 |
| stress | 320×96 | 31 | AW 0.2ms、W 1.5ms、B 1ms、R 2ms 的有界停顿 |
| short_burst | 16×8 | 7 | 一帧少于一个最大突发 |
| full | 1920×1080 | 1 | 真实 1080p60，动态帧、三 bank 全内容 |

普通回归 10 次 RTL 仿真；--full 共 11 次 RTL 仿真。Python 还复核每个端到端用例抓帧。每次运行的实际 PASS/FAIL 和耗时以 summary.json 为准。
