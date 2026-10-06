# v05 验证用例清单

本清单说明测试目标和通过条件，执行结论请查本版结果与对应日志；用例已编写不表示已通过。所有仿真由统一入口串行调度，避免并发占用 Questa 会话。

## v05 新增用例

| 用例 / top | 必须触发的刺激 | 必须满足的检查 |
| --- | --- | --- |
| `tb_sapphire_i2c` | 真实厂商I2C核，先不重启LISTEN，再按修复后的MMIO顺序执行 | 复现旧驱动第二笔ACK丢失；修复后两笔连续写、重复START单字节读回正确 |
| `tb_bayer_first_pixel` | VS与首个RAW同拍，连续帧尾仍在流水线，普通提前VS；四Bayer相位×两像素顺序 | 24帧768个空间变化像素全部准确、无少字/多字/列0覆盖 |
| `tb_camera_gate` | 半帧时延迟AXI B，ready下降且原始VS停高缺FE | 恰好一次合成截断，capture停止，AXI继续完成，半帧只拒绝不发布 |
| `tb_camera_gate`（同次运行） | disabled时VS翻转，ready恢复后无新边界但发送整帧数据 | 不泄漏原始VS；既不接收像素，也不续接旧帧 |
| `tb_camera_gate`（同次运行） | 真实新边界及两完整变化帧，随机AXI反压 | 两帧全部64个DDR像素匹配帧身份，B结束前不发布 |
| `tb_artflow_control` | APB合法/非法访问、扩展setup、默认值、上下限 | 确定PRDATA/PSLVERROR；非法写零副作用；CAMERA互斥 |
| `tb_artflow_control`（同次运行） | busy时改shadow、重复commit、长行空白、VS脉冲/电平/同拍首像素、尾流水线 | 接收快照原子不变；不得半帧调增益；完成镜像与busy同时更新；真实Bayer输出准确 |
| `tb_artflow_control`（同次运行） | 帧中停流、恢复边界、共同系统复位 | 无边界保持busy，边界恢复；复位取消旧请求且不重放 |
| `control_async_7_11` | APB半周期7ns、像素半周期11ns，复用控制完整刺激 | 与默认时钟关系相同的功能通过条件 |
| `control_async_11_7` | APB半周期11ns、像素半周期7ns，复用控制完整刺激 | 与默认时钟关系相同的功能通过条件 |
| `soc_success` / `tb_soc_boot` | 生产固件在真实Sapphire CPU执行、I2C引脚事务、UART白平衡命令 | 顺序准确的164次写和5次回读；READY/串口OK文本；目标增益原子生效 |
| `soc_nack` / `tb_soc_boot +SENSOR_NACK` | 首项传感器事务NACK | 真实CPU输出错误，摄像头保持复位，ready不置位，默认增益不变，UART help仍可响应 |

`python -B tools/run_v05.py --control-only` 覆盖真实I2C外设、Bayer首字、摄像头gate及三组控制时钟测试；`--soc-only --soc-scenario all` 覆盖成功与NACK CPU场景；`--full` 还包含继承视频完整回归。具体参数以入口 `--help` 为准。

## 继承视频用例

| 类别 | 用例 | 检查范围 |
| --- | --- | --- |
| 单元 | `scheduler`、`gamma`、`pattern`、`bayer` | 仲裁有界让步、Gamma查表、色条时序、Bayer黄金输出 |
| 组合 | `small_p{0..3}_r{0..1}_v{0..1}` | 16组合，三bank命中及左右窗/背景逐像素 |
| 压力 | `stress_31`、`stress_73`、`short_burst` | 独立通道反压、长等待、短帧尾突发、协议稳定性 |
| 故障 | `bresp_error`、`rresp_error`、`camera_stop_restart`、`truncated_frame` | 无效帧不发布，错误读帧按规定退化，撤销故障后恢复 |
| 共同复位 | `reset_during_write`、`reset_during_read` | 与存储器模型共同复位，清除事务并重新工作 |
| 显示模式 | `legacy_fullscreen` | DUAL_WINDOW=0兼容模式的完整黄金图比较 |
| 实际尺寸 | `full_high_load`、`full_30fps` | 1920×1080输出，双窗像素/帧身份及正常30fps采集重复显示 |
| 持续轮转 | `endurance` | 1000小尺寸完整输出帧，无冻结/倒退/错误像素 |
| 反向门禁 | `negative_gamma_missing`、`negative_x_vector`、`negative_missing_vector` | 缺失/未知黄金文件必须指定Fatal |
| 反向门禁 | `negative_startup`、`negative_stress`、`negative_frozen`、`negative_right_window`、`negative_border`、`negative_geometry` | 损坏图像/边框/帧连续性/几何必须指定Fatal |

## 实现、固件与硬件

`test_video_cdc_gate.py` 验证报告解析器必须拒绝缺位、错位、错预算、超延迟、错误corner及伪造并列reference；只接受由完整逐位记录证明的并列最短端点情形。`test_implementation_gate.py` 拒绝负setup/hold、缺活动时钟以及把CDC审计副本当正常时序报告。

`test_v04_evidence.py` 的7项自测验证RUNNING/PREPARED/FAIL/PASS生命周期、输入变更与日志替换；`test_delivery_gates.py` 的17项隔离夹具验证实现快照、旧输出、72项用例完整性、耐久帧数以及日志/截图哈希。它们不启动EDA，不属于功能覆盖率。

布线后 `check_video_cdc.py` 必须覆盖32+32+48端点，预算分别2.5/2.5/20ns；这是实际路由证据，与合成报告夹具不同。固件主机C测试、生产固件构建、RAM镜像一致性检查、CPU RTL执行及Efinity全工程实现分别保存证据，不相互替代。

UART电气、真实传感器、HDMI采集和30分钟稳定运行需单独上板执行，未执行前标为NOT_RUN。独立CPU/debug复位没有本版入口，不列为已支持的恢复场景。
