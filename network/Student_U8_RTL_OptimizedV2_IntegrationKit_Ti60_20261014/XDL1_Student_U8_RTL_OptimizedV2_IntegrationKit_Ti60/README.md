# 同一U8学生的RTL优化版V2

本工程保留已认可的XDL1教师蒸馏B8R3学生U8第4轮QAT权重、整数模型、反射边界、S12精度、残差单次舍入与RGB nearest-even。本次V2指RTL实现优化，没有重新训练或更换学生模型。

完整480×270真实RTL仿真已对原整数模型逐层逐字验证；综合和布局布线使用同一组RTL/ROM哈希。结果见 `优化实测报告.md`，原始证据路径和版本见 `final_evidence.json`。

## 已实现的优化

1. **精确单遍中心化**：在前层输出时累计源特征9个reflection tap的和，再投影到当前卷积权重，得到与原始卷积全图累加相同的S_A。省去中心化层的统计卷积；仍计算当前帧精确均值。
2. **逐层系数缓存和8路累加器并行初始化**：避免每个输出组重复等待bias/M ROM，缩短MAC调度。
3. **DW一次捕获16通道**：利用已有24字节行缓存读口，减少逐通道组读取。同一周期捕获末尾窗口样本并发布窗口。
4. **1×1层下一行预取**：复用现有三行缓存的空闲槽，重叠下一行读入与当前行计算；保留最多1个未完成读的原接口，未缩短测试中的响应延迟。
5. **固定图地址简化**：针对最多16通道的已冻结模型，用移位和选择代替通用地址乘法，避免占用DSP。

## 工程文件

- `reference/integer/`：冻结的真整数模型、计算图、原范围证明与SHA256。
- `reference/U8_QAT_SelectedE04.pt`：原U8选中权重，供追溯。
- `mem/`：权重、bias、M和beta ROM，与上一版逐字节一致。
- `baseline/rtl/`：原U8基线RTL；`optimize.py` 从这些冻结文件重建优化RTL。
- `rtl/`：六个RTL模块及层描述符；新增 `source_stats.v`，`center_div.v`复用宽乘法器处理统计投影与原均值除法。
- `optimization_proof.json`：新统计通路覆盖全部合法编码的范围证明。
- `student_u8.xml`、`student_u8_flat.v`、`clock.sdc`：独立Ti60F225/I3工程，时钟周期6.667 ns。
- `reports/`：最终哈希对应的综合、布局布线、仿真、专项回归日志与原始工具产物。
- `review/`：实际RTL输出与原U8输出的三张图片对比。

本机在原 `.venv_xdl2_gpu` 中运行NumPy/Pillow脚本，在已有独立 `.venv_u8_rtl` 中使用Verilator 5.48.0；使用现有Visual Studio 2019和Efinity 2026.1.132，没有修改base环境。

在本工程目录中执行（`<python>`为工作区 `.venv_xdl2_gpu\Scripts\python.exe`）：

```powershell
<python> optimize.py
<python> generate.py
<python> prove_bounds.py
<python> infer_integer.py input.jpg output.png
<python> verify_statistics.py
<python> verify_units.py
<python> verify.py --width 24 --height 18 --latency 20 --stall 1 --frames 2
<python> verify_verilator.py --width 480 --height 270 --latency 3 --stall 1 --frames 2
<python> run_efinity.py --flow map --period 6.667
<python> run_efinity.py --flow pnr --period 6.667 --source <综合打印的STAGE目录>
```

本机ASCII暂存路径为 `../xfeat/.fpga_u8_stages`，工具副本位于 `../xfeat/.fpga_tools`。换电脑时需调整脚本中的工具、暂存和MSVC路径；Icarus可设置 `IVERILOG_BIN`。建议把工程放在英文目录。包内不分发Efinity、MSVC等商业工具。

部署尺寸固定480×270，内部480×272；其他尺寸仅用于验证，要求宽度为8的倍数且至少16，高度至少14。V2地址逻辑只适用于当前最多16通道、19层的固定模型，不应直接替换任意网络权重。

## 接口与整机边界

顶层名仍为 `student_u8`，64位ready/valid存储接口、三块2 MiB相对地址区、NHWC通道补齐到8、S12按16位小端保存、最终RGB位于槽1均保持原定义。预取响应增加内部owner标记，外部端口不变；桥必须维护写后读可见性，并在读命令接受后至少1周期返回数据。

输入每像素8字节，低3字节RGB；底部补行由读取端反射完成。输出每像素8字节，低3字节RGB，仅写270行。所有中间层写回与原基线顺序和地址相同，便于整数参考核对。

当前交付仍为独立CNN核心。真实DDR桥、摄像头与显示调度、CDC及板级约束尚需整合后重新验证。报告帧率是相应逻辑访存条件下的估算，不是板上视频实测；历史视频资源相加也不是整系统综合报告。布局布线日志内工具的内部“Bitstream generation”阶段记录不表示已经完成可烧录的摄像头整机位流。

旧U8基线工程及压缩包保留。本包只收录当前最终版本通过的记录，开发中的失败/中间尝试不作为最终结果。
