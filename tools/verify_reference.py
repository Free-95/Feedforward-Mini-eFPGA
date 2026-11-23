#!/usr/bin/env python3
"""Pure Python reference model sanity checks (NOT a Verilog simulation)."""
from make_config import example, CONFIG_BITS


def field(word: int, offset: int, width: int) -> int:
    return (word >> offset) & ((1 << width) - 1)


def comb_eval(config: int, fab_in: int, ext: int = 0, q_stage2: int = 0):
    stage1, stage2 = [], []

    def route(sel, prev):
        if 0 <= sel < 8:
            return (fab_in >> sel) & 1
        if sel == 8:
            return ext & 1
        if 9 <= sel <= 12:
            return (prev >> (sel - 9)) & 1
        return 0

    def clb(c, values, q):
        lut = field(config, 17*c, 16)
        use_ff = field(config, 17*c+16, 1)
        index = sum((v & 1) << i for i, v in enumerate(values))
        d = (lut >> index) & 1
        return ((q if use_ff else d), d)

    for c in range(4):
        pins = [route(field(config, 136+4*(4*c+p), 4), q_stage2) for p in range(4)]
        y, _ = clb(c, pins, 0)
        stage1.append(y)
    stage1_bus = sum(bit << i for i, bit in enumerate(stage1))
    stage2_d = []
    for c in range(4):
        pins = [route(field(config, 200+4*(4*c+p), 4), stage1_bus) for p in range(4)]
        y, d = clb(c+4, pins, (q_stage2 >> c) & 1)
        stage2.append(y)
        stage2_d.append(d)
    clb_bus = stage1_bus | sum(bit << (i+4) for i, bit in enumerate(stage2))
    outs = 0
    for o in range(8):
        sel = field(config, 264+4*o, 4)
        v = (clb_bus >> sel) & 1 if sel < 8 else (fab_in >> (sel-8)) & 1
        outs |= v << o
    return outs, sum(v << i for i, v in enumerate(stage2_d))


def run():
    c = example('and_xor')
    for a in range(4):
        y, _ = comb_eval(c.word, a)
        x0, x1 = (a & 1), ((a >> 1) & 1)
        expected = ((x0 & x1) << 0) | ((x0 ^ x1) << 1) | (((x0 & x1) ^ (x0 ^ x1)) << 2)
        assert y & 7 == expected, f'comb expected {expected}, got {y & 7} at {a}'
    c = example('registered_feedback')
    y, d = comb_eval(c.word, 1, q_stage2=0)
    assert y & 0x11 == 0 and d & 1 == 1
    y, d = comb_eval(c.word, 3, q_stage2=1)
    assert y & 0x11 == 0x11 and d & 1 == 0
    assert 0 <= c.word < 1 << CONFIG_BITS
    print('PASS: independent Python configuration/functional reference checks')
    print('NOTE: These checks do not compile or run the Verilog RTL.')


if __name__ == '__main__':
    run()
