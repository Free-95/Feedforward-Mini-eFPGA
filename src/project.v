`timescale 1ns/1ps
`default_nettype none
// Tiny Tapeout-style top level. Adapt module name as required by submission.
// ui_in[7:0] = fab_in[7:0]
// uio_in[0] cfg_prog_n, [1] cfg_sin, [3] cfg_sclk,
//        [4] fab_clk_en, [5] fab_rst_n, [6] fab_in_ext.
// uio_out[2] cfg_sout, [7] cfg_active. uio_oe = 8'b1000_0100.
// 296-bit map:
//   [135:0]   CLB 0..7, 17 bits each: {FF_select, LUT[15:0]}
//   [199:136] stage1 routing: 4 CLBs x 4 pins x 4 bits
//   [263:200] stage2 routing: 4 CLBs x 4 pins x 4 bits
//   [295:264] output routing: 8 outs x 4-bit selector
module tt_um_free95_efpga8clb (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire cfg_prog_n = uio_in[0];
    wire cfg_sin = uio_in[1];
    wire cfg_sclk = uio_in[3];
    wire fab_clk_en = uio_in[4] & cfg_prog_n & ena;
    wire fab_rst_n = rst_n & uio_in[5];
    wire fab_in_ext = uio_in[6];
    wire cfg_sout;
    wire [295:0] cfg;
    wire [3:0] s1_out, s1_q, s2_out, s2_q;
    wire [7:0] raw_outputs;
    wire [7:0] all_clb_outputs = {s2_out, s1_out};

    cfg_shift_chain u_cfg (
        .rst_n(rst_n), .ena(ena), .cfg_sclk(cfg_sclk),
        .cfg_prog_n(cfg_prog_n), .cfg_sin(cfg_sin),
        .cfg_sout(cfg_sout), .cfg_bits(cfg)
    );

    // IMPORTANT: Stage1 feedback reads only Stage2 FF Q, never Stage2 bypass.
    // This structurally prevents combinational loops across the two stages.
    genvar i, p;
    generate
        for (i = 0; i < 4; i = i + 1) begin : g_stage1
            wire [3:0] lut_pins;
            for (p = 0; p < 4; p = p + 1) begin : g_pin
                fabric_route_mux u_route (
                    .fab_in(ui_in), .fab_in_ext(fab_in_ext),
                    .from_prev(s2_q),
                    .sel(cfg[136 + ((i*4+p)*4) +: 4]),
                    .routed(lut_pins[p])
                );
            end
            clb u_clb (
                .clk(clk), .fab_rst_n(fab_rst_n),
                .fab_clk_en(fab_clk_en), .lut_in(lut_pins),
                .cfg_word(cfg[i*17 +: 17]),
                .clb_out(s1_out[i]), .ff_q(s1_q[i])
            );
        end
        for (i = 0; i < 4; i = i + 1) begin : g_stage2
            wire [3:0] lut_pins;
            for (p = 0; p < 4; p = p + 1) begin : g_pin
                fabric_route_mux u_route (
                    .fab_in(ui_in), .fab_in_ext(fab_in_ext),
                    .from_prev(s1_out),
                    .sel(cfg[200 + ((i*4+p)*4) +: 4]),
                    .routed(lut_pins[p])
                );
            end
            clb u_clb (
                .clk(clk), .fab_rst_n(fab_rst_n),
                .fab_clk_en(fab_clk_en), .lut_in(lut_pins),
                .cfg_word(cfg[(i+4)*17 +: 17]),
                .clb_out(s2_out[i]), .ff_q(s2_q[i])
            );
        end
        for (i = 0; i < 8; i = i + 1) begin : g_outputs
            io_out_mapper u_map (
                .fab_in(ui_in), .clb_outputs(all_clb_outputs),
                .sel(cfg[264 + i*4 +: 4]),
                .routed_out(raw_outputs[i])
            );
        end
    endgenerate

    // Freeze state updates and mask fabric outputs in configuration mode.
    assign uo_out = (ena && cfg_prog_n) ? raw_outputs : 8'h00;
    assign uio_out = {~cfg_prog_n, 4'b0000, cfg_sout, 2'b00};
    assign uio_oe  = 8'b1000_0100;
    // uio_in[2] and uio_in[7] are unused because those GPIOs are outputs.
    // Stage1 FF-Q bits are intentionally not used for Stage2 combinational routing.
endmodule
`default_nettype wire
