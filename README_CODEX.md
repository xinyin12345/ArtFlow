# ArtFlow v03 修订工程

从本目录的 `ArtFlow.xml` 打开完整工程。

- 改动与设计：`doc/v03_notes.md`
- 实测结果与限制：`doc/verification_results.md`
- 仿真：`python -B tools/run_v03.py --full`
- Efinity：`powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile`

基线为 Claude v03 `febbada`。修订在此副本内完成；原 Claude 工程及 FPGA 工程未改动。旧 frame_buffer 控制器保留为参考，新顶层使用 rgb_frame_store。
