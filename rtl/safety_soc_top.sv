// =============================================================================
// File: safety_soc_top.sv
// Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
// Description: Complete Top-Level Safety-Critical SoC integrating:
//              1. Dual-Core Lockstep (DCLS) Subsystem with 2-cycle temporal diversity
//                 (Master Core and Shadow Core executing with Delta t = 2 cycles).
//              2. DCLS Combinational Comparator and Zero-Cycle Bus Firewall
//                 (clamps corrupt writes in < 1.0 ns).
//              3. Fault Control Unit (FCU) with autonomous blackbox crash logging
//                 directly into the UART circular FIFO.
//              4. AMBA AXI4-Lite Crossbar Interconnect.
//              5. High-Reliability AXI4-Lite UART Peripheral (Dual 16-word FIFOs).
//              6. Custom Q8.8 Fixed-Point Matrix-Vector Accelerator.
//              7. On-chip 16 KB Instruction Memory and 64 KB Data Memory.
// =============================================================================

`timescale 1ns / 1ps

module safety_soc_top #(
    parameter int IMEM_WORDS   = 4096,  // 16 KB Instruction Memory
    parameter int DMEM_WORDS   = 16384, // 64 KB Data Memory
    parameter int UART_DIVISOR = 53     // 100 MHz clock -> 115200 Baud
)(
    input  logic        clk,
    input  logic        rst_n,

    // Serial Communication Pins
    output logic        uart_txd,
    input  logic        uart_rxd,

    // Safety Interlock and Fault Status Pins
    output logic        safe_state_out,
    output logic        fault_indicator,

    // Hardware Interrupt Pins
    output logic        uart_irq,
    output logic        accel_irq
);

    // =========================================================================
    // 1. ON-CHIP INSTRUCTION MEMORY (16 KB)
    // =========================================================================
    logic [31:0] imem_storage [0:IMEM_WORDS-1];
    logic [31:0] raw_imem_addr;
    logic [31:0] raw_imem_rdata;

    // Asynchronous read for single-cycle RV32I instruction fetch
    assign raw_imem_rdata = imem_storage[raw_imem_addr[13:2]];

    // =========================================================================
    // 2. DUAL-CORE LOCKSTEP SUBSYSTEM (Delta t = 2 clock cycles)
    // =========================================================================
    logic [31:0] raw_dmem_addr;
    logic [31:0] raw_dmem_rdata;

    logic [31:0] m_imem_addr_delayed, s_imem_addr;
    logic [31:0] m_dmem_addr_delayed, s_dmem_addr;
    logic [31:0] m_dmem_wdata_delayed, s_dmem_wdata;
    logic [3:0]  m_dmem_strb_delayed, s_dmem_strb;
    logic        m_dmem_we_delayed, s_dmem_we;
    logic        m_dmem_re_delayed, s_dmem_re;
    logic        dcls_active;

    dcls_core_wrapper u_dcls_core (
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

    // =========================================================================
    // 3. DCLS COMBINATIONAL COMPARATOR & ZERO-CYCLE BUS FIREWALL
    // =========================================================================
    logic [31:0] protected_dmem_addr;
    logic [31:0] protected_dmem_wdata;
    logic [3:0]  protected_dmem_strb;
    logic        protected_dmem_we;
    logic        protected_dmem_re;

    logic        fault_detected_comb;
    logic        fault_latched;
    logic        cmp_safe_state;
    logic [4:0]  fault_code;
    logic [31:0] fault_pc;
    logic [31:0] fault_addr;
    logic [31:0] fault_m_data;
    logic [31:0] fault_s_data;

    dcls_comparator_firewall u_firewall (
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
        .safe_state_out         (cmp_safe_state),
        .fault_code             (fault_code),
        .fault_pc               (fault_pc),
        .fault_addr             (fault_addr),
        .fault_m_data           (fault_m_data),
        .fault_s_data           (fault_s_data)
    );

    assign fault_indicator = fault_latched;

    // =========================================================================
    // 4. FAULT CONTROL UNIT (FCU) & BLACKBOX TELEMETRY ENGINE
    // =========================================================================
    logic       fcu_safe_state;
    logic       fcu_tx_push;
    logic [7:0] fcu_tx_byte;
    logic       uart_tx_full;
    logic [3:0] fcu_state;
    logic       fcu_busy;
    logic       fcu_done;

    dcls_fcu u_fcu (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .fault_detected_comb    (fault_detected_comb),
        .fault_latched          (fault_latched),
        .fault_code             (fault_code),
        .fault_pc               (fault_pc),
        .fault_addr             (fault_addr),
        .fault_m_data           (fault_m_data),
        .fault_s_data           (fault_s_data),
        .safe_state_out         (fcu_safe_state),
        .fcu_tx_push            (fcu_tx_push),
        .fcu_tx_byte            (fcu_tx_byte),
        .uart_tx_full           (uart_tx_full),
        .fcu_state_out          (fcu_state),
        .fcu_busy               (fcu_busy),
        .fcu_done               (fcu_done)
    );

    // Combined safety interlock output pin
    assign safe_state_out = cmp_safe_state | fcu_safe_state;

    // =========================================================================
    // 5. AMBA AXI4-LITE MASTER BRIDGE
    // =========================================================================
    // Driven by protected outputs from firewall. If firewall clamps,
    // cpu_req is forced to 0 instantly, suppressing AXI transactions.
    wire cpu_req = protected_dmem_we | protected_dmem_re;

    logic [31:0] axi_m_awaddr;
    logic        axi_m_awvalid;
    logic        axi_m_awready;
    logic [31:0] axi_m_wdata;
    logic [3:0]  axi_m_wstrb;
    logic        axi_m_wvalid;
    logic        axi_m_wready;
    logic [1:0]  axi_m_bresp;
    logic        axi_m_bvalid;
    logic        axi_m_bready;
    logic [31:0] axi_m_araddr;
    logic        axi_m_arvalid;
    logic        axi_m_arready;
    logic [31:0] axi_m_rdata;
    logic [1:0]  axi_m_rresp;
    logic        axi_m_rvalid;
    logic        axi_m_rready;
    logic        cpu_ready;
    logic        cpu_err;
    logic [31:0] cpu_axi_rdata;

    axi_lite_master u_axi_master_bridge (
        .clk          (clk),
        .rst_n        (rst_n),
        .cpu_req      (cpu_req),
        .cpu_we       (protected_dmem_we),
        .cpu_addr     (protected_dmem_addr),
        .cpu_wdata    (protected_dmem_wdata),
        .cpu_strb     (protected_dmem_strb),
        .cpu_rdata    (cpu_axi_rdata),
        .cpu_ready    (cpu_ready),
        .cpu_err      (cpu_err),
        .m_axi_awaddr (axi_m_awaddr),
        .m_axi_awvalid(axi_m_awvalid),
        .m_axi_awready(axi_m_awready),
        .m_axi_wdata  (axi_m_wdata),
        .m_axi_wstrb  (axi_m_wstrb),
        .m_axi_wvalid (axi_m_wvalid),
        .m_axi_wready (axi_m_wready),
        .m_axi_bresp  (axi_m_bresp),
        .m_axi_bvalid (axi_m_bvalid),
        .m_axi_bready (axi_m_bready),
        .m_axi_araddr (axi_m_araddr),
        .m_axi_arvalid(axi_m_arvalid),
        .m_axi_arready(axi_m_arready),
        .m_axi_rdata  (axi_m_rdata),
        .m_axi_rresp  (axi_m_rresp),
        .m_axi_rvalid (axi_m_rvalid),
        .m_axi_rready (axi_m_rready)
    );

    // =========================================================================
    // 6. AMBA AXI4-LITE 1-MASTER TO 3-SLAVE CROSSBAR INTERCONNECT
    // =========================================================================
    // Slave 0: Data RAM (0x2000_0000 - 0x2000_FFFF)
    logic [31:0] s0_awaddr, s0_wdata, s0_araddr, s0_rdata;
    logic [3:0]  s0_wstrb;
    logic        s0_awvalid, s0_awready, s0_wvalid, s0_wready;
    logic [1:0]  s0_bresp, s0_rresp;
    logic        s0_bvalid, s0_bready, s0_arvalid, s0_arready, s0_rvalid, s0_rready;

    // Slave 1: Custom Accelerator (0x4000_0000 - 0x4000_07FF)
    logic [31:0] s1_awaddr, s1_wdata, s1_araddr, s1_rdata;
    logic [3:0]  s1_wstrb;
    logic        s1_awvalid, s1_awready, s1_wvalid, s1_wready;
    logic [1:0]  s1_bresp, s1_rresp;
    logic        s1_bvalid, s1_bready, s1_arvalid, s1_arready, s1_rvalid, s1_rready;

    // Slave 2: UART Peripheral (0x1000_0000 - 0x1000_001F)
    logic [31:0] s2_awaddr, s2_wdata, s2_araddr, s2_rdata;
    logic [3:0]  s2_wstrb;
    logic        s2_awvalid, s2_awready, s2_wvalid, s2_wready;
    logic [1:0]  s2_bresp, s2_rresp;
    logic        s2_bvalid, s2_bready, s2_arvalid, s2_arready, s2_rvalid, s2_rready;

    axi_interconnect u_interconnect (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axi_awaddr (axi_m_awaddr),
        .s_axi_awvalid(axi_m_awvalid),
        .s_axi_awready(axi_m_awready),
        .s_axi_wdata  (axi_m_wdata),
        .s_axi_wstrb  (axi_m_wstrb),
        .s_axi_wvalid (axi_m_wvalid),
        .s_axi_wready (axi_m_wready),
        .s_axi_bresp  (axi_m_bresp),
        .s_axi_bvalid (axi_m_bvalid),
        .s_axi_bready (axi_m_bready),
        .s_axi_araddr (axi_m_araddr),
        .s_axi_arvalid(axi_m_arvalid),
        .s_axi_arready(axi_m_arready),
        .s_axi_rdata  (axi_m_rdata),
        .s_axi_rresp  (axi_m_rresp),
        .s_axi_rvalid (axi_m_rvalid),
        .s_axi_rready (axi_m_rready),

        // Slave 0: Data RAM
        .m0_axi_awaddr (s0_awaddr),
        .m0_axi_awvalid(s0_awvalid),
        .m0_axi_awready(s0_awready),
        .m0_axi_wdata  (s0_wdata),
        .m0_axi_wstrb  (s0_wstrb),
        .m0_axi_wvalid (s0_wvalid),
        .m0_axi_wready (s0_wready),
        .m0_axi_bresp  (s0_bresp),
        .m0_axi_bvalid (s0_bvalid),
        .m0_axi_bready (s0_bready),
        .m0_axi_araddr (s0_araddr),
        .m0_axi_arvalid(s0_arvalid),
        .m0_axi_arready(s0_arready),
        .m0_axi_rdata  (s0_rdata),
        .m0_axi_rresp  (s0_rresp),
        .m0_axi_rvalid (s0_rvalid),
        .m0_axi_rready (s0_rready),

        // Slave 1: Accelerator
        .m1_axi_awaddr (s1_awaddr),
        .m1_axi_awvalid(s1_awvalid),
        .m1_axi_awready(s1_awready),
        .m1_axi_wdata  (s1_wdata),
        .m1_axi_wstrb  (s1_wstrb),
        .m1_axi_wvalid (s1_wvalid),
        .m1_axi_wready (s1_wready),
        .m1_axi_bresp  (s1_bresp),
        .m1_axi_bvalid (s1_bvalid),
        .m1_axi_bready (s1_bready),
        .m1_axi_araddr (s1_araddr),
        .m1_axi_arvalid(s1_arvalid),
        .m1_axi_arready(s1_arready),
        .m1_axi_rdata  (s1_rdata),
        .m1_axi_rresp  (s1_rresp),
        .m1_axi_rvalid (s1_rvalid),
        .m1_axi_rready (s1_rready),

        // Slave 2: UART
        .m2_axi_awaddr (s2_awaddr),
        .m2_axi_awvalid(s2_awvalid),
        .m2_axi_awready(s2_awready),
        .m2_axi_wdata  (s2_wdata),
        .m2_axi_wstrb  (s2_wstrb),
        .m2_axi_wvalid (s2_wvalid),
        .m2_axi_wready (s2_wready),
        .m2_axi_bresp  (s2_bresp),
        .m2_axi_bvalid (s2_bvalid),
        .m2_axi_bready (s2_bready),
        .m2_axi_araddr (s2_araddr),
        .m2_axi_arvalid(s2_arvalid),
        .m2_axi_arready(s2_arready),
        .m2_axi_rdata  (s2_rdata),
        .m2_axi_rresp  (s2_rresp),
        .m2_axi_rvalid (s2_rvalid),
        .m2_axi_rready (s2_rready)
    );

    // =========================================================================
    // 7. SLAVE 0: ON-CHIP DATA RAM (64 KB)
    // =========================================================================
    axi_ram_ctrl #(
        .MEM_DEPTH_WORDS(DMEM_WORDS)
    ) u_data_ram (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axi_awaddr (s0_awaddr),
        .s_axi_awvalid(s0_awvalid),
        .s_axi_awready(s0_awready),
        .s_axi_wdata  (s0_wdata),
        .s_axi_wstrb  (s0_wstrb),
        .s_axi_wvalid (s0_wvalid),
        .s_axi_wready (s0_wready),
        .s_axi_bresp  (s0_bresp),
        .s_axi_bvalid (s0_bvalid),
        .s_axi_bready (s0_bready),
        .s_axi_araddr (s0_araddr),
        .s_axi_arvalid(s0_arvalid),
        .s_axi_arready(s0_arready),
        .s_axi_rdata  (s0_rdata),
        .s_axi_rresp  (s0_rresp),
        .s_axi_rvalid (s0_rvalid),
        .s_axi_rready (s0_rready)
    );

    // Fast direct read mux for CPU memory stage
    // When CPU loads from Data RAM or peripherals, return the appropriate bus data
    assign raw_dmem_rdata = (raw_dmem_addr >= 32'h2000_0000 && raw_dmem_addr <= 32'h2000_FFFF) ?
                            u_data_ram.ram_memory[raw_dmem_addr[15:2]] : cpu_axi_rdata;

    // =========================================================================
    // 8. SLAVE 1: CUSTOM Q8.8 MATRIX-VECTOR ACCELERATOR (0x4000_0000)
    // =========================================================================
    accel_top u_accel (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axi_awaddr (s1_awaddr),
        .s_axi_awvalid(s1_awvalid),
        .s_axi_awready(s1_awready),
        .s_axi_wdata  (s1_wdata),
        .s_axi_wstrb  (s1_wstrb),
        .s_axi_wvalid (s1_wvalid),
        .s_axi_wready (s1_wready),
        .s_axi_bresp  (s1_bresp),
        .s_axi_bvalid (s1_bvalid),
        .s_axi_bready (s1_bready),
        .s_axi_araddr (s1_araddr),
        .s_axi_arvalid(s1_arvalid),
        .s_axi_arready(s1_arready),
        .s_axi_rdata  (s1_rdata),
        .s_axi_rresp  (s1_rresp),
        .s_axi_rvalid (s1_rvalid),
        .s_axi_rready (s1_rready),
        .irq          (accel_irq)
    );

    // =========================================================================
    // 9. SLAVE 2: HIGH-RELIABILITY AXI4-LITE UART PERIPHERAL (0x1000_0000)
    // =========================================================================
    uart_axi_top #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .FIFO_DEPTH    (16),
        .DEFAULT_DIV   (UART_DIVISOR)
    ) u_uart (
        .s_axi_aclk       (clk),
        .s_axi_aresetn    (rst_n),
        .s_axi_awaddr     (s2_awaddr),
        .s_axi_awprot     (3'b000),
        .s_axi_awvalid    (s2_awvalid),
        .s_axi_awready    (s2_awready),
        .s_axi_wdata      (s2_wdata),
        .s_axi_wstrb      (s2_wstrb),
        .s_axi_wvalid     (s2_wvalid),
        .s_axi_wready     (s2_wready),
        .s_axi_bresp      (s2_bresp),
        .s_axi_bvalid     (s2_bvalid),
        .s_axi_bready     (s2_bready),
        .s_axi_araddr     (s2_araddr),
        .s_axi_arprot     (3'b000),
        .s_axi_arvalid    (s2_arvalid),
        .s_axi_arready    (s2_arready),
        .s_axi_rdata      (s2_rdata),
        .s_axi_rresp      (s2_rresp),
        .s_axi_rvalid     (s2_rvalid),
        .s_axi_rready     (s2_rready),
        .uart_txd         (uart_txd),
        .uart_rxd         (uart_rxd),
        .uart_irq         (uart_irq),
        .fcu_tx_push      (fcu_tx_push),
        .fcu_tx_byte      (fcu_tx_byte),
        .uart_tx_full_out (uart_tx_full)
    );

endmodule
