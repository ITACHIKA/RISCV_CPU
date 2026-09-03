ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 32K
    DMEM (rw)  : ORIGIN = 0x80000000, LENGTH = 32K
}

SECTIONS
{
    .text :
    {
        . = ALIGN(4);

        KEEP(*(.text.start))
        *(.text*)

        . = ALIGN(4);
    } > IMEM

    .rodata :
    {
        . = ALIGN(4);

        *(.rodata*)
        *(.srodata*)

        . = ALIGN(4);
    } > IMEM

    .data :
    {
        . = ALIGN(4);

        __data_start = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        __data_end = .;
    } > DMEM AT > IMEM

    __data_load_start = LOADADDR(.data);
    __data_load_end = LOADADDR(.data) + SIZEOF(.data);

    .bss (NOLOAD) :
    {
        . = ALIGN(4);

        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DMEM

    . = ALIGN(16);
    __heap_start = .;

    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
