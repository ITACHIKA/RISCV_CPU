.section .text
.globl _start

_start:
    li t0, -45
    sw t0, 0(x0)

    li t0, -22
    sw t0, 4(x0)

    li t0, -35
    sw t0, 8(x0)

    li t0, -42
    sw t0, 12(x0)

    li t0, -52
    sw t0, 16(x0)

    li t0, -59
    sw t0, 20(x0)

    li x1, 0
    li x2, 6
    lw x6, 0(x0)
    j loop

loop:
    beq x1, x2, done
    slli x3, x1, 2
    addi x1, x1, 1
    lw x4, 0(x3)
    j compare

compare:
    blt x4, x6, loop
    addi x6, x4, 0
    j loop

done:
    j done