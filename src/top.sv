/*
 * Copyright (c) 2024 Hannah Ravensloft
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "cmd.vh"

module tt_um_chess (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
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

wire [3:0] data_in;
wire       data_in_valid;
reg  [3:0] data_out;
reg        data_out_valid;
wire       data_out_ack;

assign uo_out[3:0] = 0;
assign uio_out = 0;
assign uio_oe = 0;

spi_rxtx #(
    .N_BITS(4)
) spi (
    .clk(clk),
    .rst_n(rst_n),
    .sck(ui_in[5]),
    .cs_n(ui_in[4]),
    .sdi({uio_in[1:0], ui_in[7:6]}),
    .sdo(uo_out[7:4]),
    .din(data_in),
    .din_valid(data_in_valid),
    .dout(data_out),
    .dout_valid(data_out_valid),
    .dout_ack(data_out_ack)
);

wire [7:0] board_data_out;

board b (
    .clk(clk),
    .rst_n(rst_n),
    .state_mode(state_mode),
    .mask_mode(mask_mode),
    .wtm(wtm),
    .write_bus(write_bus),
    .ss1(ss1),

    .data_out(board_data_out[6:0]),
    .illegal(board_data_out[7])
);

reg [3:0] state;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out    <= 0;
        data_out_valid <= 0;

        state_mode  <= `SM_IDLE;
        mask_mode   <= `MM_NO_CHANGE;
        wtm         <= 0;
        write_bus   <= 0;
        ss1         <= 0;
        ss2         <= 0;

        state       <= 0;
    end else begin
        case (state)
        4'b0000: begin
            data_out_valid <= 0;
            if (data_in_valid) begin
                state_mode <= `SM_IDLE;
                mask_mode  <= `MM_NO_CHANGE;

                // nybbles to read
                casez (data_in)
                4'b0001: // misc commands
                    state <= 4'b0001;
                4'b0011: // set ss1
                    state <= 4'b0010;
                4'b1000: // disable victim, enable all aggressors
                    mask_mode <= `MM_DV_EAA;
                4'b1001: // disable aggressor
                    mask_mode <= `MM_DA;
                4'b1011: // set square
                    state <= 4'b1000;
                4'b1100: // enable all victims, enable all aggressors
                    mask_mode <= `MM_EAV_EAA;
                4'b1101: begin // find-pivot
                    state_mode <= `SM_FP;
                    state <= 4'b1001;
                end
                4'b1110: begin // find-aggressor
                    state_mode <= `SM_FA;
                    state <= 4'b1010;
                end
                4'b1111: begin // find-victim
                    state_mode <= `SM_FV;
                    state <= 4'b1011;
                end
                default:
                    ;
                endcase
            end
        end
        4'b0001: begin // misc commands
            if (data_in_valid) begin
                state_mode <= `SM_IDLE;
                mask_mode  <= `MM_NO_CHANGE;
                casez (data_in)
                4'b0100: // white to move
                    wtm <= 0;
                4'b0101: // black to move
                    wtm <= 1;
                default:
                    ;
                endcase
                state <= 4'b0000;
            end
        end
        4'b0010: begin // set ss1, first nybble
            if (data_in_valid) begin
                ss1[5:4] <= data_in[1:0];
                state    <= 4'b0011;
            end
        end
        4'b0011: begin // set ss1, second nybble
            if (data_in_valid) begin
                ss1[3:0] <= data_in;
                state    <= 4'b0000;
            end
        end
        4'b1000: begin // write
            if (data_in_valid) begin
                write_bus  <= data_in;
                state_mode <= `SM_W;
                state      <= 4'b0000;
            end
        end
        4'b1001: begin // find-pivot, first nybble
            data_out       <= board_data_out[7:4];
            data_out_valid <= 1;
            if (data_out_ack) begin
                data_out  <= board_data_out[3:0];
                state <= 4'b1111;
            end
        end
        4'b1010: begin // find-aggressor, first nybble
            data_out       <= board_data_out[7:4];
            data_out_valid <= 1;
            if (data_out_ack) begin
                data_out  <= board_data_out[3:0];
                state     <= 4'b1100;
            end
        end
        4'b1011: begin // find-victim, first nybble
            data_out       <= board_data_out[7:4];
            data_out_valid <= 1;
            if (data_out_ack) begin
                data_out  <= board_data_out[3:0];
                state <= 4'b1111;
            end
        end
        4'b1100: begin // find-aggressor, second nybble
            data_out       <= board_data_out[3:0];
            data_out_valid <= 1;
            if (data_out_ack) begin
                ss2       <= ss1;
                ss1       <= board_data_out[5:0];
                mask_mode <= `MM_DA;
                state     <= 4'b1101;
            end
        end
        4'b1101: begin // find-aggressor, disable aggressor
            data_out_valid <= 0;
            ss1            <= ss2;
            state          <= 4'b0000;
        end
        4'b1111: begin // data out, second nybble
            data_out       <= board_data_out[3:0];
            data_out_valid <= 1;
            if (data_out_ack) begin
                ss1   <= board_data_out[5:0];
                state <= 4'b0000;
            end
        end
        default:
            ;
        endcase
    end
end

`ifndef SYNTHESIS
reg [32*8-1:0] state_string;

always_comb begin
    case (state)
    4'b0000: begin
        if (data_in_valid) begin
            case (data_in)
            4'b0000: state_string = "IDLE";
            4'b0001: state_string = "MISC";
            4'b0011: state_string = "SET-SS1";
            4'b0100: state_string = "SET-SS2";
            4'b0101: state_string = "SET-DEPTH";
            4'b1000: state_string = "MM-DV-EA";
            4'b1001: state_string = "MM-DA";
            4'b1011: state_string = "SET-SQUARE";
            4'b1100: state_string = "MM-EAV-EAA";
            4'b1101: state_string = "SM-FP";
            4'b1110: state_string = "SM-FA";
            4'b1111: state_string = "SM-FV";
            default: state_string = "!!! UNKNOWN !!!";
            endcase
        end else
            state_string = "IDLE";
    end
    4'b0001: begin
        if (data_in_valid) begin
            case (data_in)
            4'b0000: state_string = "NORMAL-PRIORITY";
            4'b0001: state_string = "INVERT-PRIORITY";
            4'b0010: state_string = "SS2-DISABLE";
            4'b0011: state_string = "SS2-ENABLE";
            4'b0100: state_string = "WHITE-TO-MOVE";
            4'b0101: state_string = "BLACK-TO-MOVE";
            default: state_string = "!!! UNKNOWN !!!";
            endcase
        end else
            state_string = "MISC";
    end
    4'b0010: state_string = "SET-SS1 MSN";
    4'b0011: state_string = "SET-SS1 LSN";
    4'b0100: state_string = "SET-SS2 MSN";
    4'b0101: state_string = "SET-SS2 LSN";
    4'b0110: state_string = "SET-DEPTH MSN";
    4'b0111: state_string = "SET-DEPTH LSN";
    4'b1000: state_string = "WRITE-BUS";
    4'b1001: state_string = "FIND-PIVOT MSN";
    4'b1010: state_string = "FIND-AGGRESSOR MSN";
    4'b1011: state_string = "FIND-VICTIM MSN";
    4'b1100: state_string = "FIND-AGGRESSOR LSN";
    4'b1111: state_string = "DATA-OUT LSN";
    default: state_string = "!!! UNKNOWN !!!";
    endcase
end

`endif

endmodule
