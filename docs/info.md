A Reimplementation of Belle's Move Generator
============================================

## How it works

Internally, there is a 256-bit chessboard (4 bits per square), along with a 64-bit square-enable mask.

Each square "transmits" attacks to its neighbour squares, which either propagate attacks along empty squares, or generate their own.
These attacks are processed by "receivers", which produce a priority level based on opcode and the piece on that square.
The priority levels go through an arbitration network, which chooses the most promising square, which gets output from the chip.

## How to test

Explain how to use your project

## External hardware

Some kind of external processor is needed to drive the move generator.
