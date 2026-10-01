// =============================================================================
// File: uart.h
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Low-level driver header for AXI4-Lite UART peripheral.
// =============================================================================

#ifndef UART_H
#define UART_H

#include <stdint.h>

#define UART_BASE_ADDR        0x10000000

#define UART_DATA_REG         (*(volatile uint32_t*)(UART_BASE_ADDR + 0x00))
#define UART_STATUS_REG       (*(volatile uint32_t*)(UART_BASE_ADDR + 0x04))
#define UART_CTRL_REG         (*(volatile uint32_t*)(UART_BASE_ADDR + 0x08))
#define UART_BAUD_DIV_REG     (*(volatile uint32_t*)(UART_BASE_ADDR + 0x0C))
#define UART_FIFO_CNT_REG     (*(volatile uint32_t*)(UART_BASE_ADDR + 0x10))

#define UART_STATUS_TX_EMPTY  (1 << 0)
#define UART_STATUS_TX_FULL   (1 << 1)
#define UART_STATUS_RX_EMPTY  (1 << 2)
#define UART_STATUS_RX_FULL   (1 << 3)
#define UART_STATUS_RX_READY  (1 << 4)

void uart_init(uint16_t baud_div);
void uart_putc(char c);
void uart_puts(const char* str);
char uart_getc(void);

#endif // UART_H
