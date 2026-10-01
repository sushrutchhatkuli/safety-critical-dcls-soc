// =============================================================================
// File: accel.h
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Low-level driver header for Q8.8 Matrix-Vector Accelerator.
// =============================================================================

#ifndef ACCEL_H
#define ACCEL_H

#include <stdint.h>

#define ACCEL_BASE_ADDR       0x40000000

#define ACCEL_CTRL_REG        (*(volatile uint32_t*)(ACCEL_BASE_ADDR + 0x00))
#define ACCEL_STATUS_REG      (*(volatile uint32_t*)(ACCEL_BASE_ADDR + 0x04))
#define ACCEL_DIM_REG         (*(volatile uint32_t*)(ACCEL_BASE_ADDR + 0x08))
#define ACCEL_BUFFER_OFFSET   0x00000100

#define ACCEL_CTRL_START      (1 << 0)
#define ACCEL_CTRL_IRQ_EN     (1 << 1)
#define ACCEL_STATUS_BUSY     (1 << 0)
#define ACCEL_STATUS_DONE     (1 << 1)

void accel_start_matrix_mult(uint8_t rows, uint8_t cols);
int  accel_is_busy(void);
void accel_load_buffer(uint32_t offset_words, const uint32_t* data, uint32_t count);
void accel_read_buffer(uint32_t offset_words, uint32_t* dest, uint32_t count);

#endif // ACCEL_H
