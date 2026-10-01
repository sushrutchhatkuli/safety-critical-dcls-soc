// =============================================================================
// File: accel_buffer.sv
// Project: Heterogeneous RISC-V SoC with AXI4-Lite & Accelerator
// Description: Scratchpad SRAM for Matrix Storage.
//              Port A: 32-bit word read/write with byte strobes for AXI interface.
//              Port B: 16-bit halfword read/write for Accelerator FSM datapath.
//              Single-write-port multiplexed architecture for distributed RAM
//              FPGA synthesis compliance.
// =============================================================================

`timescale 1ns / 1ps

module accel_buffer #(
    parameter int DEPTH_WORDS = 448 // 448 words = 1792 bytes (offsets 0x100 - 0x7FF)
)(
    input  logic        clk,
    input  logic        rst_n,

    // -------------------------------------------------------------------------
    // Port A: 32-Bit AXI Interface
    // -------------------------------------------------------------------------
    input  logic        a_we,
    input  logic [8:0]  a_addr,     // 0 to DEPTH_WORDS-1
    input  logic [31:0] a_wdata,
    input  logic [3:0]  a_wstrb,
    output logic [31:0] a_rdata,

    // -------------------------------------------------------------------------
    // Port B: 16-Bit Datapath Interface (Q8.8 Halfwords)
    // -------------------------------------------------------------------------
    input  logic        b_we,
    input  logic [9:0]  b_addr,     // 0 to (2*DEPTH_WORDS)-1
    input  logic [15:0] b_wdata,
    output logic [15:0] b_rdata
);

    // 4 independent byte banks for collision-free byte strobing
    (* ram_style = "distributed" *) logic [7:0] mem0 [0:DEPTH_WORDS-1];
    (* ram_style = "distributed" *) logic [7:0] mem1 [0:DEPTH_WORDS-1];
    (* ram_style = "distributed" *) logic [7:0] mem2 [0:DEPTH_WORDS-1];
    (* ram_style = "distributed" *) logic [7:0] mem3 [0:DEPTH_WORDS-1];

    // Initialize all memory to 0
    integer init_i;
    initial begin
        for (init_i = 0; init_i < DEPTH_WORDS; init_i = init_i + 1) begin
            mem0[init_i] = 8'd0;
            mem1[init_i] = 8'd0;
            mem2[init_i] = 8'd0;
            mem3[init_i] = 8'd0;
        end
    end

    // Port B address mapping
    logic [8:0] b_word_addr;
    logic       b_half_sel;

    assign b_word_addr = b_addr[9:1];
    assign b_half_sel  = b_addr[0];

    // -------------------------------------------------------------------------
    // Synchronous Write Process (Single-Port Arbiter for Synthesis Compliance)
    // Priority: Port A (AXI external host write) > Port B (Internal FSM write)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (a_we) begin
            if (a_wstrb[0]) mem0[a_addr] <= a_wdata[7:0];
            if (a_wstrb[1]) mem1[a_addr] <= a_wdata[15:8];
            if (a_wstrb[2]) mem2[a_addr] <= a_wdata[23:16];
            if (a_wstrb[3]) mem3[a_addr] <= a_wdata[31:24];
        end else if (b_we) begin
            if (b_half_sel) begin
                mem2[b_word_addr] <= b_wdata[7:0];
                mem3[b_word_addr] <= b_wdata[15:8];
            end else begin
                mem0[b_word_addr] <= b_wdata[7:0];
                mem1[b_word_addr] <= b_wdata[15:8];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Asynchronous Read Ports
    // -------------------------------------------------------------------------
    assign a_rdata = {mem3[a_addr], mem2[a_addr], mem1[a_addr], mem0[a_addr]};
    assign b_rdata = b_half_sel ? {mem3[b_word_addr], mem2[b_word_addr]} 
                                : {mem1[b_word_addr], mem0[b_word_addr]};

endmodule
