// =============================================================================
// File: accel.c
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Low-level driver implementation for Q8.8 Matrix-Vector Accelerator.
// =============================================================================

#include "accel.h"

void accel_start_matrix_mult(uint8_t rows, uint8_t cols) {
    ACCEL_DIM_REG  = ((uint32_t)rows << 8) | (uint32_t)cols;
    ACCEL_CTRL_REG = ACCEL_CTRL_START;
}

int accel_is_busy(void) {
    return (ACCEL_STATUS_REG & ACCEL_STATUS_BUSY) ? 1 : 0;
}

void accel_load_buffer(uint32_t offset_words, const uint32_t* data, uint32_t count) {
    volatile uint32_t* buf = (volatile uint32_t*)(ACCEL_BASE_ADDR + ACCEL_BUFFER_OFFSET);
    for (uint32_t i = 0; i < count; i++) {
        buf[offset_words + i] = data[i];
    }
}

void accel_read_buffer(uint32_t offset_words, uint32_t* dest, uint32_t count) {
    volatile uint32_t* buf = (volatile uint32_t*)(ACCEL_BASE_ADDR + ACCEL_BUFFER_OFFSET);
    for (uint32_t i = 0; i < count; i++) {
        dest[i] = buf[offset_words + i];
    }
}
