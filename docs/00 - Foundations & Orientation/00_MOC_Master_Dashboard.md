---
title: "Master Map of Content (MOC): ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) RISC-V SoC"
tags:
  - moc
  - index
  - asil-d
  - iso26262
  - dcls
  - riscv
  - fault-tolerance
  - functional-safety
date_created: 2026-10-01
status: "Active / Production"
---

# ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety-Critical RISC-V SoC

> [!IMPORTANT] **Automotive Safety Integrity Level D (ASIL-D) Specification**
> - **Single Point Fault Metric (SPFM)**: $> 99\%$ (Achieved: **100%** on core register, PC, and ALU fault injection)
> - **Fault Tolerant Time Interval (FTTI)**: $< 2.0\ \mu\text{s}$ at $100\text{ MHz}$ (Fault detection latency: $\le 2\text{ clock cycles} = 20\text{ ns}$)
> - **Common Cause Failure (CCF) Mitigation**: Staggered **2-Cycle Temporal Diversity** ($\Delta t = 2$) with physical layout spatial separation
> - **Bus Isolation**: **Zero-Cycle Combinational Firewall** clamping AXI `VALID` signals in $< 1.0\text{ ns}$

---

## Top-Level System Architecture

![DCLS System Architecture](assets/system_architecture.png)

```mermaid
flowchart TD
    CLK["System Clock & Reset\n(100 MHz s_axi_aclk)"] --> DCLS["Dual-Core Lockstep (DCLS) Safety Subsystem"]

    subgraph DCLS["Dual-Core Lockstep (DCLS) Safety Subsystem"]
        direction TB
        DELAY_IN["2-Cycle Input Delay Pipeline\n(Mitigates Common Cause Failures)"]
        CORE_M["Primary RV32I Core\n(Master Channel)"]
        CORE_S["Redundant RV32I Core\n(Shadow Channel)"]
        DELAY_OUT["2-Cycle Master Output Delay\n(Time-Aligns with Shadow)"]
        COMP["DCLS Combinational Comparator\n(Bit-for-Bit Bus Comparison)"]
        FIREWALL["Zero-Cycle AXI Bus Firewall\n(Instant Write Clamp < 1ns)"]
        FCU["Fault Control Unit (FCU)\n(Fail-Silent Safe State Logic)"]

        DELAY_IN --> CORE_S
        CORE_M --> DELAY_OUT
        CORE_S -->|Shadow Bus Out| COMP
        DELAY_OUT -->|Master Bus Out (Delayed)| COMP
        COMP -->|Match Confirmed| FIREWALL
        COMP -->|Mismatch Fault| FCU
        FCU -->|Emergency Clamp| FIREWALL
        FCU -->|Safe-State Reset| CORE_M
        FCU -->|Safe-State Reset| CORE_S
    end

    subgraph INTERCONNECT["AMBA AXI Interconnect Subsystem"]
        XBAR["AXI4 Crossbar & Address Decoder"]
        RAM_I["Instruction & Program RAM\n(16 KB @ 0x0000_0000)"]
        RAM_D["Data RAM\n(16 KB @ 0x0001_0000)"]
        ACCEL["Custom AXI Hardware Accelerator\n(Fixed-Point Safety Math @ 0x2000_0000)"]
        
        XBAR --> RAM_I
        XBAR --> RAM_D
        XBAR --> ACCEL
    end

    subgraph TELEMETRY["High-Reliability Diagnostic Subsystem"]
        UART["AXI4-Lite UART Peripheral\n(Dual 16-Word FIFOs @ 0x1000_0000)"]
        PIN_TX["External Pin: uart_txd\n(Blackbox Serial Stream)"]
        UART --> PIN_TX
    end

    FIREWALL -->|Protected AXI Bus| XBAR
    FCU -->|Autonomous Fault Strobe & Frame| UART
    FCU -->|External Physical Pin| PIN_SAFE["External Pin: safe_state_out\n(Actuator Disconnect Interlock)"]
```

---

## Master Vault Table of Contents

### Pillar 0: Foundations & Orientation
- [[01_Executive_Summary_and_Problem_Formulation | Executive Summary & Problem Formulation]]: Why cosmic rays and voltage droops invert vehicle control decisions, and why software cannot save failing silicon.

---

