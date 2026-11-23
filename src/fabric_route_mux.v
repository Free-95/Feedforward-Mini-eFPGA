`timescale 1ns/1ps
`default_nettype none
// All 4-bit codes defined. Choices 13..15 drive zero, avoiding X/latches.
// 0..7  = fab_in[0..7]
// 8     = fab_in_ext (uio_in[6])
// 9..12 = from_prev[0..3]
// 13..15= constant zero
module fabric_route_mux (
    input  wire [7:0] fab_in,
    input  wire fab_in_ext,
    input  wire [3:0] from_prev,
    input  wire [3:0] sel,
    output reg  routed
);
    always @* begin
        case (sel)
             4'd0: routed = fab_in[0];
             4'd1: routed = fab_in[1];
             4'd2: routed = fab_in[2];
             4'd3: routed = fab_in[3];
             4'd4: routed = fab_in[4];
             4'd5: routed = fab_in[5];
             4'd6: routed = fab_in[6];
             4'd7: routed = fab_in[7];
             4'd8: routed = fab_in_ext;
             4'd9: routed = from_prev[0];
            4'd10: routed = from_prev[1];
            4'd11: routed = from_prev[2];
            4'd12: routed = from_prev[3];
            default: routed = 1'b0;
        endcase
    end
endmodule
`default_nettype wire
