OUTPUT_ARCH(riscv)
ENTRY(_start)

PHDRS
{
  text   PT_LOAD FLAGS(5);
  rodata PT_LOAD FLAGS(4);
  data   PT_LOAD FLAGS(6);
}

SECTIONS
{
  /* Spike reserves 0x0000-0x0fff for its debug ROM. */
  . = 0x00001000;
  .text : { KEEP(*(.text.start)) *(.text .text.*) } :text
  . = 0x00003000;
  .rodata : { *(.rodata .rodata.*) } :rodata
  . = ALIGN(4);
  .data : { *(.data .data.*) } :data
  . = ALIGN(4);
  __bss_start = .;
  .bss : { *(.bss .bss.*) *(COMMON) } :data
  __bss_end = .;
  __stack_top = 0x00003F00;
}
