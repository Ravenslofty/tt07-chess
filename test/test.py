# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

from gc import enable
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    moves = 0

    WKNIGHT = 1
    WBISHOP = 2
    WROOK = 3
    WQUEEN = 4
    WKING = 5

    async def cs_start():
        dut.cs_n.value = 0

    async def cs_finish():
        dut.cs_n.value = 1
        dut.sck.value = 0
        dut.sdi.value = 0
        await ClockCycles(dut.clk, 1)

    async def spi_transfer_nocs(sdi):
        assert sdi <= 0xF
        sdo = 0
        dut.sck.value = 0
        dut.sdi.value = sdi
        await ClockCycles(dut.clk, 1)
        dut.sck.value = 1
        await ClockCycles(dut.clk, 1)
        sdo = int(dut.sdo.value)
        #print("SPI transfer: in {:04b}, out {:04b}".format(sdi, sdo))
        return sdo

    async def spi_transfer(sdi):
        await cs_start()
        sdo = await spi_transfer_nocs(sdi)
        await cs_finish()
        return sdo

    async def find_aggressor(sq=None):
        #print("FIND AGGRESSOR [{}]".format(sq))
        await cs_start()
        if sq is not None:
            await spi_transfer_nocs(0b0011)
            await spi_transfer_nocs(sq >> 4)
            await spi_transfer_nocs(sq & 0xF)
        await spi_transfer_nocs(0b1110)
        await spi_transfer_nocs(0b0000)
        sq = (await spi_transfer_nocs(0b0000)) << 4
        sq |= (await spi_transfer_nocs(0b0000))
        await cs_finish()
        return sq

    async def find_victim():
        #print("FIND VICTIM")
        await cs_start()
        await spi_transfer_nocs(0b1111)
        await spi_transfer_nocs(0b0000)
        sq = (await spi_transfer_nocs(0b0000)) << 4
        sq |= (await spi_transfer_nocs(0b0000))
        await cs_finish()
        return sq

    async def enable_all():
        #print("ENABLE ALL")
        await spi_transfer(0b1100)

    async def set_piece(sq, value):
        await spi_transfer(0b0011)
        await spi_transfer(sq >> 4)
        await spi_transfer(sq & 0xF)
        await spi_transfer(0b1011)
        await spi_transfer(value)

    async def disable_aggressor(sq=None):
        #print("DISABLE AGGRESSOR [{}]".format(sq))
        if sq is not None:
            await spi_transfer(0b0011)
            await spi_transfer(sq >> 4)
            await spi_transfer(sq & 0xF)
        await spi_transfer(0b1001)

    async def enable_friendly(sq=None):
        if sq is not None:
            await spi_transfer(0b0011)
            await spi_transfer(sq >> 4)
            await spi_transfer(sq & 0xF)
        await spi_transfer(0b1000)

    async def white_to_move():
        await spi_transfer(0b0001)
        await spi_transfer(0b0100)

    async def black_to_move():
        await spi_transfer(0b0001)
        await spi_transfer(0b0101)

    async def tb_square_loop():
        await enable_all()
        squares = []
        while True:
            dst = await find_victim()
            assert not (dst & 128)
            if dst & 64:
                break
            #print("dst: {}{}".format(chr(ord('a')+(dst%8)), chr(ord('1')+(dst//8))))
            while True:
                src = await find_aggressor()
                assert not (src & 128)
                if src & 64:
                    break
                #print("  src: {}{}".format(chr(ord('a')+(src%8)), chr(ord('1')+(src//8))))
                squares.append(dst)
            await enable_friendly()
        return squares

    dut._log.info("Start")

    clock = Clock(dut.clk, 1, units="ns")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.sck.value = 0
    dut.cs_n.value = 1
    dut.sdi.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)
    
    dut._log.info("king on empty board")

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
        await white_to_move()
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, WKING + 8)
        await black_to_move()
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
        await white_to_move()
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, WQUEEN + 8)
        await black_to_move()
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
        await white_to_move()
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, WROOK + 8)
        await black_to_move()
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
        await white_to_move()
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, WBISHOP + 8)
        await black_to_move()
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
        await white_to_move()
        actual = await tb_square_loop()
        actual.sort()
        print(sq, expected, actual)
        assert actual == expected
        await set_piece(sq, WKNIGHT + 8)
        await black_to_move()
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

    async def cs_start():
        dut.cs_n.value = 0

    async def cs_finish():
        dut.cs_n.value = 1
        dut.sck.value = 0
        dut.sdi.value = 0
        await ClockCycles(dut.clk, 1)

    async def spi_transfer_nocs(sdi):
        assert sdi <= 0xF
        sdo = 0
        dut.sck.value = 0
        dut.sdi.value = sdi
        await ClockCycles(dut.clk, 1)
        dut.sck.value = 1
        await ClockCycles(dut.clk, 1)
        sdo = int(dut.sdo.value)
        #print("SPI transfer: in {:04b}, out {:04b}".format(sdi, sdo))
        return sdo

    async def spi_transfer(sdi):
        await cs_start()
        sdo = await spi_transfer_nocs(sdi)
        await cs_finish()
        return sdo

    async def find_aggressor(sq=None):
        #print("FIND AGGRESSOR [{}]".format(sq))
        await cs_start()
        if sq is not None:
            await spi_transfer_nocs(0b0011)
            await spi_transfer_nocs(sq >> 4)
            await spi_transfer_nocs(sq & 0xF)
        await spi_transfer_nocs(0b1110)
        await spi_transfer_nocs(0b0000)
        sq = (await spi_transfer_nocs(0b0000)) << 4
        sq |= (await spi_transfer_nocs(0b0000))
        await cs_finish()
        return sq

    async def find_victim():
        #print("FIND VICTIM")
        await cs_start()
        await spi_transfer_nocs(0b1111)
        await spi_transfer_nocs(0b0000)
        sq = (await spi_transfer_nocs(0b0000)) << 4
        sq |= (await spi_transfer_nocs(0b0000))
        await cs_finish()
        return sq

    async def enable_all():
        #print("ENABLE ALL")
        await spi_transfer(0b1100)

    async def set_piece(sq, value):
        await spi_transfer(0b0011)
        await spi_transfer(sq >> 4)
        await spi_transfer(sq & 0xF)
        await spi_transfer(0b1011)
        await spi_transfer(value)

    async def disable_aggressor(sq=None):
        #print("DISABLE AGGRESSOR [{}]".format(sq))
        if sq is not None:
            await spi_transfer(0b0011)
            await spi_transfer(sq >> 4)
            await spi_transfer(sq & 0xF)
        await spi_transfer(0b1001)

    async def enable_friendly(sq=None):
        if sq is not None:
            await spi_transfer(0b0011)
            await spi_transfer(sq >> 4)
            await spi_transfer(sq & 0xF)
        await spi_transfer(0b1000)

    async def white_to_move():
        await spi_transfer(0b0001)
        await spi_transfer(0b0100)

    async def black_to_move():
        await spi_transfer(0b0001)
        await spi_transfer(0b0101)

    async def tb_square_loop():
        await enable_all()
        squares = []
        while True:
            dst = await find_victim()
            assert not (dst & 128)
            if dst & 64:
                break
            print("dst: {}{}".format(chr(ord('a')+(dst%8)), chr(ord('1')+(dst//8))))
            while True:
                src = await find_aggressor()
                assert not (src & 128)
                if src & 64:
                    break
                assert src != 5
                print("  src: {}{}".format(chr(ord('a')+(src%8)), chr(ord('1')+(src//8))))
                squares.append((src, dst))
            await enable_friendly()
        return squares

    clock = Clock(dut.clk, 1, units="ns")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.sck.value = 0
    dut.cs_n.value = 1
    dut.sdi.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

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
    await white_to_move()

    dut._log.info("Start")

    actual = await tb_square_loop()

    #actual.sort()
    print(actual)
    print(len(actual))

    #assert actual == [(12, 40), (21, 45), (14, 23), (21, 23), (35, 44), (36, 46), (36, 51), (36, 53), (18, 1), (0, 1), (11, 2), (0, 2), (18, 3), (12, 3), (0, 3), (4, 3), (12, 5), (7, 5), (4, 5), (7, 6), (8, 16), (9, 17), (36, 19), (12, 19), (21, 19), (11, 20), (21, 20), (14, 22), (21, 22), (18, 24), (36, 26), (12, 26), (11, 29), (21, 29), (36, 30), (21, 30), (25, 33), (18, 33), (12, 33), (21, 37), (11, 38), (21, 39), (36, 42), (35, 43), (11, 47)]
