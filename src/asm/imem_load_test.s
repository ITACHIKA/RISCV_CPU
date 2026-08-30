.section .text
.globl _start

_start:
    # Test status:
    #   x31 = 0          running
    #   x31 = 1          pass
    #   x31 = 0xffffffff fail
    # x29 contains the current test section number for waveform debugging.
    addi x31, x0, 0
    addi x29, x0, 0

    # Obtain the byte address of the known data embedded in IMEM.
    lui  x20, %hi(imem_test_data)
    addi x20, x20, %lo(imem_test_data)

    # ------------------------------------------------------------------
    # 1. Read address zero through IMEM port B.
    # Address zero contains "addi x31, x0, 0", encoded as 0x00000f93.
    # ------------------------------------------------------------------
    addi x29, x0, 1
    lw   x1, 0(x0)
    lui  x2, 0x1
    addi x2, x2, -109          # x2 = 0x00000f93
    bne  x1, x2, fail

    # ------------------------------------------------------------------
    # 2. Aligned word reads from nonzero IMEM addresses.
    # ------------------------------------------------------------------
    addi x29, x0, 2
    lw   x3, 0(x20)
    lui  x4, 0x12345
    addi x4, x4, 0x678         # x4 = 0x12345678
    bne  x3, x4, fail

    lw   x3, 4(x20)
    lui  x4, 0x80ff8
    addi x4, x4, -255          # x4 = 0x80ff7f01
    bne  x3, x4, fail

    # ------------------------------------------------------------------
    # 3. Back-to-back IMEM requests. Results and WB metadata must remain
    # aligned even though the requests target consecutive words.
    # ------------------------------------------------------------------
    addi x29, x0, 3
    lw   x5,  0(x20)
    lw   x6,  4(x20)
    lw   x7,  8(x20)
    lw   x8, 12(x20)

    lui  x9, 0x12345
    addi x9, x9, 0x678         # 0x12345678
    bne  x5, x9, fail

    lui  x9, 0x80ff8
    addi x9, x9, -255          # 0x80ff7f01
    bne  x6, x9, fail

    lui  x9, 0xa5c34
    addi x9, x9, -934          # 0xa5c33c5a
    bne  x7, x9, fail

    lui  x9, 0xdeadc
    addi x9, x9, -273          # 0xdeadbeef
    bne  x8, x9, fail

    # ------------------------------------------------------------------
    # 4. Byte lanes and signed/unsigned extension.
    # The bytes of 0x80ff7f01 at increasing addresses are 01, 7f, ff, 80.
    # ------------------------------------------------------------------
    addi x29, x0, 4
    lbu  x10, 4(x20)
    addi x11, x0, 1
    bne  x10, x11, fail

    lbu  x10, 5(x20)
    addi x11, x0, 127
    bne  x10, x11, fail

    lbu  x10, 6(x20)
    addi x11, x0, 255
    bne  x10, x11, fail

    lb   x10, 6(x20)
    addi x11, x0, -1
    bne  x10, x11, fail

    lbu  x10, 7(x20)
    addi x11, x0, 128
    bne  x10, x11, fail

    lb   x10, 7(x20)
    addi x11, x0, -128
    bne  x10, x11, fail

    # ------------------------------------------------------------------
    # 5. Halfword lanes and signed/unsigned extension.
    # ------------------------------------------------------------------
    addi x29, x0, 5
    lh   x12, 4(x20)           # 0x00007f01
    lui  x13, 0x8
    addi x13, x13, -255
    bne  x12, x13, fail

    lhu  x12, 6(x20)          # 0x000080ff
    lui  x13, 0x8
    addi x13, x13, 255
    bne  x12, x13, fail

    lh   x12, 6(x20)           # 0xffff80ff
    lui  x13, 0xffff8
    addi x13, x13, 255
    bne  x12, x13, fail

    # ------------------------------------------------------------------
    # 6. Immediate load-use dependency from IMEM.
    # The current design should stall twice and deliver the value through
    # WB-to-ID bypass before the dependent ADD enters EX.
    # ------------------------------------------------------------------
    addi x29, x0, 6
    lw   x14, 16(x20)          # x14 = 37
    add  x15, x14, x14        # x15 = 74
    addi x16, x0, 74
    bne  x15, x16, fail

pass:
    addi x31, x0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    addi x31, x0, -1
fail_loop:
    jal  x0, fail_loop

    # Keep test data in the executable IMEM image, but outside all executed
    # control-flow paths. Port B must return these exact little-endian words.
    .balign 4
imem_test_data:
    .word 0x12345678
    .word 0x80ff7f01
    .word 0xa5c33c5a
    .word 0xdeadbeef
    .word 37
