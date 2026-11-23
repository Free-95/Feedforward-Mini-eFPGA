# Mini-eFPGA Verification Results

## Project
8-CLB Feedforward Mini-eFPGA

## RTL Simulation
Tool: Vivado XSim
Result: PASS (5/5 directed tests)

Tests:
- Combinational LUT and Stage-2 routing
- Flip-flop, reset, enable, and feedback
- Ninth fabric input and output mapping
- 4-bit counter wraparound
- Exhaustive LUT4 truth table

## Cocotb Verification
Simulator: Icarus Verilog
Result: PASS (5/5 tests)

## ASIC Verification
Technology: SKY130
- GDS physical implementation: PASS
- Tiny Tapeout precheck: PASS
- Gate-level simulation: PASS (5/5 tests)

## Pending
- GitHub Pages GDS viewer publication
- Final timing and clock-domain safety review

## GitHub Actions Evidence
https://github.com/Free-95/Feedforward-Mini-eFPGA/actions/runs/45176696945
