# ArtFlow v03 — Codex 修订版

本目录以 Claude v03 的 `febbada` 为基线。原工程未修改。本版保留 2×2 Bayer 合并与白平衡算法，重新实现活动视频路径的 DDR 帧生命周期管理。

## 当前数据流

CSI RAW10 → `bayer_bin2x2` → `rgb_frame_store` → 水平/竖直各重复两次 → `test_pattern` → `gamma_lut` → HDMI。

顶层 `ArtFlow_top.v` 与端到端仿真均例化 `cam_fb_pipe.v`。其内部现使用 `rgb_frame_store.v`。`rtl/frame_buffer/` 的旧控制器留作历史参考，除了 `DC_FIFO.v` 和 `rst_n_piple.v`，不再列入当前 Efinity 工程，也不参与新回归。

## 保持的帧格式

- 输入 1920×1080，输出存储图像 960×540。
- 三个 bank 起始地址：`0x000000`、`0x400000`、`0x800000`。
- 地址：`bank + (y*960+x)*4`，行跨度 3840 字节。
- 小端 XRGB8888：字节顺序 B、G、R、0；每帧 2,073,600 字节。
- 固定 AXI 128 位、INCR、最大 128 beats，按 4 KB 边界分段。
- 每帧字节数与旧版 RAW8 存储相同。瞬时写入负载已经改变，不能由总字节数推断拥塞行为不变。
- 增益统一为 R=280、G=255、B=350。保留 10 位精度计算和饱和输出。

## 帧生命周期

1. AXI 控制器预留一个空闲 bank，通过 toggle 握手给摄像头一次捕获许可。
2. 摄像头只在帧的第一个有效 RGB 数据处接受许可；其余帧整帧丢弃。输入没有反压接口。
3. 写 FIFO 连续运行，不在帧头复位。发出 AW 前，整个突发的数据必须已经在 FIFO 中。
4. 每个突发完整完成 AW/W/B。新摄像头帧不会清除 AXI 状态。
5. 捕获完成、字数正确、无 FIFO 溢出且全部 B 响应成功后，才发布 bank。
6. FIFO 溢出或截断帧标记为无效；已接受的 AXI 突发仍完成，余下已缓存数据排空，无效帧不发布。
7. 读侧在显示帧请求时固定一个已发布 bank，直到最后一个 R beat 完成才释放。写侧避开最新完整帧与正在读的 bank。
8. 数据携带 32 位显示帧编号。显示帧切换后，迟到的旧编号数据丢弃，不混入当前帧；已发出的 AR 保持到握手，已接受的 R 突发正常收完。

这里使用“保留最新完整帧”的策略，允许跳过摄像头帧和重复显示完整帧，不承诺逐帧无损录像。

## 启动和拥塞行为

- HDMI 时序固定运行；没有完整帧时显示黑色，不读取未初始化 DDR 作为画面。
- 输入拥塞：丢帧，保留最后完整图像，DDR 恢复后继续捕获。
- 输出带宽不足：从欠载位置起，该输出帧剩余部分变黑；下一帧重新对齐并恢复。此前已经输出的像素无法撤回，因此不承诺严重拥塞期间每帧都完整可见。
- 停流后会重复最近完整帧。传感器重新提供帧同步后可恢复捕获。
- 顶层保留上电 5 秒色条。色条与摄像头时序切换的实板显示器表现仍需确认。

## 配置约束

这是针对当前固定分辨率的视频通路，不是通用 AXI DMA。`MAX_IN_HEIGHT` 已增加为显式参数。存储宽度必须为偶数，像素总数为 4 的倍数；bank 足够大且 4 KB 对齐；起始地址 16 字节对齐；显示有效区必须与配置的二倍放大尺寸一致。运行期间不要改变增益、尺寸和 Bayer 配置。

`CFG_BAYER`、`CFG_PIX_REV` 保留原默认值。仿真不能确认真实传感器上的排列，请用红/绿物体及细竖边上板确认。74.25 MHz 与 148.5 MHz 必须维持工程 PLL 的同源关系。

## 回归

在工程根目录执行：

```powershell
python -B tools/run_v03.py          # 完整的小分辨率/压力回归
python -B tools/run_v03.py --full   # 再加真实 1080p60 的全分辨率测试
```

Python 入口的生成物位于 `work/regression/`，包括每个用例日志、抓帧、Python 对比图和 `summary.json`。失败进程、仿真 Error/Fatal、FAIL 或缺失 PASS 都使总回归失败。

Questa 中先 `cd D:/work/CodexWork/ArtFlow/v03`，再执行 `do sim/run_v03.do full`。该入口复用当前仿真会话，输出位于 `work/questa_<时间戳>/`；支持 `smoke` 冒烟模式。若从工程目录以外执行，先设置 `V03_PROJECT_ROOT` 环境变量。单会话许可证下，不要同时运行 Python 回归与另一场 Questa 仿真。

新增测试 `tb_v03_checked.sv` 每帧更换图像，逐像素检查同一输出帧只来自同一输入图像；每次发布都检查 DDR 内容，强制三个 bank 都经过验证。还检查 AXI 五通道反压稳定性、4 KB 边界、WLAST、未知值、B 前不发布及 RLAST 前不释放。

旧 `tb_v03_pipe.sv`、`axi_mem_model.sv` 仅保留作参考，不是当前验证入口。最新实测结论见 `verification_results.md`。

## Efinity

打开根目录 `ArtFlow.xml`，或执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_efinity.ps1 -Flow compile
```

脚本默认使用本机 `D:\soft\Efinity\2026.1`，可通过 `-EfinityRoot` 指定安装目录。输出位于 `work/efinity_out/`。脚本只编译，不烧录硬件。
