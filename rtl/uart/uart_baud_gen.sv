// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  uart_baud_gen
// Description: Programmable 16X oversampling clock divider. Emits a single-cycle
//              pulse strobe every (DIVISOR + 1) master clock cycles.
// =============================================================================

module uart_baud_gen #(
    parameter int DEFAULT_DIVISOR = 53 // 100MHz / (16 * 115200) - 1
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] baud_div_val,
    output logic        baud_16x_tick
);

    logic [15:0] count_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg     <= '0;
            baud_16x_tick <= 1'b0;
        end else begin
            if (count_reg >= baud_div_val) begin
                count_reg     <= '0;
                baud_16x_tick <= 1'b1; // 1-cycle active high strobe
            end else begin
                count_reg     <= count_reg + 1'b1;
                baud_16x_tick <= 1'b0;
            end
        end
    end

endmodule : uart_baud_gen
