# MEM priority over WB
lui  x13, 0x10000       # DMEM base = 0x1000_0000
addi x1, x0, 1
addi x1, x1, 1
add  x2, x1, x0       # x2 should be 2

# Store data forwarding
addi x3, x0, 55
sw   x3, 0(x13)
lw   x4, 0(x13)       # x4 should be 55

# Store base forwarding
addi x5, x13, 16
sw   x3, 0(x5)

# Branch operand forwarding
addi x6, x0, 1
beq  x6, x0, fail

# WB-to-ID case
addi x7, x0, 7
addi x8, x0, 0
addi x9, x0, 0
add  x10, x7, x0      # x10 should be 7

# load-use case

lw   x11, 0(x5)        # x11 should be 55
addi x12, x11, 1       # x12 should be 56
beq  x0, x0, ok

fail:
    beq x0, x0, fail

ok:
    beq x0, x0, ok
