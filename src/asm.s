addi x1, x0, 5
addi x2, x0, 4
addi x7, x0, -1
sw x1, 0(x2)        # Store x1 to memory at x2+0
lw x3, 0(x2)        # Load from memory at x2+0 into x3
sh x1, 6(x2)        # Store halfword x1 to x2+4
lh x4, 6(x2)       # Load halfword from x2+4 into x4
sb x7, 9(x2)        # Store byte x1 to x2+8
lbu x5, 9(x2)       # Load byte from x2+8 into x5
lb x6, 9(x2)