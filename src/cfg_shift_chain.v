`timescale 1ns/1ps
`default_nettype none
// 296 shift bits: serial input goes into bit 0; old bit 295 is serial out.
// Send desired config bits from 295 down to 0, one on each cfg_sclk posedge.
// cfg_prog_n low = programming; high = run (hold configuration).
module cfg_shift_chain (
    input  wire rst_n,
    input  wire ena,
    input  wire cfg_sclk,
    input  wire cfg_prog_n,
    input  wire cfg_sin,
    output wire cfg_sout,
    output reg  [295:0] cfg_bits
);
    always @(posedge cfg_sclk or negedge rst_n) begin
        if (!rst_n)
            cfg_bits <= 296'b0;
        else if (ena && !cfg_prog_n)
            cfg_bits <= {cfg_bits[294:0], cfg_sin};
    end
    assign cfg_sout = cfg_bits[295];
endmodule
`default_nettype wire
