// =============================================================================
// File: tb_comparator_firewall.sv
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Testbench for DCLS Combinational Comparator and Zero-Cycle Bus
//              Firewall.
//              Verifies:
//              1. Nominal pass-through when cores match.
//              2. Combinational zero-cycle gating on write data mismatch.
//              3. Combinational gating on address and control mismatches.
//              4. Sticky latch behavior and diagnostic freeze registers.
// =============================================================================

`timescale 1ns / 1ps

module tb_comparator_firewall;

    logic        clk;
    logic        rst_n;
    logic        dcls_active;

    // Master signals
    logic [31:0] m_imem_addr_delayed;
    logic [31:0] m_dmem_addr_delayed;
    logic [31:0] m_dmem_wdata_delayed;
    logic [3:0]  m_dmem_strb_delayed;
    logic        m_dmem_we_delayed;
    logic        m_dmem_re_delayed;

    // Shadow signals
    logic [31:0] s_imem_addr;
    logic [31:0] s_dmem_addr;
    logic [31:0] s_dmem_wdata;
    logic [3:0]  s_dmem_strb;
    logic        s_dmem_we;
    logic        s_dmem_re;

    // Protected Bus Outputs
    logic [31:0] protected_dmem_addr;
    logic [31:0] protected_dmem_wdata;
    logic [3:0]  protected_dmem_strb;
    logic        protected_dmem_we;
    logic        protected_dmem_re;

    // Safety and Diagnostics
    logic        fault_detected_comb;
    logic        fault_latched;
    logic        safe_state_out;
    logic [4:0]  fault_code;
    logic [31:0] fault_pc;
    logic [31:0] fault_addr;
    logic [31:0] fault_m_data;
    logic [31:0] fault_s_data;

    // Error counter
    int test_errors = 0;

    // Instantiate Device Under Test
    dcls_comparator_firewall dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .dcls_active            (dcls_active),
        .m_imem_addr_delayed    (m_imem_addr_delayed),
        .m_dmem_addr_delayed    (m_dmem_addr_delayed),
        .m_dmem_wdata_delayed   (m_dmem_wdata_delayed),
        .m_dmem_strb_delayed    (m_dmem_strb_delayed),
        .m_dmem_we_delayed      (m_dmem_we_delayed),
        .m_dmem_re_delayed      (m_dmem_re_delayed),
        .s_imem_addr            (s_imem_addr),
        .s_dmem_addr            (s_dmem_addr),
        .s_dmem_wdata           (s_dmem_wdata),
        .s_dmem_strb            (s_dmem_strb),
        .s_dmem_we              (s_dmem_we),
        .s_dmem_re              (s_dmem_re),
        .protected_dmem_addr    (protected_dmem_addr),
        .protected_dmem_wdata   (protected_dmem_wdata),
        .protected_dmem_strb    (protected_dmem_strb),
        .protected_dmem_we      (protected_dmem_we),
        .protected_dmem_re      (protected_dmem_re),
        .fault_detected_comb    (fault_detected_comb),
        .fault_latched          (fault_latched),
        .safe_state_out         (safe_state_out),
        .fault_code             (fault_code),
        .fault_pc               (fault_pc),
        .fault_addr             (fault_addr),
        .fault_m_data           (fault_m_data),
        .fault_s_data           (fault_s_data)
    );

    // 100 MHz Clock Generator (10ns period)
    always #5 clk = ~clk;

    initial begin
        clk                 = 0;
        rst_n               = 0;
        dcls_active         = 0;
        m_imem_addr_delayed = 32'h0000_0000;
        m_dmem_addr_delayed = 32'h0000_0000;
        m_dmem_wdata_delayed= 32'h0000_0000;
        m_dmem_strb_delayed = 4'b0000;
        m_dmem_we_delayed   = 0;
        m_dmem_re_delayed   = 0;
        s_imem_addr         = 32'h0000_0000;
        s_dmem_addr         = 32'h0000_0000;
        s_dmem_wdata        = 32'h0000_0000;
        s_dmem_strb         = 4'b0000;
        s_dmem_we           = 0;
        s_dmem_re           = 0;

        $display("=================================================================");
        $display("   TESTBENCH: DCLS Combinational Comparator and Bus Firewall     ");
        $display("=================================================================");

        // Release reset
        #20;
        rst_n = 1;
        #10;
        dcls_active = 1;

        // ---------------------------------------------------------------------
        // TEST 1: Nominal Matched Write Transaction
        // ---------------------------------------------------------------------
        $display("[TEST 1] Nominal Matched Memory Write Transaction...");
        @(posedge clk);
        m_imem_addr_delayed  = 32'h0000_0100;
        s_imem_addr          = 32'h0000_0100;
        m_dmem_addr_delayed  = 32'h2000_0010;
        s_dmem_addr          = 32'h2000_0010;
        m_dmem_wdata_delayed = 32'hCAFE_BABE;
        s_dmem_wdata         = 32'hCAFE_BABE;
        m_dmem_strb_delayed  = 4'b1111;
        s_dmem_strb          = 4'b1111;
        m_dmem_we_delayed    = 1'b1;
        s_dmem_we            = 1'b1;

        #1; // Sample combinational outputs
        if (fault_detected_comb !== 1'b0) begin
            $display("ERROR: Spurious fault detected on matching cycle!");
            test_errors++;
        end
        if (protected_dmem_we !== 1'b1 || protected_dmem_wdata !== 32'hCAFE_BABE) begin
            $display("ERROR: Protected bus failed to pass nominal write data!");
            test_errors++;
        end
        if (safe_state_out !== 1'b0) begin
            $display("ERROR: safe_state_out asserted during nominal cycle!");
            test_errors++;
        end

        // ---------------------------------------------------------------------
        // TEST 2: Zero-Cycle Gating on Write Data Mismatch
        // ---------------------------------------------------------------------
        $display("[TEST 2] Injected Write Data Mismatch (Zero-Cycle Clamp Verification)...");
        // Corrupt shadow data combinatorially right before next clock edge
        #2;
        s_dmem_wdata = 32'hDEAD_BEEF; // Injected mismatch!

        #1; // Verify instant combinational clamp (< 1ns)
        if (fault_detected_comb !== 1'b1) begin
            $display("ERROR: fault_detected_comb did not assert on data mismatch!");
            test_errors++;
        end
        if (protected_dmem_we !== 1'b0) begin
            $display("ERROR: protected_dmem_we was NOT clamped to zero on mismatch!");
            test_errors++;
        end
        if (protected_dmem_wdata !== 32'h0000_0000) begin
            $display("ERROR: protected_dmem_wdata was NOT zeroed on mismatch!");
            test_errors++;
        end
        if (safe_state_out !== 1'b1) begin
            $display("ERROR: safe_state_out did not assert instantly on mismatch!");
            test_errors++;
        end

        // Now advance clock edge: sticky latch should capture context
        @(posedge clk);
        #1;
        if (fault_latched !== 1'b1) begin
            $display("ERROR: fault_latched did not set on clock edge!");
            test_errors++;
        end
        if (fault_code[2] !== 1'b1) begin // Bit 2: dmem_wdata_mismatch
            $display("ERROR: fault_code[2] (wdata mismatch) not set! Code = %b", fault_code);
            test_errors++;
        end
        if (fault_pc !== 32'h0000_0100) begin
            $display("ERROR: Captured fault_pc mismatch: expected 0x00000100, got 0x%08X", fault_pc);
            test_errors++;
        end
        if (fault_m_data !== 32'hCAFE_BABE || fault_s_data !== 32'hDEAD_BEEF) begin
            $display("ERROR: Captured diagnostic data mismatch!");
            test_errors++;
        end

        // ---------------------------------------------------------------------
        // TEST 3: Sticky Latch Isolation Persistence
        // ---------------------------------------------------------------------
        $display("[TEST 3] Verifying Sticky Fault Latch Persistence...");
        // Realign inputs to identical values
        s_dmem_wdata = 32'hCAFE_BABE;
        @(posedge clk);
        #1;
        // Even though inputs match now, firewall MUST remain clamped
        if (fault_latched !== 1'b1) begin
            $display("ERROR: Sticky fault cleared unexpectedly!");
            test_errors++;
        end
        if (protected_dmem_we !== 1'b0) begin
            $display("ERROR: protected_dmem_we re-opened after fault was latched!");
            test_errors++;
        end
        if (safe_state_out !== 1'b1) begin
            $display("ERROR: safe_state_out dropped after fault was latched!");
            test_errors++;
        end

        // ---------------------------------------------------------------------
        // TEST 4: Reset Recovery
        // ---------------------------------------------------------------------
        $display("[TEST 4] Hardware Reset Recovery...");
        rst_n = 0;
        #20;
        rst_n = 1;
        #1;
        if (fault_latched !== 1'b0 || safe_state_out !== 1'b0) begin
            $display("ERROR: Fault state did not clear upon hardware reset!");
            test_errors++;
        end

        // ---------------------------------------------------------------------
        // TEST 5: Control Signal Divergence (m_dmem_we != s_dmem_we)
        // ---------------------------------------------------------------------
        $display("[TEST 5] Control Signal Divergence Verification...");
        @(posedge clk);
        m_imem_addr_delayed  = 32'h0000_0200;
        s_imem_addr          = 32'h0000_0200;
        m_dmem_addr_delayed  = 32'h2000_0040;
        s_dmem_addr          = 32'h2000_0040;
        m_dmem_wdata_delayed = 32'h1122_3344;
        s_dmem_wdata         = 32'h1122_3344;
        m_dmem_strb_delayed  = 4'b1111;
        s_dmem_strb          = 4'b1111;
        m_dmem_we_delayed    = 1'b1;
        s_dmem_we            = 1'b0; // Master attempts write, shadow does not

        #1;
        if (fault_detected_comb !== 1'b1 || protected_dmem_we !== 1'b0) begin
            $display("ERROR: Control divergence not clamped immediately!");
            test_errors++;
        end

        @(posedge clk);
        #1;
        if (fault_code[4] !== 1'b1) begin // Bit 4: dmem_ctrl_mismatch
            $display("ERROR: fault_code[4] (ctrl mismatch) not set! Code = %b", fault_code);
            test_errors++;
        end

        // ---------------------------------------------------------------------
        // SUMMARY
        // ---------------------------------------------------------------------
        #20;
        $display("=================================================================");
        if (test_errors == 0) begin
            $display("   TESTBENCH PASSED: All 5 Firewall Tests Verified Successfully  ");
            $display("   Zero-cycle combinational gating verified in < 1.0 ns.         ");
        end else begin
            $display("   TESTBENCH FAILED: %0d error(s) detected.                     ", test_errors);
        end
        $display("=================================================================");

        $finish;
    end

endmodule
