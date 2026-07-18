OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;
  .text : { KEEP(*(.text.start)) *(.text .text.*) }
  . = 0x00002000;
  .rodata : { *(.rodata .rodata.*) }
  . = ALIGN(4);
  .data : { *(.data .data.*) }
  . = ALIGN(4);
  __bss_start = .;
  .bss : { *(.bss .bss.*) *(COMMON) }
  __bss_end = .;
  __stack_top = 0x00004000;
}
