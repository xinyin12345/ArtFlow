# Model4 三风格 FP32 权重交付

这三组采用同一个网络结构，仅训练损失、风格参考图和训练得到的状态不同。统一的 `model4.py` 可直接加载全部三套权重。

| 风格选项 | 对应实验 | CONTENT_WEIGHT | 文件名前缀 |
|---|---|---:|---|
| `sketch` | 第三轮铅笔素描 | 0.25 | `sketch_cw025_epoch010` |
| `oil` | 第五轮 O3，油彩，笔触与颜色分离约束 | 0.25 | `oil_decoupled_cw025_epoch010` |
| `pointillism` | 第六轮 R3，新参考图＋局部笔触约束 | 1.5 | `pointillism_R3_cw150_epoch010` |

全部使用相同的 5000 张内容图片，STYLE_WEIGHT=25000，完成 10 轮、3130 步。没有独立保存的 `best.pt`，也没有以艺术效果验证集自动挑选最佳轮次。本包收录此前展示效果对应的第 10 轮最终参数，不将它标注为经过评选的全局最佳。原始 `last.pt` 的模型状态已与 `epoch_010.pt` 逐张量核对一致。

## 文件用途

- `weights/*.pt`：完整 `state_dict`，包含卷积、归一化可训练参数和 BatchNorm 运行统计量。推理推荐使用这些文件。
- `checkpoints/*_checkpoint.pt`：服务器原始 `last.pt` 的逐字节副本，包含 `model`、优化器、训练配置、随机状态与进度。可供原训练工程续训或追溯。
- `model4.py`：三组共享的原始网络定义，未修改计算结构。
- `image_io.py`：原项目预处理与反归一化代码的副本。
- `infer.py`：统一推理及风格切换接口。
- `styles.json`：风格映射、来源、结构、配置摘要与 SHA256。
- `configs/`、`provenance/`：完整配置、训练曲线、导出检查和 CPU 参考输出。
- `examples/`：未参与这 5000 张训练的斑马图片，以及三种真实网络输出。
- `verify_package.py`：校验完整 checkpoint、纯权重和风格切换结果。

## 同一个模型如何切换风格

在本目录、已安装依赖的独立环境中执行：

```powershell
python infer.py --style sketch --input examples/input_zebra.jpg --output results/sketch.png
python infer.py --style oil --input examples/input_zebra.jpg --output results/oil.png
python infer.py --style pointillism --input examples/input_zebra.jpg --output results/pointillism.png
```

也可在一个进程、同一个模型实例中依次生成全部风格：

```powershell
python infer.py --style all --input examples/input_zebra.jpg --output results
```

默认使用 CPU。需要 GPU 推理时加 `--device cuda`；服务器需用 `CUDA_VISIBLE_DEVICES` 指定已获准使用的 GPU。

集成到自己的程序：

```python
from infer import StyleRenderer

renderer = StyleRenderer("cpu")
for style in ["sketch", "oil", "pointillism"]:
    renderer.set_style(style)  # 原模型实例上完整加载参数和缓冲值
    renderer.render("photo.jpg", f"results/{style}.png")
```

直接加载纯权重：

```python
import torch
from model4 import Model4

model = Model4()
state = torch.load("weights/sketch_cw025_epoch010.pt", map_location="cpu", weights_only=True)
model.load_state_dict(state, strict=True)
model.eval()
```

如使用完整 checkpoint，需从字典取出 `model`：

```python
checkpoint = torch.load("checkpoints/sketch_cw025_epoch010_checkpoint.pt", map_location="cpu", weights_only=True)
model.load_state_dict(checkpoint["model"], strict=True)
model.eval()
```

## 输入输出和集成要点

网络标识为 `hwang2025_model4_sum8192_camera480x270_input3x3_res32_r4`，共有 **7755 个可训练参数、81 个状态张量**。四个残差块，输入卷积 3×3，残差通道 32；残差归一化为 sum/8192 中心化。它是项目中特定的 Model4 变体，不能将这些文件直接用于结构不同的其他“Model4”。

- 输入固定 RGB、480×270（宽×高），张量为 `[N,3,270,480]`。内部底部反射补到 272 行，输出裁回 270 行。
- 先将像素缩放到 `[0,1]`，再按 ImageNet mean=`[0.485,0.456,0.406]`、std=`[0.229,0.224,0.225]` 归一化。输出做逆归一化并裁剪到 `[0,1]`。
- 示例沿用训练工程的直接 resize；不同长宽比的原图会被拉伸到 480×270。网络不能直接接收任意分辨率。
- 换风格时必须加载完整 `state_dict`，包括 BatchNorm 的 `running_mean`、`running_var`、`num_batches_tracked`，并保持 `eval()`。只换卷积权重不能保证复现效果。
- `CONTENT_WEIGHT`、分离约束与局部笔触约束仅在训练阶段生效。推理阶段不加载 VGG、不需要风格图，也不需要重新设置这些损失系数。
- 三个模型均为独立训练的单风格 FP32 权重，不是可通过一个连续风格系数插值的条件模型。本包不包含 INT8 校准结果。
- 完整 checkpoint 用于配合原训练工程续训；本包是推理交付包，不包含 VGG 权重、COCO 数据和完整训练代码。

## 环境与核验

服务器导出环境：Python 独立 `.venv`，PyTorch 2.4.1+cu124、torchvision 0.19.1+cu124、Pillow 10.4.0。`requirements.txt` 记录相应基础版本。请使用独立环境，勿在 base 环境中安装。

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe verify_package.py
```

如已有兼容的独立 PyTorch 环境，可以直接运行，无需重建。验证脚本检查：三组结构一致、原始 checkpoint 哈希正确、完整与纯权重推理结果一致，以及同一实例切换回素描后结果不变。服务器结果见 `provenance/export_verification.json`；交付机器的实际检查结果见 `verification_local.json`。

交付前已在另一套独立环境（PyTorch 2.8.0+cu128、torchvision 0.23.0+cu128、Pillow 11.3.0）完成 CPU 验证：三组完整/纯权重输出完全相同，切回原风格完全相同；与服务器 CPU 参考输出的最大差异小于 `3e-6`（像素范围 0–1）。统一命令 `--style all` 已实际执行，输出见 `examples/cli_verified/`，示例拼图见 `examples/three_styles_comparison.png`。

`SHA256SUMS.json` 记录包内文件摘要（不包含该清单自身）。示例输出是网络实际推理结果，未做锐化或额外色彩调整。
