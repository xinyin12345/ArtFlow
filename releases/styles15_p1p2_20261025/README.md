# 确认排序的15风格P1/P2候选

已完成离线签核：15 款最终顺序包、8 项功能回归、全新综合、单次 TIMING_3 合法路由、原时钟最终 STA、全部 5 组 CDC 和 bit/配置 hex 生成均通过。签核收据为 reports/styles15_final_receipt.json。尚未上板或写 Flash。

原R23T冻结目录保持不变。所有工程改动仅在本候选。未操作板卡、串口、JTAG或Flash；无Git提交。

|新索引|旧索引|中文名称|标识|模型槽地址|
|---:|---:|---|---|---|
|0|0|原彩绘玻璃|`glass`|`0x400000`|
|1|17|油画 O3|`oil`|`0x404000`|
|2|11|复古网点漫画|`halftone`|`0x408000`|
|3|1|油画星空|`starry`|`0x40C000`|
|4|3|红白剪纸|`papercut`|`0x410000`|
|5|16|素描|`sketch`|`0x414000`|
|6|8|波普风|`popart`|`0x418000`|
|7|2|水墨画|`inkwash`|`0x41C000`|
|8|5|富彩粗刀版画|`woodrich`|`0x420000`|
|9|15|朱红人物黑白|`vermilion_ink`|`0x424000`|
|10|6|偏紫马赛克|`mosaic`|`0x428000`|
|11|7|双色版画|`woodcut`|`0x42C000`|
|12|10|野兽派平涂|`fauve`|`0x430000`|
|13|4|赛璐璐|`cel`|`0x434000`|
|14|13|沙画|`sand`|`0x438000`|

仅4处STYLE_COUNT从19改15，5位接口不变。KEY3循环0–14后回0，默认glass=0。未改变CNN整数运算、原时钟、19款基线中其余功能或P1/P2交互行为；未用SoC SPI/GPIO保持此前已删除状态。

CPU固件没有风格数量/名称表，因此其源码与初始化映像逐项保持；FPGA参数负责15款循环，pair返回新索引。OSD原本只显示布局和CAP/PROC FPS，未新增风格名称UI。

模型包 outputs/models15_parameters.bin：245760字节；SHA-256 `81b99fc11a2460669d672832d2fb3311319ee78edab25aed9c8ad44b0413b3da`。outputs/models15_parameters.hex 是模型字节文本，供仿真读取，不是FPGA配置hex。每槽仅AFSM头索引可变，保留载荷、CRC及FF填充不变。

## 验证边界

- 真实SPI加载器按新包核对15款参数写入，CRC/头错误、缺失Flash、快速请求替换恢复通过。真实artflow_button逻辑参与循环测试，消抖计数为测试缩短值4，生产值未改。
- 配对标签/源帧保护/风格请求安全退出等36场景；系统15次渲染55296像素；停靠22场景；B响应延迟、超时、重试、复位与两套跨时钟RAM FIFO回归通过。系统CNN使用事务夹具，不宣称新跑完整15模型数值扫描。
- CPU正常启动/NACK和真实CNN数值证据按未变源码与初始化映像继承；不是新执行的长CPU或全尺寸CNN测试。
- 首次直接press循环仿真功能完成，但夹具运行中修改导致哈希守卫拒绝，未计入签核；test_fixture_revision.json与旧日志保留，固定新文件在独立输出重跑通过。
- P3色卡光标/P4蒙版涂画/P5展示UI未加入。无上板视觉、Flash内容确认或稳定FPS结论。

## 可复跑入口

- `C:\Python314\python.exe -B verify_package.py`：只读包完整性与反例校验。
- `C:\Python314\python.exe -B regenerate_package.py`：按确认顺序重新推导字节并比对bin/hex，不写文件。
- `tools/run_styles15_tests_v2.py`、`tools/run_styles15_prephysical.py`、`tools/finish_styles15_physical.py`保存本轮执行入口；已有输出会被守卫拒绝覆盖，不应原地重复运行。
- 最终只读检查为 `C:\Python314\python.exe -B tools/check_styles15_final.py`，只在全流程完成后运行。

配套15款bit与本模型包必须匹配。仅生成文件不会清除Flash尾部旧槽，也不会更新板上配置。未来部署须另行授权并明确备份、范围和回读；本轮不执行。

## 本次签核与交付

交付目录：`releases/styles15_p1p2_20261025`。其中 `ArtFlow_styles15_p1p2.bit` 和 `ArtFlow_styles15_p1p2.hex` 为 FPGA 配置文件；`models15_parameters.bin` 为配套模型包，基地址 `0x400000`，结束地址 `0x43BFFF`。两者须按本次 15 款顺序配套使用。本任务没有执行加载或烧录。

实际资源 56589 XLR / 246 RAM / 144 DSP，较原冻结 R23T 净减132 XLR，RAM/DSP不变。一次 TIMING_3 路由在第47轮达0冲突。原时钟最终最小setup/hold为 +0.244/+0.023 ns；CNN 7 ns、core 10 ns、SDRAM 2.5 ns不变。

全部5组CDC检查通过；7块原生双时钟返回RAM的写端、读地址、读数据setup/hold共6类报告逐块覆盖。SPI外部器件/PCB预算采用原签核假设，尚无本版板上测量。正式工程400个基线文件和原R23T冻结文件哈希均未变。

详细变更、证据、失败夹具记录及继承测试边界见 `reports/styles15_delivery_report.md`。交付manifest包含逐文件和ZIP内部文件SHA-256。生成完毕时本任务Efinity/Questa进程已退出。
