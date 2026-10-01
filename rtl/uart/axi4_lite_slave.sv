// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  axi4_lite_slave
// Description: AMBA AXI4-Lite slave interface with decoupled AW/W channel handling,
//              memory-mapped register file, byte enable slicing, and W1C interrupt logic.
// =============================================================================

import uart_pkg::*;

module axi4_lite_slave #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input  logic                  s_axi_aclk,
    input  logic                  s_axi_aresetn,

    // Write Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [2:0]            s_axi_awprot,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,

    // Write Response Channel
    output logic [1:0]            s_axi_bresp,
    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready,

    // Read Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [2:0]            s_axi_arprot,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,

    // Read Data Channel
    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready,

    // Internal Peripheral Register Interface
    output logic [31:0]           reg_ctrl,
    output logic [15:0]           reg_baud_div,
    input  logic [31:0]           reg_status,
    input  logic [31:0]           reg_fifo_cnt,

    // FIFO Data Interfaces
    output logic [7:0]            tx_fifo_wdata,
    output logic                  tx_fifo_push,
    input  logic [7:0]            rx_fifo_rdata,
    output logic                  rx_fifo_pop,

    // Hardware Event Strobes for Interrupts
    input  logic                  hw_tx_empty_event,
    input  logic                  hw_rx_ready_event,
    input  logic                  hw_framing_err_event,
    input  logic                  hw_overrun_err_event,

    // W1C clear strobes, one per UART_INTR_STAT bit, for sticky status flags
    output logic [3:0]            intr_clr,

    // Interrupt Line
    output logic                  uart_irq
);

    // Internal registers
    logic [31:0] ctrl_reg;
    logic [15:0] baud_div_reg;
    logic [3:0]  intr_stat_reg; // W1C
    logic [3:0]  intr_en_reg;

    assign reg_ctrl     = ctrl_reg;
    assign reg_baud_div = baud_div_reg;

    // Decoupled Write Channel Latching
    logic [ADDR_WIDTH-1:0] awaddr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [(DATA_WIDTH/8)-1:0] wstrb_reg;
    logic aw_captured;
    logic w_captured;

    wire aw_hs = s_axi_awvalid && s_axi_awready;
    wire w_hs  = s_axi_wvalid  && s_axi_wready;

    // AWREADY and WREADY generation
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b1;
            s_axi_wready  <= 1'b1;
            awaddr_reg    <= '0;
            wdata_reg     <= '0;
            wstrb_reg     <= '0;
            aw_captured   <= 1'b0;
            w_captured    <= 1'b0;
        end else begin
            if (aw_hs) begin
                awaddr_reg    <= s_axi_awaddr;
                aw_captured   <= 1'b1;
                s_axi_awready <= 1'b0;
            end

            if (w_hs) begin
                wdata_reg    <= s_axi_wdata;
                wstrb_reg    <= s_axi_wstrb;
                w_captured   <= 1'b1;
                s_axi_wready <= 1'b0;
            end

            // Re-arm when write transaction completes
            if (s_axi_bvalid && s_axi_bready) begin
                aw_captured   <= 1'b0;
                w_captured    <= 1'b0;
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
            end
        end
    end

    // Write Execution & Response Logic
    wire write_ready_to_commit = (aw_captured || aw_hs) && (w_captured || w_hs) && !s_axi_bvalid;
    wire [ADDR_WIDTH-1:0] write_addr = aw_captured ? awaddr_reg : s_axi_awaddr;
    wire [DATA_WIDTH-1:0] write_data = w_captured  ? wdata_reg  : s_axi_wdata;
    wire [(DATA_WIDTH/8)-1:0] write_strb = w_captured ? wstrb_reg : s_axi_wstrb;

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= AXI_RESP_OKAY;
            tx_fifo_push  <= 1'b0;
            tx_fifo_wdata <= '0;
            ctrl_reg      <= 32'h00000003; // Default TX_EN=1, RX_EN=1
            baud_div_reg  <= 16'd53;       // Default 115200 baud @ 100MHz
            intr_en_reg   <= 4'b0000;
        end else begin
            tx_fifo_push <= 1'b0;

            if (write_ready_to_commit) begin
                s_axi_bvalid <= 1'b1;

                case (write_addr[7:0])
                    ADDR_UART_DATA: begin
                        if (write_strb[0]) begin
                            tx_fifo_wdata <= write_data[7:0];
                            tx_fifo_push  <= 1'b1;
                        end
                        s_axi_bresp <= AXI_RESP_OKAY;
                    end

                    ADDR_UART_CTRL: begin
                        for (int i = 0; i < 4; i++) begin
                            if (write_strb[i]) begin
                                ctrl_reg[i*8 +: 8] <= write_data[i*8 +: 8];
                            end
                        end
                        s_axi_bresp <= AXI_RESP_OKAY;
                    end

                    ADDR_UART_BAUD_DIV: begin
                        if (write_strb[0]) baud_div_reg[7:0]  <= write_data[7:0];
                        if (write_strb[1]) baud_div_reg[15:8] <= write_data[15:8];
                        s_axi_bresp <= AXI_RESP_OKAY;
                    end

                    ADDR_UART_INTR_EN: begin
                        if (write_strb[0]) intr_en_reg <= write_data[3:0];
                        s_axi_bresp <= AXI_RESP_OKAY;
                    end

                    ADDR_UART_INTR_STAT,
                    ADDR_UART_STATUS,
                    ADDR_UART_FIFO_CNT: begin
                        // Read-only or handled in W1C process
                        s_axi_bresp <= AXI_RESP_OKAY;
                    end

                    default: begin
                        s_axi_bresp <= AXI_RESP_SLVERR; // Unmapped address
                    end
                endcase
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // Write-1-to-Clear (W1C) Interrupt Status Register
    assign intr_clr = (write_ready_to_commit &&
                       (write_addr[7:0] == ADDR_UART_INTR_STAT) &&
                       write_strb[0]) ? write_data[3:0] : 4'b0000;

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            intr_stat_reg <= '0;
        end else begin
            // Software W1C clear is applied first so that a hardware event landing
            // on the same cycle overrides it and is never silently lost.
            for (int b = 0; b < 4; b++) begin
                if (intr_clr[b]) begin
                    intr_stat_reg[b] <= 1'b0;
                end
            end

            if (hw_tx_empty_event)    intr_stat_reg[INTR_TX_EMPTY_BIT]    <= 1'b1;
            if (hw_rx_ready_event)    intr_stat_reg[INTR_RX_READY_BIT]    <= 1'b1;
            if (hw_framing_err_event) intr_stat_reg[INTR_FRAMING_ERR_BIT] <= 1'b1;
            if (hw_overrun_err_event) intr_stat_reg[INTR_OVERRUN_ERR_BIT] <= 1'b1;
        end
    end

    // Global Interrupt Generation
    assign uart_irq = ctrl_reg[CTRL_INTR_GLOBAL_BIT] && (|(intr_stat_reg & intr_en_reg));

    // Read Channel Logic
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= '0;
            s_axi_rresp   <= AXI_RESP_OKAY;
            rx_fifo_pop   <= 1'b0;
        end else begin
            rx_fifo_pop <= 1'b0;

            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_arready <= 1'b0;
                s_axi_rvalid  <= 1'b1;

                case (s_axi_araddr[7:0])
                    ADDR_UART_DATA: begin
                        s_axi_rdata <= {24'h0, rx_fifo_rdata};
                        s_axi_rresp <= AXI_RESP_OKAY;
                        rx_fifo_pop <= 1'b1; // Pop byte on read
                    end

                    ADDR_UART_STATUS: begin
                        s_axi_rdata <= reg_status;
                        s_axi_rresp <= AXI_RESP_OKAY;
                    end

                    ADDR_UART_CTRL: begin
                        s_axi_rdata <= ctrl_reg;
                        s_axi_rresp <= AXI_RESP_OKAY;
                    end

                    ADDR_UART_BAUD_DIV: begin
                        s_axi_rdata <= {16'h0, baud_div_reg};
                        s_axi_rresp <= AXI_RESP_OKAY;
                    end

                    ADDR_UART_FIFO_CNT: begin
                        s_axi_rdata <= reg_fifo_cnt;
                        s_axi_rresp <= AXI_RESP_OKAY;
                    end

                    ADDR_UART_INTR_STAT: begin
                        s_axi_rdata <= {28'h0, intr_stat_reg};
                        s_axi_rresp <= AXI_RESP_OKAY;
                    end

                    ADDR_UART_INTR_EN: begin
                        s_axi_rdata <= {28'h0, intr_en_reg};
                        s_axi_rresp <= AXI_RESP_OKAY;
                    end

                    default: begin
                        s_axi_rdata <= 32'hDEAD_BEEF;
                        s_axi_rresp <= AXI_RESP_SLVERR;
                    end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid  <= 1'b0;
                s_axi_arready <= 1'b1;
            end
        end
    end

endmodule : axi4_lite_slave
