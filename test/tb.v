`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
  end

  // Wire up the inputs and outputs:
  reg  clk;
  reg  rst_n;
  reg  ena;

  wire [7:0] uio_in, uio_out, uio_oe, uo_out;

  reg  sck;
  reg  cs_n;
  wire [3:0] sdi;
  wire [3:0] sdo = uo_out[7:4];

  // Replace tt_um_example with your module name:
  tt_um_chess user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(1'b1),
      .VGND(1'b0),
`endif

      .ui_in  ({sdi[1:0], sck, cs_n, 4'b0}), // Dedicated inputs
      .uo_out (uo_out),                      // Dedicated outputs
      .uio_in ({6'b0, sdi[3:2]}),     // IOs: Input path
      .uio_out(uio_out),                     // IOs: Output path
      .uio_oe (uio_oe),                      // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),                         // enable - goes high when design is selected
      .clk    (clk),                         // clock
      .rst_n  (rst_n)                        // not reset
  );

endmodule
