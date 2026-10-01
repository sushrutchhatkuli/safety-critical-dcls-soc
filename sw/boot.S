# =============================================================================
# File: boot.S
# Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
# Description: RV32I bare-metal startup assembly. Initializes stack pointer,
#              clears BSS memory space, and enters the C main routine.
# =============================================================================

.section .init
.global _start

_start:
    # 1. Initialize all general purpose registers to zero
    addi x1,  x0, 0
    addi x2,  x0, 0
    addi x3,  x0, 0
    addi x4,  x0, 0
    addi x5,  x0, 0
    addi x6,  x0, 0
    addi x7,  x0, 0
    addi x8,  x0, 0
    addi x9,  x0, 0
    addi x10, x0, 0
    addi x11, x0, 0
    addi x12, x0, 0
    addi x13, x0, 0
    addi x14, x0, 0
    addi x15, x0, 0

    # 2. Set Stack Pointer to top of Data RAM (0x2000_FFF0)
    lui  sp, 0x20010
    addi sp, sp, -16

    # 3. Enter main C function
    jal  ra, main

    # 4. Infinite trap loop if main returns
trap_loop:
    jal  x0, trap_loop
