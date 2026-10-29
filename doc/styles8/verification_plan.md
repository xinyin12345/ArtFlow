# Eight-style 30 Hz verification plan

P0: exact order [0,5,1,3,2,14,7,8] from the previous fifteen-style release; byte-identical 14448-byte payloads; valid AFSM IDs, CRC32 and FF padding; 131072-byte archive at 0x400000..0x41ffff. Reconstruct independently from frozen source19 and reject corrupted, truncated and reordered packages.

P0: boot style 0, button debounce, every slot including 7->0 wrap, all 668 configuration writes per load, bank change only on job boundaries, rapid replacement, invalid header/ID, CRC error, erased/disconnected Flash, recovery. Directed RTL scoreboards compare every emitted payload word against the Flash image.

P0: pair/freeze/live/interaction renderer and return-memory lease, timeout, asynchronous FIFO and staggered clocks. Run the existing eight original RTL groups plus real C firmware tests.

P0: SPI producer/real C receiver payload agreement, mailbox, reset-generation equivalence, tap capture, ESP diagnostics and WebSocket loopback/browser tests.

P0: fresh synthesis/interface/P&R, unchanged clocks/constraints and seed, resource limits, all-clock setup/hold, video/CNN/UI/model-SPI/native-return-RAM CDC and streaming IO audit; five corrupt-report rejection cases. Generate bit/hex only after all offline gates pass. Merge verified config HEX with the model BIN; verify every config/model byte and FF gap independently.

Limits: existing system tests use a CNN transaction fixture. Weights and arithmetic are unchanged and payload equivalence is exhaustive. No new full numerical CNN inference, CPU boot, board frame rate, visual quality, serial/JTAG/Flash or ESP programming is part of this task. No coverage percentage is claimed for directed tests.
