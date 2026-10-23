19 styles: original IDs 0-15 unchanged; new IDs 16 sketch, 17 oil O3, 18 pointillism R3.
KEY3 cycles 0..18..0. All style IDs and frame tags remain five bits. KEY1 display and KEY2 OSD unchanged.
The existing OSD displays layout/FPS, not style names; this UI remains unchanged. Names/IDs are in manifest.json.
Archive: 311296 bytes (304 KiB), address 0x400000-0x44BFFF. 19 slots x 16384 bytes; each includes 32-byte header, 14448-byte payload, CRC32.
parameters.bin is the external Flash archive. parameters.hex is readmemh simulation input, NOT FPGA configuration HEX.
No Flash/JTAG access, no training. New model PTQ previews and verification are under models/.
