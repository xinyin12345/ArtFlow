# U8 throughput optimization verification plan

Target: improve complete 960x540 display-frame processing toward 15 FPS, with the frozen 480x270 U8 model and exact integer pixels. Do not commit Git or program the board.

Baseline: outputs/student_u8_v2, 8.725 FPS under 256 MB/s background reads and 64 MB/s writes; 142.857 MHz CNN and 100 MHz AXI. Original source modifications are preserved in work/u8_optimization/baseline.

P0 numeric equivalence: independent golden.py plus integer_model.py, all 19 layers, every feature address/data, preparation and final scaled pixels. Exercise reflection edges, cropped padded rows, signed S12, residual rounding and frame restart.
P0 bus correctness: randomized ready stalls, long read latency, unrelated dirty lines, read-after-write hazards, dual write-buffer ownership, simultaneous read/write progress, drain fence, four R/B error classes.
P0 implementation: full Efinity mapping/place/route, original board clocks and pins, source-hashed artifacts, setup/hold and all video/UI/CNN CDC checks.
P1 integration: camera/video/AXI scheduler/display ownership/IRQ system scoreboard and firmware host tests.

Screen candidates with 192x108 multi-frame tests, then stress tests and two full-size frames. Performance counters report phase wall time and per-layer logical reads/writes, AXI bursts and backpressure. Compare identical memory latency/stall/video-load configurations. Small-size timings are screening data, not board FPS predictions.

Candidate directions: partition read cache to avoid residual/prefetch thrashing; independent read/write engines, double write-combining buffers and pipelined write data; return available read beats before the full burst; pack stem RGB taps onto idle MAC lanes; replicate quantization lanes and overlap accumulator initialization; pipeline scaler write bursts.

No UVM/coverage-closure claim. Existing Questa four-state arithmetic scoreboards are reused. Board FPS, image quality and long-run hardware stability require board observation.
