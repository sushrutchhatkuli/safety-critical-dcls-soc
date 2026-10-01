---
title: "System Interconnect & Memory Map Architecture: AMBA AXI4-Lite Routing"
tags:
  - axi-interconnect
  - memory-map
  - address-decoder
  - soc-architecture
  - crossbar
date_created: 2026-10-01
status: "Active / Production"
---

# System Interconnect & Memory Map Architecture

> [!NOTE] **Subsystem Integration**
> Connects the **DCLS Protected Core** to 4 distinct memory-mapped slave modules via an AXI4-Lite Crossbar: Instruction RAM, Data RAM, High-Reliability UART, and Custom Fixed-Point Accelerator.

---

## 1. System Memory Map Specification

The 32-bit address space is partitioned to prevent address aliasing and enforce strict hardware boundaries:

```
  32-Bit Address Space
  ┌───────────────────────────────┐ 0xFFFF_FFFF
  │ Reserved / Unmapped           │
  ├───────────────────────────────┤ 0x2000_0100
  │ Custom Compute Accelerator    │ (Slave 3: Fixed-Point Math Engine)
  ├───────────────────────────────┤ 0x2000_0000
  │ Reserved                      │
  ├───────────────────────────────┤ 0x1000_0030
  │ DCLS Safety & FCU Registers   │ (Slave 2B: Hardware Status / Fault Regs)
  ├───────────────────────────────┤ 0x1000_0020
  │ AXI4-Lite UART Peripheral     │ (Slave 2A: 16-Word FIFOs, Baud Gen)
  ├───────────────────────────────┤ 0x1000_0000
  │ Reserved                      │
  ├───────────────────────────────┤ 0x0001_4000
  │ Data RAM (16 KB)              │ (Slave 1: Stack, Heap, Global Variables)
  ├───────────────────────────────┤ 0x0001_0000
  │ Reserved                      │
  ├───────────────────────────────┤ 0x0000_4000
  │ Instruction / Program RAM     │ (Slave 0: Bootloader & C Application Code)
  └───────────────────────────────┘ 0x0000_0000
```

### Detailed Address Decoding Matrix:

| Subsystem / Peripheral | Base Address | End Address | Size | AXI Channel Role |
| :--- | :--- | :--- | :--- | :--- |
| **Instruction / Program RAM** | `0x0000_0000` | `0x0000_3FFF` | 16 KB | Slave 0 (Read/Write via AXI) |
| **Data RAM** | `0x0001_0000` | `0x0001_3FFF` | 16 KB | Slave 1 (Data Memory Controller) |
| **AXI4-Lite UART Peripheral** | `0x1000_0000` | `0x1000_001F` | 32 B | Slave 2 (Serial Telemetry Link) |
| **DCLS Safety Status Registers** | `0x1000_0020` | `0x1000_002F` | 16 B | Slave 2 (FCU Hardware Context) |
| **Custom Compute Accelerator** | `0x2000_0000` | `0x2000_00FF` | 256 B | Slave 3 (Real-Time Safety Math) |

---

## 2. AXI4-Lite Crossbar Address Decoding Logic

```systemverilog
// Combinational Address Decoding for Master Transactions
logic [1:0] slave_sel_aw;
logic [1:0] slave_sel_ar;

always_comb begin
    // Write Address Decoder
    if (m_axi_awaddr >= 32'h0000_0000 && m_axi_awaddr <= 32'h0000_3FFF)
        slave_sel_aw = 2'd0; // Instruction RAM
    else if (m_axi_awaddr >= 32'h0001_0000 && m_axi_awaddr <= 32'h0001_3FFF)
        slave_sel_aw = 2'd1; // Data RAM
    else if (m_axi_awaddr >= 32'h1000_0000 && m_axi_awaddr <= 32'h1000_002F)
        slave_sel_aw = 2'd2; // UART & FCU Registers
    else if (m_axi_awaddr >= 32'h2000_0000 && m_axi_awaddr <= 32'h2000_00FF)
        slave_sel_aw = 2'd3; // Accelerator
    else
        slave_sel_aw = 2'd0; // Default fallback (DECERR handled)
end
```

---

## 3. Peripheral Register Map Details

### 3.1 UART Peripheral Register Map (`0x1000_0000`)
- `0x1000_0000`: `DATA_REG` (TX Write Byte [7:0], RX Read Byte [7:0])
- `0x1000_0004`: `STATUS_REG` (Bit 0: `tx_full`, Bit 1: `tx_empty`, Bit 2: `rx_full`, Bit 3: `rx_empty`, Bit 4: `rx_overrun`, Bit 5: `rx_frame_err`)
- `0x1000_0008`: `CTRL_REG` (Bit 0: `tx_en`, Bit 1: `rx_en`, Bit 2: `loopback_en`, Bit 3: `irq_en`)
- `0x1000_000C`: `BAUD_DIV_REG` (16-bit clock divisor for baud rate generation)
- `0x1000_0010`: `FIFO_CNT_REG` (Bits [4:0]: TX count, Bits [12:8]: RX count)

### 3.2 DCLS Safety Registers (`0x1000_0020`)
- `0x1000_0020`: `SAFETY_CTRL_STATUS` (Read/Clear status)
- `0x1000_0024`: `FAULT_PC_CAPTURE` (Frozen Program Counter)
- `0x1000_0028`: `FAULT_MISMATCH_BITS` (Mismatch classification bitmask)

Next: Review the bare-metal C software running on this memory map in [[01_Safety_Firmware_and_ABS_Control_Loop | Bare-Metal Safety Firmware & ABS Control Algorithm]].
