// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  uart_axi_top
// Description: Top-level integration module connecting AXI4-Lite slave, dual
//              circular FIFOs, 16X baud generator, TX/RX serial cores, internal
//              loopback multiplexer, and interrupt logic.
// =============================================================================

import uart_pkg::*;

module uart_axi_top #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int FIFO_DEPTH     = 16,
    parameter int DEFAULT_DIV    = 53
)(
    input  logic                      s_axi_aclk,
    input  logic                      s_axi_aresetn,

    // AXI4-Lite Write Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [2:0]                s_axi_awprot,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,

    // AXI4-Lite Write Response Channel
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [2:0]                s_axi_arprot,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,

    // AXI4-Lite Read Data Channel
    output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready,

    // Serial Pins
    output logic                      uart_txd,
    input  logic                      uart_rxd,

    // Interrupt Pin
    output logic                      uart_irq
);

    // Internal Interconnect Wires
    logic [31:0] ctrl_reg;
    logic [15:0] baud_div_val;
    logic [31:0] status_reg;
    logic [31:0] fifo_cnt_reg;

    logic        baud_16x_tick;

    // TX FIFO Signals
    logic [7:0]  tx_fifo_wdata;
    logic        tx_fifo_push;
    logic [7:0]  tx_fifo_rdata;
    logic        tx_fifo_pop;
    logic        tx_fifo_full;
    logic        tx_fifo_empty;
    logic [4:0]  tx_fifo_count;

    // RX FIFO Signals
    logic [7:0]  rx_fifo_wdata;
    logic        rx_fifo_push;
    logic [7:0]  rx_fifo_rdata;
    logic        rx_fifo_pop;
    logic        rx_fifo_full;
    logic        rx_fifo_empty;
    logic [4:0]  rx_fifo_count;

    // Serial Core Signals
    logic        tx_serial_out;
    logic        tx_busy;
    logic        tx_done;

    logic        rx_serial_selected;
    logic        rx_busy;
    logic        framing_err;
    logic        overrun_err;

    // Event Detectors for Interrupts
    logic tx_empty_prev;
    logic rx_empty_prev;

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            tx_empty_prev <= 1'b1;
            rx_empty_prev <= 1'b1;
        end else begin
            tx_empty_prev <= tx_fifo_empty;
            rx_empty_prev <= rx_fifo_empty;
        end
    end

    wire hw_tx_empty_event    = (tx_empty_prev == 1'b0) && (tx_fifo_empty == 1'b1);
    wire hw_rx_ready_event    = (rx_empty_prev == 1'b1) && (rx_fifo_empty == 1'b0);
    wire hw_framing_err_event = framing_err;

    // An AXI write landing on a full TX FIFO is discarded by fifo_circular, unless a
    // pop retires an entry on the very same cycle. That is a silent data loss on the
    // transmit path, so it raises OVERRUN_ERR alongside the receive-side overrun.
    wire tx_overrun_event     = tx_fifo_push && tx_fifo_full && !tx_fifo_pop;
    wire hw_overrun_err_event = overrun_err || tx_overrun_event;

    // Sticky error flags for UART_STATUS[6:5]. The receiver emits single-cycle
    // pulses, but software polling STATUS must still observe the error, so they
    // latch until the matching UART_INTR_STAT bit is cleared via W1C.
    logic [3:0] intr_clr;
    logic       sticky_framing_err;
    logic       sticky_overrun_err;

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            sticky_framing_err <= 1'b0;
            sticky_overrun_err <= 1'b0;
        end else begin
            if (framing_err)                         sticky_framing_err <= 1'b1;
            else if (intr_clr[INTR_FRAMING_ERR_BIT]) sticky_framing_err <= 1'b0;

            if (hw_overrun_err_event)                sticky_overrun_err <= 1'b1;
            else if (intr_clr[INTR_OVERRUN_ERR_BIT]) sticky_overrun_err <= 1'b0;
        end
    end

    // Status Register Aggregation
    assign status_reg = {
        23'h0,
        rx_busy,                // bit 8
        tx_busy,                // bit 7
        sticky_overrun_err,     // bit 6
        sticky_framing_err,     // bit 5
        !rx_fifo_empty,         // bit 4 (RX_DATA_READY)
        rx_fifo_full,           // bit 3
        rx_fifo_empty,          // bit 2
        tx_fifo_full,           // bit 1
        tx_fifo_empty           // bit 0
    };

    // FIFO Count Register Aggregation
    assign fifo_cnt_reg = {
        19'h0,
        rx_fifo_count,          // bits [12:8]
        3'b000,
        tx_fifo_count           // bits [4:0]
    };

    // Digital Loopback Multiplexer
    // If CTRL[2] == 1, route tx_serial_out back to rx_serial_selected internally
    assign rx_serial_selected = ctrl_reg[CTRL_LOOPBACK_BIT] ? tx_serial_out : uart_rxd;
    assign uart_txd            = tx_serial_out;

    // 1. AXI4-Lite Slave Instance
    axi4_lite_slave #(
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .DATA_WIDTH(AXI_DATA_WIDTH)
    ) axi_slave_inst (
        .s_axi_aclk           (s_axi_aclk),
        .s_axi_aresetn        (s_axi_aresetn),
        .s_axi_awaddr         (s_axi_awaddr),
        .s_axi_awprot         (s_axi_awprot),
        .s_axi_awvalid        (s_axi_awvalid),
        .s_axi_awready        (s_axi_awready),
        .s_axi_wdata          (s_axi_wdata),
        .s_axi_wstrb          (s_axi_wstrb),
        .s_axi_wvalid         (s_axi_wvalid),
        .s_axi_wready         (s_axi_wready),
        .s_axi_bresp          (s_axi_bresp),
        .s_axi_bvalid         (s_axi_bvalid),
        .s_axi_bready         (s_axi_bready),
        .s_axi_araddr         (s_axi_araddr),
        .s_axi_arprot         (s_axi_arprot),
        .s_axi_arvalid        (s_axi_arvalid),
        .s_axi_arready        (s_axi_arready),
        .s_axi_rdata          (s_axi_rdata),
        .s_axi_rresp          (s_axi_rresp),
        .s_axi_rvalid         (s_axi_rvalid),
        .s_axi_rready         (s_axi_rready),
        .reg_ctrl             (ctrl_reg),
        .reg_baud_div         (baud_div_val),
        .reg_status           (status_reg),
        .reg_fifo_cnt         (fifo_cnt_reg),
        .tx_fifo_wdata        (tx_fifo_wdata),
        .tx_fifo_push         (tx_fifo_push),
        .rx_fifo_rdata        (rx_fifo_rdata),
        .rx_fifo_pop          (rx_fifo_pop),
        .hw_tx_empty_event    (hw_tx_empty_event),
        .hw_rx_ready_event    (hw_rx_ready_event),
        .hw_framing_err_event (hw_framing_err_event),
        .hw_overrun_err_event (hw_overrun_err_event),
        .intr_clr             (intr_clr),
        .uart_irq             (uart_irq)
    );

    // 2. Transmit Circular FIFO
    fifo_circular #(
        .DATA_WIDTH(8),
        .DEPTH(FIFO_DEPTH)
    ) tx_fifo_inst (
        .clk   (s_axi_aclk),
        .rst_n (s_axi_aresetn),
        .push  (tx_fifo_push),
        .wdata (tx_fifo_wdata),
        .full  (tx_fifo_full),
        .pop   (tx_fifo_pop),
        .rdata (tx_fifo_rdata),
        .empty (tx_fifo_empty),
        .count (tx_fifo_count)
    );

    // 3. Receive Circular FIFO
    fifo_circular #(
        .DATA_WIDTH(8),
        .DEPTH(FIFO_DEPTH)
    ) rx_fifo_inst (
        .clk   (s_axi_aclk),
        .rst_n (s_axi_aresetn),
        .push  (rx_fifo_push),
        .wdata (rx_fifo_wdata),
        .full  (rx_fifo_full),
        .pop   (rx_fifo_pop),
        .rdata (rx_fifo_rdata),
        .empty (rx_fifo_empty),
        .count (rx_fifo_count)
    );

    // 4. 16X Baud Rate Generator
    uart_baud_gen #(
        .DEFAULT_DIVISOR(DEFAULT_DIV)
    ) baud_gen_inst (
        .clk           (s_axi_aclk),
        .rst_n         (s_axi_aresetn),
        .baud_div_val  (baud_div_val),
        .baud_16x_tick (baud_16x_tick)
    );

    // 5. UART Transmitter Engine
    uart_tx tx_inst (
        .clk           (s_axi_aclk),
        .rst_n         (s_axi_aresetn),
        .baud_16x_tick (baud_16x_tick),
        .tx_en         (ctrl_reg[CTRL_TX_EN_BIT]),
        .tx_data       (tx_fifo_rdata),
        .tx_empty      (tx_fifo_empty),
        .tx_pop        (tx_fifo_pop),
        .tx_out        (tx_serial_out),
        .tx_busy       (tx_busy),
        .tx_done       (tx_done)
    );

    // 6. UART Receiver Engine
    uart_rx rx_inst (
        .clk           (s_axi_aclk),
        .rst_n         (s_axi_aresetn),
        .baud_16x_tick (baud_16x_tick),
        .rx_en         (ctrl_reg[CTRL_RX_EN_BIT]),
        .rx_async_in   (rx_serial_selected),
        .rx_data       (rx_fifo_wdata),
        .rx_push       (rx_fifo_push),
        .rx_fifo_full  (rx_fifo_full),
        .rx_busy       (rx_busy),
        .framing_err   (framing_err),
        .overrun_err   (overrun_err)
    );

endmodule : uart_axi_top
