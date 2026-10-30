# 2026-10-31 OSD 黑边布局与 CAP/OUT 集成

## 界面与操作

双窗口保留左右各 960×540、y=270～809 的画面，上下黑边显示 64 像素 ARTFLOW 标题、32 像素模式/ORIGINAL/真实已发布风格名。修复叠字、行距、字形与像素流水对齐；采用白字、黄高亮、深灰底、状态色、边框和分隔线，显示 8 项风格指示。左右外沿及中间分隔边框覆盖少量边缘像素。两种全屏采用紧凑 HUD，图像不缩小。KEY1 三布局、KEY2 OSD 开关、KEY3 风格循环及原 UART 操作保留。

CAP 是实际抓取事件的一秒计数；OUT 是送入 TMDS 的最终 OSD VS 上升沿一秒计数，不是 PRC 改名或固定 30。界面不再显示 PRC，内部处理速率诊断保留。两条进度条目标均为 30；CAP 目标不是实测性能保证。冻结图像时 OUT 继续计数；VS 停止而像素时钟继续时，完整空窗口后公开 OUT 归零。像素时钟停止时无法继续计时或刷新屏幕。

保留玻璃、素描、油画、星空、网点、沙画、水墨、富彩粗刀版画 8 风格与模型、1080p30 / 74.25 MHz HDMI、原 Wi-Fi 推流、freeze/pair/blend/curtain/window/live。未合入手势试验或 ESP32 多客户端修改。

## 工程与构建

实际入口 `ArtFlow.xml` 与别名 `ArtFlow_glass.xml` 字节相同，73 项综合源文件完整。XML、SDC、peri 引脚/时钟约束未改，因此没有无意义的 XML diff。OSD 通过相对路径读取 `rtl/video/osd_text_rows.mem`；保留 `osd_font.mem` 作为字形源及参考模型输入。主要变更为 ArtFlow_top、artflow_accel_ctrl、artflow_osd、artflow_ui、cam_fb_pipe_v09、rgb_frame_store_v07 与两份 ROM。

从工程根目录执行：

```powershell
python -B tools/verify_osd_integration.py
python -B tools/build_osd_text_rows.py
python -B tools/run_osd_tests.py
python -B tools/check_osd_frames.py
$env:HOST_CC='C:/msys64/ucrt64/bin/gcc.exe'
python -B tools/run_osd_regression.py
python -B releases/osd_blackbars_20261031/flash_package/tools/verify_backup.py
```

仿真必须串行运行：本机 Questa 2025.3 节点锁定许可证只允许一个会话。Python 像素参考模型需 Pillow。工具可用 `QUESTA_ROOT`、`EFINITY_ROOT`、`HOST_CC` 指定。

完整重新综合/实现入口为 `python -B tools/build_osd.py`：interface、speed map（16 线程）、TIMING_3 seed=2 placer effort=5（16 线程）、原约束最终时序和 CDC 审计、pgm。新产物位于 `work/osd_impl/out/ArtFlow.bit` / `.hex`。已有结果需先在工程 work 下明确归档，脚本拒绝覆盖既有构建日志。原 `build_styles8.py` 的历史验证门禁不作为本 OSD 版本的正式构建入口。

## 物理证据与复用依据

本次未重新执行综合/布局布线。已在主工程逐项核对 236 项实现源码/初始化/配置输入，472 项非手势模型资料，以及两个入口。它们与最终候选输入相同；未改变综合选项、约束或 ROM 内容，只有目录迁移及构建/验证包装脚本适配。候选原总清单含 6 项未参与综合的手势源码和 7 项手势模型资料，这些不复制进主工程。73 项实际源列表和最终综合网表均排除手势。

`candidate_evidence.zip` 保留原相对目录、221 项源码/构建脚本/最终网表/布局/时序/CDC/固件证据及原 release_manifest，逐项 SHA256 核验。归档里的绝对路径是历史溯源记录，不是当前构建依赖。`implementation_inputs.json` 与 `tools/verify_osd_integration.py` 提供主工程独立复核。

Efinity 2026.1.132，Ti60F225，I3：LUT4 38,530；FF 25,807；ADD 6,672；SRL8 2,065；XLR 58,112/60,800；RAM 253/256；DSP 144/160。最终路由第 46 轮 overlap=0；setup 最小裕量 +0.313 ns、hold +0.026 ns。十个适用时钟和全部边沿关系通过；video/CNN/UI/native return RAM/新增 OSD 握手及 SPI 接口预算通过。外部 SPI 线延迟与器件时序仍使用既有预算假设。

## 固件与回退

正式文件在 `flash_package/`，其 README_FLASH_BACKUP.md、manifest.json、SHA256SUMS.txt 和 tools/verify_backup.py 说明并核验全部产物。`fpga/*.bit` 用于原有临时加载流程，`fpga/*.hex` 仅含 FPGA 配置；`models/models8_parameters.bin` 是 128 KiB 模型包，单独写入地址 0x400000。`flash/ArtFlow_osd_8styles_fullflash.hex` 已包含 FPGA 配置、FF 间隙和模型，从 0x000000 写入，末址 0x41FFFF。hex 为 Efinity 逐字节文本，非 Intel HEX。

本次已有 `bit/osdchange_version_20261031_0436/` 六个文件也全部提交，五个固件/模型文件与正式包逐字节一致，readme 保留。未执行任何烧录或推送。

旧版本为 4473983390d7009be06fc6f5fdb5ad54fe4bce03；旧固件仍在 `releases/styles8_stream30_20261030/` 及原 bit 归档。需要回退源码时优先对本次提交执行普通 `git revert <本次提交>`，先保存后续未提交工作，不 reset。合并前 Git 现场、完整 HEAD 归档及原 OSD 未跟踪文件备份位于工程树外 `../backups/osd_merge_20261031/`。独立候选保持原样。

## 手动验收与限制

用户在之前聊天确认同哈希 bit 上板显示效果不错。本次未执行实板测试，不将该反馈扩展为全功能验收。待检查：摄像头真实 CAP、HDMI 实际 OUT、三布局和 OSD 开关、全部 8 风格标签、按键/UART、冻结及创意功能、Wi-Fi 长时间稳定性、SPI 电气裕量、Flash 写入 Verify 和断电冷启动。系统仿真有一次启动下溢，与旧基线一致，不宣称全程零下溢。系统测试有 3 条警告，显示抽取测试桩有 55 条未连接端口等警告，测试显式 PASS 且无 Error/Fatal；这些不是零警告构建。

主工程本次实际测试结果见 `main_validation.json`，失败及恢复记录与未执行项目分列；逐文件交付清单见 `DELIVERY_FILES.md`。

## 固件 SHA256

- `flash_package/flash/ArtFlow_osd_8styles_fullflash.hex`：`9237026a9831d63b54e869a4867c0ebc95ba29838fbf07dfb9f5ebb377e56e07`
- `flash_package/fpga/ArtFlow_osd_blackbars_20261030.bit`：`8ff3f2565d92b7f9e4092d06513b8cefbc771ae21a2bc81f1458ba0fc31d1e50`
- `flash_package/fpga/ArtFlow_osd_blackbars_20261030.hex`：`8f0d1b632a34a4397542edb09b7a4d368c2a0f073bebb5aa23ac02d48600b104`
- `flash_package/models/models8_parameters.bin`：`2cdef6557e3c4b693d383ec039343dc3b1066b2c39921cf619b458266aa50c09`
- `flash_package/models/models8_parameters.hex`：`e6eef8394ec8af4df648cb94efe037ca644db134f938c6b36950105a1107d724`
