// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  uart_pkg
// Standard: SystemVerilog (IEEE 1800-2017)
// Description: Global package containing register map offsets, control bit masks,
//              status bit masks, and system default parameters.
// =============================================================================

package uart_pkg;

    // Register Address Offsets (32-bit word aligned)
    localparam logic [7:0] ADDR_UART_DATA      = 8'h00; // Transmit / Receive Data
    localparam logic [7:0] ADDR_UART_STATUS    = 8'h04; // Operational Status (RO)
    localparam logic [7:0] ADDR_UART_CTRL      = 8'h08; // Core Control (RW)
    localparam logic [7:0] ADDR_UART_BAUD_DIV  = 8'h0C; // Baud Divisor Register (RW)
    localparam logic [7:0] ADDR_UART_FIFO_CNT  = 8'h10; // FIFO Occupancy Count (RO)
    localparam logic [7:0] ADDR_UART_INTR_STAT = 8'h14; // Interrupt Status (W1C)
    localparam logic [7:0] ADDR_UART_INTR_EN   = 8'h18; // Interrupt Enable Mask (RW)

    // Status Register Bit Masks (UART_STATUS @ 0x04)
    localparam int STAT_TX_EMPTY_BIT    = 0;
    localparam int STAT_TX_FULL_BIT     = 1;
    localparam int STAT_RX_EMPTY_BIT    = 2;
    localparam int STAT_RX_FULL_BIT     = 3;
    localparam int STAT_RX_READY_BIT    = 4;
    localparam int STAT_FRAMING_ERR_BIT = 5;
    localparam int STAT_OVERRUN_ERR_BIT = 6;
    localparam int STAT_TX_BUSY_BIT     = 7;
    localparam int STAT_RX_BUSY_BIT     = 8;

    // Control Register Bit Masks (UART_CTRL @ 0x08)
    localparam int CTRL_TX_EN_BIT       = 0;
    localparam int CTRL_RX_EN_BIT       = 1;
    localparam int CTRL_LOOPBACK_BIT    = 2;
    localparam int CTRL_INTR_GLOBAL_BIT = 3;

    // Interrupt Bits (UART_INTR_STAT @ 0x14 / UART_INTR_EN @ 0x18)
    localparam int INTR_TX_EMPTY_BIT    = 0;
    localparam int INTR_RX_READY_BIT    = 1;
    localparam int INTR_FRAMING_ERR_BIT = 2;
    localparam int INTR_OVERRUN_ERR_BIT = 3;

    // AXI Response Codes
    localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam logic [1:0] AXI_RESP_EXOKAY = 2'b01;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;
    localparam logic [1:0] AXI_RESP_DECERR = 2'b11;

    // Default Configuration
    localparam int DEFAULT_BAUD_DIV = 53; // 100MHz / (16 * 115200) - 1
    localparam int FIFO_DEPTH       = 16; // 16-element circular buffer

endpackage : uart_pkg
