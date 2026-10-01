# ==============================================================================
# File: constraints.xdc
# Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
# Target: xc7a100tcsg324-1 (100 MHz System Clock)
# ==============================================================================

# Primary 100 MHz System Clock Constraint (10.0 ns period, 50% duty cycle)
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

# Asynchronous Reset Input
set_false_path -from [get_ports rst_n]

# Asynchronous Serial UART Pins (Handled by Internal Baud Generator Oversampling)
set_false_path -from [get_ports uart_rxd]
set_false_path -to   [get_ports uart_txd]

# Hardware Safety Interlock & Actuator Disconnect Outputs (Direct Analog/Relay Drivers)
set_false_path -to [get_ports safe_state_out]
set_false_path -to [get_ports fault_indicator]

# Asynchronous Interrupt Request Outputs
set_false_path -to [get_ports uart_irq]
set_false_path -to [get_ports accel_irq]
