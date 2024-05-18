# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

from gc import enable
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):

    WKNIGHT = 1
    WBISHOP = 2
    WROOK = 3
    WQUEEN = 4
    WKING = 5

    async def find_aggressor(square):
        dut.ui_in.value = 0b1111_0000 | (square >> 4)
        dut.uio_in.value = (square & 15) << 4
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 0b00000000
        await ClockCycles(dut.clk, 9)

    async def find_victim():
        dut.ui_in.value = 0b1110_0000
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 0b00000000
        await ClockCycles(dut.clk, 9)

    async def set_enable(square, value):
        dut.ui_in.value = 0b1101_0000 | (square >> 4)
        dut.uio_in.value = ((square & 15) << 4) | value
        await ClockCycles(dut.clk, 1)

    async def enable_all():
        dut.ui_in.value = 0b1100_0000
        await ClockCycles(dut.clk, 1)

    async def set_piece(square, value):
        dut.ui_in.value = 0b1011_0000 | (square >> 4)
        dut.uio_in.value = ((square & 15) << 4) | value
        await ClockCycles(dut.clk, 1)

    async def rotate_board():
        dut.ui_in.value = 0b1010_0000
        await ClockCycles(dut.clk, 1)

    async def enable_friendly():
        dut.ui_in.value = 0b1000_0000
        await ClockCycles(dut.clk, 1)

    async def tb_reset():
        dut.ena.value = 1
        dut.ui_in.value = 0
        dut.uio_in.value = 0
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 10)
        dut.rst_n.value = 1
        for square in range(64):
            await set_piece(square, 0xF)
        await enable_all()

    async def tb_square_loop():
        await enable_all()
        squares = []
        for _ in range(2):
            while True:
                await find_victim()
                dst = int(dut.uo_out.value)
                #dut._log.info("dst: {}".format(dst))
                if dst & 64:
                    break
                squares.append(dst)
                while True:
                    await find_aggressor(dst)
                    src = int(dut.uo_out.value)
                    #dut._log.info("src: {}".format(src))
                    if src & 64:
                        break
                    await set_enable(src, 0)
                await enable_friendly()
                await set_enable(dst, 0)
            await rotate_board()
            #dut._log.info("(rotating)")

        return squares

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

    await tb_reset()

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

        await enable_all()
        await set_piece(sq, WKING)
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
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
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
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
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
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
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
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
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, 0xF)
