# glass 第20轮 INT8模型与参数

来源：glass_5_20epochs_sum8192_480x270_input3x3_res32_r4/epoch_020.pt
源检查点SHA256：fd861ac8c99714e85812585491b293c8ed4e5561e3a7564af4c105053a769c7e

## 文件

- model_int8.pt：已编译、可直接执行的TorchScript整数模型，包含网络计算图和量化参数。
- model.py：可阅读的模型结构与整数运算源码，仅依赖PyTorch。
- parameters/model_int8.npz：独立整数参数数组。
- parameters/parameters.bin：连续小端序硬件参数。
- parameters/parameters.json：参数类型、形状、字节偏移及长度。
- parameters/graph.json：22个节点连接、卷积、残差、移位及限幅规则。
- parameters/range_proof.json：整数运算的位宽上界。
- parameters/audit_scales.json：仅离线查看浮点比例，运行模型不依赖此文件。
- infer.py：独立出图脚本。
- example_input.png / example_output_int8.png：已验证的示例输入输出。
- verification.json / evaluation_summary.json：模型验证和200张评估结果。

## 出图

在本文件夹中运行：

```powershell
D:/MiniConda/envs/ai/python.exe infer.py --input example_input.png --output result_int8.png
```

也可以使用装有PyTorch、NumPy、Pillow的其他Python环境，不需要原项目、FP32检查点、VGG或训练数据。没有复制Python环境或VGG权重。

Python中直接加载：

```python
import torch
model = torch.jit.load('model_int8.pt', map_location='cpu').eval()
# image: torch.uint8，形状[N,3,270,480]，RGB，CPU
with torch.inference_mode():
    result = model(image)  # torch.uint8，[N,3,270,480]
```

模型输入输出宽480、高270，内部补至480×272，残差特征120×68，sum/8192。
卷积权重和层间特征为INT8，RGB为UINT8，偏置和定点乘数使用更宽整数。
本CPU参考使用实际INT64乘加/求和以验证整数计算规则；它不是CPU原生INT8卷积性能测试。
BN和ImageNet归一化已合并进参数，运行时不需要浮点归一化。
负数移位使用round-half-up：floor(x/2^shift+0.5)。

200张平均分：INT8 LPIPS=0.635563，SSIM=0.252296。
已重新加载.pt并在3张图片及batch=2上，与原整数参考/已评估输出逐字节核对。
FPGA可直接读取parameters.bin，必须同时遵循parameters.json和graph.json的布局及计算约定。
