// =============================================================================
// File: axi_ram_ctrl.sv
// Project: Heterogeneous RISC-V SoC with AXI4-Lite & Accelerator
// Description: AMBA AXI4-Lite Synchronous RAM Controller.
//              Implements an on-chip SRAM controller inferring Block RAM.
//              Supports byte-write strobes (wstrb[3:0]), standard AXI4-Lite
//              handshake contracts, and generates OKAY (2'b00) responses.
// =============================================================================

`timescale 1ns / 1ps

module axi_ram_ctrl #(
    parameter int MEM_DEPTH_WORDS = 1024 // Default 1024 words = 4 KB
)(
    input  logic        clk,
    input  logic        rst_n,

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave Bus Interface
    // -------------------------------------------------------------------------
    // Write Address Channel (AW)
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    // Write Data Channel (W)
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    // Write Response Channel (B)
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    // Read Address Channel (AR)
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    // Read Data Channel (R)
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready
);

    // -------------------------------------------------------------------------
    // Internal Memory Array (Inferred as Hardware Block RAM)
    // -------------------------------------------------------------------------
    (* ram_style = "block" *) logic [31:0] ram_memory [0:MEM_DEPTH_WORDS-1];

    // Local registers to latch address and control
    logic [13:0] write_word_addr;
    logic        aw_done_reg;
    logic        w_done_reg;

    // Write Channels (AW, W, B) FSM / Handshake
    typedef enum logic [1:0] {
        WR_IDLE = 2'b00,
        WR_DATA = 2'b01,
        WR_RESP = 2'b10
    } wr_state_t;

    wr_state_t wr_state;

    // Synchronous RAM Write Signals (Isolated from Asynchronous Reset)
    logic        ram_we;
    logic [13:0] ram_waddr;
    logic [31:0] ram_wdata;
    logic [3:0]  ram_wstrb;

    always_comb begin
        ram_we    = 1'b0;
        ram_waddr = 14'd0;
        ram_wdata = s_axi_wdata;
        ram_wstrb = s_axi_wstrb;

        if (wr_state == WR_IDLE) begin
            if (s_axi_wvalid && s_axi_wready) begin
                ram_we    = 1'b1;
                ram_waddr = s_axi_awaddr[15:2];
            end
        end else if (wr_state == WR_DATA) begin
            if (!w_done_reg && s_axi_wvalid && s_axi_wready) begin
                ram_we    = 1'b1;
                ram_waddr = write_word_addr;
            end
        end
    end

    // Dedicated pure synchronous write port (BRAM synthesis compliant)
    always_ff @(posedge clk) begin
        if (ram_we) begin
            if (ram_wstrb[0]) ram_memory[ram_waddr][7:0]   <= ram_wdata[7:0];
            if (ram_wstrb[1]) ram_memory[ram_waddr][15:8]  <= ram_wdata[15:8];
            if (ram_wstrb[2]) ram_memory[ram_waddr][23:16] <= ram_wdata[23:16];
            if (ram_wstrb[3]) ram_memory[ram_waddr][31:24] <= ram_wdata[31:24];
        end
    end

    // -------------------------------------------------------------------------
    // Write Channels (AW, W, B) FSM / Handshake Process
    // -------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state        <= WR_IDLE;
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= 2'b00; // OKAY
            write_word_addr <= 14'd0;
            aw_done_reg     <= 1'b0;
            w_done_reg      <= 1'b0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    s_axi_bvalid  <= 1'b0;
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b1;

                    // Address accepted
                    if (s_axi_awvalid && s_axi_awready) begin
                        write_word_addr <= s_axi_awaddr[15:2];
                        aw_done_reg     <= 1'b1;
                        s_axi_awready   <= 1'b0;
                    end

                    // Data accepted
                    if (s_axi_wvalid && s_axi_wready) begin
                        w_done_reg   <= 1'b1;
                        s_axi_wready <= 1'b0;
                    end

                    // If both arrived simultaneously in WR_IDLE
                    if ((s_axi_awvalid && s_axi_awready) && (s_axi_wvalid && s_axi_wready)) begin
                        wr_state     <= WR_RESP;
                        s_axi_bvalid <= 1'b1;
                        s_axi_bresp  <= 2'b00; // OKAY
                    end else if ((s_axi_awvalid && s_axi_awready) || (s_axi_wvalid && s_axi_wready)) begin
                        wr_state     <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    // Wait for the remaining channel
                    if (!aw_done_reg) begin
                        s_axi_awready <= 1'b1;
                        if (s_axi_awvalid && s_axi_awready) begin
                            write_word_addr <= s_axi_awaddr[15:2];
                            aw_done_reg     <= 1'b1;
                            s_axi_awready   <= 1'b0;
                        end
                    end

                    if (!w_done_reg) begin
                        s_axi_wready <= 1'b1;
                        if (s_axi_wvalid && s_axi_wready) begin
                            w_done_reg   <= 1'b1;
                            s_axi_wready <= 1'b0;
                        end
                    end

                    // Once both are finished, issue write response
                    if ((aw_done_reg || (s_axi_awvalid && s_axi_awready)) &&
                        (w_done_reg  || (s_axi_wvalid  && s_axi_wready))) begin
                        wr_state     <= WR_RESP;
                        s_axi_bvalid <= 1'b1;
                        s_axi_bresp  <= 2'b00; // OKAY
                    end
                end

                WR_RESP: begin
                    if (s_axi_bready && s_axi_bvalid) begin
                        s_axi_bvalid <= 1'b0;
                        aw_done_reg  <= 1'b0;
                        w_done_reg   <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read Channels (AR, R) FSM / Handshake
    // -------------------------------------------------------------------------
    typedef enum logic {
        RD_IDLE = 1'b0,
        RD_RESP = 1'b1
    } rd_state_t;

    rd_state_t rd_state;

    // Dedicated pure synchronous read port (BRAM synthesis compliant)
    always_ff @(posedge clk) begin
        if (s_axi_arvalid && s_axi_arready) begin
            s_axi_rdata <= ram_memory[s_axi_araddr[15:2]];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state      <= RD_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00; // OKAY
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arready <= 1'b0;
                        s_axi_rvalid  <= 1'b1;
                        s_axi_rresp   <= 2'b00; // OKAY
                        rd_state      <= RD_RESP;
                    end
                end

                RD_RESP: begin
                    if (s_axi_rready && s_axi_rvalid) begin
                        s_axi_rvalid  <= 1'b0;
                        s_axi_arready <= 1'b1;
                        rd_state      <= RD_IDLE;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
