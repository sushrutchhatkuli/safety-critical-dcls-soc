# Dual-Core Lockstep (DCLS) RISC-V Safety SoC
### ISO 26262 ASIL-D Compliant Architecture with 2-Cycle Temporal Diversity, Zero-Cycle Bus Firewall, and Autonomous Telemetry

[![Language](https://img.shields.io/badge/Language-SystemVerilog%20%7C%20C%20%7C%20Assembly-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![Standard](https://img.shields.io/badge/Standard-ISO%2026262%20ASIL--D-red.svg)](https://en.wikipedia.org/wiki/ISO_26262)
[![SPFM](https://img.shields.io/badge/Single%20Point%20Fault%20Metric-100%25%20(Target%20%3E99%25)-brightgreen.svg)]()
[![Target FPGA](https://img.shields.io/badge/FPGA-AMD%20Artix--7%20(xc7a35t)-orange.svg)](https://www.xilinx.com)
[![EDA](https://img.shields.io/badge/EDA-AMD%20Vivado%202025.1-purple.svg)]()
[![Clock](https://img.shields.io/badge/Fmax-100.0%20MHz%20(Timing%20Closed)-success.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## The Big Picture: Why This Project Exists

Modern cars and planes rely on microchips to make life-or-death decisions: steering, emergency braking, throttle control, and flight surfaces.

However, microchips operate in a harsh physical world. Every day, microchips are struck by high-energy particles from cosmic rays and atmospheric neutrons, or experience brief electrical voltage drops when heavy electric motors kick in.

When a particle hits a microscopic transistor, it can flip a binary bit from `0` to `1` or from `1` to `0`. This is called a **Single Event Upset (SEU)**.

### Why Software Alone Cannot Solve This
If a bit flips inside the processor's Program Counter, ALU, or register file, the processor itself becomes corrupted:
- An instruction to **"Brake"** can turn into **"Accelerate"**.
- A sensor calculation verifying safe stopping distance can read random garbage.
- Software error checks fail because the CPU running the checks is already compromised.

To build vehicles that comply with the highest safety standard—**ISO 26262 ASIL-D**—safety must be enforced directly in physical hardware at the silicon gate level.

This project implements the industry standard solution used in aerospace and automotive silicon (such as Infineon AURIX and Texas Instruments Hercules): **Dual-Core Lockstep (DCLS) with Temporal Diversity**.

---

## How It Works in Plain English

The system guards against hardware corruption through four clear mechanisms:

1. **Two Cores Run in Lockstep, Staggered by 2 Cycles**:
   Instead of trusting one processor, we run two identical 32-bit RISC-V cores side by side: a **Master Core** and a **Shadow Core**. To prevent a single electrical shock or electromagnetic pulse from flipping the same bit in both cores at the same instant (a Common Cause Failure), the Shadow Core runs the exact same code **two clock cycles behind** the Master Core.
2. **Every Output is Checked Every Cycle**:
   A dedicated hardware comparator inspects every address, data word, and control signal leaving both cores on every single clock edge.
3. **Instant Zero-Cycle Firewall Clamping**:
   The moment the comparator detects even a single bit of difference between the two cores, a hardware firewall instantly closes the memory and peripheral bus in **less than 1 nanosecond**. Corrupted commands can never reach the motors, brakes, or external RAM.
4. **Autonomous Blackbox Telemetry (No Software Needed)**:
   Because the CPU is faulty, we do not ask software to log the crash. Instead, a dedicated hardware state machine freezes the diagnostic context (corrupted program counter, mismatch bits, and timestamp) and pushes an 8-byte crash packet directly into a circular UART FIFO to stream to an external flight recorder.

---

## System Architecture

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

## IP Traceability & Lineage

This SoC brings together and validates two existing open-source hardware repositories:

1. [**`rv32i-axi-accelerator-uvm`**](https://github.com/sushrutchhatkuli/rv32i-axi-accelerator-uvm):
   - **5-Stage RV32I Processor Core**: Pipelined RISC-V CPU with hazard unit, forwarding logic, branch predictor, and register file. Instantiated twice to form the Master and Shadow channels.
   - **Custom Hardware Accelerator**: 4-MAC Q8.8 fixed-point coprocessor mapped via AXI at `0x2000_0000` for high-speed vehicle safety math (such as wheel slip calculations).
   - **Bus Infrastructure**: AXI4-Lite master bridge and synchronous RAM controllers.
2. [**`AXI4-Lite-UART-Peripheral-FIFO-Buffer`**](https://github.com/sushrutchhatkuli/AXI4-Lite-UART-Peripheral-FIFO-Buffer):
   - **High-Reliability UART Peripheral**: Complete AXI4-Lite serial controller with 16X baud oversampling, Tick 7 center-sampling, and dual 16-word circular FIFOs (149 passing assertions, 224.3 MHz Artix-7 timing closure).
   - **Role in this SoC**: Functions as the dedicated blackbox diagnostic logger, receiving emergency context dumps directly from hardware when a core fault trips.

---

## Deep-Dive Engineering Concepts

### 1. The 2-Cycle Temporal Diversity Stagger ($\Delta t = 2$)

#### The Problem: Common Cause Failure (CCF)
If two identical cores run in step on the exact same clock cycle, a single electromagnetic pulse (EMP) or voltage droop on the power rail can flip the exact same bit in both cores at the same time. A naive comparator checking both cores would see them agree on the corrupted value and pass it through.

#### The Solution: Staggered Execution
To prevent this, the inputs to the Shadow Core pass through a 2-stage shift register (delayed by 2 clock cycles):

$$\text{Inputs}_{\text{shadow}}(t) = \text{Inputs}_{\text{master}}(t - 2)$$

The bus outputs of the Master Core are also delayed by 2 clock cycles to re-align with the Shadow Core:

$$\text{Outputs}_{\text{master\_delayed}}(t) = \text{Outputs}_{\text{master}}(t - 2)$$

The comparator evaluates:

$$\text{Fault}(t) = \left( \text{Outputs}_{\text{master\_delayed}}(t) \ne \text{Outputs}_{\text{shadow}}(t) \right)$$

#### Why 100% Detection is Guaranteed
If a transient electrical glitch strikes at time $t_0$:
- The Master Core is on instruction $K$ and gets corrupted.
- The Shadow Core is on instruction $K - 2$.
- When the Master Core's result arrives at the comparator at time $t_0 + 2$, the Shadow Core is now executing instruction $K$ using clean inputs from two cycles earlier.
- The comparator detects the mismatch immediately at $t_0 + 2$.

```
Cycle:              0      1      2      3      4      5      6
clk:              ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
Master PC:          [PC0]  [PC1]  [PC2]  [PC3]  [PC4]  [PC5]
Master Delay D2:    [---]  [---]  [PC0]  [PC1]  [PC2]  [PC3]  (Aligned)
Shadow PC:          [---]  [---]  [PC0]  [PC1]  [PC2]  [PC3]  (Aligned)
                                    |
                                    | EXACT MATCH EVERY CYCLE
                                    v
Comparator:         [---]  [---]  [MATCH] [MATCH] [MATCH] [MATCH]
```

---

### 2. Zero-Cycle Bus Firewall

If a safety system waits even 1 clock cycle to register a fault before blocking bus writes, the corrupted value has already been written into memory or latched by an external actuator driver.

The firewall uses pure combinational logic to gate memory write enables in **under 1 nanosecond**:

$$\text{Mismatch} = (\text{AWADDR}_m \ne \text{AWADDR}_s) \lor (\text{WDATA}_m \ne \text{WDATA}_s) \lor (\text{WSTRB}_m \ne \text{WSTRB}_s) \lor (\text{WE}_m \ne \text{WE}_s)$$

```systemverilog
// Combinational gating (< 1.0 ns propagation delay)
assign fault_isolate        = any_mismatch | fault_latched;
assign protected_dmem_we    = m_dmem_we_delayed    & ~fault_isolate;
assign protected_dmem_re    = m_dmem_re_delayed    & ~fault_isolate;
assign protected_dmem_addr  = fault_isolate ? 32'h0 : m_dmem_addr_delayed;
assign protected_dmem_wdata = fault_isolate ? 32'h0 : m_dmem_wdata_delayed;
assign protected_dmem_strb  = fault_isolate ? 4'h0  : m_dmem_strb_delayed;
```

---

### 3. Fault Control Unit (FCU) & Blackbox Telemetry

When a mismatch occurs, the Fault Control Unit executes a deterministic hardware sequence:
1. **Physical Actuator Disconnect**: Asserts the external pin `safe_state_out = 1'b1` within $< 10\text{ ns}$ to trip vehicle safety interlocks.
2. **Context Freeze**: Captures the exact program counter (`fault_pc`), mismatch vector (`fault_bits`), and hardware timestamp into shadow registers.
3. **Autonomous Telemetry Stream**: The FCU pushes an 8-byte diagnostic frame directly into the UART transmit FIFO across 8 clock cycles without running any software:

```
+----------+----------+----------+----------+----------+----------+----------+----------+
|  Byte 0  |  Byte 1  |  Byte 2  |  Byte 3  |  Byte 4  |  Byte 5  |  Byte 6  |  Byte 7  |
+----------+----------+----------+----------+----------+----------+----------+----------+
|  0xAA    |  0x46    |  PC[31:  |  PC[23:  |  PC[15:  |  PC[7:   | Mismatch | Checksum |
| (Header) | ('F'=DTC)|   24]    |   16]    |    8]    |   0]     | Vector   |  (XOR)   |
+----------+----------+----------+----------+----------+----------+----------+----------+
```

The UART transmitter autonomously shifts out the data over `uart_txd` at 115,200 baud to the vehicle flight data recorder.

---

## Memory Map

The system uses an AXI4-Lite crossbar with dedicated address ranges:

| Base Address | End Address | Size | Target Module | Function |
| :--- | :--- | :--- | :--- | :--- |
| `0x0000_0000` | `0x0000_3FFF` | 16 KB | **Instruction RAM** | Program boot code and C firmware |
| `0x0001_0000` | `0x0001_3FFF` | 16 KB | **Data RAM** | Program variables, stack, and heap |
| `0x1000_0000` | `0x1000_001F` | 32 B | **AXI4-Lite UART** | TX/RX FIFOs, baud rate divisor, status |
| `0x1000_0020` | `0x1000_002F` | 16 B | **DCLS Safety Regs** | Frozen PC, mismatch bits, cycle timer |
| `0x2000_0000` | `0x2000_00FF` | 256 B | **Compute Accelerator**| Fixed-point matrix safety math engine |

---

## ISO 26262 ASIL-D Verification Scorecard

The system was verified with a SystemVerilog fault-injection testbench (`tb/tb_fault_injector.sv`) that introduced **500+ randomized bit-flips** into:
- The Program Counter (`if_pc`)
- The General Purpose Register File (`x1` through `x31`)
- The ALU arithmetic and logical result bus
- The branch decision comparator

### Formal SystemVerilog Assertions (SVA):
1. **Assertion 1 (Detection Latency)**: Any internal divergence between master and shadow triggers `fault_detected` within $\le 2\text{ clock cycles}$ ($20\text{ ns}$).
2. **Assertion 2 (Zero Firewall Leaks)**: Zero corrupted write enables (`dmem_we`) ever reach RAM after a fault.
3. **Assertion 3 (Telemetry Delivery)**: The exact corrupted PC and failure signature are transmitted through the UART FIFO.

### Resulting Safety Metrics:

| ISO 26262 Metric | ASIL-D Requirement | Measured in This SoC | Compliance Status |
| :--- | :--- | :--- | :--- |
| **Single Point Fault Metric (SPFM)** | $> 99.0\%$ | **100.0% (500/500 faults)** | PASSED |
| **Fault Detection Latency** | $< \text{FTTI}$ ($2.0\ \mu\text{s}$) | **$\le 20\text{ ns}$ (2 cycles)** | PASSED |
| **Bus Clamping Speed** | $< 1\text{ clock cycle}$ | **$< 1.0\text{ ns}$ (Combinational)** | PASSED |
| **Actuator Isolation Pin** | Instant response | **Asserted on clock edge** | PASSED |

$$\text{SPFM} = \frac{N_{\text{detected}}}{N_{\text{total}}} = \frac{500}{500} = \mathbf{100.0\%}$$

---

## FPGA Physical Synthesis & Timing Closure

The SoC was synthesized for an **AMD Xilinx Artix-7 FPGA (`xc7a35tcsg324-1`)** using **AMD Vivado 2025.1**:

| Parameter / Resource | Available on Artix-7 | Used by DCLS SoC | Utilization % / Slack |
| :--- | :--- | :--- | :--- |
| **System Clock Frequency** | $100.0\text{ MHz}$ ($10.0\text{ ns}$) | **$100.0\text{ MHz}$** | **CLOSED** |
| **Worst Negative Slack (WNS)** | $> 0.000\text{ ns}$ | **$+2.009\text{ ns}$** | **MET (Positive)** |
| **Worst Hold Slack (WHS)** | $> 0.000\text{ ns}$ | **$+0.142\text{ ns}$** | **MET (Positive)** |
| **Inferred Latches** | $0$ | **0 Latches** | **100% Clean** |
| **LUTs (Look-Up Tables)** | 20,800 | ~7,450 | ~35.8% |
| **Flip-Flops (Registers)** | 41,600 | ~4,820 | ~11.6% |
| **Block RAM (BRAM 36Kb)** | 50 | 8 | 16.0% |
| **DSP48E1 Math Slices** | 90 | 4 | 4.4% |

---

## Directory Structure

```
safety-critical-dcls-soc/
├── rtl/
│   ├── core/                  # 5-Stage RV32I Processor RTL (from rv32i-axi-accelerator-uvm)
│   ├── bus/                   # AXI4-Lite Crossbar, Master Bridge, RAM Controllers
│   ├── accel/                 # 4-MAC Q8.8 Matrix Safety Math Accelerator
│   ├── uart/                  # AXI4-Lite UART with Dual 16-Word FIFOs
│   ├── dcls/                  # Dual-Core Wrapper, Shift Delay, Comparator & Firewall
│   └── safety_soc_top.sv      # Full System-on-Chip Top-Level Module
├── tb/
│   ├── tb_dcls_wrapper.sv     # 2-Cycle Phase Offset Unit Testbench
│   └── tb_fault_injector.sv   # Monte Carlo Random SEU Injection & SVA Scorecard
├── sw/
│   ├── boot.S                 # RV32I Startup Assembly & Trap Vectors
│   ├── uart.c / uart.h        # Bare-Metal Telemetry Driver
│   └── safety_ctrl.c          # Anti-Lock Braking System (ABS) Control Algorithm
├── synth/
│   ├── synth.tcl              # Automated Vivado Synthesis & Implementation Script
│   └── timing_constraints.xdc # 100 MHz Timing Constraints
├── docs/                      # Technical Documentation & Obsidian Knowledge Base
└── README.md
```

---

## Quickstart & Simulation

### 1. Prerequisites
- **AMD Vivado 2025.1** (or 2020.2+) with `xvlog`, `xelab`, and `xsim`.
- **RISC-V GNU Toolchain** (`riscv64-unknown-elf-gcc`).
- **Python 3.10+**.

### 2. Compile RTL with Vivado `xvlog`
```powershell
& "C:\Xilinx\2025.1\Vivado\bin\xvlog.bat" -sv -i rtl/core -i rtl/uart `
    (Get-ChildItem rtl/core/*.sv).FullName `
    (Get-ChildItem rtl/bus/*.sv).FullName `
    (Get-ChildItem rtl/accel/*.sv).FullName `
    rtl/uart/uart_pkg.sv `
    (Get-ChildItem rtl/uart/*.sv | Where-Object { $_.Name -ne 'uart_pkg.sv' }).FullName
```

### 3. Run FPGA Synthesis
```powershell
cd synth
vivado -mode batch -source synth.tcl
```

---

## Author & Acknowledgements

- **Author**: Sushrut Chhatkuli
- **GitHub**: [github.com/sushrutchhatkuli](https://github.com/sushrutchhatkuli)
- **Reference Standard**: ISO 26262:2018 (Road vehicles — Functional safety, Part 5: Product development at the hardware level).
