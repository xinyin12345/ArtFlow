# v06 用例目录

| 用例/入口 | 主要检查 | 特征 |
|---|---|---|
| tb_v06_ui | 12 项自检：复位、毛刺、帧提交、长按、释放反弹、四模式回绕、OSD 开关 | 消抖阈值缩短至4周期，生产参数20ms由综合使用 |
| tb_v06_fps | 4 个完整采样窗；独立事件/CDC 模型；窗口末拍和饱和/零统计 | 4096周期/窗；不作为实测时间 |
| tb_v06_osd + pixel_reference | 9×1920×100，四模式开/关以及未有效FPS文本，共1728000像素 | 比较字形、位置、颜色、边界、消隐和同步；不强制内部状态 |
| tb_v06_chain | 4×1920×1080，画面中途按键、Gamma LUT、左右遮罩、色条、帧原子性 | 共8294400有效像素，OSD区域由前一用例逐像素覆盖 |
| inherited control | 真实 Sapphire I2C、首像素24帧、camera gate、APB三组时钟 | 复用 v05 用例，重新运行 |
| inherited video | 调度器、Gamma、色条、Bayer、16种相位/顺序/VS、小尺寸/1080p/30fps、错误/拥塞、1000小帧、预期失败门禁 | 72项结果组成以继承 summary.json 为准 |
| host firmware | console、I2C、camera、command dispatch、ROM | 5组实际C代码测试 |
| optional CPU boot | 生产 Sapphire 执行固件，正常启动/NACK | `run_v06.py --full --soc`；本轮是否执行见结果文档 |

v06 新增用例采用确定性激励；继承随机种子保留在 `work/regression_v06/inherited/video/summary.json`。不以 testcase 个数替代功能覆盖或代码覆盖。
