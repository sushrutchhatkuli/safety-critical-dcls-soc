---
title: "Bare-Metal Safety Firmware: ABS Real-Time Control Loop & Diagnostic Drivers"
tags:
  - firmware
  - bare-metal
  - c-driver
  - abs-control
  - bootloader
  - riscv-asm
date_created: 2026-10-01
status: "Active / Production"
---

# 🚗 Bare-Metal Safety Firmware & ABS Control Algorithm

> [!NOTE] **Software Architecture**
> Pure bare-metal C and RV32I assembly executing from Instruction RAM (`0x0000_0000`). Demonstrates continuous vehicle safety monitoring, actuator feedback control, and diagnostic UART streaming.

---

## 1. Startup & Initialization Assembly (`boot.S`)

Before C code can execute safely, the CPU registers and memory spaces must be put into a clean, deterministic state:

```assembly
# boot.S - RISC-V RV32I Startup Assembly
.section .init
.global _start

_start:
    # 1. Clear pipeline & disable interrupts
    csrci mstatus, 0x8

    # 2. Initialize Stack Pointer to top of Data RAM (0x0001_3FF0)
    la sp, _stack_top

    # 3. Clear BSS Segment (zero-initialized global variables)
    la t0, _bss_start
    la t1, _bss_end
clear_bss_loop:
    bge t0, t1, bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j clear_bss_loop
bss_done:

    # 4. Jump to C Safety Main Function
    call main

    # 5. Trap loop if main returns
halt:
    wfi
    j halt
```

---

## 2. Low-Level UART Driver Implementation (`uart.c`)

```c
#include <stdint.h>

#define UART_BASE         0x10000000
#define UART_DATA_REG     (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_STATUS_REG   (*(volatile uint32_t*)(UART_BASE + 0x04))
#define UART_CTRL_REG     (*(volatile uint32_t*)(UART_BASE + 0x08))
#define UART_BAUD_DIV_REG (*(volatile uint32_t*)(UART_BASE + 0x0C))

#define STATUS_TX_FULL    (1 << 0)
#define STATUS_TX_EMPTY   (1 << 1)
#define STATUS_RX_EMPTY   (1 << 3)

void uart_init(uint16_t baud_div) {
    UART_BAUD_DIV_REG = baud_div; // e.g. 54 for 115200 baud @ 100 MHz
    UART_CTRL_REG = 0x03;         // Enable TX and RX
}

void uart_putc(char c) {
    // Wait until TX FIFO has room
    while (UART_STATUS_REG & STATUS_TX_FULL);
    UART_DATA_REG = (uint32_t)c;
}

void uart_puts(const char* s) {
    while (*s) {
        uart_putc(*s++);
    }
}
```

---

## 3. Simulated Anti-Lock Braking System (ABS) Control Loop (`safety_ctrl.c`)

The safety controller computes the **Wheel Slip Ratio ($\lambda$)**:

$$\lambda = \frac{v_{\text{vehicle}} - \omega \cdot r_{\text{wheel}}}{v_{\text{vehicle}}}$$

```c
typedef struct {
    uint32_t vehicle_speed_q8;  // Vehicle velocity in Q8.8 fixed-point (km/h)
    uint32_t wheel_speed_q8;    // Wheel linear speed in Q8.8 fixed-point (km/h)
    uint32_t brake_pedal_force; // Requested force (0-100%)
    uint32_t commanded_pressure;// Final modulated brake pressure
} abs_state_t;

void abs_control_step(abs_state_t* state) {
    // 1. Calculate slip ratio: slip = (v_veh - v_wheel) / v_veh
    uint32_t speed_diff = state->vehicle_speed_q8 - state->wheel_speed_q8;
    uint32_t slip_ratio_percent = (speed_diff * 100) / state->vehicle_speed_q8;

    // 2. ABS Threshold Decision Logic
    if (slip_ratio_percent > 20) {
        // High wheel lockup risk (> 20% slip): Pressure Relief Mode
        state->commanded_pressure = state->brake_pedal_force / 2;
        uart_puts("[ABS] Slip threshold exceeded! Modulating hydraulic valve.\r\n");
    } else {
        // Optimal traction (< 20% slip): Apply full requested brake pressure
        state->commanded_pressure = state->brake_pedal_force;
    }

    // 3. Actuator Write-Back (Monitored by DCLS Bus Firewall)
    *(volatile uint32_t*)(0x00010100) = state->commanded_pressure;
}
```

If an SEU corrupts `state->commanded_pressure` during this computation in the Master Core, the DCLS Comparator intercepts the corrupted store operation before it can reach address `0x00010100`, clamping the bus in zero clock cycles.

Next: Review the comprehensive verification suite and automated fault injection in [[01_Fault_Injection_and_ASIL_D_Verification | Fault Injection & ASIL-D Verification Suite]].
