# ArtFlow：8 风格、30 Hz HDMI 与 ESP32 推流

主工程入口为 `ArtFlow.xml`；`ArtFlow_glass.xml` 是相同入口。保留 1080p30、KEY1 三态显示、KEY2 OSD、白平衡默认 280/170/280、freeze/pair/blend/curtain/window/live 和原诊断功能。

|新编号|旧 15 风格编号|风格|
|---|---|---|
|00|00|原彩绘玻璃|
|01|05|素描|
|02|01|油画|
|03|03|油画星空|
|04|02|复古网点漫画|
|05|14|沙画|
|06|07|水墨画|
|07|08|富彩粗刀版画|

上电默认 00，KEY3 按上述顺序循环，07 后回到 00。风格切换由 FPGA 控制器完成；CPU 无独立风格循环，现有 OSD 仅显示布局和帧率，没有风格名称表。协议与诊断中的风格编号使用新编号，字段宽度保持兼容。

模型未训练、未量化、未改变网络结构。`network/styles8/models8_manifest.json` 同时记录新编号、旧 15 风格编号、最初 19 风格源编号和权重/载荷 SHA256。每槽 16 KiB，包长 128 KiB；模型 Flash 起址仍为 `0x400000`，末址 `0x41FFFF`。仅 AFSM 头中的槽位 ID 随重排改变，权重载荷逐字节保留。

## 构建与验证

使用已有 Python 3、RISC-V GCC、Questa 和 Efinity 2026.1：

```powershell
$env:HOST_CC='C:/msys64/ucrt64/bin/gcc.exe'
& C:/Espressif/tools/python/v5.5.6/venv/Scripts/python.exe -B tools/build_styles8.py
```

也可依次执行 `--phase tests`、`--phase map`、`--phase physical`。`BuildStream.ps1` 的 Check/Tests/EspTests/OriginalTests/Map/Physical 入口保留。完整脚本先运行原系统与推流测试，再综合、布局布线、原时钟 STA、CDC 与流接口审计，最后生成 BIT/HEX。`EFINITY_ROOT`、`QUESTA_ROOT`、`RISCV_GCC` 和 `HOST_CC` 可指定已有工具路径。

新结果位于 `work/styles8/`、`work/styles8_v2_*` 和 `reports/styles8/`。不复用 15 风格构建结果；不要同时启动重复构建。重跑前用 `--archive-run` 保存该轮的工作和报告。验证范围见 [计划](doc/styles8/verification_plan.md)、[功能映射](doc/styles8/feature_list.md) 与 [测试清单](doc/styles8/case_list.md)。

## 资源清理与兼容边界

当前包移除 papercut、popart、vermilion_ink、mosaic、woodcut、fauve、cel 七个槽位，共减少 114688 字节（46.67%）。当前 RTL 默认和顶层仅循环 8 个槽，当前构建、验证和模型重建入口同步为 8 风格。所有风格共用同一 CNN 和双参数 bank，因此没有七套独立运算引擎可删除。保留通用换模、CRC 拒绝和失效回退能力。

历史 `network/styles15` / `styles19`、既有 release 与回退镜像保留，既是回退资料，也是不可变的模型溯源；不参与新包的额外运行槽位。旧说明保存在 [历史 README](doc/styles15/README_before_styles8.md)。本任务不改独立 60 Hz Process 工程。

8 风格 BIT 必须配套新模型包，不能继续配旧 15 风格 Flash 模型。保留现有 ESP 应用；本任务不生成或发布含凭据的 ESP 固件，不访问串口、JTAG 或硬件 Flash。离线验证通过仍需用户上板确认画面、按键、推流及断电启动。

本次离线验证已通过：[验证结果](doc/styles8/verification_results.md)，[完整发布包](releases/styles8_stream30_20261030/README.md)。尚待用户上板验收。
