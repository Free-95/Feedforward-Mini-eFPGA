`timescale 1ns/1ps
`default_nettype none
// LUT bit lut_init[{in3,in2,in1,in0}] is the combinational result.
module lut4_mux16 (
    input  wire [3:0] lut_in,
    input  wire [15:0] lut_init,
    output wire lut_out
);
    assign lut_out = lut_init[lut_in];
endmodule
`default_nettype wire
