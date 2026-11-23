"""Cocotb 2.1 functional regression for the 8-CLB mini-eFPGA.

Run via `cd test && make SIM=icarus`. Config clock is manually toggled on
uio[3]; fabric clock is manually toggled on clk. Tests are fully automated.
"""
import sys
from pathlib import Path

import cocotb
from cocotb.triggers import Timer

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
from make_config import EfpgaConfig, example

CFG_BITS = 296
CFG_PROG_N = 1 << 0
CFG_SIN = 1 << 1
CFG_SCLK = 1 << 3
FAB_CLK_EN = 1 << 4
FAB_RST_N = 1 << 5
FAB_IN_EXT = 1 << 6
BASE = FAB_CLK_EN | FAB_RST_N


async def settle():
    await Timer(2, unit="ns")


async def init_dut(dut):
    dut.clk.value = 0
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = BASE | CFG_PROG_N
    await Timer(10, unit="ns")
    dut.rst_n.value = 1
    await settle()
    assert int(dut.uio_oe.value) == 0x84, "uio[2] and uio[7] must be outputs"


async def load_cfg(dut, config: int):
    assert 0 <= config < (1 << CFG_BITS)
    dut.uio_in.value = BASE  # programming mode: cfg_prog_n=0
    await settle()
    assert int(dut.uo_out.value) == 0, "fabric outputs must be masked while programming"
    assert int(dut.uio_out.value) & 0x80
    for pos in range(CFG_BITS - 1, -1, -1):
        bit = (config >> pos) & 1
        value = BASE | (CFG_SIN if bit else 0)
        dut.uio_in.value = value
        await settle()
        dut.uio_in.value = value | CFG_SCLK
        await settle()
        dut.uio_in.value = value
        await settle()
    dut.uio_in.value = BASE | CFG_PROG_N
    await settle()
    assert not (int(dut.uio_out.value) & 0x80), "cfg_active should deassert"


async def verify_readback(dut, config: int):
    """Read out all 296 bits while shifting the same bits back in."""
    dut.uio_in.value = BASE
    await settle()
    for pos in range(CFG_BITS - 1, -1, -1):
        expected = (config >> pos) & 1
        actual = (int(dut.uio_out.value) >> 2) & 1
        assert actual == expected, f"bitstream readback mismatch at bit {pos}"
        v = BASE | (CFG_SIN if expected else 0)
        dut.uio_in.value = v
        await settle()
        dut.uio_in.value = v | CFG_SCLK
        await settle()
        dut.uio_in.value = v
        await settle()
    dut.uio_in.value = BASE | CFG_PROG_N
    await settle()


async def reset_fabric(dut):
    dut.uio_in.value = BASE | CFG_PROG_N
    await settle()
    dut.uio_in.value = (BASE & ~FAB_RST_N) | CFG_PROG_N
    await settle()
    dut.uio_in.value = BASE | CFG_PROG_N
    await settle()


async def tick(dut):
    dut.clk.value = 0
    await settle()
    dut.clk.value = 1
    await settle()
    dut.clk.value = 0
    await settle()


@cocotb.test()
async def staged_logic_and_readback(dut):
    await init_dut(dut)
    config = example("and_xor").word
    await load_cfg(dut, config)
    await verify_readback(dut, config)
    for val in range(4):
        dut.ui_in.value = val
        await settle()
        a, b = val & 1, (val >> 1) & 1
        got = int(dut.uo_out.value) & 7
        exp = (a & b) | ((a ^ b) << 1) | (((a & b) ^ (a ^ b)) << 2)
        assert got == exp, f"AND/XOR failed for inputs {val:02b}: got {got:03b}"
    dut.ena.value = 0
    await settle()
    assert int(dut.uo_out.value) == 0, "ena must mask fabric outputs"
    dut.ena.value = 1
    await settle()
    dut._log.info("PASS: staged logic, 296-bit readback, ena masking")


@cocotb.test()
async def exhaustive_lut4_truth_table(dut):
    await init_dut(dut)
    config = EfpgaConfig()
    truth = 0xA96C
    config.clb(0, truth)
    for pin in range(4):
        config.route(1, 0, pin, pin)
    config.output(0, 0)
    await load_cfg(dut, config.word)
    for value in range(16):
        dut.ui_in.value = value
        await settle()
        got = int(dut.uo_out.value) & 1
        expected = (truth >> value) & 1
        assert got == expected, f"LUT4 address {value}: got {got}, expected {expected}"
    dut._log.info("PASS: exhaustive LUT4 truth table (16 input patterns)")


@cocotb.test()
async def register_enable_reset_and_feedback(dut):
    await init_dut(dut)
    await load_cfg(dut, example("registered_feedback").word)
    await reset_fabric(dut)
    dut.ui_in.value = 1
    await settle()
    assert int(dut.uo_out.value) & 0x11 == 0
    await tick(dut)
    assert int(dut.uo_out.value) & 0x11 == 0x11
    dut.ui_in.value = 3
    await settle()
    assert int(dut.uo_out.value) & 0x11 == 0x11
    dut.uio_in.value = CFG_PROG_N | FAB_RST_N  # disable fabric FF clock enable
    await tick(dut)
    assert int(dut.uo_out.value) & 0x11 == 0x11
    dut.uio_in.value = BASE | CFG_PROG_N
    await tick(dut)
    assert int(dut.uo_out.value) & 0x11 == 0x00
    # An operational reset must not erase the LUT/configuration bitstream.
    await reset_fabric(dut)
    dut.ui_in.value = 1
    await tick(dut)
    assert int(dut.uo_out.value) & 0x11 == 0x11
    dut._log.info("PASS: FF/reset/enable/feedback and persistent configuration")


@cocotb.test()
async def ninth_input_and_direct_output_routing(dut):
    await init_dut(dut)
    config = EfpgaConfig()
    config.clb(0, 0xAAAA)
    config.route(1, 0, 0, 8)  # ninth fabric input
    config.output(0, 0)
    for pin in range(1, 8):
        config.output(pin, 8 + pin)
    await load_cfg(dut, config.word)
    dut.ui_in.value = 0xA6
    dut.uio_in.value = BASE | CFG_PROG_N | FAB_IN_EXT
    await settle()
    got = int(dut.uo_out.value)
    exp = (0xA6 & 0xFE) | 1
    assert got == exp, f"external input/output routing: got {got:02x}, expected {exp:02x}"
    dut.uio_in.value = BASE | CFG_PROG_N
    await settle()
    assert (int(dut.uo_out.value) & 1) == 0
    dut._log.info("PASS: ninth fabric input and direct output mapping")


@cocotb.test()
async def four_bit_counter_wraparound(dut):
    await init_dut(dut)
    config = example("counter4").word
    await load_cfg(dut, config)
    await reset_fabric(dut)
    assert (int(dut.uo_out.value) & 0x0F) == 0
    for count in range(1, 33):
        await tick(dut)
        got = int(dut.uo_out.value) & 0x0F
        expected = count & 0x0F
        assert got == expected, f"counter tick {count}: got {got}, expected {expected}"
    # Freezing fabric clock enable must leave Q unchanged across clock edges.
    dut.uio_in.value = CFG_PROG_N | FAB_RST_N
    await tick(dut)
    assert (int(dut.uo_out.value) & 0x0F) == 0
    dut._log.info("PASS: 4-bit modulo-16 counter, 2 wraps and enable freeze")
