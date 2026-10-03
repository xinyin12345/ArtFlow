# ArtFlow v03 修订工程

从本目录 ArtFlow.xml 打开工程。所有开发在 v03 分支；上一版已单独保存为 f6f2388，本轮改进另作后续提交。FPGA 原工程未修改。

- [设计与配置](doc/v03_notes.md)
- [修改与实际验证结果](doc/verification_results.md)
- [合并到 FPGA 工程](doc/merge_to_fpga.md)
- [验证计划](doc/verification_plan.md)、[功能映射](doc/feature_list.md)、[用例表](doc/case_list.md)

```powershell
python -B tools/run_v03.py --full
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
```

ArtFlow_top.v 为仿真与上板参数的唯一配置源。生成物位于 work/；Git 保留源码、脚本及 doc/verification/ 验证摘要。Efinity 脚本完成实现后自动执行 CDC 路由审计，不下载硬件。
