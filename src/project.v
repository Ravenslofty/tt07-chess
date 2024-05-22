/*
 * Copyright (c) 2024 Hannah Ravensloft
 * SPDX-License-Identifier: Apache-2.0
 */

/* verilator lint_off DECLFILENAME */

`default_nettype none

`define PAWN   3'd0
`define KNIGHT 3'd1
`define BISHOP 3'd2
`define ROOK   3'd3
`define QUEEN  3'd4
`define KING   3'd5
`define EMPTY  3'd7

`define WHITE  1'b0
`define BLACK  1'b1

`define VICTIM    1'b0
`define AGGRESSOR 1'b1


// Propagate incoming attacks or generate attacks from this square.
module xmit (
    input  wire [3:0] piece_reg,
    input  wire       op,
    input  wire       wtm,
    input  wire       xmit_addr,
    input  wire       north_in,
    input  wire       east_in,
    input  wire       south_in,
    input  wire       west_in,
    input  wire       northeast_in,
    input  wire       southeast_in,
    input  wire       southwest_in,
    input  wire       northwest_in,
    output wire       north_out,
    output wire       east_out,
    output wire       south_out,
    output wire       west_out,
    output wire       northeast_out,
    output wire       southeast_out,
    output wire       southwest_out,
    output wire       northwest_out,
    output wire       knight,
    output wire       king,
    output wire       wpawn_1sq,
    output wire       wpawn_2sq,
    output wire       wpawn_cap,
    output wire       bpawn_1sq,
    output wire       bpawn_2sq,
    output wire       bpawn_cap
);

parameter RANK_IS_1 = 0;
parameter RANK_IS_6 = 0;

wire [2:0] piece = piece_reg[2:0];
wire color = piece_reg[3];

