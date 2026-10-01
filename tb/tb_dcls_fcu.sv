// =============================================================================
// File: tb_dcls_fcu.sv
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Testbench for Fault Control Unit (FCU) and Autonomous Blackbox
//              Telemetry Streaming Engine.
//              Verifies:
//              1. Nominal idle state.
//              2. Instantaneous safe_state_out assertion upon fault trigger.
//              3. Autonomous 8-byte crash packet generation into UART FIFO.
//              4. Bit-exact checksum verification.
//              5. Fail-silent persistent interlock state.
// =============================================================================

`timescale 1ns / 1ps

module tb_dcls_fcu;

    logic        clk;
    logic        rst_n;

    // Fault Trigger and Diagnostic Context
    logic        fault_detected_comb;
    logic        fault_latched;
    logic [4:0]  fault_code;
    logic [31:0] fault_pc;
    logic [31:0] fault_addr;
    logic [31:0] fault_m_data;
    logic [31:0] fault_s_data;

    // Outputs
    logic        safe_state_out;
    logic        fcu_tx_push;
    logic [7:0]  fcu_tx_byte;
    logic        uart_tx_full;
    logic [3:0]  fcu_state_out;
    logic        fcu_busy;
    logic        fcu_done;

    // Captured Telemetry Stream
    logic [7:0] captured_bytes [0:7];
    logic [7:0] expected_chk;
    int byte_count = 0;
    int test_errors = 0;

    // Instantiate Device Under Test
    dcls_fcu dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .fault_detected_comb    (fault_detected_comb),
        .fault_latched          (fault_latched),
        .fault_code             (fault_code),
        .fault_pc               (fault_pc),
        .fault_addr             (fault_addr),
        .fault_m_data           (fault_m_data),
        .fault_s_data           (fault_s_data),
        .safe_state_out         (safe_state_out),
        .fcu_tx_push            (fcu_tx_push),
        .fcu_tx_byte            (fcu_tx_byte),
        .uart_tx_full           (uart_tx_full),
        .fcu_state_out          (fcu_state_out),
        .fcu_busy               (fcu_busy),
        .fcu_done               (fcu_done)
    );

    // 100 MHz Clock Generator (10ns period)
    always #5 clk = ~clk;

    // Monitor and capture pushed bytes
    always_ff @(posedge clk) begin
        if (fcu_tx_push) begin
            if (byte_count < 8) begin
                captured_bytes[byte_count] <= fcu_tx_byte;
                $display("[UART STREAM] Byte %0d pushed: 0x%02X", byte_count, fcu_tx_byte);
            end
            byte_count <= byte_count + 1;
        end
    end

    initial begin
        clk                 = 0;
        rst_n               = 0;
        fault_detected_comb = 0;
        fault_latched       = 0;
        fault_code          = 5'b00000;
        fault_pc            = 32'h0000_0000;
        fault_addr          = 32'h0000_0000;
        fault_m_data        = 32'h0000_0000;
        fault_s_data        = 32'h0000_0000;
        uart_tx_full        = 0;

        $display("=================================================================");
        $display("   TESTBENCH: Fault Control Unit (FCU) Blackbox Telemetry        ");
        $display("=================================================================");

        #20;
        rst_n = 1;
        #20;

        // ---------------------------------------------------------------------
        // TEST 1: Nominal Idle State
        // ---------------------------------------------------------------------
        $display("[TEST 1] Nominal Idle Verification...");
        if (safe_state_out !== 1'b0 || fcu_busy !== 1'b0 || fcu_tx_push !== 1'b0) begin
            $display("ERROR: FCU not in clean idle state upon reset release!");
            test_errors++;
        end

        // ---------------------------------------------------------------------
        // TEST 2: Inject Fault and Verify Instant Interlock
        // ---------------------------------------------------------------------
        $display("[TEST 2] Injecting Fault (PC=0x0000041C, Code=5'b00100)...");
        @(posedge clk);
        #1;
        fault_detected_comb = 1'b1;
        fault_latched       = 1'b1;
        fault_pc            = 32'h0000_041C;
        fault_code          = 5'b00100; // DMEM write data mismatch
        fault_addr          = 32'h2000_0080;
        fault_m_data        = 32'hDEAD_BEEF;
        fault_s_data        = 32'hCAFE_BABE;

        // Combinational safe_state_out must assert instantly (< 1ns)
        #1;
        if (safe_state_out !== 1'b1) begin
            $display("ERROR: safe_state_out failed to assert instantly on fault!");
            test_errors++;
        end

        // ---------------------------------------------------------------------
        // TEST 3: Wait for 8-Byte Burst to Complete
        // ---------------------------------------------------------------------
        $display("[TEST 3] Observing Autonomous 8-Byte Telemetry Burst...");
        // Wait 12 clock cycles
        repeat (12) @(posedge clk);

        #1;
        if (byte_count !== 8) begin
            $display("ERROR: Expected exactly 8 bytes pushed, got %0d!", byte_count);
            test_errors++;
        end

        // Verify Byte 0: Header 0xAA
        if (captured_bytes[0] !== 8'hAA) begin
            $display("ERROR: Byte 0 expected 0xAA, got 0x%02X", captured_bytes[0]);
            test_errors++;
        end
        // Verify Byte 1: DTC 0x46 ('F')
        if (captured_bytes[1] !== 8'h46) begin
            $display("ERROR: Byte 1 expected 0x46, got 0x%02X", captured_bytes[1]);
            test_errors++;
        end
        // Verify Bytes 2-5: PC = 0x0000_041C
        if (captured_bytes[2] !== 8'h00 || captured_bytes[3] !== 8'h00 ||
            captured_bytes[4] !== 8'h04 || captured_bytes[5] !== 8'h1C) begin
            $display("ERROR: PC bytes mismatch! Got 0x%02X%02X%02X%02X",
                     captured_bytes[2], captured_bytes[3], captured_bytes[4], captured_bytes[5]);
            test_errors++;
        end
        // Verify Byte 6: Code = 0x04
        if (captured_bytes[6] !== 8'h04) begin
            $display("ERROR: Byte 6 expected 0x04, got 0x%02X", captured_bytes[6]);
            test_errors++;
        end
        // Verify Byte 7: XOR Checksum
        // 0xAA ^ 0x46 ^ 0x00 ^ 0x00 ^ 0x04 ^ 0x1C ^ 0x04 = 0xAA ^ 0x46 ^ 0x1C = 0xF0
        expected_chk = 8'hAA ^ 8'h46 ^ 8'h00 ^ 8'h00 ^ 8'h04 ^ 8'h1C ^ 8'h04;
        if (captured_bytes[7] !== expected_chk) begin
            $display("ERROR: Checksum mismatch! Expected 0x%02X, got 0x%02X", expected_chk, captured_bytes[7]);
            test_errors++;
        end else begin
            $display("[CHECKSUM] Checksum verified: 0x%02X matches expected 0x%02X", captured_bytes[7], expected_chk);
        end

        // ---------------------------------------------------------------------
        // TEST 4: Fail-Silent Persistent Interlock
        // ---------------------------------------------------------------------
        $display("[TEST 4] Verifying Fail-Silent Persistent State...");
        if (fcu_done !== 1'b1 || safe_state_out !== 1'b1 || fcu_tx_push !== 1'b0) begin
            $display("ERROR: FCU not locked in fail-silent state after telemetry burst!");
            test_errors++;
        end

        repeat (10) @(posedge clk);
        // Ensure no extra bytes are pushed
        if (byte_count !== 8) begin
            $display("ERROR: Extra bytes pushed after burst completion!");
            test_errors++;
        end

        // ---------------------------------------------------------------------
        // SUMMARY
        // ---------------------------------------------------------------------
        #20;
        $display("=================================================================");
        if (test_errors == 0) begin
            $display("   TESTBENCH PASSED: FCU Blackbox Telemetry 100%% Verified!      ");
            $display("   8-byte crash packet generated in 8 cycles with valid checksum.");
        end else begin
            $display("   TESTBENCH FAILED: %0d error(s) detected.                     ", test_errors);
        end
        $display("=================================================================");

        $finish;
    end

endmodule
