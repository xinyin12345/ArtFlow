# Sapphire SoC source and integration

Imported from the local Ti60F225 DemoBoard v4 demo 10 reference:

`E:\Work\FPGA\Efinity\Ti60F225_DemoBoard_v4完整资料包\Ti60F225_DemoBoard_v4\10_Ti60f225_sc431hai2hdmi_demo\Ti60f225_sc431hai2hdmi_v1\ip\sapphire_soc`

The generated `sapphire_soc.v` is the actual Efinix Sapphire SoC
2.2.9 implementation produced by Efinity 2023.1.150. The original copyright
and license notices are retained. Most of the netlist is plain Verilog, but two
CPU modules contain protected vendor implementation. Use the root file for
Efinity synthesis. Use `sim/sapphire_soc.v` for ModelSim/Questa simulation;
it combines the same top wrapper with the vendor's corresponding
`source/hardware/netlist/source_modelsim/EfxSapphireSoc.v` implementation.
Compile exactly one of these alternatives. Simulation requires a simulator
that can read the vendor's protected blocks. No behavior-only CPU replacement
is used.

Original SHA256: `97b76d96391ad068ce692b4a5fd541a3ca68f619dbe998f7ca39d58a8171e0bb`

Only four `$readmemb` file paths have been changed to project-relative
`ip/sapphire_soc/EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbolN.bin`.
Run simulation and synthesis from the v05 project root. Firmware builds replace
these four files, each containing 2,048 eight-bit binary words. Lane 0 holds the
least significant byte of each little-endian 32-bit instruction/data word.
The old vendor camera binary is retained under `provenance/` for provenance only;
it is not the v05 firmware.

The checked-in `provenance/settings.original.json` has stale GUI defaults that
do NOT match its generated netlist. Do not regenerate this IP with that file.
The actual configuration is established by `provenance/soc_config.original`
and the address decoders in the netlist:

| Resource | Base / setting |
| --- | --- |
| System clock | 100 MHz |
| ISA | RV32IM, CSR and instruction-cache fence; no A/C/F |
| CPU reset PC / initialized RAM | `0xf9000000`, 8,192 bytes total |
| UART0 | `0xf8010000`, 128-byte TX/RX FIFOs, 8 samples/bit |
| SPI0 (unused) | `0xf8014000` |
| GPIO0 (unused) | `0xf8015000`, width 4 |
| I2C0 | `0xf8016000` |
| APB0 | `0xf8100000`, 64 KiB |
| CLINT | `0xf8b00000`, 100 MHz |
| PLIC | `0xf8c00000` |
| AXI-A (unused; DECERR termination) | `0x01000000`, 16 MiB |

`rtl/control/artflow_soc.v` integrates the SoC. Firmware boots directly from
initialized on-chip RAM, so v05 needs no SPI application image, external DDR
access, or JTAG debugger to start. JTAG inputs are tied inactive in this version.
The SoC reset output also resets APB control, with asynchronous assertion and
two-clock release synchronization. The I2C pads use open-drain output: drive
data zero, assert OE only when the SoC requests a zero, release during reset.

UART board mapping is independently corroborated by demo 08's
`par/ddr_demo_ti60/ddr_demo_ti60.peri.xml` and demo 17's `top.peri.xml`:
RX=`GPIOL_02`, TX=`GPIOR_28`, 3.3 V LVCMOS. Use source project peripheral files,
not stale generated `outflow` variants. Camera SCL=`GPIOR_20`, SDA=`GPIOR_18`.
