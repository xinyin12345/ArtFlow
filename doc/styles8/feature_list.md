# Feature and testcase mapping

| Feature | Evidence/checker |
|---|---|
| Eight models, names, addresses and immutable weights | verify_package.py + regenerate_package.py; SHA256 and CRC32 |
| Button/glitch/hold, 0..7 wrap, in-flight replacement | style_cycle RTL scoreboard |
| CRC, invalid/out-of-range ID, missing Flash and recovery | style_crc + style_cycle |
| Atomic parameter-bank commit | Both loader scoreboards and DUT assertion |
| Freeze/pair/live scheduling and render ownership | pair_control, system, lease, timeout |
| Return FIFO and asynchronous clocks | fifo, fifo_stagger |
| 30 Hz HDMI modes/OSD/WB/diagnostics | Preserved baseline source hashes; original system and firmware regressions |
| SPI to actual receiver, WebSocket/browser | stream RTL/tap/reset, native C and ESP tests |
| Routed legality/timing/CDC | Native Efinity reports and independent audit scripts |
