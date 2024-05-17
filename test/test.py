# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):

    WHITE = 0
    BLACK = 1

    WKNIGHT = 1
    WBISHOP = 2
    WROOK = 3
    WQUEEN = 4
    WKING = 5

    D3 = 19
    E3 = 20
    F3 = 21
    D4 = 27
    E4 = 28
    F4 = 29
    D5 = 35
    E5 = 36
    F5 = 37

    async def find_aggressor(color, square):
        dut.ui_in.value = 0b1110_0000 | (color << 4)
        dut.uio_in.value = square
        await ClockCycles(dut.clk, 2)

    async def find_victim(color):
        dut.ui_in.value = 0b1100_0000 | (color << 4)
        await ClockCycles(dut.clk, 2)

    async def set_enable(square, value):
        dut.ui_in.value = 0b10_000000 | square
        dut.uio_in.value = value
        await ClockCycles(dut.clk, 1)

    async def enable_all():
        dut.ui_in.value = 0b0110_0000
        await ClockCycles(dut.clk, 1)

    async def enable_color(color):
        dut.ui_in.value = 0b0100_0000 | (color << 4)
        await ClockCycles(dut.clk, 1)

    async def set_piece(square, value):
        dut.ui_in.value = 0b00_000000 | square
        dut.uio_in.value = value
        await ClockCycles(dut.clk, 1)

    async def tb_no_more_moves():
        assert dut.uo_out.value == 0x40

    async def tb_expect_move_white(src, dst):
        await find_victim(WHITE)
        assert dut.uo_out.value == dst # victim square
        await find_aggressor(WHITE, dst)
        assert dut.uo_out.value == src # aggressor square
        await set_enable(src, 0)
        await find_aggressor(WHITE, dst)
        await tb_no_more_moves()
        await set_enable(dst, 0)
        await enable_color(WHITE)

    async def tb_expect_move_black(src, dst):
        await find_victim(BLACK)
        assert dut.uo_out.value == dst # victim square
        await find_aggressor(BLACK, dst)
        assert dut.uo_out.value == src # aggressor square
        await set_enable(src, 0)
        await find_aggressor(BLACK, dst)
        await tb_no_more_moves()
        await set_enable(dst, 0)
        await enable_color(BLACK)

    dut._log.info("Start")

    clock = Clock(dut.clk, 1, units="ns")
    cocotb.start_soon(clock.start())

    dut._log.info("king on empty board")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 1)
    dut.rst_n.value = 1

    for sq in range(128):
        if sq & 0x88:
            continue

        expected = []
        for offset in [1, 15, 16, 17, -1, -15, -16, -17]:
            offset += sq
            if offset & 0x88:
                continue
            expected.append((offset + (offset & 7)) >> 1)
        expected.sort()

        sq = (sq + (sq & 7)) >> 1

        print(sq, expected)

        await enable_all()
        await set_piece(sq, WKING)
        for esq in expected:
            await tb_expect_move_white(sq, esq)
        await tb_no_more_moves()

        await enable_all()
        await set_piece(sq, WKING + 8)
        for esq in expected:
            await tb_expect_move_black(sq, esq)
        await tb_no_more_moves()

        await set_piece(sq, 0xF)

    dut._log.info("queen on empty board")

    for sq in range(128):
        if sq & 0x88:
            continue

        expected = []
        for offset in [1, 15, 16, 17, -1, -15, -16, -17]:
            s = sq
            while True:
                s += offset
                if s & 0x88:
                    break
                expected.append((s + (s & 7)) >> 1)
        expected.sort()

        sq = (sq + (sq & 7)) >> 1

        print(sq, expected)

        await enable_all()
        await set_piece(sq, WQUEEN)
        for esq in expected:
            await tb_expect_move_white(sq, esq)
        await tb_no_more_moves()

        await enable_all()
        await set_piece(sq, WQUEEN + 8)
        for esq in expected:
            await tb_expect_move_black(sq, esq)
        await tb_no_more_moves()

        await set_piece(sq, 0xF)

    dut._log.info("rook on empty board")

    for sq in range(128):
        if sq & 0x88:
            continue

        expected = []
        for offset in [1, 16, -1, -16]:
            s = sq
            while True:
                s += offset
                if s & 0x88:
                    break
                expected.append((s + (s & 7)) >> 1)
        expected.sort()

        sq = (sq + (sq & 7)) >> 1

        print(sq, expected)

        await enable_all()
        await set_piece(sq, WROOK)
        for esq in expected:
            await tb_expect_move_white(sq, esq)
        await tb_no_more_moves()

        await enable_all()
        await set_piece(sq, WROOK + 8)
        for esq in expected:
            await tb_expect_move_black(sq, esq)
        await tb_no_more_moves()

        await set_piece(sq, 0xF)

    dut._log.info("bishop on empty board")

    for sq in range(128):
        if sq & 0x88:
            continue

        expected = []
        for offset in [15, 17, -15, -17]:
            s = sq
            while True:
                s += offset
                if s & 0x88:
                    break
                expected.append((s + (s & 7)) >> 1)
        expected.sort()

        sq = (sq + (sq & 7)) >> 1

        print(sq, expected)

        await enable_all()
        await set_piece(sq, WBISHOP)
        for esq in expected:
            await tb_expect_move_white(sq, esq)
        await tb_no_more_moves()

        await enable_all()
        await set_piece(sq, WBISHOP + 8)
        for esq in expected:
            await tb_expect_move_black(sq, esq)
        await tb_no_more_moves()

        await set_piece(sq, 0xF)

    dut._log.info("knight on empty board")

    for sq in range(128):
        if sq & 0x88:
            continue

        expected = []
        for offset in [33, 18, -18, -33, -31, -14, 14, 31]:
            offset += sq
            if offset & 0x88:
                continue
            expected.append((offset + (offset & 7)) >> 1)
        expected.sort()

        sq = (sq + (sq & 7)) >> 1

        print(sq, expected)

        await enable_all()
        await set_piece(sq, WKNIGHT)
        for esq in expected:
            await tb_expect_move_white(sq, esq)
        await tb_no_more_moves()

        await enable_all()
        await set_piece(sq, WKNIGHT + 8)
        for esq in expected:
            await tb_expect_move_black(sq, esq)
        await tb_no_more_moves()

        await set_piece(sq, 0xF)
