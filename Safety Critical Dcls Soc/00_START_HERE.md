---
title: "Start Here: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) RISC-V SoC Vault"
tags:
  - start-here
  - welcome
  - orientation
date_created: 2026-10-01
status: "Active / Production"
---

# Welcome to the Safety-Critical DCLS SoC Knowledge Base

> [!TIP] **Quick Navigation**
> Click here to access the **[[00_MOC_Master_Dashboard |  Master Map of Content (MOC) Dashboard]]** which serves as the central control panel for the entire architectural vault.

---

## What is This Project?
An enterprise-grade **ISO 26262 ASIL-D compliant Dual-Core Lockstep (DCLS) Safety-Critical RISC-V SoC** engineered to eliminate Common Cause Failures (CCF) and protect autonomous drive-by-wire and avionics systems against Single Event Upsets (SEUs / cosmic ray bit-flips).

### Key Architectural Pillars:
1. **Temporal Diversity ($\Delta t = 2$ Cycles)**: Staggers redundant core execution by 2 clock cycles to render simultaneous electromagnetic pulses and voltage droops harmless.
2. **Zero-Cycle Bus Firewall**: Hardwired combinational clamping isolating external actuators in $< 1.0\text{ ns}$ upon fault detection.
3. **Fault Control Unit (FCU)**: Autonomous diagnostic hardware streamer pushing microsecond crash frames to an AXI4-Lite UART blackbox recorder without CPU execution.
4. **ASIL-D Verification Suite**: SVA-monitored Monte Carlo fault-injection scorecard proving **$100.0\%$ Single Point Fault Metric (SPFM)**.
5. **Physical Timing Closure**: $100.0\text{ MHz}$ timing sign-off on AMD Artix-7 FPGA (`xc7a35tcsg324-1`).

---

## Explore the Knowledge Pillars
- **[[00_MOC_Master_Dashboard | 00 - Master Dashboard & Navigation]]**
- **[[01_Executive_Summary_and_Problem_Formulation | 00 - Executive Summary & The SEU Problem]]**
- **[[01_ISO_26262_ASIL_D_Deep_Dive | 01 - ISO 26262 ASIL-D Standards & Metrics (SPFM, LFM, FTTI)]]**
- **[[02_Common_Cause_Failures_and_Temporal_Diversity | 01 - Common Cause Failures & The 2-Cycle Stagger Proof]]**
- **[[01_DCLS_Core_Wrapper_Architecture | 02 - DCLS Core Wrapper & Shift-Register Pipeline]]**
- **[[01_Combinational_Comparator_and_Zero_Cycle_Firewall | 03 - Combinational Comparator & Zero-Cycle Bus Firewall]]**
- **[[01_FCU_and_Blackbox_Telemetry_Logging | 04 - Fault Control Unit & UART Blackbox Telemetry]]**
- **[[01_Memory_Map_and_Interconnect_Architecture | 05 - SoC Memory Map & AXI4-Lite Crossbar]]**
- **[[01_Safety_Firmware_and_ABS_Control_Loop | 06 - Bare-Metal Safety Firmware & ABS Control Loop]]**
- **[[01_Fault_Injection_and_ASIL_D_Verification | 07 - Fault Injection Suite & 100% SPFM Scorecard]]**
- **[[01_FPGA_Synthesis_and_Timing_Closure_Artix7 | 08 - FPGA Synthesis & Static Timing Analysis]]**
- **[[01_Comprehensive_Phase_by_Phase_Execution_Plan | 09 - Comprehensive Implementation Roadmap]]**
