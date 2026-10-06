# v03 → v04 变更索引

| 文件 | 变更 |
|---|---|
| `rtl/video/video_axi_scheduler.v` | 新增突发级 AXI 读写分配器，FIFO 水位优先与最多连续两次服务限制 |
| `rtl/video/rgb_frame_store.v` | 保留三缓冲所有权；读写状态机接入 grant；新增居中双窗和右窗行复用 |
| `rtl/video/cam_fb_pipe.v` | 新增编译参数 `DUAL_WINDOW`；双窗在 HDMI 像素时钟运行；保留全屏兼容模式 |
| `rtl/ArtFlow_top.v` | 加入唯一板级开关 `CFG_DUAL_WINDOW=1` |
| `ArtFlow.xml` | 新增调度器源文件 |
| `ArtFlow.sdc` | 同源 HDMI 慢/快时钟加入显示时钟组，保留组内分析和独立 Gray 审计 |
| `sim/tb_video_axi_scheduler.sv` | 新增仲裁安全、公平性与复位自检 |
| `sim/tb_v04_checked.sv` | 逐像素双窗/背景检查、单事务限制、定向截断许可帧、右窗/黑边负向注入 |
| `tools/run_v04.py` 等 | 独立 v04 注册表、黄金布局、配置检查、连续帧测试及 Questa 原生入口 |
| `tools/check_implementation.py` | 正常 setup/hold、活动时钟、CDC 和比特流存在性门禁 |
| `tools/package_v04.py` | 收集当前证据、检查 v03 未改和当前回归源指纹、生成交付包 |

摄像头 I²C、DDR PHY、CSI IP、Gamma LUT、Bayer 合并算法和存储地址布局延续基线。未接入 Sapphire/RISC-V、CNN/INT8 或新的算法帧存储，属于后续路线图版本。

复制时未带入 v03 的 `.git`、`work/` 和 `outflow/`。v04 生成物全部属于 v04；已安装 EDA 工具保持原位置。基线源文件指纹记录在 `baseline_v03/source_sha256.json`。旧验证入口和报告的归档位置分别见 `legacy_moves.txt` 与 `baseline_v03/`。
