/*
 * Copyright (c) 2024 Hannah Ravensloft
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "cmd.vh"


module square (
    input  wire       clk,
    input  wire       rst_n,

    input  wire [2:0] state_mode,
    input  wire [1:0] mask_mode,
    input  wire       wtm,
    input  wire [3:0] write_bus,
    input  wire       ss1,
    input  wire       ss2,

    input  wire [4:0] north_in,
    input  wire [4:0] east_in,
    input  wire [4:0] south_in,
    input  wire [4:0] west_in,
    input  wire [4:0] northeast_in,
    input  wire [4:0] southeast_in,
    input  wire [4:0] southwest_in,
    input  wire [4:0] northwest_in,

    input  wire [1:0] nne_in,
    input  wire [1:0] nee_in,
    input  wire [1:0] see_in,
    input  wire [1:0] sse_in,
    input  wire [1:0] ssw_in,
    input  wire [1:0] sww_in,
    input  wire [1:0] nww_in,
    input  wire [1:0] nnw_in,

    output reg  [4:0] north_out,
    output reg  [4:0] east_out,
    output reg  [4:0] south_out,
    output reg  [4:0] west_out,
    output reg  [4:0] northeast_out,
    output reg  [4:0] southeast_out,
    output reg  [4:0] southwest_out,
    output reg  [4:0] northwest_out,

    output reg  [1:0] knight_out,

    output reg  [2:0] prio,
    output reg        king
);

parameter SQUARE = 0;

// neighbour bus:
// bit 0: pawn
// bit 1: king
// bit 2: diagonal
// bit 3: manhattan
// bit 4: color

// knight bus:
// bit 0: knight
// bit 1: color

reg  [2:0]  piece;
reg         color;
reg  [4:0]  depth;
reg  [31:0] mask;

wire [5:0] decoded_piece = {
    color,
    piece == `ROOK   || piece == `QUEEN,
    piece == `BISHOP || piece == `QUEEN,
    piece == `KING,
    piece == `PAWN,
    piece == `KNIGHT
};

wire attacked_white_king = |{
    north_in[4]     == `WHITE && north_in[1],
    east_in[4]      == `WHITE && east_in[1],
    south_in[4]     == `WHITE && south_in[1],
    west_in[4]      == `WHITE && west_in[1],
    northeast_in[4] == `WHITE && northeast_in[1],
    southeast_in[4] == `WHITE && southeast_in[1],
    southwest_in[4] == `WHITE && southwest_in[1],
    northwest_in[4] == `WHITE && northwest_in[1]
};

wire attacked_white_manhattan = |{
    north_in[4]     == `WHITE && north_in[3],
    east_in[4]      == `WHITE && east_in[3],
    south_in[4]     == `WHITE && south_in[3],
    west_in[4]      == `WHITE && west_in[3]
};

wire attacked_white_diagonal = |{
    northeast_in[4] == `WHITE && northeast_in[2],
    southeast_in[4] == `WHITE && southeast_in[2],
    southwest_in[4] == `WHITE && southwest_in[2],
    northwest_in[4] == `WHITE && northwest_in[2]
};

wire attacked_white_knight = |{
    nne_in[1]       == `WHITE && nne_in[0],
    nee_in[1]       == `WHITE && nee_in[0],
    see_in[1]       == `WHITE && see_in[0],
    sse_in[1]       == `WHITE && sse_in[0],
    ssw_in[1]       == `WHITE && ssw_in[0],
    sww_in[1]       == `WHITE && sww_in[0],
    nww_in[1]       == `WHITE && nww_in[0],
    nnw_in[1]       == `WHITE && nnw_in[0]
};

wire attacked_white_pawn = |{
    1'b0
};

wire attacked_white = |{
    attacked_white_king,
    attacked_white_manhattan,
    attacked_white_diagonal,
    attacked_white_knight,
    attacked_white_pawn
};

wire attacked_black_king = |{
    north_in[4]     == `BLACK && north_in[1],
    east_in[4]      == `BLACK && east_in[1],
    south_in[4]     == `BLACK && south_in[1],
    west_in[4]      == `BLACK && west_in[1],
    northeast_in[4] == `BLACK && northeast_in[1],
    southeast_in[4] == `BLACK && southeast_in[1],
    southwest_in[4] == `BLACK && southwest_in[1],
    northwest_in[4] == `BLACK && northwest_in[1]
};

wire attacked_black_manhattan = |{
    north_in[4]     == `BLACK && north_in[3],
    east_in[4]      == `BLACK && east_in[3],
    south_in[4]     == `BLACK && south_in[3],
    west_in[4]      == `BLACK && west_in[3]
};

wire attacked_black_diagonal = |{
    northeast_in[4] == `BLACK && northeast_in[2],
    southeast_in[4] == `BLACK && southeast_in[2],
    southwest_in[4] == `BLACK && southwest_in[2],
    northwest_in[4] == `BLACK && northwest_in[2]
};

wire attacked_black_knight = |{
    nne_in[1]       == `BLACK && nne_in[0],
    nee_in[1]       == `BLACK && nee_in[0],
    see_in[1]       == `BLACK && see_in[0],
    sse_in[1]       == `BLACK && sse_in[0],
    ssw_in[1]       == `BLACK && ssw_in[0],
    sww_in[1]       == `BLACK && sww_in[0],
    nww_in[1]       == `BLACK && nww_in[0],
    nnw_in[1]       == `BLACK && nnw_in[0]
};

wire attacked_black_pawn = |{
    1'b0
};

wire attacked_black = |{
    attacked_black_king,
    attacked_black_manhattan,
    attacked_black_diagonal,
    attacked_black_knight,
    attacked_black_pawn
};

wire moved_white = |{
    north_in[4]     == `WHITE && north_in[0] && state_mode == `SM_FV,
    south_in[4]     == `WHITE && south_in[0] && state_mode == `SM_FA
};

wire moved_black = |{
    south_in[4]     == `BLACK && south_in[0] && state_mode == `SM_FV,
    north_in[4]     == `BLACK && south_in[0] && state_mode == `SM_FA
};

reg xmit_manhattan_gen, xmit_diagonal_gen;
reg xmit_manhattan, xmit_diagonal, xmit_king, xmit_knight;

reg [1:0] xmit_mode;
reg [1:0] recv_mode;

always @(posedge clk) begin
    if (!rst_n) begin
        piece <= ~3'b0;
        color <= 0;
        depth <= 0;
        mask  <= ~32'b0;
    end else begin
        casez (state_mode)
        `SM_W:
            if (ss1)
                {color, piece} <= write_bus;
        `SM_WD:
            if (ss1)
                depth <= {wtm, write_bus};
        `SM_DAAA:
            if (!ss1 && color == wtm)
                mask[depth] <= 0;
        default:
            ;
        endcase

        casez (mask_mode)
        `MM_EAV_EAA:
            mask[depth] <= 1;
        `MM_DV_EAA:
            if (ss1)
                mask[depth] <= 0;
            else if (color == wtm && piece != `EMPTY)
                mask[depth] <= 1;
        `MM_DA:
            if (ss1)
                mask[depth] <= 0;
        default:
            ;
        endcase
    end
end

always @* begin
    xmit_mode = 2'b00;
    recv_mode = 2'b10;

    casez (state_mode)
    `SM_FV: begin
        // transmitter
        if (piece == `EMPTY) begin
            xmit_manhattan_gen = 1'b0;
            xmit_diagonal_gen  = 1'b0;
            xmit_manhattan     = 1'b0;
            xmit_diagonal      = 1'b0;
            xmit_king          = 1'b0;
            xmit_knight        = 1'b0;
        end else begin
            xmit_manhattan_gen = 1'b1;
            xmit_diagonal_gen  = 1'b1;
            xmit_manhattan     = decoded_piece[4] && color == wtm;
            xmit_diagonal      = decoded_piece[3] && color == wtm;
            xmit_king          = decoded_piece[2] && color == wtm;
            xmit_knight        = decoded_piece[0] && color == wtm;
        end

        // receiver
        recv_mode = 2'b10;
    end
    `SM_FP: begin
        // transmitter: TODO
        xmit_manhattan_gen = 1'b0;
        xmit_diagonal_gen  = 1'b0;
        xmit_manhattan     = 1'b0;
        xmit_diagonal      = 1'b0;
        xmit_king          = 1'b0;
        xmit_knight        = 1'b0;

        // receiver
        recv_mode = 2'b00;
    end
    `SM_FA: begin
        // transmitter
        if (ss1) begin
            xmit_manhattan_gen = 1'b1;
            xmit_diagonal_gen  = 1'b1;
            xmit_manhattan     = 1'b1;
            xmit_diagonal      = 1'b1;
            xmit_king          = 1'b1;
            xmit_knight        = 1'b1;
        end else begin
            xmit_manhattan_gen = piece != `EMPTY;
            xmit_diagonal_gen  = piece != `EMPTY;
            xmit_manhattan     = 1'b0;
            xmit_diagonal      = 1'b0;
            xmit_king          = 1'b0;
            xmit_knight        = 1'b0;
        end

        // receiver
        recv_mode = 2'b11;
    end
    default:
        ;
    endcase

    // Transmitter

    // Manhattan
    north_out    = 5'b0;
    east_out     = 5'b0;
    south_out    = 5'b0;
    west_out     = 5'b0;

    north_out[4] = xmit_manhattan_gen ? color          : south_in[4];
    north_out[3] = xmit_manhattan_gen ? xmit_manhattan : south_in[3];
    north_out[1] = xmit_king;

    east_out[4]  = xmit_manhattan_gen ? color          : west_in[4];
    east_out[3]  = xmit_manhattan_gen ? xmit_manhattan : west_in[3];
    east_out[1]  = xmit_king;

    south_out[4] = xmit_manhattan_gen ? color          : north_in[4];
    south_out[3] = xmit_manhattan_gen ? xmit_manhattan : north_in[3];
    south_out[1] = xmit_king;

    west_out[4]  = xmit_manhattan_gen ? color          : east_in[4];
    west_out[3]  = xmit_manhattan_gen ? xmit_manhattan : east_in[3];
    west_out[1]  = xmit_king;

    // Diagonal
    northeast_out    = 5'b0;
    southeast_out    = 5'b0;
    southwest_out    = 5'b0;
    northwest_out    = 5'b0;

    northeast_out[4] = xmit_diagonal_gen ? color         : southwest_in[4];
    northeast_out[2] = xmit_diagonal_gen ? xmit_diagonal : southwest_in[2];
    northeast_out[1] = xmit_king;

    southeast_out[4] = xmit_diagonal_gen ? color         : northwest_in[4];
    southeast_out[2] = xmit_diagonal_gen ? xmit_diagonal : northwest_in[2];
    southeast_out[1] = xmit_king;

    southwest_out[4] = xmit_diagonal_gen ? color         : northeast_in[4];
    southwest_out[2] = xmit_diagonal_gen ? xmit_diagonal : northeast_in[2];
    southwest_out[1] = xmit_king;

    northwest_out[4] = xmit_diagonal_gen ? color         : southeast_in[4];
    northwest_out[2] = xmit_diagonal_gen ? xmit_diagonal : southeast_in[2];
    northwest_out[1] = xmit_king;

    // Knight
    knight_out = {color, xmit_knight};

    // Receiver

    king = 0;
    prio = 0;

    if (!mask[depth])
        prio = 0;
    else begin
        casez (recv_mode)
        2'b0?: begin // pivot
            casez (piece)
            `KING:
                ;
            `QUEEN:
                if (color == !wtm && attacked_white && attacked_black)
                    prio = 7;
            `ROOK:
                if (color == !wtm && attacked_white && attacked_black)
                    prio = 6;
            `BISHOP:
                if (color == !wtm && attacked_white && attacked_black)
                    prio = 5;
            `KNIGHT:
                if (color == !wtm && attacked_white && attacked_black)
                    prio = 4;
            `PAWN:
                if (color == !wtm && attacked_white && attacked_black)
                    prio = 3;
            3'b11?:
                if (color == !wtm && attacked_white && attacked_black)
                    prio = 2;
            endcase
        end
        2'b10: begin // victim
            casez (piece)
            `KING:
                if (wtm != color && (attacked_white || attacked_black))
                    king = 1;
            `QUEEN:
                if (wtm != color && (attacked_white || attacked_black))
                    prio = 7;
            `ROOK:
                if (wtm != color && (attacked_white || attacked_black))
                    prio = 6;
            `BISHOP:
                if (wtm != color && (attacked_white || attacked_black))
                    prio = 5;
            `KNIGHT:
                if (wtm != color && (attacked_white || attacked_black))
                    prio = 4;
            `PAWN:
                if (wtm != color && (attacked_white || attacked_black))
                    prio = 3;
            3'b11?:
                if (attacked_white || attacked_black)
                    prio = 1;
            endcase
        end
        2'b11: begin // aggressor
            casez (piece)
            `KING:
                if (wtm == color && (attacked_white_king || attacked_black_king))
                    prio = 1;
            `QUEEN:
                if (wtm == color && (attacked_white_diagonal || attacked_white_manhattan || attacked_black_diagonal || attacked_black_manhattan))
                    prio = 7;
            `ROOK:
                if (wtm == color && (attacked_white_manhattan || attacked_black_manhattan))
                    prio = 6;
            `BISHOP:
                if (wtm == color && (attacked_white_diagonal || attacked_black_diagonal))
                    prio = 5;
            `KNIGHT:
                if ((wtm == color && (attacked_white_knight || attacked_black_knight)))
                    prio = 4;
            `PAWN:
                if ((wtm == color && (attacked_white_pawn || attacked_black_pawn)))
                    prio = 3;
            3'b11?:
                ;
                /*if ((wtm == `WHITE && moved_white) || (wtm == `BLACK && moved_black))
                    prio = 3;*/
            endcase
        end
        endcase
    end
end
endmodule
