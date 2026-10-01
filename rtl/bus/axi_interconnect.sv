// =============================================================================
// File: axi_interconnect.sv
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: AMBA AXI4-Lite 1-Master to 3-Slave Crossbar Interconnect.
//              Routes bus transactions based on system memory map:
//                Slave 0: Data RAM (0x2000_0000 - 0x2000_FFFF)
//                Slave 1: Accelerator (0x4000_0000 - 0x4000_07FF)
//                Slave 2: AXI4-Lite UART Peripheral (0x1000_0000 - 0x1000_001F)
//              Any unmapped address is routed to internal DECERR responder.
// =============================================================================

`timescale 1ns / 1ps

module axi_interconnect (
    input  logic        clk,
    input  logic        rst_n,

    // =========================================================================
    // Master Interface (From CPU AXI Master Bridge)
    // =========================================================================
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // =========================================================================
    // Slave 0: RAM Controller (0x2000_0000 - 0x2000_FFFF)
    // =========================================================================
    output logic [31:0] m0_axi_awaddr,
    output logic        m0_axi_awvalid,
    input  logic        m0_axi_awready,

    output logic [31:0] m0_axi_wdata,
    output logic [3:0]  m0_axi_wstrb,
    output logic        m0_axi_wvalid,
    input  logic        m0_axi_wready,

    input  logic [1:0]  m0_axi_bresp,
    input  logic        m0_axi_bvalid,
    output logic        m0_axi_bready,

    output logic [31:0] m0_axi_araddr,
    output logic        m0_axi_arvalid,
    input  logic        m0_axi_arready,

    input  logic [31:0] m0_axi_rdata,
    input  logic [1:0]  m0_axi_rresp,
    input  logic        m0_axi_rvalid,
    output logic        m0_axi_rready,

    // =========================================================================
    // Slave 1: Custom Accelerator (0x4000_0000 - 0x4000_07FF)
    // =========================================================================
    output logic [31:0] m1_axi_awaddr,
    output logic        m1_axi_awvalid,
    input  logic        m1_axi_awready,

    output logic [31:0] m1_axi_wdata,
    output logic [3:0]  m1_axi_wstrb,
    output logic        m1_axi_wvalid,
    input  logic        m1_axi_wready,

    input  logic [1:0]  m1_axi_bresp,
    input  logic        m1_axi_bvalid,
    output logic        m1_axi_bready,

    output logic [31:0] m1_axi_araddr,
    output logic        m1_axi_arvalid,
    input  logic        m1_axi_arready,

    input  logic [31:0] m1_axi_rdata,
    input  logic [1:0]  m1_axi_rresp,
    input  logic        m1_axi_rvalid,
    output logic        m1_axi_rready,

    // =========================================================================
    // Slave 2: High-Reliability UART Peripheral (0x1000_0000 - 0x1000_001F)
    // =========================================================================
    output logic [31:0] m2_axi_awaddr,
    output logic        m2_axi_awvalid,
    input  logic        m2_axi_awready,

    output logic [31:0] m2_axi_wdata,
    output logic [3:0]  m2_axi_wstrb,
    output logic        m2_axi_wvalid,
    input  logic        m2_axi_wready,

    input  logic [1:0]  m2_axi_bresp,
    input  logic        m2_axi_bvalid,
    output logic        m2_axi_bready,

    output logic [31:0] m2_axi_araddr,
    output logic        m2_axi_arvalid,
    input  logic        m2_axi_arready,

    input  logic [31:0] m2_axi_rdata,
    input  logic [1:0]  m2_axi_rresp,
    input  logic        m2_axi_rvalid,
    output logic        m2_axi_rready
);

    // -------------------------------------------------------------------------
    // Address Decode Helpers
    // -------------------------------------------------------------------------
    function logic [1:0] decode_addr(input logic [31:0] addr);
        begin
            if (addr >= 32'h2000_0000 && addr <= 32'h2000_FFFF) begin
                decode_addr = 2'b00; // Slave 0: Data RAM
            end else if (addr >= 32'h4000_0000 && addr <= 32'h4000_07FF) begin
                decode_addr = 2'b01; // Slave 1: Accelerator
            end else if (addr >= 32'h1000_0000 && addr <= 32'h1000_001F) begin
                decode_addr = 2'b10; // Slave 2: UART Peripheral
            end else begin
                decode_addr = 2'b11; // Error / Unmapped (DECERR)
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // Write Routing
    // -------------------------------------------------------------------------
    logic [1:0] wr_sel;
    logic [1:0] latched_wr_sel;
    logic       wr_active;

    assign wr_sel = decode_addr(s_axi_awaddr);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_wr_sel <= 2'b00;
            wr_active      <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready && !wr_active) begin
                latched_wr_sel <= wr_sel;
                wr_active      <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                wr_active <= 1'b0;
            end
        end
    end

    wire [1:0] active_wr_sel = wr_active ? latched_wr_sel : wr_sel;

    // Internal DECERR Slave for Writes
    logic err_bvalid;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            err_bvalid <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && (wr_sel == 2'b11) && !err_bvalid) begin
                err_bvalid <= 1'b1;
            end else if (s_axi_bready && err_bvalid) begin
                err_bvalid <= 1'b0;
            end
        end
    end

    // Slave 0: RAM
    assign m0_axi_awaddr  = s_axi_awaddr;
    assign m0_axi_wdata   = s_axi_wdata;
    assign m0_axi_wstrb   = s_axi_wstrb;
    assign m0_axi_awvalid = (active_wr_sel == 2'b00) ? s_axi_awvalid : 1'b0;
    assign m0_axi_wvalid  = (active_wr_sel == 2'b00) ? s_axi_wvalid  : 1'b0;
    assign m0_axi_bready  = (active_wr_sel == 2'b00) ? s_axi_bready  : 1'b0;

    // Slave 1: Accelerator
    assign m1_axi_awaddr  = s_axi_awaddr;
    assign m1_axi_wdata   = s_axi_wdata;
    assign m1_axi_wstrb   = s_axi_wstrb;
    assign m1_axi_awvalid = (active_wr_sel == 2'b01) ? s_axi_awvalid : 1'b0;
    assign m1_axi_wvalid  = (active_wr_sel == 2'b01) ? s_axi_wvalid  : 1'b0;
    assign m1_axi_bready  = (active_wr_sel == 2'b01) ? s_axi_bready  : 1'b0;

    // Slave 2: UART
    assign m2_axi_awaddr  = s_axi_awaddr;
    assign m2_axi_wdata   = s_axi_wdata;
    assign m2_axi_wstrb   = s_axi_wstrb;
    assign m2_axi_awvalid = (active_wr_sel == 2'b10) ? s_axi_awvalid : 1'b0;
    assign m2_axi_wvalid  = (active_wr_sel == 2'b10) ? s_axi_wvalid  : 1'b0;
    assign m2_axi_bready  = (active_wr_sel == 2'b10) ? s_axi_bready  : 1'b0;

    // Write Master Handshake Multiplexer
    always_comb begin
        case (active_wr_sel)
            2'b00: begin
                s_axi_awready = m0_axi_awready;
                s_axi_wready  = m0_axi_wready;
                s_axi_bvalid  = m0_axi_bvalid;
                s_axi_bresp   = m0_axi_bresp;
            end
            2'b01: begin
                s_axi_awready = m1_axi_awready;
                s_axi_wready  = m1_axi_wready;
                s_axi_bvalid  = m1_axi_bvalid;
                s_axi_bresp   = m1_axi_bresp;
            end
            2'b10: begin
                s_axi_awready = m2_axi_awready;
                s_axi_wready  = m2_axi_wready;
                s_axi_bvalid  = m2_axi_bvalid;
                s_axi_bresp   = m2_axi_bresp;
            end
            default: begin // DECERR slave (2'b11)
                s_axi_awready = 1'b1;
                s_axi_wready  = 1'b1;
                s_axi_bvalid  = err_bvalid;
                s_axi_bresp   = 2'b11; // DECERR
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Read Routing
    // -------------------------------------------------------------------------
    logic [1:0] rd_sel;
    logic [1:0] latched_rd_sel;
    logic       rd_active;

    assign rd_sel = decode_addr(s_axi_araddr);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_rd_sel <= 2'b00;
            rd_active      <= 1'b0;
        end else begin
            if (s_axi_arvalid && s_axi_arready && !rd_active) begin
                latched_rd_sel <= rd_sel;
                rd_active      <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                rd_active <= 1'b0;
            end
        end
    end

    wire [1:0] active_rd_sel = rd_active ? latched_rd_sel : rd_sel;

    // Internal DECERR Slave for Reads
    logic err_rvalid;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            err_rvalid <= 1'b0;
        end else begin
            if (s_axi_arvalid && (rd_sel == 2'b11) && !err_rvalid) begin
                err_rvalid <= 1'b1;
            end else if (s_axi_rready && err_rvalid) begin
                err_rvalid <= 1'b0;
            end
        end
    end

    // Slave 0: RAM
    assign m0_axi_araddr  = s_axi_araddr;
    assign m0_axi_arvalid = (active_rd_sel == 2'b00) ? s_axi_arvalid : 1'b0;
    assign m0_axi_rready  = (active_rd_sel == 2'b00) ? s_axi_rready  : 1'b0;

    // Slave 1: Accelerator
    assign m1_axi_araddr  = s_axi_araddr;
    assign m1_axi_arvalid = (active_rd_sel == 2'b01) ? s_axi_arvalid : 1'b0;
    assign m1_axi_rready  = (active_rd_sel == 2'b01) ? s_axi_rready  : 1'b0;

    // Slave 2: UART
    assign m2_axi_araddr  = s_axi_araddr;
    assign m2_axi_arvalid = (active_rd_sel == 2'b10) ? s_axi_arvalid : 1'b0;
    assign m2_axi_rready  = (active_rd_sel == 2'b10) ? s_axi_rready  : 1'b0;

    // Read Master Handshake Multiplexer
    always_comb begin
        case (active_rd_sel)
            2'b00: begin
                s_axi_arready = m0_axi_arready;
                s_axi_rvalid  = m0_axi_rvalid;
                s_axi_rdata   = m0_axi_rdata;
                s_axi_rresp   = m0_axi_rresp;
            end
            2'b01: begin
                s_axi_arready = m1_axi_arready;
                s_axi_rvalid  = m1_axi_rvalid;
                s_axi_rdata   = m1_axi_rdata;
                s_axi_rresp   = m1_axi_rresp;
            end
            2'b10: begin
                s_axi_arready = m2_axi_arready;
                s_axi_rvalid  = m2_axi_rvalid;
                s_axi_rdata   = m2_axi_rdata;
                s_axi_rresp   = m2_axi_rresp;
            end
            default: begin // DECERR slave (2'b11)
                s_axi_arready = 1'b1;
                s_axi_rvalid  = err_rvalid;
                s_axi_rdata   = 32'hdead_dead;
                s_axi_rresp   = 2'b11; // DECERR
            end
        endcase
    end

endmodule
