// =============================================================================
// File: dcls_fcu.sv
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Fault Control Unit (FCU) and Autonomous Blackbox Telemetry Engine.
//              Operates independently of CPU software. Senses hardware fault
//              triggers from the DCLS comparator, locks the system into a
//              fail-silent safe state, asserts the external safe_state_out pin,
//              and autonomously bursts an 8-byte diagnostic telemetry frame
//              directly into the UART TX FIFO buffer in 8 clock cycles.
// =============================================================================

`timescale 1ns / 1ps

module dcls_fcu (
    input  logic        clk,
    input  logic        rst_n,

    // Fault Trigger and Diagnostic Context from DCLS Comparator
    input  logic        fault_detected_comb,
    input  logic        fault_latched,
    input  logic [4:0]  fault_code,
    input  logic [31:0] fault_pc,
    input  logic [31:0] fault_addr,
    input  logic [31:0] fault_m_data,
    input  logic [31:0] fault_s_data,

    // External Hardware Safety Interlock
    output logic        safe_state_out,

    // Autonomous UART FIFO Streaming Interface
    output logic        fcu_tx_push,
    output logic [7:0]  fcu_tx_byte,
    input  logic        uart_tx_full,

    // FCU Status
    output logic [3:0]  fcu_state_out,
    output logic        fcu_busy,
    output logic        fcu_done
);

    // =========================================================================
    // FSM State Definitions
    // =========================================================================
    typedef enum logic [3:0] {
        ST_IDLE         = 4'd0,
        ST_LATCH_CTX    = 4'd1,
        ST_BURST_HDR    = 4'd2,
        ST_BURST_DTC    = 4'd3,
        ST_BURST_PC3    = 4'd4,
        ST_BURST_PC2    = 4'd5,
        ST_BURST_PC1    = 4'd6,
        ST_BURST_PC0    = 4'd7,
        ST_BURST_CODE   = 4'd8,
        ST_BURST_CHKSUM = 4'd9,
        ST_FAIL_SILENT  = 4'd10
    } fcu_state_t;

    fcu_state_t state, next_state;
    assign fcu_state_out = state;

    // Internal frozen diagnostic registers
    logic [31:0] reg_fault_pc;
    logic [4:0]  reg_fault_code;
    logic        reg_safe_state;

    // Immediate external interlock assertion
    assign safe_state_out = reg_safe_state | fault_detected_comb | fault_latched;
    assign fcu_busy       = (state != ST_IDLE) && (state != ST_FAIL_SILENT);
    assign fcu_done       = (state == ST_FAIL_SILENT);

    // =========================================================================
    // Checksum Calculation (XOR of bytes 0 through 6)
    // =========================================================================
    wire [7:0] checksum = 8'hAA ^ 
                          8'h46 ^ 
                          reg_fault_pc[31:24] ^ 
                          reg_fault_pc[23:16] ^ 
                          reg_fault_pc[15:8]  ^ 
                          reg_fault_pc[7:0]   ^ 
                          {3'b000, reg_fault_code};

    // =========================================================================
    // Sequential State and Context Freezing Logic
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            reg_safe_state <= 1'b0;
            reg_fault_pc   <= 32'h0;
            reg_fault_code <= 5'h0;
        end else begin
            state <= next_state;

            if ((fault_detected_comb || fault_latched) && (state == ST_IDLE)) begin
                reg_safe_state <= 1'b1;
                reg_fault_pc   <= fault_pc;
                reg_fault_code <= fault_code;
            end
        end
    end

    // =========================================================================
    // Next State and Telemetry Output Logic
    // =========================================================================
    always_comb begin
        next_state  = state;
        fcu_tx_push = 1'b0;
        fcu_tx_byte = 8'h00;

        case (state)
            ST_IDLE: begin
                if (fault_detected_comb || fault_latched) begin
                    next_state = ST_LATCH_CTX;
                end
            end

            ST_LATCH_CTX: begin
                // Context captured; initiate telemetry stream if FIFO not full
                if (!uart_tx_full) begin
                    next_state = ST_BURST_HDR;
                end
            end

            // Byte 0: Sync Header 0xAA
            ST_BURST_HDR: begin
                fcu_tx_push = 1'b1;
                fcu_tx_byte = 8'hAA;
                next_state  = ST_BURST_DTC;
            end

            // Byte 1: DTC Code 0x46 (ASCII 'F')
            ST_BURST_DTC: begin
                fcu_tx_push = 1'b1;
                fcu_tx_byte = 8'h46;
                next_state  = ST_BURST_PC3;
            end

            // Byte 2: PC[31:24]
            ST_BURST_PC3: begin
                fcu_tx_push = 1'b1;
                fcu_tx_byte = reg_fault_pc[31:24];
                next_state  = ST_BURST_PC2;
            end

            // Byte 3: PC[23:16]
            ST_BURST_PC2: begin
                fcu_tx_push = 1'b1;
                fcu_tx_byte = reg_fault_pc[23:16];
                next_state  = ST_BURST_PC1;
            end

            // Byte 4: PC[15:8]
            ST_BURST_PC1: begin
                fcu_tx_push = 1'b1;
                fcu_tx_byte = reg_fault_pc[15:8];
                next_state  = ST_BURST_PC0;
            end

            // Byte 5: PC[7:0]
            ST_BURST_PC0: begin
                fcu_tx_push = 1'b1;
                fcu_tx_byte = reg_fault_pc[7:0];
                next_state  = ST_BURST_CODE;
            end

            // Byte 6: Fault Classification Bitmask Vector
            ST_BURST_CODE: begin
                fcu_tx_push = 1'b1;
                fcu_tx_byte = {3'b000, reg_fault_code};
                next_state  = ST_BURST_CHKSUM;
            end

            // Byte 7: XOR Checksum
            ST_BURST_CHKSUM: begin
                fcu_tx_push = 1'b1;
                fcu_tx_byte = checksum;
                next_state  = ST_FAIL_SILENT;
            end

            // Permanent Fail-Silent Lockout State until hardware reset
            ST_FAIL_SILENT: begin
                fcu_tx_push = 1'b0;
                fcu_tx_byte = 8'h00;
                next_state  = ST_FAIL_SILENT;
            end

            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end

endmodule
