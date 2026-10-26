OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0xf9000000, LENGTH = 12K }
SECTIONS
{
  . = ORIGIN(RAM);
  .text : { KEEP(*(.text.start)) *(.text .text.*) } > RAM
  .rodata : { *(.rodata .rodata.* .srodata .srodata.*) } > RAM
  .data : ALIGN(4) {
    __global_pointer$ = . + 0x800;
    *(.data .data.* .sdata .sdata.*)
  } > RAM
  .bss (NOLOAD) : ALIGN(4) {
    __bss_start = .;
    *(.bss .bss.* .sbss .sbss.*) *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM
  __stack_top = ORIGIN(RAM) + LENGTH(RAM);
  __stack_bottom = __stack_top - 1024;
  ASSERT(__bss_end <= __stack_bottom, "Firmware exceeds 12 KiB OCRAM with 1 KiB reserved stack")
  /DISCARD/ : { *(.comment .note .eh_frame .eh_frame_hdr) }
}
