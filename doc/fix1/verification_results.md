# FIX1 verification results

All packaged gates PASS. Three reset runs: 2676/2624/3691 checks, 88 assertions each.
Re-init integration: 64 complete DDR pixels checked; accepted write response drains,
partial frame is rejected, two subsequent frames publish without mixing.
Firmware: 4 native groups; binary 6272 bytes with a reserved 1 KiB stack.
Normal setup minimum +0.459 ns; hold +0.026 ns.
Reset chain stage-to-stage setup minimum +9.542 ns; hold +0.109 ns.

Physical-board FIX1 verification: NOT_RUN. Encrypted CSI/analog D-PHY is not
represented by the receiver output-clamp model. New full-resolution capture
endurance and actual Sapphire CPU boot tests were not rerun. No structural or
UVM coverage closure claim. See verification_results.json and evidence for scope.
Mapped reset output FF aliases were resolved for the STA audit; the audit still
requires all nine FFs and the six stage-to-stage paths, with positive setup/hold.
