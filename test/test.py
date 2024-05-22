# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

from gc import enable
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


#@cocotb.test()
async def test_project(dut):

    moves = 0

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
        await ClockCycles(dut.clk, 1)

    async def find_victim():
        dut.ui_in.value = 0b1110_0000
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 0b00000000
        await ClockCycles(dut.clk, 1)

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

    async def tb_square_loop():
        await enable_all()
        squares = []
        while True:
            await find_victim()
            dst = int(dut.uo_out.value)
            if dst & 64:
                break
            squares.append(dst)
            while True:
                await find_aggressor(dst)
                src = int(dut.uo_out.value) 
                if src & 64:
                    break
                await set_enable(src, 0)
            await enable_friendly()
            await set_enable(dst, 0)

        return squares

    dut._log.info("Start")

    clock = Clock(dut.clk, 1, units="ns")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    dut._log.info("king on empty board")

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

        await set_piece(sq, WKING)
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, 0xF)

        moves += len(actual)

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

        await set_piece(sq, WQUEEN)
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, 0xF)

        moves += len(actual)

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

        await set_piece(sq, WROOK)
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, 0xF)

        moves += len(actual)

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

        await set_piece(sq, WBISHOP)
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, 0xF)

        moves += len(actual)

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

        await set_piece(sq, WKNIGHT)
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, 0xF)

        moves += len(actual)

    dut._log.info("computed {} moves".format(moves))

@cocotb.test()
async def kiwipete(dut):

    moves = 0

    WPAWN = 0
    WKNIGHT = 1
    WBISHOP = 2
    WROOK = 3
    WQUEEN = 4
    WKING = 5
    BPAWN = 8
    BKNIGHT = 9
    BBISHOP = 10
    BROOK = 11
    BQUEEN = 12
    BKING = 13
    EMPTY = 15

    async def find_aggressor(square):
        dut.ui_in.value = 0b1111_0000 | (square >> 4)
        dut.uio_in.value = (square & 15) << 4
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 0b00000000
        await ClockCycles(dut.clk, 1)

    async def find_victim():
        dut.ui_in.value = 0b1110_0000
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 0b00000000
        await ClockCycles(dut.clk, 1)

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

    async def rotate_board(pawn_inhibit):
        dut.ui_in.value = 0b1010_0000 
        dut.uio_in.value = pawn_inhibit
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

    async def tb_square_loop():
        await enable_all()
        squares = []
        while True:
            await find_victim()
            dst = int(dut.uo_out.value)
            assert not (dst & 128)
            if dst & 64:
                break
            print("dst: {}{}".format(chr(ord('a')+(dst%8)), chr(ord('1')+(dst//8))))
            while True:
                await find_aggressor(dst)
                src = int(dut.uo_out.value)
                assert not (src & 128)
                if src & 64:
                    break
                print("  src: {}{}".format(chr(ord('a')+(src%8)), chr(ord('1')+(src//8))))
                squares.append((src, dst))
                await set_enable(src, 0)
            await enable_friendly()
            await set_enable(dst, 0)
        return squares

    dut._log.info("Start")

    clock = Clock(dut.clk, 1, units="ns")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    await set_piece(0,  WROOK)
    await set_piece(4,  WKING)
    await set_piece(7,  WROOK)
    await set_piece(8,  WPAWN)
    await set_piece(9,  WPAWN)
    await set_piece(10, WPAWN)
    await set_piece(11, WBISHOP)
    await set_piece(12, WBISHOP)
    await set_piece(13, WPAWN)
    await set_piece(14, WPAWN)
    await set_piece(15, WPAWN)
    await set_piece(18, WKNIGHT)
    await set_piece(21, WQUEEN)
    await set_piece(23, BPAWN)
    await set_piece(25, BPAWN)
    await set_piece(28, WPAWN)
    await set_piece(35, WPAWN)
    await set_piece(36, WKNIGHT)
    await set_piece(40, BBISHOP)
    await set_piece(41, BKNIGHT)
    await set_piece(44, BPAWN)
    await set_piece(45, BKNIGHT)
    await set_piece(46, BPAWN)
    await set_piece(48, BPAWN)
    await set_piece(50, BPAWN)
    await set_piece(51, BPAWN)
    await set_piece(52, BQUEEN)
    await set_piece(53, BPAWN)
    await set_piece(54, BBISHOP)
    await set_piece(56, BROOK)
    await set_piece(60, BKING)
    await set_piece(63, BROOK)

    actual = await tb_square_loop()

    #actual.sort()
    print(actual)
    print(len(actual))

    assert actual == [(12, 40), (21, 45), (14, 23), (21, 23), (35, 44), (36, 46), (36, 51), (36, 53), (18, 1), (0, 1), (11, 2), (0, 2), (18, 3), (12, 3), (0, 3), (4, 3), (12, 5), (7, 5), (4, 5), (7, 6), (8, 16), (9, 17), (36, 19), (12, 19), (21, 19), (11, 20), (21, 20), (14, 22), (21, 22), (18, 24), (36, 26), (12, 26), (11, 29), (21, 29), (36, 30), (21, 30), (25, 33), (18, 33), (12, 33), (21, 37), (11, 38), (21, 39), (36, 42), (35, 43), (11, 47)]
