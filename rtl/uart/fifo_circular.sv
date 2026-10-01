// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  fifo_circular
// Description: Synchronous circular FIFO buffer using the (N+1)-bit pointer
//              rollover method for full/empty detection without counters.
// =============================================================================

module fifo_circular #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    localparam int ADDR_WIDTH = $clog2(DEPTH), // 4 bits for 16 depth
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1 // 5 bits for pointer rollover
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Write Interface (Push)
    input  logic                  push,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic                  full,

    // Read Interface (Pop)
    input  logic                  pop,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  empty,

    // Live Occupancy Count
    output logic [PTR_WIDTH-1:0]  count
);

    // Distributed RAM array (synthesizes directly into LUTRAM)
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // 5-bit pointers (MSB acts as rollover phase bit)
    logic [PTR_WIDTH-1:0] wptr;
    logic [PTR_WIDTH-1:0] rptr;

    // Lower 4 bits address the physical RAM locations
    wire [ADDR_WIDTH-1:0] waddr = wptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] raddr = rptr[ADDR_WIDTH-1:0];

    // Pointer Rollover Logic:
    // Empty when entire 5 bits are identical
    assign empty = (wptr == rptr);

    // Full when lower address matches, but MSBs (rollover bits) differ
    assign full  = (wptr[ADDR_WIDTH] != rptr[ADDR_WIDTH]) &&
                   (wptr[ADDR_WIDTH-1:0] == rptr[ADDR_WIDTH-1:0]);

    // Live occupancy count via modular two's complement subtraction
    assign count = wptr - rptr;

    // Continuous read output from memory array
    assign rdata = mem[raddr];

    // Pointer and Memory State Updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= '0;
            rptr <= '0;
        end else begin
            // Push handling: allowed if not full, OR if simultaneously popping when full
            if (push && (!full || pop)) begin
                mem[waddr] <= wdata;
                wptr       <= wptr + 1'b1;
            end

            // Pop handling: allowed if not empty
            if (pop && !empty) begin
                rptr <= rptr + 1'b1;
            end
        end
    end

endmodule : fifo_circular
