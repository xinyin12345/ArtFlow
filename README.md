# ArtFlow: fifteen-style P1/P2 release

The active project is `ArtFlow.xml`; `ArtFlow_glass.xml` is an identical compatibility entry. Both use the accepted TIMING_3 / seed 2 strategy, original clocks and spi_low_power_mode=off.

Model order: glass, oil, halftone, starry, papercut, sketch, popart, inkwash, woodrich, vermilion_ink, mosaic, woodcut, fauve, cel, sand. KEY3 cycles 0 through 14. P3/P4/P5 are not integrated.

Run from this repository with Python 3:

```powershell
python -B tools/build_styles15.py
```

This rebuilds firmware, verifies all initialization hashes and model slots, runs four native firmware tests and eight RTL regressions, synthesizes, routes, checks original-clock STA and five CDC groups, and generates BIT/HEX files. It does not access hardware. Efinity defaults to D:/soft/Efinity/2026.1 (override EFINITY_ROOT); Questa defaults to D:/soft/Questa/questa_fse/win64. RISCV_GCC and HOST_CC can override compilers. Installations and their valid licenses must already be available.

Generated results are in `work/styles15/`, `work/styles15_v2_*`, `reports/` and `outputs/firmware/`. Use `--phase tests`, `--phase map`, then `--phase physical` for staged execution. To preserve and archive a completed run before a fresh full run, use `--archive-run`. Never launch overlapping builds. `tools/run_efinity.ps1` and `tools/run_glass_efinity.ps1` dispatch to this same workflow; their map phase requires completed tests.

The accepted release is `releases/styles15_p1p2_20261025/`: ArtFlow_styles15_p1p2.bit/.hex must be paired with models15_parameters.bin (245760 bytes, planned model address 0x400000 through 0x43BFFF). New build files stay in work/styles15/out until separately reviewed. No flash/JTAG/serial operation is part of this workflow.

`network/styles15/` contains the default model package, mapping, and the frozen 19-slot input used only to reproduce the selected 15 slots. `tools/regenerate_package.py` reconstructs bytes in memory and compares BIN/HEX. No training or external Process directory is required. Only the selected implementation and required test files remain under `candidates/`; their names preserve accepted provenance.

Prior releases and legacy scripts remain for rollback. README_CODEX.md and older doc files describe historical versions; this README and doc/styles15 are authoritative for the current default. Inherited Process evidence is explicitly under doc/styles15/inherited and is not proof of this repository's fresh validation. The release manifest describes the original complete release, including ZIP archives retained in the source location; those archives are intentionally not duplicated here.

System RTL tests use a CNN transaction fixture. Full numerical CNN/CPU boot simulations and board FPS, visuals and Flash capacity are not newly established by those tests. See doc/styles15/validation.md for the actual formal-path run.
