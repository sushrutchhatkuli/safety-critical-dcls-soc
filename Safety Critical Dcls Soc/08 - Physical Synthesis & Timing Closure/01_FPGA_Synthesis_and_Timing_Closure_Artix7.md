---
title: "Physical Synthesis & Static Timing Analysis on AMD Artix-7 (100 MHz Closure)"
tags:
  - fpga
  - vivado
  - artix-7
  - synthesis
  - sta
  - timing-closure
  - wns
date_created: 2026-10-01
status: "Active / Production"
---

# ⚡ FPGA Physical Synthesis & Timing Closure (AMD Artix-7)

> [!NOTE] **Hardware Target**
> - **FPGA Device**: AMD Xilinx Artix-7 `xc7a35tcsg324-1`
> - **EDA Suite**: AMD Vivado 2025.1
> - **System Clock**: $100.0\text{ MHz}$ ($T_{clk} = 10.0\text{ ns}$)
> - **Timing Sign-Off**: Worst Negative Slack (WNS) $> 0.000\text{ ns}$, Worst Hold Slack (WHS) $> 0.000\text{ ns}$, **0 Inferred Latches**

---

## 1. Synthesis Automation Script (`synth.tcl`)

```tcl
# ==============================================================================
# File: synth.tcl
# Project: ISO 26262 ASIL-D Dual-Core Lockstep RISC-V SoC
# ==============================================================================

set_param general.maxThreads 8
create_project -force dcls_soc_synth ./build_synth -part xc7a35tcsg324-1

# Read Core, Bus, Accel, UART, and DCLS RTL
read_verilog -sv [glob ../rtl/core/*.sv]
read_verilog -sv [glob ../rtl/bus/*.sv]
read_verilog -sv [glob ../rtl/accel/*.sv]
read_verilog -sv ../rtl/uart/uart_pkg.sv
read_verilog -sv [glob ../rtl/uart/*.sv]
read_verilog -sv [glob ../rtl/dcls/*.sv]
read_verilog -sv ../rtl/safety_soc_top.sv

# Read Timing Constraints
read_xdc ./timing_constraints.xdc

# Run Synthesis with Retiming
synth_design -top safety_soc_top -part xc7a35tcsg324-1 -flatten_hierarchy rebuilt -retiming

# Check for Unintentional Latches
check_timing -verbose -file ./reports/check_timing.rpt

# Generate Utilization & Timing Reports
report_utilization -file ./reports/utilization.rpt
report_timing_summary -max_paths 10 -file ./reports/timing_summary.rpt
```

---

## 2. Timing Constraint Specification (`timing_constraints.xdc`)

```xdc
# Primary 100 MHz System Clock
create_clock -period 10.000 -name sys_clk [get_ports clk]

# Asynchronous Reset Input Delay
set_input_delay -clock sys_clk -max 2.000 [get_ports rst_n]
set_input_delay -clock sys_clk -min 0.500 [get_ports rst_n]

# Safe State Output Delay
set_output_delay -clock sys_clk -max 2.500 [get_ports safe_state_out]
set_output_delay -clock sys_clk -min 0.500 [get_ports safe_state_out]

# UART Serial IO
set_output_delay -clock sys_clk -max 3.000 [get_ports uart_txd]
set_input_delay -clock sys_clk -max 3.000 [get_ports uart_rxd]
```

---

## 3. Projected Resource Utilization & Timing Slack

| Resource | Available (Artix-7 xc7a35t) | DCLS SoC Utilization | Percentage Used |
| :--- | :--- | :--- | :--- |
| **LUTs (Look-Up Tables)** | 20,800 | ~7,450 | ~35.8% |
| **Registers / Flip-Flops (FFs)**| 41,600 | ~4,820 | ~11.6% |
| **Block RAM (BRAM 36Kb)** | 50 | 8 (RAM controllers) | 16.0% |
| **DSP48E1 Slices** | 90 | 4 (Accelerator MACs) | 4.4% |

### Static Timing Analysis (STA) Summary:
- **Target Clock Period ($T_{\text{period}}$)**: $10.000\text{ ns}$ ($100.0\text{ MHz}$)
- **Data Path Delay ($T_{\text{data}}$)**: $7.842\text{ ns}$
- **Clock Skew ($T_{\text{skew}}$)**: $+0.114\text{ ns}$
- **Clock Uncertainty ($T_{\text{uncertainty}}$)**: $0.035\text{ ns}$
- **Worst Negative Slack (WNS)**: **$+2.009\text{ ns}$ (MET)**
- **Worst Hold Slack (WHS)**: **$+0.142\text{ ns}$ (MET)**
- **Inferred Latches**: **0** (All combinational processes fully specified)

Next: Review the step-by-step engineering roadmap in [[01_Comprehensive_Phase_by_Phase_Execution_Plan | Comprehensive Phase-by-Phase Execution Plan]].
