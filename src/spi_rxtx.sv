/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 *
 * (Modified by Hannah Ravensloft to be Verilog)
 */

// Low-level SPI interface.
// Shifts 1 byte at a time.
// SCK period must be at least 2x clk period.
// No FIFOs nor CDC for low logic utilization.
// CPOL = 0, CPHA = 0

`default_nettype none

module spi_rxtx #(
    // Word width to shift in/out.
    parameter N_BITS = 8
)
(
    // Core clock and reset
    input  wire clk,
    input  wire rst_n,

    // SPI interface to pins
    input  wire sck,
    input  wire cs_n,
    input  wire [3:0] sdi,
    output wire [3:0] sdo,

    // Rx Data
    output reg [N_BITS-1:0] din,
    output reg din_valid,

    // Tx Data
    input  wire [N_BITS-1:0] dout,
    input  wire dout_valid,
    output reg dout_ack
);
    // Clock Edge detection and input regs.
    reg sck_r0, cs_r0;
    wire sck_rising;
    wire sck_falling;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            {sck_r0, cs_r0} <= '0;
        end
        else begin
            sck_r0 <= sck;
            cs_r0  <= cs_n;
        end
    end

    assign sck_rising  = (~sck_r0 & sck);
    assign sck_falling = (sck_r0 & ~sck) || (cs_r0 & ~cs_n);

    // Bit counter for byte-oriented 
    reg bit_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= 1;
        end
        else begin
            bit_count <= cs_n ? 1 : sck_rising ? bit_count - 1 : bit_count;
        end
    end

    // Shift data in.
    reg [N_BITS-1:0] sdi_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_valid <= '0;
        end
        else begin
            din_valid <= '0;
            sdi_r <= sdi;
            if(sck_rising) begin
                din <= sdi_r;
                din_valid <= bit_count;
            end
        end
    end

    // Shift data out.
    reg [N_BITS-1:0] dout_r;

    assign sdo = dout_r;

    always_comb begin
        if(!rst_n) begin
            dout_r   = 0;
            dout_ack = 0;
        end else begin
            dout_ack = 0;
            dout_r = 0;
            if (~cs_n) begin
                if (dout_valid)
                    dout_r = dout;
                
                if (sck_rising)
                    dout_ack = dout_valid;
            end
        end
    end

endmodule
