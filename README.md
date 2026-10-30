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

上电默认 00，KEY3 按上述顺序循环，07 后回到 00。风格切换由 FPGA 控制器完成；CPU 无独立风格循环，新版 OSD 显示布局、实际已发布风格名称和 CAP/OUT 帧率。协议与诊断中的风格编号使用新编号，字段宽度保持兼容。

模型未训练、未量化、未改变网络结构。`network/styles8/models8_manifest.json` 同时记录新编号、旧 15 风格编号、最初 19 风格源编号和权重/载荷 SHA256。每槽 16 KiB，包长 128 KiB；模型 Flash 起址仍为 `0x400000`，末址 `0x41FFFF`。仅 AFSM 头中的槽位 ID 随重排改变，权重载荷逐字节保留。

## 构建与验证

当前 OSD 版本使用 `python -B tools/build_osd.py`，串行执行功能检查、综合、布局布线、最终时序/CDC 和 bit/hex 生成。已有构建日志需先归档，不能覆盖。工具路径支持 `EFINITY_ROOT`、`QUESTA_ROOT`、`HOST_CC`。

仅核验集成与发布文件：`python -B tools/verify_osd_integration.py`；固件核验：`python -B releases/osd_blackbars_20261031/flash_package/tools/verify_backup.py`。

完整命令、依赖、资源与时序、物理证据复用依据和实板验收项见 [OSD 更新说明](releases/osd_blackbars_20261031/README.md)。历史 `build_styles8.py` / `BuildStream.ps1` 与 `doc/styles8/` 保留用于原版本溯源，不作为本次 OSD 的正式完整验证入口。

## 资源清理与兼容边界

当前包移除 papercut、popart、vermilion_ink、mosaic、woodcut、fauve、cel 七个槽位，共减少 114688 字节（46.67%）。当前 RTL 默认和顶层仅循环 8 个槽，当前构建、验证和模型重建入口同步为 8 风格。所有风格共用同一 CNN 和双参数 bank，因此没有七套独立运算引擎可删除。保留通用换模、CRC 拒绝和失效回退能力。

历史 `network/styles15` / `styles19`、既有 release 与回退镜像保留，既是回退资料，也是不可变的模型溯源；不参与新包的额外运行槽位。旧说明保存在 [历史 README](doc/styles15/README_before_styles8.md)。本任务不改独立 60 Hz Process 工程。

8 风格 BIT 必须配套新模型包，不能继续配旧 15 风格 Flash 模型。保留现有 ESP 应用；本任务不生成或发布含凭据的 ESP 固件，不访问串口、JTAG 或硬件 Flash。离线验证通过仍需用户上板确认画面、按键、推流及断电启动。

旧基线验证与回退包：[历史验证结果](doc/styles8/verification_results.md)，[旧发布包](releases/styles8_stream30_20261030/README.md)。当前 OSD 验证见下方更新说明。

## 2026-10-31 OSD 更新

[中文版本说明、构建入口、验证与固件](releases/osd_blackbars_20261031/README.md)。双窗口黑边大字、8 风格标签和 CAP/OUT；实际入口和约束不变。当前正式完整构建使用 `python -B tools/build_osd.py`。
