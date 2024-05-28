/*
 * Copyright (c) 2024 Hannah Ravensloft
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

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
    input  wire [191:0] priority_,
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
