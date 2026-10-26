# 当前主工程：30Hz FPGA 推流 + ESP32 WebSocket

2026-10-26：根目录 RTL、工程 XML/peri/SDC 已整合实板配套的 wifi_stream_20261025 推流版本，保留三布局、15 风格、KEY1/KEY3、OSD 和 WB 280/170/280。169 项签核源哈希逐项校验；没有引入 60Hz 改动。

交接入口：[30Hz 配对交接](releases/stream30_websocket_20261026/README.md)。最终 ESP 源码位于该目录 source/esp_project；含热点密码的已验收 app 仅在本地 private 中，未公开提交。

根工程验证/构建入口：`./BuildStream.ps1 -Phase Check`（默认，只读身份检查）、`-Phase Tests`（离线定向回归）、`-Phase EspTests`（最终 ESP 离线验证）、`-Phase OriginalTests`（原系统回归）、`-Phase Map`、`-Phase Physical`（需先完成原功能回归及映射前置证据，使用独立干净构建副本，不清理现有 work）。当前交付复用签核 bit，未重跑综合/P&R。

**板上 FPGA Flash 仍是历史非推流 15 风格镜像**；根源码变更不意味着已刷 Flash。推流仍须每次掉电后 JTAG 加载匹配 bit，不改模型。

以下保留原项目说明，其中历史构建/Flash 信息以本节和本次交接为准。

---

# ArtFlow: fifteen-style P1/P2 release

The active project is `ArtFlow.xml`; `ArtFlow_glass.xml` is an identical compatibility entry. Both use the accepted TIMING_3 / seed 2 strategy, original clocks and spi_low_power_mode=off.

Model order: glass, oil, halftone, starry, papercut, sketch, popart, inkwash, woodrich, vermilion_ink, mosaic, woodcut, fauve, cel, sand. KEY3 cycles 0 through 14. P3/P4/P5 are not integrated.

Run from this repository with Python 3:

```powershell
python -B tools/build_styles15.py
```

This rebuilds firmware, verifies all initialization hashes and model slots, runs four native firmware tests and eight RTL regressions, synthesizes, routes, checks original-clock STA and five CDC groups, and generates BIT/HEX files. It does not access hardware. Efinity defaults to D:/soft/Efinity/2026.1 (override EFINITY_ROOT); Questa defaults to D:/soft/Questa/questa_fse/win64. RISCV_GCC and HOST_CC can override compilers. Installations and their valid licenses must already be available.

Generated results are in `work/styles15/`, `work/styles15_v2_*`, `reports/` and `outputs/firmware/`. Use `--phase tests`, `--phase map`, then `--phase physical` for staged execution. To preserve and archive a completed run before a fresh full run, use `--archive-run`. Never launch overlapping builds. `tools/run_efinity.ps1` and `tools/run_glass_efinity.ps1` dispatch to this same workflow; their map phase requires completed tests.

The accepted release is `releases/styles15_p1p2_20261025/`: ArtFlow_styles15_p1p2.bit/.hex must be paired with models15_parameters.bin (245760 bytes, planned model address 0x400000 through 0x43BFFF). New build files stay in work/styles15/out until separately reviewed. No flash/JTAG/serial operation is part of this workflow.

`network/styles15/` contains the default model package, mapping, and the frozen 19-slot input used only to reproduce the selected 15 slots. `tools/regenerate_package.py` reconstructs bytes in memory and compares BIN/HEX. No training or external Process directory is required. Only the selected implementation and required test files remain under `candidates/`; their names preserve accepted provenance.

Prior releases and legacy scripts remain for rollback. README_CODEX.md and older doc files describe historical versions; this README and doc/styles15 are authoritative for the current default. Inherited Process evidence is explicitly under doc/styles15/inherited and is not proof of this repository's fresh validation. The release manifest describes the original complete release, including ZIP archives retained in the source location; those archives are intentionally not duplicated here.

System RTL tests use a CNN transaction fixture. Full numerical CNN/CPU boot simulations and board FPS, visuals and Flash capacity are not newly established by those tests. See doc/styles15/validation.md for the actual formal-path run.
