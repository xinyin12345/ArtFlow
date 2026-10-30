# ArtFlow OSD + 8 风格 Flash 固化备份

本包使用用户已上板确认显示效果不错的 OSD bit，原始 bit/hex 未重新综合或改写。合并文件已完成离线逐字节校验；本次没有执行烧录，Flash 冷启动仍待用户手动验证。

## 应当选择哪个文件

| 文件 | 用途 |
|---|---|
| `flash/ArtFlow_osd_8styles_fullflash.hex` | **完整固化文件**：FPGA 配置 + 8 风格模型，从 Flash 地址 **0x000000** 写入 |
| `fpga/ArtFlow_osd_blackbars_20261030.bit` | 已上板确认的原始 RTL 构建 bit，供原有加载流程使用 |
| `fpga/ArtFlow_osd_blackbars_20261030.hex` | 同次 Efinity 构建产生的 FPGA 配置 hex，不包含外部模型区域 |
| `models/models8_parameters.bin` | 全部 8 风格运行时模型包，单独写入时地址为 **0x400000** |
| `models/models8_parameters.hex` | 同一模型包的逐字节 hex 表示，偏移从模型包自身的 0 开始 |
| `models/models8_manifest.json` | 模型顺序、地址、CRC、槽位及有效负载 SHA256 |
| `models/old_new_mapping.csv` | 原模型编号与最终 8 风格编号对应 |

这里的 `.hex` 是工程/Efinity 使用的逐字节十六进制文本，不是冒号开头的 Intel HEX。请按原有 Efinity Flash 文件流程选择完整合并文件；无需再次附加模型或对合并文件施加 0x400000 偏移。

## Flash 地址布局

| 区域 | 起始地址 | 结束地址（包含） | 解码后字节数 |
|---|---|---|---:|
| FPGA 配置 hex 原始内容 | 0x00000000 | 0x0010DAFB | 1104636 |
| 擦除态填充 FF | 0x0010DAFC | 0x003FFFFF | 3089668 |
| 8 风格模型包 | 0x00400000 | 0x0041FFFF | 131072 |
| 完整合并镜像 | 0x00000000 | 0x0041FFFF | 4325376（0x420000） |

合并 hex 文本文件大小为 12976128 字节；文本大小不等于实际 Flash 占用。

风格顺序与地址：

| ID | 风格 | Flash 地址 |
|---|---|---|
| 0 | 玻璃 | 0x400000 |
| 1 | 素描 | 0x404000 |
| 2 | 油画 | 0x408000 |
| 3 | 星空 | 0x40C000 |
| 4 | 网点 | 0x410000 |
| 5 | 沙画 | 0x414000 |
| 6 | 水墨 | 0x418000 |
| 7 | 富彩粗刀版画 | 0x41C000 |

每槽 16384 字节：32 字节 AFSM 头 + 14448 字节模型有效负载 + 1904 字节 FF。已检查每槽 ID、CRC32、SHA256、填充和地址，并从已有源模型重建核对全包。

## 校验值

- bit SHA256：`8ff3f2565d92b7f9e4092d06513b8cefbc771ae21a2bc81f1458ba0fc31d1e50`
- FPGA hex SHA256：`8f0d1b632a34a4397542edb09b7a4d368c2a0f073bebb5aa23ac02d48600b104`
- 模型 bin SHA256：`2cdef6557e3c4b693d383ec039343dc3b1066b2c39921cf619b458266aa50c09`
- 完整合并 hex SHA256：`9237026a9831d63b54e869a4867c0ebc95ba29838fbf07dfb9f5ebb377e56e07`

解压后可运行 `python -B tools/verify_backup.py`。脚本只读本包文件，核对全部 SHA256 和合并镜像，不调用 EDA 或硬件。`SHA256SUMS.txt` 也可用于独立核对。

## 手动固化与验证

1. 解压备份并运行校验脚本，确认 PASS。
2. 在原有 Efinity Flash 编程流程中使用与板载 Flash 匹配的设备配置，选择 `flash/ArtFlow_osd_8styles_fullflash.hex`，起始地址 **0x000000**。
3. 手动执行写入及 Verify。这个合并文件已经包含模型区，不必再单独写模型。
4. 按板卡原有 Flash 启动设置断电重上电，检查 OSD、三个布局、OSD 开关、全部 8 风格及标签，并复查冻结/创意功能和原有 Wi-Fi 推流。

本包不含 ESP 固件更新，也不改变主工程或 FPGA 源码。原物理验收证据位于 `evidence/`：零资源重叠，最终 setup +0.313 ns / hold +0.026 ns，适用 CDC 检查通过。原 `FINAL_ACCEPTANCE` 中“未实板验收”是交付当时的历史状态；本包补充记录了用户随后确认 OSD 上板效果不错，未扩大为 Flash 冷启动验收。

本备份包含运行和固化需要的模型参数，不是整个训练数据/训练 checkpoint 工程备份。原始源码完整哈希清单随证据保留，完整工程仍在独立 OSD 候选目录。
