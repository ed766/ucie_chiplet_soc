OUTPUT_ARCH(riscv)
ENTRY(_start)

PHDRS
{
  text   PT_LOAD FLAGS(5); /* read + execute */
  rodata PT_LOAD FLAGS(4); /* read only */
  data   PT_LOAD FLAGS(6); /* read + write */
}

SECTIONS
{
  . = 0x00000000;
  .text : { KEEP(*(.text.start)) *(.text .text.*) } :text
  . = 0x00002000;
  .rodata : { *(.rodata .rodata.*) } :rodata
  . = ALIGN(4);
  .data : { *(.data .data.*) } :data
  . = ALIGN(4);
  __bss_start = .;
  .bss : { *(.bss .bss.*) *(COMMON) } :data
  __bss_end = .;
  /* Leave the final SRAM cache line available for architectural boundary tests. */
  __stack_top = 0x00003F00;
}
