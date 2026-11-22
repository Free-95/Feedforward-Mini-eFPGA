# Feedforward Mini-eFPGA (8-CLB Fabric)

## How it works

A two-stage programmable logic fabric with eight CLBs. Each CLB has one LUT4
(16 truth-table bits) and an optional clocked flip-flop (one mode bit).
Stage 1 contains CLBs 0-3 and Stage 2 contains CLBs 4-7. Input-select multiplexers
can route fabric inputs to each LUT. Only the **registered** Stage 2 outputs
can feed back to Stage 1, preventing purely combinational feedback loops.

A 296-bit serial configuration register holds 136 CLB configuration bits,
64 Stage-1 routing bits, 64 Stage-2 routing bits, and 32 output-routing bits.
Configuration shifts MSB first on `cfg_sclk` while `cfg_prog_n` is low;
asserting `cfg_prog_n` high resumes fabric operation. This is a raw serial
configuration interface, *not* a fully decoded SPI slave protocol.

## Pin usage

* `ui_in[7:0]`: fabric inputs; `uo_out[7:0]`: mapped fabric outputs.
* `uio_in[0]` `cfg_prog_n` (active low programming),
  `[1]` `cfg_sin`, `[3]` `cfg_sclk`, `[4]` `fab_clk_en`,
  `[5]` `fab_rst_n`, `[6]` `fab_in_ext` (ninth input).
* `uio_out[2]` `cfg_sout`, `[7]` `cfg_active`; `uio_oe=8'b1000_0100`.
* `clk` is the fabric FF clock; `rst_n` resets the configuration chain.

## How to test

The Tiny Tapeout-style Cocotb smoke test is at `test/test.py`; run it with
`cd test && make` in an environment with Cocotb and Icarus Verilog installed.
There is also a standalone Vivado/XSIM testbench at
`verification/vivado/tb_efpga_8clb.sv` (include all seven `src/*.v` files).

Verification status: RTL simulation and synthesis have **not yet been run** in
this environment. The bit allocation is a proposed engineering mapping and
must be checked against the complete course specification before tapeout.

## External hardware

No external hardware is necessary for RTL simulation; hardware may be used
later for demonstration or post-silicon testing.
