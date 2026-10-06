# v04 功能到验证映射

| 等级 / 功能 | 刺激与检查器 | 用例 / 覆盖门禁 |
|---|---|---|
| P0 / 居中双窗 | 动态 RAW、SV 逐像素、Python 独立全图比较、黑边检查 | small 16 组合、full 两组、negative_right_window / border |
| P0 / 三缓冲帧管理 | 发布逐字检查、B/RLAST 生命周期、输入输出绝对帧号 | 所有端到端用例要求 banks=111；冻结反向门禁 |
| P0 / AXI 调度公平性 | 双请求、单侧紧急、随机完成延迟、请求撤回、复位 | scheduler：两个方向的紧急命中及强制让步均非零，等待≤2个对方 grant |
| P0 / AXI 事务完整 | 五通道随机反压、长停顿、协议断言 | stress_31 / 73、short_burst；全局未完成事务≤1 |
| P0 / 正常 30 fps 到 60 Hz | 真实 1080p porch、摄像头帧周期检查 | full_30fps：正常重复完整帧且持续更新，无异常黑尾 |
| P0 / 无效帧拒绝 | B 错误、已获许可帧中途截断 | bresp_error、truncated_frame，必须实际触发拒绝事件 |
| P0 / 故障恢复 | R 错误、长等待、停流重启、共同复位 | rresp_error、camera_stop_restart、reset_during_write / read |
| P1 / 保留全屏模式 | 编译参数 DUAL_WINDOW=0 | legacy_fullscreen，SV+Python 全图比对 |
| P1 / 连续轮转 | 小尺寸连续1000完整输出帧 | endurance：全像素/帧号/三bank检查，非硬件时长验证 |
| P0 / 实现时序 | 全工程编译、正常 SDC、CDC 路由 | compile + check_implementation + check_video_cdc，门禁反向夹具 |
| P0 / 实板30分钟 | 动态场景、HDMI采集、稳定期事件记录 | board_acceptance：待实板执行，当前 NOT_RUN |

这里的覆盖为检查器要求触发的功能事件，不是 RTL 代码覆盖率或形式化证明。
