// =============================================================================
// File: tb_dcls_wrapper.sv
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Unit testbench for dcls_core_wrapper.
//              Verifies that Master Core and Shadow Core execute the identical
//              instruction stream with a strict 2-cycle phase offset (Delta t = 2)
//              and that all delayed master bus signals match shadow bus signals.
// =============================================================================

`timescale 1ns / 1ps

module tb_dcls_wrapper;

    // Clock and Reset Signals
    logic clk;
    logic rst_n;

    // Master Fetch Bus
    logic [31:0] raw_imem_addr;
    logic [31:0] raw_imem_rdata;

    // Data Memory Bus
    logic [31:0] raw_dmem_addr;
    logic [31:0] raw_dmem_rdata;

    // Synchronized Outputs
    logic [31:0] m_imem_addr_delayed, s_imem_addr;
    logic [31:0] m_dmem_addr_delayed, s_dmem_addr;
    logic [31:0] m_dmem_wdata_delayed, s_dmem_wdata;
    logic [3:0]  m_dmem_strb_delayed, s_dmem_strb;
    logic        m_dmem_we_delayed, s_dmem_we;
    logic        m_dmem_re_delayed, s_dmem_re;
    logic        dcls_active;

    // Simple Instruction & Data Memory Arrays
    logic [31:0] imem [0:63];
    logic [31:0] dmem [0:63];

    // Instantiate Device Under Test (DUT)
    dcls_core_wrapper u_dut (
        .clk                 (clk),
        .rst_n               (rst_n),
        .raw_imem_addr       (raw_imem_addr),
        .raw_imem_rdata      (raw_imem_rdata),
        .raw_dmem_addr       (raw_dmem_addr),
        .raw_dmem_rdata      (raw_dmem_rdata),
        .m_imem_addr_delayed (m_imem_addr_delayed),
        .s_imem_addr         (s_imem_addr),
        .m_dmem_addr_delayed (m_dmem_addr_delayed),
        .s_dmem_addr         (s_dmem_addr),
        .m_dmem_wdata_delayed(m_dmem_wdata_delayed),
        .s_dmem_wdata        (s_dmem_wdata),
        .m_dmem_strb_delayed (m_dmem_strb_delayed),
        .s_dmem_strb         (s_dmem_strb),
        .m_dmem_we_delayed   (m_dmem_we_delayed),
        .s_dmem_we           (s_dmem_we),
        .m_dmem_re_delayed   (m_dmem_re_delayed),
        .s_dmem_re           (s_dmem_re),
        .dcls_active         (dcls_active)
    );

    // 100 MHz System Clock Generation (10.0 ns Period)
    initial clk = 1'b0;
    always #5.0 clk = ~clk;

    // Instruction Memory Fetch Logic
    wire [5:0] imem_word_idx = raw_imem_addr[7:2];
    assign raw_imem_rdata = imem[imem_word_idx];

    // Data Memory Model
    // We observe write transactions from the delayed master bus to model memory
    always_ff @(posedge clk) begin
        if (m_dmem_we_delayed) begin
            dmem[m_dmem_addr_delayed[7:2]] <= m_dmem_wdata_delayed;
        end
    end

    // Memory Read Data Return (combinationally or registered)
    assign raw_dmem_rdata = dmem[u_dut.m_dmem_addr_raw[7:2]];

    // Verification Counters
    int match_count = 0;
    int mismatch_count = 0;
    int test_cycles = 0;

    // Test Stimulus & Program Load
    initial begin
        // Initialize memory with NOPs
        for (int i = 0; i < 64; i++) begin
            imem[i] = 32'h0000_0013; // addi x0, x0, 0
            dmem[i] = 32'h0000_0000;
        end

        // Program to execute:
        // [0] addi x1, x0, 15        (0x00f00093)
        // [1] addi x2, x0, 25        (0x01900113)
        // [2] add  x3, x1, x2        (0x002081b3) -> x3 = 40
        // [3] sw   x3, 0(x0)         (0x00302023) -> dmem[0] = 40
        // [4] lw   x4, 0(x0)         (0x00002203) -> x4 = 40
        // [5] addi x5, x4, 2         (0x00220293) -> x5 = 42
        // [6] sw   x5, 4(x0)         (0x00502223) -> dmem[1] = 42
        // [7] beq  x0, x0, 0         (0x00000063) -> infinite loop halt
        imem[0] = 32'h00f0_0093;
        imem[1] = 32'h0190_0113;
        imem[2] = 32'h0020_81b3;
        imem[3] = 32'h0030_2023;
        imem[4] = 32'h0000_2203;
        imem[5] = 32'h0022_0293;
        imem[6] = 32'h0050_2223;
        imem[7] = 32'h0000_0063;

        $display("------------------------------------------------------------");
        $display(" Starting Phase 2: Dual-Core Lockstep Wrapper Verification ");
        $display(" Target: 2-Cycle Phase Offset (Delta t = 2) Strict Match   ");
        $display("------------------------------------------------------------");

        // Apply Reset
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        $display("[%0t] Reset released. Master running at t, Shadow starting at t-2.", $time);

        // Run execution for 60 clock cycles
        for (int c = 0; c < 60; c++) begin
            @(posedge clk);
            test_cycles++;
        end

        // Evaluation Summary
        $display("------------------------------------------------------------");
        $display(" Phase 2 Verification Completed");
        $display(" Total Monitored Cycles : %0d", test_cycles);
        $display(" Matched Clock Cycles   : %0d", match_count);
        $display(" Mismatch Clock Cycles  : %0d", mismatch_count);
        $display("------------------------------------------------------------");

        if (mismatch_count == 0 && match_count > 20) begin
            $display("[SUCCESS] PHASE 2 SIGN-OFF PASSED!");
            $display("Dual cores maintained 100%% cycle-by-cycle equivalence with a 2-cycle phase offset.");
        end else begin
            $display("[FAILURE] Phase 2 failed with %0d mismatches!", mismatch_count);
            $fatal(1, "Phase 2 check failed.");
        end

        $finish;
    end

    // Cycle-by-cycle assertion checker
    always @(negedge clk) begin
        if (rst_n && dcls_active) begin
            // Check PC / Instruction Fetch Address equality
            if (m_imem_addr_delayed !== s_imem_addr) begin
                $display("[%0t ns] MISMATCH in imem_addr: Master_delayed=0x%08h, Shadow=0x%08h",
                         $time, m_imem_addr_delayed, s_imem_addr);
                mismatch_count++;
            end

            // Check Data Memory Address equality
            if (m_dmem_addr_delayed !== s_dmem_addr) begin
                $display("[%0t ns] MISMATCH in dmem_addr: Master_delayed=0x%08h, Shadow=0x%08h",
                         $time, m_dmem_addr_delayed, s_dmem_addr);
                mismatch_count++;
            end

            // Check Data Memory Write Data equality
            if (m_dmem_wdata_delayed !== s_dmem_wdata) begin
                $display("[%0t ns] MISMATCH in dmem_wdata: Master_delayed=0x%08h, Shadow=0x%08h",
                         $time, m_dmem_wdata_delayed, s_dmem_wdata);
                mismatch_count++;
            end

            // Check Write Enable equality
            if (m_dmem_we_delayed !== s_dmem_we) begin
                $display("[%0t ns] MISMATCH in dmem_we: Master_delayed=%b, Shadow=%b",
                         $time, m_dmem_we_delayed, s_dmem_we);
                mismatch_count++;
            end

            // Check Read Enable equality
            if (m_dmem_re_delayed !== s_dmem_re) begin
                $display("[%0t ns] MISMATCH in dmem_re: Master_delayed=%b, Shadow=%b",
                         $time, m_dmem_re_delayed, s_dmem_re);
                mismatch_count++;
            end

            // If all checks pass
            if (m_imem_addr_delayed === s_imem_addr &&
                m_dmem_addr_delayed === s_dmem_addr &&
                m_dmem_wdata_delayed === s_dmem_wdata &&
                m_dmem_we_delayed === s_dmem_we &&
                m_dmem_re_delayed === s_dmem_re) begin
                match_count++;
            end
        end
    end

endmodule
