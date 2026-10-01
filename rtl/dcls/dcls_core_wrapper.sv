// =============================================================================
// File: dcls_core_wrapper.sv
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Dual-Core Lockstep (DCLS) wrapper with 2-cycle temporal diversity.
//              Instantiates Primary (Master) Core and Redundant (Shadow) Core.
//              Implements a 2-stage D-FF delay pipeline for inputs to the shadow
//              core, and a 2-stage D-FF delay pipeline for master bus outputs.
//              This guarantees cycle-by-cycle equivalence at time (t - 2) while
//              eliminating Common Cause Failures (CCF) from physical transients.
// =============================================================================

`timescale 1ns / 1ps

module dcls_core_wrapper (
    input  logic        clk,
    input  logic        rst_n,

    // Real-Time Master Instruction Fetch Bus (to external Memory/ROM)
    output logic [31:0] raw_imem_addr,
    input  logic [31:0] raw_imem_rdata,

    // Real-Time Master Data Memory Bus (to external Interconnect / Bridge)
    output logic [31:0] raw_dmem_addr,
    input  logic [31:0] raw_dmem_rdata,

    // Synchronized Bus Outputs (Delayed Master vs Real-Time Shadow)
    // These drive the DCLS Combinational Comparator at time (t - 2)
    output logic [31:0] m_imem_addr_delayed,
    output logic [31:0] s_imem_addr,

    output logic [31:0] m_dmem_addr_delayed,
    output logic [31:0] s_dmem_addr,

    output logic [31:0] m_dmem_wdata_delayed,
    output logic [31:0] s_dmem_wdata,

    output logic [3:0]  m_dmem_strb_delayed,
    output logic [3:0]  s_dmem_strb,

    output logic        m_dmem_we_delayed,
    output logic        s_dmem_we,

    output logic        m_dmem_re_delayed,
    output logic        s_dmem_re,

    // Status Signals
    output logic        dcls_active
);

    // =========================================================================
    // 1. TEMPORAL DIVERSITY RESET & CONTROL LOGIC
    // =========================================================================
    // Shadow Core reset is released exactly 2 clock cycles after Master Core.
    // 50ns: Master released (d1<=1, d2<=0, d3<=0)
    // 60ns: Cycle 1 (d2<=1, d3<=0)
    // 70ns: Cycle 2 - Shadow released (d3<=1) -> Delta t = 2 clock cycles
    logic rst_n_d1, rst_n_d2, rst_n_d3, rst_n_d4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_n_d1 <= 1'b0;
            rst_n_d2 <= 1'b0;
            rst_n_d3 <= 1'b0;
            rst_n_d4 <= 1'b0;
        end else begin
            rst_n_d1 <= 1'b1;
            rst_n_d2 <= rst_n_d1;
            rst_n_d3 <= rst_n_d2;
            rst_n_d4 <= rst_n_d3;
        end
    end

    wire master_rst_n = rst_n;
    wire shadow_rst_n = rst_n_d3;

    // Lockstep is active once shadow core executes its first instruction in lockstep
    assign dcls_active = rst_n_d4;

    // =========================================================================
    // 2. INPUT DELAY PIPELINE (To Shadow Core)
    // =========================================================================
    // Inputs entering the shadow core are delayed by Delta t = 2 cycles.
    // Shift registers initialize to NOP (0x0000_0013: addi x0, x0, 0) for imem.
    logic [31:0] s_imem_rdata_d1, s_imem_rdata_d2;
    logic [31:0] s_dmem_rdata_d1, s_dmem_rdata_d2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_imem_rdata_d1 <= 32'h0000_0013; // RISC-V NOP
            s_imem_rdata_d2 <= 32'h0000_0013;
            s_dmem_rdata_d1 <= 32'h0000_0000;
            s_dmem_rdata_d2 <= 32'h0000_0000;
        end else begin
            s_imem_rdata_d1 <= raw_imem_rdata;
            s_imem_rdata_d2 <= s_imem_rdata_d1;
            s_dmem_rdata_d1 <= raw_dmem_rdata;
            s_dmem_rdata_d2 <= s_dmem_rdata_d1;
        end
    end

    // =========================================================================
    // 3. PRIMARY (MASTER) CORE INSTANTIATION (Channel 0: Real-Time t)
    // =========================================================================
    logic [31:0] m_imem_addr_raw;
    logic [31:0] m_dmem_addr_raw;
    logic [31:0] m_dmem_wdata_raw;
    logic [3:0]  m_dmem_strb_raw;
    logic        m_dmem_we_raw;
    logic        m_dmem_re_raw;

    rv32i_core_top u_core_master (
        .clk        (clk),
        .rst_n      (master_rst_n),
        .imem_addr  (m_imem_addr_raw),
        .imem_rdata (raw_imem_rdata),
        .dmem_addr  (m_dmem_addr_raw),
        .dmem_wdata (m_dmem_wdata_raw),
        .dmem_strb  (m_dmem_strb_raw),
        .dmem_we    (m_dmem_we_raw),
        .dmem_re    (m_dmem_re_raw),
        .dmem_rdata (raw_dmem_rdata)
    );

    // Master core directly drives external instruction and data memory fetch
    assign raw_imem_addr = m_imem_addr_raw;
    assign raw_dmem_addr = m_dmem_addr_raw;

    // =========================================================================
    // 4. REDUNDANT (SHADOW) CORE INSTANTIATION (Channel 1: Delayed t - 2)
    // =========================================================================
    logic [31:0] s_imem_addr_raw;
    logic [31:0] s_dmem_addr_raw;
    logic [31:0] s_dmem_wdata_raw;
    logic [3:0]  s_dmem_strb_raw;
    logic        s_dmem_we_raw;
    logic        s_dmem_re_raw;

    rv32i_core_top u_core_shadow (
        .clk        (clk),
        .rst_n      (shadow_rst_n),
        .imem_addr  (s_imem_addr_raw),
        .imem_rdata (s_imem_rdata_d2),
        .dmem_addr  (s_dmem_addr_raw),
        .dmem_wdata (s_dmem_wdata_raw),
        .dmem_strb  (s_dmem_strb_raw),
        .dmem_we    (s_dmem_we_raw),
        .dmem_re    (s_dmem_re_raw),
        .dmem_rdata (s_dmem_rdata_d2)
    );

    assign s_imem_addr  = s_imem_addr_raw;
    assign s_dmem_addr  = s_dmem_addr_raw;
    assign s_dmem_wdata = s_dmem_wdata_raw;
    assign s_dmem_strb  = s_dmem_strb_raw;
    assign s_dmem_we    = s_dmem_we_raw;
    assign s_dmem_re    = s_dmem_re_raw;

    // =========================================================================
    // 5. MASTER OUTPUT DELAY PIPELINE (Aligned to t - 2)
    // =========================================================================
    // Delays Master Core bus outputs by Delta t = 2 clock cycles so they arrive
    // at the comparator at the exact same cycle that Shadow Core produces them.
    logic [31:0] m_imem_addr_pipe1,  m_imem_addr_pipe2;
    logic [31:0] m_dmem_addr_pipe1,  m_dmem_addr_pipe2;
    logic [31:0] m_dmem_wdata_pipe1, m_dmem_wdata_pipe2;
    logic [3:0]  m_dmem_strb_pipe1,  m_dmem_strb_pipe2;
    logic        m_dmem_we_pipe1,    m_dmem_we_pipe2;
    logic        m_dmem_re_pipe1,    m_dmem_re_pipe2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_imem_addr_pipe1  <= 32'h0;
            m_imem_addr_pipe2  <= 32'h0;
            m_dmem_addr_pipe1  <= 32'h0;
            m_dmem_addr_pipe2  <= 32'h0;
            m_dmem_wdata_pipe1 <= 32'h0;
            m_dmem_wdata_pipe2 <= 32'h0;
            m_dmem_strb_pipe1  <= 4'h0;
            m_dmem_strb_pipe2  <= 4'h0;
            m_dmem_we_pipe1    <= 1'b0;
            m_dmem_we_pipe2    <= 1'b0;
            m_dmem_re_pipe1    <= 1'b0;
            m_dmem_re_pipe2    <= 1'b0;
        end else begin
            // Stage 1 (t - 1)
            m_imem_addr_pipe1  <= m_imem_addr_raw;
            m_dmem_addr_pipe1  <= m_dmem_addr_raw;
            m_dmem_wdata_pipe1 <= m_dmem_wdata_raw;
            m_dmem_strb_pipe1  <= m_dmem_strb_raw;
            m_dmem_we_pipe1    <= m_dmem_we_raw;
            m_dmem_re_pipe1    <= m_dmem_re_raw;

            // Stage 2 (t - 2)
            m_imem_addr_pipe2  <= m_imem_addr_pipe1;
            m_dmem_addr_pipe2  <= m_dmem_addr_pipe1;
            m_dmem_wdata_pipe2 <= m_dmem_wdata_pipe1;
            m_dmem_strb_pipe2  <= m_dmem_strb_pipe1;
            m_dmem_we_pipe2    <= m_dmem_we_pipe1;
            m_dmem_re_pipe2    <= m_dmem_re_pipe1;
        end
    end

    assign m_imem_addr_delayed  = m_imem_addr_pipe2;
    assign m_dmem_addr_delayed  = m_dmem_addr_pipe2;
    assign m_dmem_wdata_delayed = m_dmem_wdata_pipe2;
    assign m_dmem_strb_delayed  = m_dmem_strb_pipe2;
    assign m_dmem_we_delayed    = m_dmem_we_pipe2;
    assign m_dmem_re_delayed    = m_dmem_re_pipe2;

endmodule
