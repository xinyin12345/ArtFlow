# FIX1 features and verification mapping

|Priority|Feature|Stimulus and checker|Case|
|---|---|---|---|
|P0|Whole RX resets on software/global request|Absent clocks, direct assertion and edge counts|tb_csi_reset, 3 ratios|
|P0|No byte-clock startup deadlock|Byte source waits for released core; bounded eventual release|tb_csi_reset|
|P0|Release order and bounce recovery|64 varied-phase sequences plus bounce; local-edge and order assertions|tb_csi_reset|
|P0|Software reset preserves accepted DDR work|CSI outputs clamp while ready CDC lags, hold B, abort partial frame, release B|tb_csi_reset_gate|
|P0|No mixed frame after re-init|Gate blocks unframed restart; check 2 complete frames / 64 pixels|tb_csi_reset_gate|
|P0|User settings/XML preserved|Live-original/candidate hashes and parser snapshot|package_fix1.py, project gate|
|P0|Implemented synchronizer stages remain timed|Mapped alias-aware endpoint counts and setup/hold reports|check_ui_cdc.tcl/py|
|P1|No inherited video/UI regressions|Pixel reference, negative gates, UI/FPS/OSD checks|run_v04, run_v06|
|P1|Diagnostic counters and firmware retained|Read-only APB/CDC checks, native C tests|run_video_diag, test_firmware|
