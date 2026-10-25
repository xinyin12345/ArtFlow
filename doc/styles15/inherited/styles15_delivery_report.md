# 15款最终展示顺序 P1/P2 交付报告

状态：离线签核 PASS。记录时间 2026-10-25T09:27:52.013714+00:00。

工程：`D:\work\FPGA\ArtFlow\Process\interactive_art_20261024\integration_styles15_display_20261025`。继承冻结R23T，只调整用户确认的15款数量和顺序，原正式工程及冻结release未覆盖。一次新综合、一次TIMING_3 PNR，无换种子或放宽时钟。未操作硬件、串口、JTAG、Flash或Git。

## 实现与模型

确认新→旧索引 `[0,17,11,1,3,16,8,2,5,15,6,7,10,4,13]`；完整名称和槽地址见README与outputs/old_new_mapping.csv。默认glass=0，KEY3按0–14循环。

仅4处实现变化：rtl/ArtFlow_top.v:587；rtl/video/cam_fb_pipe_v09.v:4；candidates/round15_return_ram/artflow_cnn_accel.v:4；rtl/cnn/glass_int8/style_bank_controller.v:3。均为STYLE_COUNT19→15。循环使用STYLE_COUNT-1（style_bank_controller.v:39），保留5位接口、配对标签和错误恢复。OSD没有风格名称表，没有新增UI。

CPU程序、链接脚本、启动代码和所有初始化映像保持字节相同。CNN整数运算、摄像头/WB、按键模式、诊断、OSD/FPS、P1/P2配对冻结/艺术窗/滑帘/五档RGB混合/恢复实时保留。此前未用SoC SPI/GPIO删除状态保留。P3色卡光标/P4蒙版/P5扩展界面未纳入。

模型包245760字节，15个16KiB槽，0x400000–0x43BFFF。重建AFSM索引，每个14448字节权重载荷及CRC、1904字节FF填充与原模型完全相同；glass槽0完全相同。无重训。独立重建对照和6类破坏测试PASS。原19包与源权重未改。

## 已执行验证

8项已接受回归均PASS，见reports/round23t_functional_receipt.json及work/styles15*_*/summary.json：

- 实际SPI加载器CRC、坏CRC拒绝和恢复；全部15款载荷写入核对。
- 实际artflow_button + 实际加载器：0–14循环、抖动拒绝、帧边界提交、快速请求替换、坏header、缺失Flash恢复。仅夹具消抖参数4拍，生产值未改。
- 配对控制36场景，含15种标签的30次生命周期、取消、异常、排空、源帧保护。
- 整机事务夹具：8任务、15渲染、44捕获、55296像素；预期1次启动underflow，不隐去。
- 总线停靠22场景、15360像素、3925写/572读；B延迟、5000周期协议超时、重试/复位/恢复实时检查。
- 原生RAM FIFO标准和错相时钟两组回归，满空/背压/回卷/碰撞/排空/复位。

系统CNN使用事务夹具，不能当作15模型真实CNN数值或板上FPS验证。真实CNN和CPU正常启动/NACK证据按未变实现哈希继承冻结基线，本次未重复长CPU或完整15模型图像扫测。

首轮直接press循环仿真功能PASS，但运行时测试夹具改动触发哈希守卫，未纳入签核。原失败日志保留在work/styles15_style_cycle和reports/test_fixture_revision.json。新固定文件tb_styles15_button_cycle.sv重新运行通过，使用独立v2证据；未覆盖失败结果。其他只读检查曾遇文本编码/相对路径错误，修正读取方式后完成，不涉及实现变化。

## 物理签核

新综合37312 LUT / 25290 FF / 2065 SRL / 6496 ADD / 246 RAM / 144 DSP；相对R23T -132 LUT、+5 FF、其余相同。344条综合warning与基线归一化相同，未掩盖新增warning。

实际打包56589 XLR / 246 RAM / 144 DSP，相对R23T56721净减132 XLR。XLR不等于LUT+FF简单相加。TIMING_3，第47轮0冲突，原时钟最终STA最小setup +0.244 ns、hold +0.023 ns。CNN7ns +0.460/+0.028 ns；core10ns +1.411/+0.027 ns；SDRAM2.5ns +0.450/+0.023 ns。

video/UI/CNN/style_io/return_RAM五组CDC PASS。CNN52个Gray端点、108条同步级setup/hold路径、两条停靠/释放跨域和4条同步级路径核对。7块返回RAM每块均覆盖写端、读地址、读数据的setup/hold。6类最低裕量分别3.187/0.337/2.331/0.192/1.129/0.714 ns。SPI外部时序预算沿用原Flash/PCB假设，仍需硬件验证；未宣称上板成功。

## 产物SHA-256

- 配置bit：3307662字节，`3edf836b23255f522da09efe3b1f1c141511f562a5c3ea567e93e68dd1238070`。
- 配置hex：3307722字节，`1756429faafd0cd315810f77464aecbb87b79199b007c0642c3d8269eb78ed65`。
- 模型bin：245760字节，`81b99fc11a2460669d672832d2fb3311319ee78edab25aed9c8ad44b0413b3da`。

交付在releases/styles15_p1p2_20261025。outputs/models15_parameters.hex是仿真原始字节文本，不是FPGA配置HEX；不要混用。

## 保留与复核

正式工程400个文件、原R23T冻结7个文件及146个继承文件（仅上述4处允许变化）均复核。源权重/原19包保留。2026-10-25约09:27 UTC查询本候选Efinity/Questa/Python构建进程为空，所有本轮会话正常退出。

复核命令（候选根目录）：`C:\Python314\python.exe -B tools/check_styles15_final.py`。模型只读校验：`verify_package.py`、`regenerate_package.py`。新构建入口见README，拒绝覆盖既有输出；测试/实现/约束/工具/日志哈希已绑定，不原地重复启动。

剩余边界：本次离线目标完成，无待审批软件阻塞；没有本版板上画面、Flash回读或实际FPS验证。后续上板/写Flash需要单独授权。
