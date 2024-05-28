/*
 * Copyright (c) 2024 Hannah Ravensloft
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "cmd.vh"

module tt_um_ravenslofty_chess (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output reg  [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

reg  [2:0] state_mode;
reg  [1:0] mask_mode;
reg        wtm;
reg  [3:0] write_bus;
reg  [5:0] ss1;
reg  [5:0] ss2;
reg        ss2_en;

/* verilator lint_off UNUSEDSIGNAL */
wire [15:0] cmd;
/* verilator lint_on UNUSEDSIGNAL */
wire [7:0] data_out;

// uio used as extra input bits.
assign cmd      = {ui_in, uio_in};
assign uio_out  = 0;
assign uio_oe   = 0;

board b (
    .clk(clk),
    .rst_n(rst_n),
    .state_mode(state_mode),
    .mask_mode(mask_mode),
    .wtm(wtm),
    .write_bus(write_bus),
    .ss1(ss1),
    .ss2(ss2),
    .ss2_en(ss2_en),

    .data_out(data_out[6:0]),
    .illegal(data_out[7])
);

reg [1:0] state;
always @(posedge clk) begin
    if (!rst_n) begin
        uo_out     <= 0;

        state_mode <= 0;
        mask_mode  <= 0;
        wtm        <= 0;
        write_bus  <= 0;
        ss1        <= 0;
        ss2        <= 0;
        ss2_en     <= 0;

        state      <= 0;
    end else begin
        state_mode <= `SM_IDLE;
        mask_mode  <= `MM_NO_CHANGE;

        case (state)
        2'b00: begin
            casez (cmd[15:12])
            4'b1111: begin
                state_mode <= `SM_FA;
                ss1        <= cmd[9:4];
                state      <= 2'b10;
            end
            4'b1110: begin
                state_mode <= `SM_FV;
                state      <= 2'b01;
            end
            4'b1100: begin
                mask_mode  <= `MM_EAV_EAA;
            end
            4'b1011: begin
                state_mode <= `SM_W;
                write_bus  <= cmd[3:0];
                ss1        <= cmd[9:4];
            end
            4'b1000: begin
                mask_mode  <= `MM_DV_EAA;
                ss1        <= cmd[9:4];
            end
            default:
                ;
            endcase
        end
        2'b01: begin
            uo_out <= data_out;
            state  <= 2'b00;
        end
        2'b10: begin
            if (!uo_out[6]) begin
                mask_mode <= `MM_DA;
                ss1       <= data_out[5:0];
            end
            uo_out <= data_out;
            state <= 2'b00;
        end
        default:
            ;
        endcase
    end
end

endmodule
