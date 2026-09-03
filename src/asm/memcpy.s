.section .text
.globl _start

_start:
    # DMEM base = 0x8000_0000.
    lui s0, 0x80000

    # ----------------------------
    #  src = {45, 22, 35, 42, 52, 59}
    #    src base = 0
    # ----------------------------
    li t0, 45
    sw t0, 0(s0)

    li t0, 22
    sw t0, 4(s0)

    li t0, 35
    sw t0, 8(s0)

    li t0, 42
    sw t0, 12(s0)

    li t0, 52
    sw t0, 16(s0)

    li t0, 59
    sw t0, 20(s0)

    # ----------------------------
    # 
    #    a0 = dst base
    #    a1 = src base
    #    a2 = number of words
    # ----------------------------
    addi a0, s0, 100  # dst base = DMEM + 100
    addi a1, s0, 0    # src base = DMEM
    li a2, 6          # copy 6 words

    jal ra, memcpy

    # ----------------------------
    # 
    # ----------------------------
    li t0, 45
    lw t1, 100(s0)
    bne t1, t0, fail

    li t0, 22
    lw t1, 104(s0)
    bne t1, t0, fail

    li t0, 35
    lw t1, 108(s0)
    bne t1, t0, fail

    li t0, 42
    lw t1, 112(s0)
    bne t1, t0, fail

    li t0, 52
    lw t1, 116(s0)
    bne t1, t0, fail

    li t0, 59
    lw t1, 120(s0)
    bne t1, t0, fail

pass:
    j pass

fail:
    j fail


# -------------------------------------------------
# memcpy_word(dst, src, n)
# a0 = dst base address
# a1 = src base address
# a2 = word count
# -------------------------------------------------
memcpy:
loop:
    beq  a2, x0, done   # if n == 0, finish

    lw   t0, 0(a1)      # load *src
    sw   t0, 0(a0)      # store to *dst

    addi a1, a1, 4      # src++
    addi a0, a0, 4      # dst++
    addi a2, a2, -1     # n--

    j    loop

done:
    ret
