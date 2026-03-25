ENTRY(_start)

MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS {

	.text : ALIGN(8) {
		*(.text.init)
		*(.text)
		*(.text.*)
	} > RAM

	.rodata : ALIGN(8) {
		*(.rodata)
		*(.rodata.*)
		*(.srodata)
		*(.srodata.*)
	} > RAM

	.data : ALIGN(8) {
		*(.data)
		*(.data.*)
		*(.sdata)
		*(.sdata.*)
	} > RAM

	.bss : ALIGN(8) {
		_bss_start = .;
		*(.bss)
		*(.bss.*)
		*(.sbss)
		*(.sbss.*)
		*(COMMON)
		_bss_end = .;
	} > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
