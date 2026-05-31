.section .text
.globl _start

_start:
    # dmem[0] = 1
    li t0, 1
    li t1, 0
    sw t0, 0(t1)

    # dmem[1] = 2
    li t0, 2
    sw t0, 4(t1)

    # dmem[2] = 3
    li t0, 3
    sw t0, 8(t1)

    # dmem[3] = 4
    li t0, 4
    sw t0, 12(t1)

    # dmem[4] = 5
    li t0, 5
    sw t0, 16(t1)

    # sum(arr, 5)
    li a0, 0
    li a1, 5
    jal ra, sum

    li t0, 15
    bne a0, t0, fail

pass:
    j pass

fail:
    j fail

sum:
    li t0, 0      # s
    li t1, 0      # i

loop:
    bge t1, a1, done

    slli t2, t1, 2
    add  t2, a0, t2
    lw   t3, 0(t2)

    add  t0, t0, t3
    addi t1, t1, 1

    j loop

done:
    mv a0, t0
    ret