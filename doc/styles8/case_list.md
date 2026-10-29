# Required cases

Original RTL: style_crc, style_cycle, pair_control, system, lease, timeout, fifo, fifo_stagger (tools/styles8_tests.json).
Firmware: console, i2c, camera, commands (tools/test_firmware.py).
Streaming: protocol fixtures, run_stream_rtl, run_shared_tests, run_reset_equivalence, run_tap_rtl, test_stream_esp.
Package negatives: ID, CRC, payload, padding, truncation, slot reordering. RTL adds ID 8 rejection with otherwise valid payload CRC.
Implementation: map, interface, pnr, normal STA, five CDC domains, stream IO, negative audit parser tests, pgm, merged HEX byte audit.
