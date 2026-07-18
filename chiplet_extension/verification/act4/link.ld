OUTPUT_ARCH("riscv")
ENTRY(rvtest_entry_point)
PHDRS
{
  text PT_LOAD FLAGS(5);
  data PT_LOAD FLAGS(6);
}
SECTIONS
{
  . = 0x00001000;
  .text : {
    *(.text.init)
    *(.text.rvtest) *(.text.rvtest.*)
    *(.text.rvmodel) *(.text.rvmodel.*)
    *(.text) *(.text.*)
  } :text
  . = 0x00080000;
  .data : {
    *(.rodata) *(.rodata.*)
    *(.data) *(.data.*)
    *(.signature) *(.signature.*)
  } :data
  .bss : { *(.bss) *(.bss.*) *(COMMON) } :data
  _end = .;
}
