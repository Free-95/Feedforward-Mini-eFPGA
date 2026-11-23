`timescale 1ns/1ps
`default_nettype none
// Outputs: 0..7 select a CLB output, 8..15 select external fab_in[0..7].
module io_out_mapper (
    input  wire [7:0] fab_in,
    input  wire [7:0] clb_outputs,
    input  wire [3:0] sel,
    output wire routed_out
);
    assign routed_out = (sel < 4'd8) ? clb_outputs[sel[2:0]]
                                        : fab_in[sel[2:0]];
endmodule
`default_nettype wire
