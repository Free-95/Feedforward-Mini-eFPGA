`timescale 1ns/1ps
`default_nettype none
// DFF always samples the LUT result when enabled; output selects Q or bypass.
// fab_rst_n resets the operational state only, not the configuration bits.
module dff_bypass (
    input  wire clk,
    input  wire fab_rst_n,
    input  wire fab_clk_en,
    input  wire bypass_sel,    // 0: bypass combinational, 1: registered
    input  wire d,
    output reg  q,
    output wire y
);
    always @(posedge clk or negedge fab_rst_n) begin
        if (!fab_rst_n)
            q <= 1'b0;
        else if (fab_clk_en)
            q <= d;
    end
    assign y = bypass_sel ? q : d;
endmodule
`default_nettype wire
