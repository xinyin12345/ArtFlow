# v05 功能到验证映射

此表定义必须满足的检查，实际通过状态以本版验证结果和日志为准。

| 等级 / 功能 | 刺激与检查器 | 用例 / 证据 |
| --- | --- | --- |
| P0 / Sapphire 生产固件启动 | 厂商 CPU RTL执行本版 BRAM 固件，UART位流解码 | `tb_soc_boot`；生产固件和4个RAM字节通道哈希 |
| P0 / CPU I2C 配置摄像头 | 开漏引脚模型检查写寄存器与关键回读，配置完成后才能READY | `tb_soc_boot`；实板电气独立验收 |
| P0 / UART 白平衡交互 | 115200 8N1命令经真实CPU→APB→像素域 | `tb_soc_boot`；串口命令和返回文本 |
| P0 / APB 接口确定性 | setup无副作用、错误地址/对齐/只读写/范围边界及错误响应 | `tb_artflow_control` |
| P0 / 三色原子提交 | busy期间修改影子、重复commit拒绝、快照不变、确认镜像一致 | `tb_artflow_control` |
| P0 / 帧安全增益 | VS脉冲/持续电平/同拍首像素、长行空白、末尾流水线真实RGB比对 | `tb_artflow_control`，真实 `bayer_bin2x2` |
| P0 / 摄像头停止与重新初始化 | 缺FE、VS停高、半帧关闭、B阻塞后排空、无新边沿不能续采 | `tb_camera_gate`；恢复两帧64个DDR像素逐点检查 |
| P0 / 同拍VS与Bayer首字 | 空间变化图案、列0只写一次、旧奇数行尾流水线保留 | `tb_bayer_first_pixel`；24帧768像素，四相位×两种像素顺序 |
| P1 / 控制跨域频率关系 | 默认100/50MHz之外，APB快/慢于像素的非整数倍关系 | `control_async_7_11`、`control_async_11_7` |
| P0 / 控制复位与状态 | 共同复位取消请求、默认增益与摄像头复位恢复、cal_done同步 | `tb_artflow_control`；独立CPU reset不在范围 |
| P0 / 控制CDC物理约束 | 48个RGB端点、源位映射、慢角延迟与skew | `check_video_cdc`；20 ns，每色16bit不可缺失 |
| P0 / 双窗和三缓冲保持 | 动态RAW、SV/Python逐像素比对、全部bank命中、B/RLAST生命周期 | v04 `small`16组合、`full_high_load`、`full_30fps` |
| P0 / AXI仲裁及事务 | 紧急优先但须让步、五通道随机反压、4KB/WLAST/未知值断言 | `scheduler`、`stress_31/73`、`short_burst` |
| P0 / 无效视频与恢复 | B/RRESP错误、截断帧、停流、共同复位，必须实际触发故障 | `bresp_error`、`rresp_error`、`truncated_frame`、`camera_stop_restart`、读写复位 |
| P1 / 全屏兼容与画质基础 | 参数全屏、Bayer所有相位/顺序、Gamma、测试图 | `legacy_fullscreen`、`bayer`、`gamma`、`pattern` |
| P1 / 连续轮转 | 小尺寸连续1000完整输出帧，帧号不能冻结倒退 | `endurance`；不等于板上30分钟 |
| P0 / 验证器拒错 | 损坏图像/黄金/几何、时序或CDC报告缺端点/超限 | 视频反向用例、`test_implementation_gate`、`test_video_cdc_gate` |
| P0 / Efinity实现 | 完整工程综合、接口、布局布线、比特流、正常STA | `run_efinity.ps1`、`check_implementation`及32+32+48 CDC审计 |
| P0 / 硬件验收 | 摄像头与屏幕实物、串口调参、长时间画面和链路状态 | `board_acceptance`；未执行前NOT_RUN |

检查器要求触发的功能事件不等同于代码覆盖率或形式化证明。I2C失败及UART非法输入等错误分支仅在有专门测试和执行记录时标注为已验证。
