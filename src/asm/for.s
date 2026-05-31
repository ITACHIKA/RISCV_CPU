.section .text
.globl _start

_start:
    li x1, 0
    li x2, 10
    li x3, 1
    j loop

loop:
    beq x3, x2, done
    add x1, x1, x3
    addi x3, x3, 1
    j loop

done:
    j done