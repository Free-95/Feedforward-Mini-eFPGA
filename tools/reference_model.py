#!/usr/bin/env python3
"""Cycle-level Python reference for the proposed 8-CLB fabric.

This is independent, executable logic to validate configuration examples. It is
NOT a substitute for simulation of the Verilog RTL.
"""
from make_config import CONFIG_BITS


def field(image: int, lo: int, width: int) -> int:
    return (image >> lo) & ((1 << width) - 1)


class FabricModel:
    def __init__(self, config: int = 0):
        self.load(config)

    def load(self, config: int):
        if not 0 <= config < (1 << CONFIG_BITS):
            raise ValueError("configuration image must be a 296-bit unsigned word")
        self.config = config
        self.q = [0] * 8

    def reset_operational(self):
        self.q = [0] * 8

    def _route(self, code: int, inputs: int, ext: int, prev: list[int]) -> int:
        if code <= 7:
            return (inputs >> code) & 1
        if code == 8:
            return ext & 1
        if code <= 12:
            return prev[code - 9]
        return 0

    def evaluate(self, inputs: int = 0, ext: int = 0):
        """Return (8 mapped outputs, 8 combinational D values) at current Q."""
        s1_out, d = [], []
        for ci in range(4):
            pins = [self._route(field(self.config, 136+4*(ci*4+pin), 4),
                                inputs, ext, self.q[4:8]) for pin in range(4)]
            lut_index = sum(bit << pin for pin, bit in enumerate(pins))
            lut = field(self.config, 17*ci, 16)
            di = (lut >> lut_index) & 1
            d.append(di)
            ff_mode = field(self.config, 17*ci+16, 1)
            s1_out.append(self.q[ci] if ff_mode else di)
        s2_out = []
        for ci in range(4):
            pins = [self._route(field(self.config, 200+4*(ci*4+pin), 4),
                                inputs, ext, s1_out) for pin in range(4)]
            lut_index = sum(bit << pin for pin, bit in enumerate(pins))
            lut = field(self.config, 17*(ci+4), 16)
            di = (lut >> lut_index) & 1
            d.append(di)
            ff_mode = field(self.config, 17*(ci+4)+16, 1)
            s2_out.append(self.q[ci+4] if ff_mode else di)
        selected = s1_out + s2_out
        outputs = 0
        for pin in range(8):
            source = field(self.config, 264+pin*4, 4)
            bit = selected[source] if source < 8 else (inputs >> (source-8)) & 1
            outputs |= bit << pin
        return outputs, d

    def tick(self, inputs: int = 0, ext: int = 0, clk_enable: bool = True):
        _, d = self.evaluate(inputs, ext)
        if clk_enable:
            self.q = d.copy()
        return self.evaluate(inputs, ext)[0]
