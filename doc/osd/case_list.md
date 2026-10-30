# Cases

1. tb_osd_blackbars: 13 full 1080p raster frames, DE/HS/VS every cycle, OSD-off RGB.
2. check_osd_frames.py: independent full-raster bitmap/glyph reference, all pixels.
3. tb_osd_fps_edges / tb_v06_fps: CDC events, saturation, boundary event, idle windows,
   29/30/31 counts and reset. tb_v06_ui: bounce, hold, 3-mode cycling and OSD commit.
4. tb_osd_layout_equivalence: actual frame store vs baseline, every AXI/video/stream
   output, all three layouts; display mailbox snapshot and frame-stable style.
5. tb_p1_control: successful/failing style publication, 30 frozen pairs, cancel,
   timeout and ownership retention. styles8_button_cycle: all eight key-selected slots.
6. r15u_system: existing full control/render/system regression.
7. SPI packet/RTL-to-C/reset-equivalence/tap/ESP host regressions.
8. Whole-design map, route, setup/hold and new mailbox CDC timing audit.


9. tb_osd_output_telemetry: real OSD output VS into UI counter; 8 windows,
   30 checks, three-cycle VS pulses counted once, 29/30/31 counts, frozen RGB
   with OUT=30, stopped VS updates public OUT=0 without another frame.
