# FIX1 case list

New reset test half-period tuples (core, byte, pixel) in ns: (5,7,10),
(11,3,7), (3,13,5). Each run has 88 reset assertions, including clock absence,
software reset, all clocks stopped and varied reset/release phases with bounce.
New integration case: camera_init_axi_drain, real downstream Bayer/frame-store/
scheduler/AXI checker with a behavioral CSI reset clamp and two-stage ready CDC.

Inherited regression case names/seeds and negative-test outcomes are listed in
evidence/regression_v04/summary.json. Registry entries include compilation and
reference-check helpers and are not a count of independent simulations.
Control, diagnostic, UI and firmware case logs/summaries accompany this package.