wire manhattan = (op == `AGGRESSOR && xmit_addr) || (op == `VICTIM && color == wtm && (piece == `ROOK || piece == `QUEEN));
wire diagonal = (op == `AGGRESSOR && xmit_addr) || (op == `VICTIM && color == wtm && (piece == `BISHOP || piece == `QUEEN));
wire empty = (op == `VICTIM || ~xmit_addr) && piece == `EMPTY;

assign knight = (op == `AGGRESSOR && xmit_addr) || (op == `VICTIM && color == wtm && piece == `KNIGHT);
assign king = (op == `AGGRESSOR && xmit_addr) || (op == `VICTIM && color == wtm && piece == `KING);
assign wpawn_1sq = (op == `AGGRESSOR && xmit_addr && piece == `EMPTY) || (op == `VICTIM && color == `WHITE && piece == `PAWN);
assign wpawn_2sq = 1'b0; //wpawn_1sq && RANK_IS_1;
assign wpawn_cap = (op == `VICTIM && color == `WHITE && piece == `PAWN) || (op == `AGGRESSOR && xmit_addr && color == `WHITE && piece != `EMPTY);
assign bpawn_1sq = (op == `AGGRESSOR && xmit_addr && piece == `EMPTY) || (op == `VICTIM && color == `BLACK && piece == `PAWN);
assign bpawn_2sq = 1'b0; //bpawn_1sq && RANK_IS_6;
assign bpawn_cap = (op == `VICTIM && color == `BLACK && piece == `PAWN) || (op == `AGGRESSOR && xmit_addr && color == `BLACK && piece != `EMPTY);

// If there is an empty piece, attacks propagate through, otherwise it depends on the piece.
assign north_out = empty ? south_in : manhattan;
assign east_out  = empty ? west_in  : manhattan;
assign south_out = empty ? north_in : manhattan;
assign west_out  = empty ? east_in  : manhattan;

assign northeast_out = empty ? southwest_in : diagonal;
assign southeast_out = empty ? northwest_in : diagonal;
assign southwest_out = empty ? northeast_in : diagonal;
assign northwest_out = empty ? southeast_in : diagonal;

endmodule


// Based on incoming attacks, propagate a priority level.
module recv (
    input  wire [3:0] piece_reg,
    input  wire       op,
    input  wire       wtm,
    input  wire       enable_reg,
    input  wire       manhattan,
    input  wire       diagonal,
    input  wire       knight,
    input  wire       king,
    input  wire       wpawn_1sq,
    input  wire       wpawn_2sq,
    input  wire       wpawn_cap,
    input  wire       bpawn_1sq,
    input  wire       bpawn_2sq,
    input  wire       bpawn_cap,
    output reg  [2:0] priority_,
    output reg        illegal
);

wire [2:0] piece = piece_reg[2:0];
wire color = piece_reg[3];

wire attacked  = |{manhattan, diagonal, knight, king, wpawn_cap && color == `BLACK, bpawn_cap && color == `WHITE};
wire moved     = |{wpawn_1sq, wpawn_2sq, bpawn_1sq, bpawn_2sq};

always @* begin
    illegal = 0;
    if (!enable_reg) begin
        priority_ = 3'h0;
    end else if (op == `VICTIM) begin
        illegal = attacked && piece == `KING && color == !wtm;
        if (piece == `QUEEN && attacked && color == !wtm)
            priority_ = 6;
        else if (piece == `ROOK && attacked && color == !wtm)
            priority_ = 5;
        else if (piece == `BISHOP && attacked && color == !wtm)
            priority_ = 4;
        else if (piece == `KNIGHT && attacked && color == !wtm)
            priority_ = 3;
        else if (piece == `PAWN && attacked && color == !wtm)
            priority_ = 2;
        else if (piece == `EMPTY && (attacked || moved))
            priority_ = 1;
        else
            priority_ = 0;
    end else begin
        if (piece == `PAWN && ((wtm == `WHITE && |{bpawn_cap, bpawn_1sq, bpawn_2sq}) || (wtm == `BLACK && |{wpawn_cap, wpawn_1sq, wpawn_2sq})))
            priority_ = 6;
        else if (piece == `KNIGHT && knight && color == wtm)
            priority_ = 5;
        else if (piece == `BISHOP && diagonal && color == wtm)
            priority_ = 4;
        else if (piece == `ROOK && manhattan && color == wtm)
            priority_ = 3;
        else if (piece == `QUEEN && (diagonal || manhattan) && color == wtm)
            priority_ = 2;
        else if (piece == `KING && king && color == wtm)
            priority_ = 1;
        else
            priority_ = 0;
    end
end

endmodule

module arb_unit (
    input  wire [2:0] p_lhs,
    input  wire [5:0] s_lhs,
    input  wire [2:0] p_rhs,
    input  wire [5:0] s_rhs,
    output wire [2:0] p_out,
    output wire [5:0] s_out
);

assign p_out = (p_rhs > p_lhs) ? p_rhs : p_lhs;
assign s_out = (p_rhs > p_lhs) ? s_rhs : s_lhs;

endmodule

// Decide the priority for all squares.
module arb (
    input wire  [191:0] priority_,
    output wire [6:0]   data_out
);

generate
    wire [23:0] pr_per_rank;
    wire [47:0] sq_per_rank;
    genvar rank;
    for (rank = 0; rank < 8; rank = rank + 1) begin:arb_file_outer
        genvar file;
        wire [23:0] pr_file;
        wire [47:0] sq_file;
        assign pr_file[0 +: 3] = priority_[3*{rank[2:0], 3'b0} +: 3];
        assign sq_file[0 +: 6] = {rank[2:0], 3'b0};
        for (file = 1; file < 8; file = file + 1) begin:arb_file
            wire [2:0] p_lhs = pr_file[3*{file[2:0] - 3'b1} +: 3];
            wire [5:0] s_lhs = sq_file[6*{file[2:0] - 3'b1} +: 6];
            wire [2:0] p_rhs = priority_[3*{rank[2:0], file[2:0]} +: 3];
            wire [5:0] s_rhs = {rank[2:0], file[2:0]};
            arb_unit unit (
                .p_lhs(p_lhs),
                .s_lhs(s_lhs),
                .p_rhs(p_rhs),
                .s_rhs(s_rhs),
                .p_out(pr_file[3*file[2:0] +: 3]),
                .s_out(sq_file[6*file[2:0] +: 6])
            );
        end
        assign pr_per_rank[3*rank[2:0] +: 3] = pr_file[23:21];
        assign sq_per_rank[6*rank[2:0] +: 6] = sq_file[47:42];
    end

    wire [23:0] pr_rank;
    wire [47:0] sq_rank;
    assign pr_rank[2:0] = pr_per_rank[2:0];
    assign sq_rank[5:0] = sq_per_rank[5:0];
    for (rank = 1; rank < 8; rank = rank + 1) begin:arb_rank
        wire [2:0] p_lhs = pr_rank[3*(rank[2:0] - 1) +: 3]; 
        wire [5:0] s_lhs = sq_rank[6*(rank[2:0] - 1) +: 6];
        wire [2:0] p_rhs = pr_per_rank[3*rank[2:0] +: 3];
        wire [5:0] s_rhs = sq_per_rank[6*rank[2:0] +: 6];
        arb_unit unit (
            .p_lhs(p_lhs),
            .s_lhs(s_lhs),
            .p_rhs(p_rhs),
            .s_rhs(s_rhs),
            .p_out(pr_rank[3*rank[2:0] +: 3]),
            .s_out(sq_rank[6*rank[2:0] +: 6])
        );
    end
    assign data_out[5:0] = sq_rank[47:42];
    assign data_out[6] = pr_rank[23:21] == 0;
endgenerate

endmodule


module tt_um_chess (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path (not all bits used)
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

reg [255:0] piece_reg;
reg [63:0] enable_reg;
reg op;
reg wtm;
reg [5:0] xmit_addr;

/* verilator lint_off UNUSEDSIGNAL */
wire [7:0] addr;
/* verilator lint_on UNUSEDSIGNAL */
wire [7:0] data_out;
wire [7:0] data_in;

// uio used as extra input bits.
assign addr     = ui_in;
assign data_in  = uio_in;
assign uo_out   = data_out;
assign uio_out  = 0;
assign uio_oe   = 0;

wire [63:0] north_out;
wire [63:0] east_out;
wire [63:0] south_out;
wire [63:0] west_out;
wire [63:0] northeast_out;
wire [63:0] southeast_out;
wire [63:0] southwest_out;
wire [63:0] northwest_out;
wire [63:0] knight;
wire [63:0] king;
wire [63:0] wpawn_1sq;
wire [63:0] wpawn_2sq;
wire [63:0] wpawn_cap;
wire [63:0] bpawn_1sq;
wire [63:0] bpawn_2sq;
wire [63:0] bpawn_cap;

wire [191:0] priority_;
wire [63:0] illegal;

wire [63:0] white;
wire [63:0] black;

generate
    genvar square;
    for (square = 0; square < 64; square = square + 1) begin:sq
        localparam rank = square / 8;
        localparam file = square % 8;

        wire [2:0] piece = piece_reg[4*square +: 3];
        wire color = piece_reg[4*square + 3];
        assign white[square] = (color == `WHITE) && (piece != `EMPTY);
        assign black[square] = (color == `BLACK) && (piece != `EMPTY);

        xmit #(
            .RANK_IS_1(rank == 1),
            .RANK_IS_6(rank == 6)
        ) transmitter (
            .piece_reg(piece_reg[4*square +: 4]),
            .op(op),
            .wtm(wtm),
            .xmit_addr(xmit_addr == square),
            .north_in(rank < 7 ? south_out[square+8] : 1'b0),
            .east_in(file < 7 ? west_out[square+1] : 1'b0),
            .south_in(rank > 0 ? north_out[square-8] : 1'b0),
            .west_in(file > 0 ? east_out[square-1] : 1'b0),
            .northeast_in((rank < 7 && file < 7) ? southwest_out[square+9] : 1'b0),
            .southeast_in((rank > 0 && file < 7) ? northwest_out[square-7] : 1'b0),
            .southwest_in((rank > 0 && file > 0) ? northeast_out[square-9] : 1'b0),
            .northwest_in((rank < 7 && file > 0) ? southeast_out[square+7] : 1'b0),
            .north_out(north_out[square]),
            .east_out(east_out[square]),
            .south_out(south_out[square]),
            .west_out(west_out[square]),
            .northeast_out(northeast_out[square]),
            .southeast_out(southeast_out[square]),
            .southwest_out(southwest_out[square]),
            .northwest_out(northwest_out[square]),
            .knight(knight[square]),
            .king(king[square]),
            .wpawn_1sq(wpawn_1sq[square]),
            .wpawn_2sq(wpawn_2sq[square]),
            .wpawn_cap(wpawn_cap[square]),
            .bpawn_1sq(bpawn_1sq[square]),
            .bpawn_2sq(bpawn_2sq[square]),
            .bpawn_cap(bpawn_cap[square])
        );

        wire manhattan_attacks = |{
            (rank < 7) ? south_out[square+8] : 1'b0,
            (file < 7) ? west_out[square+1] : 1'b0,
            (rank > 0) ? north_out[square-8] : 1'b0,
            (file > 0) ? east_out[square-1] : 1'b0
        };

        wire diagonal_attacks = |{
            (rank < 7 && file < 7) ? southwest_out[square+9] : 1'b0,
            (rank > 0 && file < 7) ? northwest_out[square-7] : 1'b0,
            (rank > 0 && file > 0) ? northeast_out[square-9] : 1'b0,
            (rank < 7 && file > 0) ? southeast_out[square+7] : 1'b0
        };

        wire knight_attacks = |{
            (rank < 6 && file < 7) ? knight[square+17] : 1'b0,
            (rank < 7 && file < 6) ? knight[square+10] : 1'b0,
            (rank > 0 && file > 1) ? knight[square-10] : 1'b0,
            (rank > 1 && file > 0) ? knight[square-17] : 1'b0,
            (rank > 1 && file < 7) ? knight[square-15] : 1'b0,
            (rank > 0 && file < 6) ? knight[square-6]  : 1'b0,
            (rank < 7 && file > 1) ? knight[square+6]  : 1'b0,
            (rank < 6 && file > 0) ? knight[square+15] : 1'b0
        };

        wire king_attacks = |{
            (rank < 7) ? king[square+8] : 1'b0,
            (file < 7) ? king[square+1] : 1'b0,
            (rank > 0) ? king[square-8] : 1'b0,
            (file > 0) ? king[square-1] : 1'b0,
            (rank < 7 && file < 7) ? king[square+9] : 1'b0,
            (rank > 0 && file < 7) ? king[square-7] : 1'b0,
            (rank > 0 && file > 0) ? king[square-9] : 1'b0,
            (rank < 7 && file > 0) ? king[square+7] : 1'b0
        };

        wire wpawn_attacks = |{
            (rank > 0 && file < 7) ? wpawn_cap[square-7] : 1'b0,
            (rank > 0 && file > 0) ? wpawn_cap[square-9] : 1'b0
        };

        wire bpawn_attacks = |{
            (rank < 7 && file < 7) ? bpawn_cap[square+9] : 1'b0,
            (rank < 7 && file > 0) ? bpawn_cap[square+7] : 1'b0
        };

        recv receiver (
            .piece_reg(piece_reg[4*square +: 4]),
            .op(op),
            .wtm(wtm),
            .enable_reg(enable_reg[square]),
            .manhattan(manhattan_attacks),
            .diagonal(diagonal_attacks),
            .knight(knight_attacks),
            .king(king_attacks),
            .wpawn_1sq((rank > 0) ? wpawn_1sq[square-8] : 1'b0),
            .wpawn_2sq((rank > 1) ? wpawn_2sq[square-16] : 1'b0),
            .wpawn_cap(wpawn_attacks),
            .bpawn_1sq((rank < 7) ? bpawn_1sq[square+8] : 1'b0),
            .bpawn_2sq((rank < 6) ? bpawn_2sq[square+16] : 1'b0),
            .bpawn_cap(bpawn_attacks),
            .priority_(priority_[3*square +: 3]),
            .illegal(illegal[square])
        );
    end
endgenerate

assign data_out[7] = |illegal;

arb arbitrator (
    .priority_(priority_),
    .data_out(data_out[6:0])
);

// Commands:
// 0b111W____: FIND-AGGRESSOR, W is 1 if black to move; transmitter to select in data
// 0b110W____: FIND-VICTIM, W is 1 if black to move
// 0b10NNNNNN: SET-ENABLE, N is the square to set; value to set in data
// 0b011_____: ENABLE-ALL
// 0b010W____: ENABLE-COLOR, W is 1 if black
// 0b00NNNNNN: SET-PIECE, N is the square to set; value to set in data

reg [1:0] state;
always @(posedge clk) begin
    if (!rst_n) begin
        piece_reg  <= ~256'b0;
        enable_reg <= ~64'b0;
        op         <= 0;
        wtm        <= 0;
        xmit_addr  <= 0;
        state      <= 0;
    end else begin
        casez (state)
        0: begin
            casez (addr[7:4])
            4'b111?: begin
                op        <= addr[4];
                wtm       <= data_in[0];
                xmit_addr <= ({addr[1:0], data_in[7:4]});
            end
            4'b1101:
                enable_reg[{addr[1:0], data_in[7:4]}] <= data_in[0];
            4'b1100:
                enable_reg <= ~64'd0;
            4'b1011:
                piece_reg[4*({addr[1:0], data_in[7:4]}) +: 4] <= data_in[3:0];
            4'b1010: begin
            end
            4'b1001:
                enable_reg <= enable_reg | black;
            4'b1000:
                enable_reg <= enable_reg | white;
            4'b0111:
                ;
            4'b0110:
                ;
            4'b0101:
                ; // data_out <= {4'b0, piece_reg[4*({addr[1:0], data_in[7:4]}) +: 4]};
            4'b0100:
                /* reserved for future expansion */;
            4'b00??:
                /* NO-OP */;
            endcase
        end
        1: begin
        end
        2: begin
        end
        3: begin
        end
        endcase
    end
end

endmodule
