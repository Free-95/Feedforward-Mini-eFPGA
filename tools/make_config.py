#!/usr/bin/env python3
"""Create a 296-bit serial programming image for this proposed mini-eFPGA map.

Usage:
    python tools/make_config.py --example and_xor
    python tools/make_config.py --example registered_feedback
    python tools/make_config.py --example counter4

Generates config_*.hex and config_*.bits in the current directory.
The .bits file is a string of 296 bits, sent left to right (MSB first).
"""
from argparse import ArgumentParser
from pathlib import Path

CONFIG_BITS = 296
CLB_BITS = 17
S1_ROUTE_BASE = 136
S2_ROUTE_BASE = 200
OUTPUT_BASE = 264


def insert(cfg: int, offset: int, width: int, value: int) -> int:
    if not (0 <= value < 1 << width):
        raise ValueError(f"value {value} does not fit in {width} bits")
    if offset < 0 or offset + width > CONFIG_BITS:
        raise ValueError(f"out-of-range configuration slice {offset}:{offset+width-1}")
    mask = ((1 << width) - 1) << offset
    return (cfg & ~mask) | (value << offset)


class EfpgaConfig:
    def __init__(self) -> None:
        self.word = 0

    def clb(self, index: int, lut_truth: int, use_ff: bool = False) -> None:
        if index not in range(8):
            raise ValueError("CLB index must be 0..7")
        self.word = insert(self.word, index * CLB_BITS, 17,
                           lut_truth | (int(use_ff) << 16))

    def route(self, stage: int, clb_within_stage: int, lut_pin: int,
              source: int) -> None:
        if stage not in (1, 2) or clb_within_stage not in range(4) or lut_pin not in range(4):
            raise ValueError("stage=1/2, clb=0..3 within stage, LUT pin=0..3")
        base = S1_ROUTE_BASE if stage == 1 else S2_ROUTE_BASE
        self.word = insert(self.word, base + 4 * (clb_within_stage*4 + lut_pin), 4, source)

    def output(self, output_pin: int, source: int) -> None:
        if output_pin not in range(8):
            raise ValueError("output index must be 0..7")
        self.word = insert(self.word, OUTPUT_BASE + output_pin*4, 4, source)

    def shift_bits(self) -> str:
        # Shift-chain RTL: cfg_bits <= {cfg_bits[294:0], cfg_sin}
        return ''.join(str((self.word >> b) & 1) for b in range(295, -1, -1))


def example(name: str) -> EfpgaConfig:
    c = EfpgaConfig()
    if name == 'and_xor':
        c.clb(0, 0x8888)  # A & B
        c.clb(1, 0x6666)  # A ^ B
        c.clb(4, 0x6666)  # CLB0 ^ CLB1
        for clb in (0, 1):
            c.route(1, clb, 0, 0)  # ui_in[0]
            c.route(1, clb, 1, 1)  # ui_in[1]
        c.route(2, 0, 0, 9)  # Stage1 CLB0
        c.route(2, 0, 1, 10) # Stage1 CLB1
        c.output(0, 0)
        c.output(1, 1)
        c.output(2, 4)
    elif name == 'registered_feedback':
        c.clb(0, 0xAAAA)  # pass lut_in[0]
        c.clb(4, 0x6666, use_ff=True)  # registered XOR
        c.route(1, 0, 0, 9)  # Stage2 Q0 feedback
        c.route(2, 0, 0, 0)
        c.route(2, 0, 1, 1)
        c.output(0, 0)
        c.output(4, 4)
    elif name == 'counter4':
        # Stage2 CLB4..7 hold the 4 counter bits (Q0..Q3).
        # Stage1 CLB0..3 compute next state from Q0..Q3.
        # next[0] = ~Q0
        # next[1] = Q1 XOR Q0
        # next[2] = Q2 XOR (Q0 & Q1)
        # next[3] = Q3 XOR (Q0 & Q1 & Q2)
        def table(func):
            return sum((1 << i) if func([(i >> b) & 1 for b in range(4)]) else 0
                       for i in range(16))
        truths = [
            table(lambda b: not b[0]),
            table(lambda b: b[1] ^ b[0]),
            table(lambda b: b[2] ^ (b[0] & b[1])),
            table(lambda b: b[3] ^ (b[0] & b[1] & b[2])),
        ]
        for ci in range(4):
            c.clb(ci, truths[ci])
            # Read old counter bits only through Stage2 FF Q.
            for pin in range(ci + 1):
                c.route(1, ci, pin, 9 + pin)
            c.clb(ci + 4, 0xAAAA, use_ff=True)  # pass Stage1 result, register
            c.route(2, ci, 0, 9 + ci)          # Stage1 CLBci
            c.output(ci, ci + 4)              # uo_out[ci] -> Stage2 Qci
            c.output(ci + 4, ci + 4)          # duplicate counter on uo_out[7:4]
    else:
        raise ValueError(f"unknown example: {name}")
    return c


def validate_model() -> None:
    # With 296 MSB-first shifts, the image should occupy the cfg register exactly.
    for name in ('and_xor', 'registered_feedback', 'counter4'):
        c = example(name)
        shift = 0
        for bit in c.shift_bits():
            shift = ((shift << 1) & ((1 << CONFIG_BITS) - 1)) | int(bit)
        assert shift == c.word, name
    assert len(example('and_xor').shift_bits()) == 296
    assert (example('registered_feedback').word >> 16) & 1 == 0
    assert (example('registered_feedback').word >> (4*17+16)) & 1 == 1
    print('PASS: 296-bit map and serial shift-order self-check')


if __name__ == '__main__':
    ap = ArgumentParser()
    ap.add_argument('--example', choices=['and_xor', 'registered_feedback', 'counter4'], default='and_xor')
    args = ap.parse_args()
    validate_model()
    config = example(args.example)
    name = f'config_{args.example}'
    Path(f'{name}.hex').write_text(f'{config.word:074x}\n', encoding='utf-8')
    Path(f'{name}.bits').write_text(config.shift_bits() + '\n', encoding='utf-8')
    print(f'Wrote {name}.hex (74 hex digits) and {name}.bits (296 MSB-first bits)')
