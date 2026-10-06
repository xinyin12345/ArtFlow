# v03 功能与验证映射

| 编号 | 优先级 | 功能 | 用例和强制检查 |
|---|---|---|---|
| F01 | P0 | Bayer/白平衡/饱和 | bayer 单测；17 个 small 端到端组合 |
| F02 | P0 | XRGB8888 与三 bank | 所有端到端用例，每次发布全内容检查；banks=111 |
| F03 | P0 | 完整帧发布与隔离 | B outstanding、读写 bank 互斥、RLAST 前不可释放 |
| F04 | P0 | 跨帧 AXI 事务持续 | stress_31/73；AW/W/AR 稳定、4 KB、WLAST/RLAST 检查 |
| F05 | P0 | 输入溢出恢复 | stress 必须 dropped/overflow/rejected 非零，再连续正确帧 |
| F06 | P0 | 输出时序及黑尾 | 每个有效像素、行宽、周期；stress/rresp 只允许正确前缀＋黑尾 |
| F07 | P0 | 启动黑屏 | 所有端到端；negative_startup 必须被拒绝 |
| F08 | P0 | 帧号/冻结/更新 | 32 位绝对帧号、顺序、更新计数、积压新帧时停留上界；negative_frozen |
| F09 | P0 | 错误响应 | bresp_error 无效帧拒绝；rresp_error 黑尾且恢复 |
| F10 | P0 | 截断与停流 | truncated_frame 拒绝；camera_stop_restart 保留完整帧并恢复更新 |
| F11 | P0 | 事务中全局复位 | reset_during_write/read，同时复位 AXI 从机，重建发布和三 bank 覆盖 |
| F12 | P1 | 2× 放大/短帧/跨 4 KB | short_burst、全部逐像素检查、AXI 边界断言 |
| F13 | P0 | 实际顶层配置 | config 检查、共享参数加载器；full_30fps 与 full_high_load |
| F14 | P0 | 验证器可信度 | 文件长度/范围/X 检查，gamma LUT 路径传参与未知值检查，7 项负向门禁 |
| F15 | P1 | 参数合法性 | RTL guard；negative_geometry |
| F16 | P0 | CDC 完成元数据 | 同步级数/Gray 编码；完成时元数据一致断言；路由后 64 端点预算门禁 |

这是功能命中表，不是工具测得的代码覆盖率。未量化 RTL 行/条件/分支/翻转覆盖率；未执行所有相位的全分辨率测试、32 位计数回绕或板上长时间运行。CDC 数字仿真与路由审计不证明亚稳态概率。
