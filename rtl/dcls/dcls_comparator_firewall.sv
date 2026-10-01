// =============================================================================
// File: dcls_comparator_firewall.sv
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Dual-Core Lockstep (DCLS) Combinational Comparator and Zero-Cycle
//              Bus Firewall.
//              Compares delayed Master Core bus signals against real-time Shadow
//              Core bus signals bit-for-bit.
//              Upon any divergence, combinationally clamps all memory write and
//              read enables to zero in under 1.0 ns (zero-cycle gate latency),
//              latches a sticky fault state, asserts safe_state_out, and captures
//              diagnostic fault context for the Fault Control Unit (FCU).
// =============================================================================

`timescale 1ns / 1ps

module dcls_comparator_firewall (
    input  logic        clk,
    input  logic        rst_n,

    // Lockstep Operational Status
    input  logic        dcls_active,

    // Master Core Outputs (Delayed by Delta t = 2 clock cycles)
    input  logic [31:0] m_imem_addr_delayed,
    input  logic [31:0] m_dmem_addr_delayed,
    input  logic [31:0] m_dmem_wdata_delayed,
    input  logic [3:0]  m_dmem_strb_delayed,
    input  logic        m_dmem_we_delayed,
    input  logic        m_dmem_re_delayed,

    // Shadow Core Outputs (Executing at time t - 2)
    input  logic [31:0] s_imem_addr,
    input  logic [31:0] s_dmem_addr,
    input  logic [31:0] s_dmem_wdata,
    input  logic [3:0]  s_dmem_strb,
    input  logic        s_dmem_we,
    input  logic        s_dmem_re,

    // Protected Bus Outputs to System Interconnect (Firewall Gated)
    output logic [31:0] protected_dmem_addr,
    output logic [31:0] protected_dmem_wdata,
    output logic [3:0]  protected_dmem_strb,
    output logic        protected_dmem_we,
    output logic        protected_dmem_re,

    // Safety and Diagnostic Interface
    output logic        fault_detected_comb,
    output logic        fault_latched,
    output logic        safe_state_out,
    output logic [4:0]  fault_code,
    output logic [31:0] fault_pc,
    output logic [31:0] fault_addr,
    output logic [31:0] fault_m_data,
    output logic [31:0] fault_s_data
);

    // =========================================================================
    // 1. BIT-FOR-BIT PARALLEL COMPARISON TREES
    // =========================================================================
    logic imem_mismatch;
    logic dmem_addr_mismatch;
    logic dmem_wdata_mismatch;
    logic dmem_strb_mismatch;
    logic dmem_ctrl_mismatch;

    // Evaluate comparisons only when lockstep is active
    assign imem_mismatch = dcls_active && (m_imem_addr_delayed != s_imem_addr);

    // DMEM address evaluated when either core initiates a load or store
    assign dmem_addr_mismatch = dcls_active && 
        ((m_dmem_we_delayed | m_dmem_re_delayed | s_dmem_we | s_dmem_re) && 
         (m_dmem_addr_delayed != s_dmem_addr));

    // DMEM write data and strobe evaluated when either core asserts write enable
    assign dmem_wdata_mismatch = dcls_active && 
        ((m_dmem_we_delayed | s_dmem_we) && 
         (m_dmem_wdata_delayed != s_dmem_wdata));

    assign dmem_strb_mismatch = dcls_active && 
        ((m_dmem_we_delayed | s_dmem_we) && 
         (m_dmem_strb_delayed != s_dmem_strb));

    // Control mismatch evaluated continuously (write enable and read enable)
    assign dmem_ctrl_mismatch = dcls_active && 
        ((m_dmem_we_delayed != s_dmem_we) || 
         (m_dmem_re_delayed != s_dmem_re));

    // Instantaneous combinational fault indicator
    assign fault_detected_comb = imem_mismatch       | 
                                 dmem_addr_mismatch  | 
                                 dmem_wdata_mismatch | 
                                 dmem_strb_mismatch  | 
                                 dmem_ctrl_mismatch;

    // Combined instantaneous and sticky fault isolation term
    wire fault_isolate = fault_detected_comb | fault_latched;

    // =========================================================================
    // 2. ZERO-CYCLE BUS FIREWALL ISOLATION GATES
    // =========================================================================
    // Pure combinational gating ensures that write operations are suppressed
    // in under 1.0 ns of propagation delay before the clock edge arrives.
    assign protected_dmem_we    = m_dmem_we_delayed & ~fault_isolate;
    assign protected_dmem_re    = m_dmem_re_delayed & ~fault_isolate;
    assign protected_dmem_addr  = fault_isolate ? 32'h0000_0000 : m_dmem_addr_delayed;
    assign protected_dmem_wdata = fault_isolate ? 32'h0000_0000 : m_dmem_wdata_delayed;
    assign protected_dmem_strb  = fault_isolate ? 4'b0000       : m_dmem_strb_delayed;

    // External hardware safety interlock pin
    assign safe_state_out = fault_isolate;

    // =========================================================================
    // 3. STICKY FAULT LATCH & DIAGNOSTIC CONTEXT CAPTURE REGISTERS
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fault_latched <= 1'b0;
            fault_code    <= 5'b00000;
            fault_pc      <= 32'h0000_0000;
            fault_addr    <= 32'h0000_0000;
            fault_m_data  <= 32'h0000_0000;
            fault_s_data  <= 32'h0000_0000;
        end else begin
            if (fault_detected_comb && !fault_latched) begin
                // Latch sticky fault state on first occurrence
                fault_latched <= 1'b1;

                $display("[%0t ns] DCLS FIREWALL TRIPPED: imem_err=%b, dmem_addr_err=%b, dmem_wdata_err=%b, dmem_ctrl_err=%b",
                         $time, imem_mismatch, dmem_addr_mismatch, dmem_wdata_mismatch, dmem_ctrl_mismatch);
                $display("   Master delayed PC: 0x%08h, Shadow PC: 0x%08h", m_imem_addr_delayed, s_imem_addr);
                $display("   Master delayed DMEM addr: 0x%08h, Shadow DMEM addr: 0x%08h", m_dmem_addr_delayed, s_dmem_addr);
                $display("   Master delayed WE: %b, Shadow WE: %b, Master delayed RE: %b, Shadow RE: %b",
                         m_dmem_we_delayed, s_dmem_we, m_dmem_re_delayed, s_dmem_re);

                // Freeze fault classification code
                fault_code <= {
                    dmem_ctrl_mismatch,
                    dmem_strb_mismatch,
                    dmem_wdata_mismatch,
                    dmem_addr_mismatch,
                    imem_mismatch
                };

                // Freeze fault diagnostic context
                fault_pc     <= m_imem_addr_delayed;
                fault_addr   <= m_dmem_addr_delayed;
                fault_m_data <= m_dmem_wdata_delayed;
                fault_s_data <= s_dmem_wdata;
            end
        end
    end

endmodule
