# ArtFlow v06 白平衡改善版

2026-10-11；正式工程为 `D:\work\FPGA\ArtFlow\ArtFlow`，基于提交 `7e2670d4611bd7482c87382317fadc21cf277855` 推进。版本功能为**改善白平衡**，版本标签为 `v06-white-balance`。

## 实板结果与正式版本

用户已烧录 `ArtFlow_reference_color_trial.bit`，确认视频正常输出，画质比此前明显改善，并要求将其作为正式版本。先前的“无信号”反馈由用户更正为显示器长时间无输入后休眠，不作为本版 HDMI 故障记录。

正式工程恢复该 bit 对应的源代码、启动固件和构建结果。正式镜像 `outflow/ArtFlow.bit` 及交付文件 `ArtFlow_white_balance_improved.bit` 与用户验证的测试 bit **逐字节相同**；本次推进没有重新综合或改动视频逻辑。原回退记录保留为操作历史。实板结论来自用户观察，未进行色卡误差或白平衡精度量化。

## 采用的参考行为

用户确认参考 bit 在刚上电、没有修改 VIO 增益时颜色正常。本版迁移其黑电平、有效增益比例和显示 Gamma：

| 项目 | 修改前 ArtFlow | 白平衡改善版 |
| --- | --- | --- |
| 黑电平 | 无 | 每个 RAW10 采样先减 68，小于等于 68 时输出 0 |
| 上电 R/G/B，Q8.8 | 280 / 230 / 350 | 102 / 102 / 102 |
| 串口 `defaults`，Q8.8 | 280 / 255 / 350 | 102 / 102 / 102，与硬件复位一致 |
| 显示 Gamma | 约 2.2 次幂，压暗 | 1/2.2 次幂，与参考曲线方向和整数采样点一致 |

参考 BLC 是在 RAW8 中减 17，换算为 RAW10 是 68。本版保留 RAW10 的低两位，在两个绿色样本分别做减黑和零截断之后，再计算 `(Gr+Gb)/2`；避免先平均再减黑导致阈值附近行为不同。

参考 `debug_top.v` 的 VIO 上电值为 280/255/350，但它连接的 `wb_gain_3ch.v` 使用 **Q2.14**，并把小于 6554 的增益钳位到 6554。因此参考默认实际是三通道同为 `6554/16384 ≈ 0.400024`，并非其顶层回退常数 17826/24718/17778。ArtFlow 串口保持 Q8.8，以 102/256 ≈ 0.398438 接近这一实际状态。无需在 ArtFlow 输入 Q2.14 数值。

`rtl/ArtFlow_top.v` 的 `CFG_BLACK_LEVEL` 传入 `cam_fb_pipe` 和 `bayer_bin2x2`，后者复用原输入寄存级，数据及同步信号延迟仍为 5 拍。显示继续使用原 2 拍 `gamma_lut`，仅选择已经存在的 `gamma_inv2p2_8b.mem`。固件帮助文字直接读取默认常数，四个启动 BRAM 文件已重新生成。

ArtFlow 继续使用 2×2 合并后的 960×540 图像、原双窗口、OSD 和独立 1080p60 输出。参考的全分辨率插值、Q8.1 Gamma 输入、锐化、CCM 和饱和度处理未在本轮移植；本版采用固定默认值和串口可调白平衡，没有加入自动白平衡统计。

## 本轮验证

- Efinity 2026.1 完整 compile：map、interface、pnr、pgm 通过。普通时序最小 setup 裕量 **0.369 ns**，hold **0.026 ns**。
- 视频跨时钟总线检查：32 + 32 + 48 个端点通过；完整检查结果及 UI 同步链结果见交付包中的 JSON。
- 新增 `sim/tb_reference_color.sv`：400 帧，12,800 个 BLC/WB 像素和 12,800 个 Gamma 像素与独立算术期望一致，覆盖 4 种 Bayer 排列、两种顺序、5 组增益、阈值、饱和、绿色平均、有效空拍、首像素、帧尾和同步延迟。
- 原首像素回归：24 帧、768 像素通过。原 APB 控制回归：132 次 APB 访问、20 个 Bayer 像素通过。
- 固件 4 组主机测试通过，包含真实命令处理、默认值/帮助信息、相机 164 次寄存器写入和错误处理。启动固件 6,332 字节，4 路 BRAM 重构校验通过。
- 本机 Icarus 13.0 在输出 `DONE.` 并生成模型后发生 Windows 退出异常 `0xC0000005`。使用测试脚本明确的 `--allow-compiler-exit-crash` 选项继续运行新生成模型；三项运行退出码均为 0，所有断言通过。该工具异常保留在日志和 `color_tests.json` 中，未当作正常编译退出。
- 版本推进时逐项核对已恢复源文件与原测试/实现快照相同，并重新执行工程输入、普通时序与 CDC 结果检查；沿用该相同代码和 bit 的既有仿真、固件测试和实现结果。未重复完整编译或历史视频端到端回归。
- 实板：用户确认相同 SHA256 的 bit 视频正常、画质明显改善。长期运行、色卡校准等未包含在本次用户反馈中。

## 上板步骤

1. 下载正式文件 **`ArtFlow_white_balance_improved.bit`**，或工程 `outflow\ArtFlow.bit`。二者与已验证的 `ArtFlow_reference_color_trial.bit` 相同，板上若已运行该测试 bit，无需仅为版本推进重新烧录。修改前的旧 bit 保存在 `work\reference_color\baseline`。
2. 先保持默认参数，在相同光源下观察白纸、灰色物体、皮肤及暗处。串口 115200 8N1 发送 `status`，预期 `active=102 102 102`。OSD 版本文字仍为 V06。
3. 如颜色基本中性但亮度不合适，可发送 `wb 256 256 256` 查看三通道同倍率提高后的效果；这会改变与参考默认值的亮度对照条件。发送 `defaults` 恢复 102/102/102。串口等待 `OK wb applied` 后再发送下一条。
4. 后续微调时记录光源、白纸颜色、暗部和亮部效果，以及 `status` 的 active 三个值。白平衡调整在帧边界应用；当前串口值不会保存到断电后的默认值。

本次 bit 的 SHA256：`9e962696cb479fc9d9dae560be25e2fb5625b5b69c59a6d6f4ba97dcf2d535d0`。大小 2,446,704 字节。交付 `manifest.json` 记录正式 Git 提交、标签和文件哈希；`doc/white_balance/` 保存该版本的源文件快照、检查结果和实板记录。

## 复现

在工程根目录使用 UTF-8 Python 环境：

```powershell
$env:PYTHONUTF8='1'
python -B tools/test_firmware.py --cc C:\msys64\ucrt64\bin\gcc.exe
python -B tools/test_reference_color.py --tool-bin <Icarus的bin目录>
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
```

只有在确认上述特定 Icarus 退出异常时才增加 `--allow-compiler-exit-crash`。任意运行失败、断言失败、缺失模型或其它编译错误仍会终止测试。测试中 BLC=0 的旧模块实例仅作为延迟和历史行为对照，实际板级参数为 BLC=68。
