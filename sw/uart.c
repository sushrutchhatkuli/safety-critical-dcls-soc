// =============================================================================
// File: uart.c
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Low-level driver implementation for AXI4-Lite UART peripheral.
// =============================================================================

#include "uart.h"

void uart_init(uint16_t baud_div) {
    UART_BAUD_DIV_REG = (uint32_t)baud_div;
    UART_CTRL_REG     = 0x00000003; // Enable TX (bit 0) and RX (bit 1)
}

void uart_putc(char c) {
    // Poll status register until TX FIFO is not full
    while (UART_STATUS_REG & UART_STATUS_TX_FULL);
    UART_DATA_REG = (uint32_t)(uint8_t)c;
}

void uart_puts(const char* str) {
    while (*str) {
        uart_putc(*str++);
    }
}

char uart_getc(void) {
    // Poll status register until RX FIFO has data
    while (UART_STATUS_REG & UART_STATUS_RX_EMPTY);
    return (char)(UART_DATA_REG & 0xFF);
}
