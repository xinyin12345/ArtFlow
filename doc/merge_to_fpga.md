# 合并到 FPGA 工程

源：D:/work/CodexWork/ArtFlow/v03，分支 v03。
目标：D:/work/FPGA/ArtFlow/ArtFlow。本次只修改和提交源仓库，没有代替用户执行目标合并。

## 已保存的历史

- 690d94a：本次开始时目标 FPGA 工程的 HEAD。
- 4b9aa43 → 878baf1 → febbada：沿用的 Claude v03 基线。
- f6f2388：上一版 Codex 的事务安全 RGB 三缓冲、动态回归及 Efinity 结果；原报告可用 git show f6f2388:doc/verification_results.md 查阅。
- 本轮后续提交：补强 CDC/reset、实际配置读取、严格像素检查、故障与正常帧率覆盖，更新验证证据。

上述是连续提交链。目标若仍停在 690d94a，可直接快进合并整个 v03；不要只挑后两个提交而漏掉它们依赖的 Claude 基线。Claude 后续独立提交 a88c97d/51c84ba 没有直接合入本分支，其相关改进点已按本工程架构重做。

## 建议执行

先在目标确认工作区干净，再读取源分支到 FETCH_HEAD 并审阅：

```powershell
git -C D:/work/FPGA/ArtFlow/ArtFlow status --short
git -C D:/work/FPGA/ArtFlow/ArtFlow fetch D:/work/CodexWork/ArtFlow/v03 v03
git -C D:/work/FPGA/ArtFlow/ArtFlow log --oneline HEAD..FETCH_HEAD
git -C D:/work/FPGA/ArtFlow/ArtFlow diff --stat HEAD FETCH_HEAD
git -C D:/work/FPGA/ArtFlow/ArtFlow merge --ff-only FETCH_HEAD
```

ff-only 在目标已有分叉提交时会停止，不会覆盖目标的独立开发；届时应比较冲突后正常合并。源 v03 的 origin 仍指向原克隆来源，合并上面的本地路径不需要 push，也不需要改远端。

## 合并后验证

先执行 `python -B tools/verify_delivery.py` 核对交付文本指纹；允许 Git checkout 正常转换 CRLF/LF。源码修改后指纹检查会报 changed，此时应重跑验证并记录新结果。

从目标目录打开 ArtFlow.xml，运行 python -B tools/run_v03.py --full 以及 powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile。work/ 中的缓存、日志、向量、PNG 和比特流未提交，需重建。Git 中保留 verification_results.md、机器摘要、时序/CDC 报告与指纹；见 doc/verification/。

此版通过的条件与实板待验边界见 verification_results.md。真实 Bayer/像素顺序、DDR 校准及 HDMI 表现仍应由板上验收确认。