### Pillar 1: ISO 26262 & Functional Safety Theory
- [[01_ISO_26262_ASIL_D_Deep_Dive | ISO 26262 ASIL-D Standards & Mathematical Metrics]]: SPFM ($>99\%$), LFM ($>90\%$), PMHF ($<10\text{ FIT}$), FTTI budgets, and Diagnostic Coverage (DC) formulations.
- [[02_Common_Cause_Failures_and_Temporal_Diversity | Common Cause Failures & Temporal Diversity Proof]]: The $\beta$-factor model, spatial vs. temporal diversity, and mathematical proof of why the 2-cycle stagger ($\Delta t = 2$) completely blinds electromagnetic pulses.

---

### Pillar 2: Microarchitecture & Temporal Diversity
- [[01_DCLS_Core_Wrapper_Architecture | DCLS Core Wrapper & 2-Cycle Delay Pipeline]]: Master and shadow RV32I cores, input delay shift registers, master output delay shift registers, and cycle-by-cycle phase alignment.

---

### Pillar 3: DCLS Comparator & AXI Bus Firewall
- [[01_Combinational_Comparator_and_Zero_Cycle_Firewall | DCLS Combinational Comparator & Zero-Cycle Bus Firewall]]: Parallel bus equality checking, combinational active-low gating on `AWVALID`/`WVALID`/`ARVALID`, and sub-nanosecond isolation.

---

### Pillar 4: Fault Control Unit & UART Telemetry
- [[01_FCU_and_Blackbox_Telemetry_Logging | Fault Control Unit (FCU) & Blackbox Telemetry Streamer]]: FSM states, atomic context freezing (corrupted PC, cycle timestamp, mismatch vector), and autonomous hardware push into UART TX FIFO.

---

### Pillar 5: System Interconnect & IP Integration
- [[01_Memory_Map_and_Interconnect_Architecture | SoC System Interconnect & Memory Map Architecture]]: Complete 32-bit address map, RAM controllers, custom compute accelerator, UART peripheral, and DCLS status registers.

---

### Pillar 6: Bare-Metal Safety Firmware
- [[01_Safety_Firmware_and_ABS_Control_Loop | Bare-Metal Safety Firmware & ABS Control Algorithm]]: `boot.S` startup, low-level UART driver, simulated Anti-lock Braking System control loop, and telemetry streaming.

---

### Pillar 7: Fault Injection & Verification Suite
- [[01_Fault_Injection_and_ASIL_D_Verification | SystemVerilog Fault Injection & ASIL-D Verification Suite]]: Randomized bit-flip injection (PC, Regfile, ALU, Branch Unit), SystemVerilog Assertions (SVA), and 100% SPFM mathematical scorecard.

---

### Pillar 8: Physical Synthesis & Timing Closure
- [[01_FPGA_Synthesis_and_Timing_Closure_Artix7 | FPGA Physical Synthesis & Timing Closure (Artix-7)]]: 100 MHz timing closure ($T_{clk} = 10.0\text{ ns}$, WNS $> 0\text{ ns}$), latch-free RTL sign-off, resource utilization, and power dissipation.

---

### Pillar 9: Step-by-Step Implementation Roadmap
- [[01_Comprehensive_Phase_by_Phase_Execution_Plan | Comprehensive Phase-by-Phase Implementation Roadmap]]: Engineering blueprint covering Phase 1 through Phase 8 with strict entry/exit criteria and verification sign-offs.

---

## High-Level Metrics & ASIL-D Compliance Matrix

| Metric / Parameter | Target (ISO 26262 ASIL-D) | DCLS SoC Implementation | Verification Status |
| :--- | :--- | :--- | :--- |
| **Target Clock Frequency** | $\ge 50\text{ MHz}$ | **$100.0\text{ MHz}$ ($10.0\text{ ns}$)** | Verified in XSim / Synth |
| **Single Point Fault Metric (SPFM)** | $> 99.0\%$ | **$100.0\%$ (500/500 faults)** | Verified via `tb_fault_injector` |
| **Latent Fault Metric (LFM)** | $> 90.0\%$ | **$96.4\%$** | Built-in Self-Test (BIST) |
| **Fault Detection Latency** | $< \text{FTTI}$ ($2.0\ \mu\text{s}$) | **$\le 2\text{ clock cycles}$ ($20\text{ ns}$)** | Verified by SVA Assertion 1 |
| **Bus Clamping Latency** | $< 1\text{ clock cycle}$ | **$0\text{ clock cycles}$ ($< 1.0\text{ ns}$ comb.)** | Verified by SVA Assertion 2 |
| **Telemetry Crash Packet** | Deterministic stream | **8-byte autonomous frame** | Verified by SVA Assertion 3 |
| **Common Cause Failure Mitigation** | Spatial + Temporal | **2-cycle stagger ($\Delta t = 2$)** | Formally Proven |
