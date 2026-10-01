// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  uart_rx
// Description: Synthesizable 8-N-1 UART receiver with 2-FF CDC synchronizer,
//              start-bit glitch suppression, center sampling at Tick 7,
//              framing error detection, and ERR_WAIT recovery.
// =============================================================================

module uart_rx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_16x_tick,
    input  logic       rx_en,
    input  logic       rx_async_in,

    // FIFO Push Interface
    output logic [7:0] rx_data,
    output logic       rx_push,
    input  logic       rx_fifo_full,

    // Status & Error Flags
    output logic       rx_busy,
    output logic       framing_err,
    output logic       overrun_err
);

    typedef enum logic [2:0] {
        ST_IDLE     = 3'b000,
        ST_START    = 3'b001,
        ST_DATA     = 3'b010,
        ST_STOP     = 3'b011,
        ST_ERR_WAIT = 3'b100
    } rx_state_t;

    rx_state_t state_reg;
    logic [7:0] shift_reg;
    logic [3:0] tick_cnt;
    logic [2:0] bit_cnt;

    // 2-Stage Flip-Flop Synchronizer for CDC
    (* ASYNC_REG = "TRUE" *) logic rx_sync0;
    (* ASYNC_REG = "TRUE" *) logic rx_sync1;
    logic rx_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
            rx_prev  <= 1'b1;
        end else begin
            rx_sync0 <= rx_async_in;
            rx_sync1 <= rx_sync0;
            rx_prev  <= rx_sync1;
        end
    end

    // Falling edge transition detection (1 -> 0)
    wire fall_edge = (rx_prev == 1'b1) && (rx_sync1 == 1'b0);

    // Receiver Finite State Machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg   <= ST_IDLE;
            shift_reg   <= '0;
            tick_cnt    <= '0;
            bit_cnt     <= '0;
            rx_data     <= '0;
            rx_push     <= 1'b0;
            rx_busy     <= 1'b0;
            framing_err <= 1'b0;
            overrun_err <= 1'b0;
        end else begin
            rx_push     <= 1'b0;
            framing_err <= 1'b0;
            overrun_err <= 1'b0;

            case (state_reg)
                ST_IDLE: begin
                    rx_busy  <= 1'b0;
                    tick_cnt <= '0;
                    bit_cnt  <= '0;

                    if (fall_edge && rx_en) begin
                        rx_busy   <= 1'b1;
                        state_reg <= ST_START;
                    end
                end

                ST_START: begin
                    rx_busy <= 1'b1;

                    if (baud_16x_tick) begin
                        if (tick_cnt == 4'd7) begin
                            // Start-Bit Glitch Qualification:
                            // Must be logic 0 at center. If returned to 1, reject noise glitch.
                            if (rx_sync1 != 1'b0) begin
                                state_reg <= ST_IDLE;
                            end else begin
                                tick_cnt <= tick_cnt + 1'b1;
                            end
                        end else if (tick_cnt == 4'd15) begin
                            tick_cnt  <= '0;
                            bit_cnt   <= '0;
                            state_reg <= ST_DATA;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                ST_DATA: begin
                    rx_busy <= 1'b1;

                    if (baud_16x_tick) begin
                        if (tick_cnt == 4'd7) begin
                            // Center Sample Data Bit (Tick 7 = 50% midpoint)
                            shift_reg <= {rx_sync1, shift_reg[7:1]};
                            tick_cnt  <= tick_cnt + 1'b1;
                        end else if (tick_cnt == 4'd15) begin
                            tick_cnt <= '0;
                            if (bit_cnt == 3'd7) begin
                                state_reg <= ST_STOP;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                ST_STOP: begin
                    rx_busy <= 1'b1;

                    if (baud_16x_tick) begin
                        if (tick_cnt == 4'd7) begin
                            // Sample Stop Bit at center:
                            if (rx_sync1 == 1'b1) begin
                                // Valid stop bit confirmed
                                if (!rx_fifo_full) begin
                                    rx_data <= shift_reg;
                                    rx_push <= 1'b1;
                                end else begin
                                    overrun_err <= 1'b1;
                                end
                                // Re-arm at the stop-bit midpoint rather than riding out
                                // the remaining 8 ticks. On a zero-bubble back-to-back
                                // burst the next start edge lands at the end of this stop
                                // bit, and IDLE must already be active to detect it.
                                tick_cnt  <= '0;
                                state_reg <= ST_IDLE;
                            end else begin
                                // Framing Error detected (stop bit == 0)
                                framing_err <= 1'b1;
                                state_reg   <= ST_ERR_WAIT;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                ST_ERR_WAIT: begin
                    rx_busy <= 1'b1;
                    // Recovery state: wait for serial line to return high (idle Mark)
                    // before returning to IDLE, preventing cascading false start detections.
                    if (rx_sync1 == 1'b1) begin
                        state_reg <= ST_IDLE;
                    end
                end
            endcase
        end
    end

endmodule : uart_rx
