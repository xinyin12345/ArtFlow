# v05 → v06 设计说明

## 范围及来源

以相邻 `v05` 为基线，保留摄像头、三缓冲、DDR/AXI、Sapphire、固件、Gamma。新增功能不修改相机格式、白平衡寄存器或帧缓存几何。v05 原始源文件哈希记录于 `baseline_v05/source_sha256.json`，构建检查原工程未变化。

引脚和按键极性核对自用户指定资料：

`E:\Work\FPGA\Efinity\Ti60F225_DemoBoard_v4完整资料包\Ti60F225_DemoBoard_v4\01_Ti60F225_Key_led_osc_demo\01_Ti60F225_key_demo\LED_8bit_Test.peri.xml` 和 `src/key_detect.v`。原示例仅作为板卡接口依据。新增按键 RTL 与字库由本工程实现，未复制示例的消抖状态机或外部 OSD IP。

## 数据通路

`cam_fb_pipe → test_pattern → gamma_lut → artflow_osd → dvi_encoder`。

OSD 两拍延迟，RGB/DE/HS/VS 等长流水；Gamma 两拍保持不变。坐标从 DE/VS 恢复，以有效像素左上角为 (0,0)。字符 ROM 1024×8，8×8 格式中包含 5×7 字形，4 倍显示；面板 x=32..927、y=32..95，28 字符×2 行，背景 #081828，标题 #40E0FF，数字白色。面板外透明，消隐输出黑色。`tools/gen_osd_font.py` 是字库源，`rtl/video/osd_font.mem` 是硬件初始化文件。

模式 DUAL 原样通过；LEFT 遮黑右半；RIGHT 遮黑左半；BARS 输出白、黄、青、绿、品红、红、蓝、黑。两窗口本来显示同一帧，v06 不引入缩放或 CNN。模式仅在最终显示端切换，DDR 帧所有权和读请求不随模式变化。

## 计数、CDC 与复位

`rgb_frame_store.published_frames[0]` 作为 capture_toggle，通过 cam_fb_pipe 输出。只有全部像素完成且所有 AXI B 响应成功才改变；丢帧、截断、BRESP 错误不计入 CAP。HDMI 域双级同步 toggle，再检测变化；正常每帧间隔远大于三个 HDMI 周期，单比特跨域无需多位总线采样。该计数不是 RAW VS 数，也不是独立新画面实际显示帧数。

HDMI 148.5 MHz 域以 148,500,000 拍作为一秒采样窗，直接使用饱和 BCD 计数器，避免像素路径上的二进制除法。计数包含窗口最后一拍事件，最大显示 999。OUT 统计正 VS 边沿。数值更新后由 UI 在下一次正 VS 整组锁存，因此会有最多一个显示帧的附加延迟。首次有效读数前显示破折号。采集停止后至 CAP=000 最长约两秒加一个输出帧。

按键经独立双级同步，并连续 2,970,000 拍确认新电平；按下产生单脉冲，稳定释放后才能再次触发。未显示的 mode/osd 请求可累积，VS 时提交；同拍按键脉冲也纳入当前提交。复位默认 DUAL/OSD ON。复位期间按住按键，释放复位后达到消抖时间会视为一次按下。

UI 使用 HDMI 域同步释放复位。按键 SDC 例外只截至第一级同步器，后级保留普通时序约束。capture_toggle 跨 AXI/HDMI 由原异步时钟分组覆盖；同步链后级由正常 STA 检查。`run_ui_cdc.ps1` 还要求三个新同步链各两个触发器实际存在，分别输出第二级 setup/hold 路径并检查非负 slack；完整实现入口自动调用。继承的两条 Gray 总线和增益 mailbox 继续执行独立布局后 CDC 总线延迟检查。

## 兼容与复现

新增四个 RTL 模块、一个字库；顶层接两个 GPIO，peri/SDC 加对应约束。帧缓存仅导出已有统计计数最低位，不改变读写状态机。旧单测连接新增输出，保留既有逐像素与 AXI 检查。固件仍用 v05 二进制及其内存初始化命名，镜像内容应逐字节保持相同。

历史 `run_v04.py` / `run_v05.py` 是被调用的子回归入口；`check_project_v05.py` 提供继承固件检查函数。v06 交付仅使用 `package_v06.py` / `verify_v06.py`。旧版本的打包/交付脚本不适用于 v06。
