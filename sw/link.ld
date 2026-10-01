/* =============================================================================
 * File: link.ld
 * Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
 * Description: GNU Linker script partitioning code and data into hardware SRAM:
 *              - Instruction RAM: 0x00000000 - 0x00003FFF (16 KB)
 *              - Data RAM:        0x20000000 - 0x2000FFFF (64 KB)
 * =============================================================================
 */

OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rw)  : ORIGIN = 0x20000000, LENGTH = 64K
}

SECTIONS
{
    .text : {
        *(.init)
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        _etext = .;
    } > IMEM

    .data : {
        _sdata = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        _edata = .;
    } > DMEM AT > IMEM

    .bss : {
        _sbss = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        _ebss = .;
    } > DMEM

    /* Stack placed at top of Data RAM */
    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM) - 16;
}
