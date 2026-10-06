# ArtFlow v04

在 Efinity 中打开本目录 `ArtFlow.xml`。本版基于相邻的 v03，按路线图加入居中的左右双窗口和 AXI 突发调度，继续使用事务安全三缓冲。v03 没有修改。

- [设计、布局及配置](doc/v04_notes.md)
- [实际验证结果](doc/verification_results.md)
- [验证计划](doc/verification_plan.md)、[功能映射](doc/feature_list.md)、[用例列表](doc/case_list.md)
- [实板 30 分钟验收](doc/board_acceptance.md)

```powershell
cd D:\work\CodexWork\ArtFlow\v04
python -B tools/run_v04.py --smoke
python -B tools/run_v04.py --full --soak-frames 1000 --run-dir work/regression_final
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
python -B tools/verify_delivery.py --with-generated
```

Questa 原生入口：`do sim/run_v04.do smoke` 或 `do sim/run_v04.do full`；从工程外启动可设置 `V04_PROJECT_ROOT`。不要同时运行两场 Questa 仿真。

`CFG_DUAL_WINDOW=1`：左/右各 960×540，位于 (0,270)/(960,270)，上下黑边。两侧当前显示同一帧，右窗算法尚未实现。`CFG_DUAL_WINDOW=0` 可回到全屏二倍放大；配置入口是 `rtl/ArtFlow_top.v`。修改配置后重新跑对应回归并构建比特流。

编译结果在 `work/efinity_out/ArtFlow.bit` / `ArtFlow.hex`。脚本只生成文件，不烧录硬件。实板 30 分钟验收尚未执行，不能将小尺寸连续帧回归当作该项通过。历史 v03 报告仅存于 `doc/baseline_v03/`。

v03 的旧验证入口保存在 `_archive/v03_verification/`，只作历史参考；迁移清单在 `doc/legacy_moves.txt`。v04 的有效入口为上面的 Python / Questa 命令。
