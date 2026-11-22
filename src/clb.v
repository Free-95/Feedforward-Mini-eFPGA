`timescale 1ns/1ps
`default_nettype none
// Config: {use_ff, 16-bit LUT truth table} (17 bits per CLB).
module clb (
    input  wire clk,
    input  wire fab_rst_n,
    input  wire fab_clk_en,
    input  wire [3:0] lut_in,
    input  wire [16:0] cfg_word,
    output wire clb_out,
    output wire ff_q
);
    wire lut_out;
    lut4_mux16 u_lut (
        .lut_in(lut_in),
        .lut_init(cfg_word[15:0]),
        .lut_out(lut_out)
    );
    dff_bypass u_ff (
        .clk(clk),
        .fab_rst_n(fab_rst_n),
        .fab_clk_en(fab_clk_en),
        .bypass_sel(cfg_word[16]),
        .d(lut_out),
        .q(ff_q),
        .y(clb_out)
    );
endmodule
`default_nettype wire
