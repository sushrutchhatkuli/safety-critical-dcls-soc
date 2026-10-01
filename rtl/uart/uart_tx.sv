// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  uart_tx
// Description: Synthesizable 8-N-1 UART transmitter with zero-bubble back-to-back
//              burst transmission support.
// =============================================================================

module uart_tx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_16x_tick,
    input  logic       tx_en,

    // FIFO Interface
    input  logic [7:0] tx_data,
    input  logic       tx_empty,
    output logic       tx_pop,

    // Serial Output & Status
    output logic       tx_out,
    output logic       tx_busy,
    output logic       tx_done
);

    typedef enum logic [1:0] {
        ST_IDLE  = 2'b00,
        ST_START = 2'b01,
        ST_DATA  = 2'b10,
        ST_STOP  = 2'b11
    } tx_state_t;

    tx_state_t  state_reg;
    logic [7:0] shift_reg;
    logic [3:0] tick_cnt;
    logic [2:0] bit_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= ST_IDLE;
            shift_reg <= '0;
            tick_cnt  <= '0;
            bit_cnt   <= '0;
            tx_out    <= 1'b1; // UART idle state is Mark (logic 1)
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            tx_pop    <= 1'b0;
        end else begin
            tx_done <= 1'b0;
            tx_pop  <= 1'b0;

            case (state_reg)
                ST_IDLE: begin
                    tx_out   <= 1'b1;
                    tx_busy  <= 1'b0;
                    tick_cnt <= '0;
                    bit_cnt  <= '0;

                    if (!tx_empty && tx_en) begin
                        shift_reg <= tx_data;
                        tx_pop    <= 1'b1;
                        tx_busy   <= 1'b1;
                        state_reg <= ST_START;
                    end
                end

                ST_START: begin
                    tx_out  <= 1'b0; // Drive Start Bit (Space)
                    tx_busy <= 1'b1;

                    if (baud_16x_tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt  <= '0;
                            state_reg <= ST_DATA;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                ST_DATA: begin
                    tx_out  <= shift_reg[0]; // Transmit LSB first
                    tx_busy <= 1'b1;

                    if (baud_16x_tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt  <= '0;
                            shift_reg <= {1'b0, shift_reg[7:1]};
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
                    tx_out  <= 1'b1; // Drive Stop Bit (Mark)
                    tx_busy <= 1'b1;

                    if (baud_16x_tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= '0;
                            tx_done  <= 1'b1;

                            // Zero-bubble burst transmission check:
                            if (!tx_empty && tx_en) begin
                                shift_reg <= tx_data;
                                tx_pop    <= 1'b1;
                                bit_cnt   <= '0; // ST_IDLE is bypassed, so re-arm here
                                state_reg <= ST_START;
                            end else begin
                                state_reg <= ST_IDLE;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end
            endcase
        end
    end

endmodule : uart_tx
