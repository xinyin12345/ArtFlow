# v06 功能映射

| ID | 功能 | 级别 | 实现 | 检查/功能覆盖点 |
|---|---|---|---|---|
| F06-01 | 版本、模式、FPS 字符 ROM | P0 | artflow_osd、osd_font.mem | 4 模式、开关、透明/边界像素、---，Python 逐像素 |
| F06-02 | 采集 FPS 与 HDMI FPS 区分 | P0 | artflow_fps、capture_toggle | 正常、零、BCD 进位、窗口末事件、999 饱和 |
| F06-03 | 两个按键同步/消抖/长按 | P0 | artflow_button | 短按、抖动、长按、释放、复位 |
| F06-04 | 帧边界切换和统计提交 | P0 | artflow_ui | DUAL/LEFT/RIGHT/BARS 循环、OSD 开关、帧内不变断言 |
| F06-05 | 最终 HDMI 像素对齐 | P0 | Gamma→OSD→TMDS 入口 | 两拍 OSD、四拍串联、DE/HS/VS、全1080p |
| F06-06 | 保留 DDR/相机/SoC 控制 | P0 | v05 原通路 + 遥测输出 | 继承视频72项、控制测试、固件主机5组 |
| F06-07 | 可复现构建与上板镜像 | P0 | XML、peri、SDC、工具 | 源/镜像哈希、GPIO、STA、CDC |
| F06-08 | 实际硬件体验及持续运行 | P1 | 板卡 | 独立实板验收，离线通过不替代 |
| F06-09 | 改善白平衡 | P0 | RAW10 黑电平减 68、默认 Q8.8 增益 102/102/102、1/2.2 显示 Gamma | 400 帧颜色算术自检；用户上板确认视频正常、画质改善，见 white_balance_improvement.md |
