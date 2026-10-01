// =============================================================================
// File: main.c
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Bare-metal automotive safety application: Anti-lock Braking
//              System (ABS) wheel-slip monitoring and hydraulic pressure
//              modulation control loop.
// =============================================================================

#include <stdint.h>
#include "uart.h"
#include "accel.h"

// Hardware Memory Map for Actuators and RAM
#define DATA_RAM_BASE         0x20000000
#define BRAKE_ACTUATOR_REG    (*(volatile uint32_t*)(DATA_RAM_BASE + 0x0100))
#define SAFETY_HEARTBEAT_REG  (*(volatile uint32_t*)(DATA_RAM_BASE + 0x0104))

// ABS State in Q8.8 fixed-point representation
typedef struct {
    uint32_t vehicle_speed_q8;   // Vehicle speed (e.g. 100 km/h = 100 << 8)
    uint32_t wheel_speed_q8;     // Wheel speed (e.g. 70 km/h = 70 << 8)
    uint32_t driver_pedal_force; // Requested brake force (0 to 100%)
    uint32_t commanded_pressure; // Modulated actuator pressure
} abs_controller_t;

// ABS Control Step
void abs_control_step(abs_controller_t* abs) {
    // Slip ratio: lambda = (v_vehicle - v_wheel) / v_vehicle
    uint32_t speed_diff = abs->vehicle_speed_q8 - abs->wheel_speed_q8;
    uint32_t slip_ratio_percent = (speed_diff * 100) / abs->vehicle_speed_q8;

    if (slip_ratio_percent > 20) {
        // High wheel lockup risk (>20% slip): Pressure relief modulation
        abs->commanded_pressure = abs->driver_pedal_force / 2;
        uart_puts("[ABS] Slip detected (>20%). Pressure relief active.\r\n");
    } else {
        // Optimal traction (<20% slip): Full brake pressure application
        abs->commanded_pressure = abs->driver_pedal_force;
        uart_puts("[ABS] Traction nominal. Normal brake pressure applied.\r\n");
    }

    // Actuator write-back: Monitored bit-for-bit by DCLS bus firewall
    BRAKE_ACTUATOR_REG = abs->commanded_pressure;
}

int main(void) {
    // 1. Initialize UART (divisor 53 for 115200 baud at 100 MHz)
    uart_init(53);
    uart_puts("====================================================\r\n");
    uart_puts(" ISO 26262 ASIL-D Dual-Core Lockstep Safety System   \r\n");
    uart_puts(" Bare-Metal ABS Safety Controller Active             \r\n");
    uart_puts("====================================================\r\n");

    abs_controller_t abs;
    abs.vehicle_speed_q8   = 100 << 8; // 100.0 km/h
    abs.wheel_speed_q8     = 70 << 8;  // 70.0 km/h (30% slip -> lockup danger!)
    abs.driver_pedal_force = 80;       // 80% brake pedal pressure
    abs.commanded_pressure = 0;

    uint32_t loop_count = 0;

    // Safety Execution Loop
    while (1) {
        SAFETY_HEARTBEAT_REG = loop_count++;
        abs_control_step(&abs);

        // Gradually recover wheel speed (simulating anti-lock release)
        if (abs.wheel_speed_q8 < abs.vehicle_speed_q8) {
            abs.wheel_speed_q8 += (5 << 8); // +5 km/h recovery per cycle
        }
    }

    return 0;
}
