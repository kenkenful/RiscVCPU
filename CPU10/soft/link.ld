OUTPUT_FORMAT("elf32-littleriscv");
OUTPUT_ARCH("riscv")

ENTRY(_start);
MEMORY {
  ROM(rxai) : ORIGIN = 0x0000, LENGTH = 2k
  RAM(wa) : ORIGIN = 0x800, LENGTH = 10k
}

SECTIONS
{ 
  .text : { *(.text) } > ROM
  .rodata : { *(.rodata) } > RAM
  .data : { *(.data) } > RAM
  . = ALIGN(4);
  __bss_start = .;
  .bss : {*(.bss)} > RAM
  __bss_end = .;
}
