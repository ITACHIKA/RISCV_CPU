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

    # Values used to detect wrong-path register and memory writes.
    addi x20, x0, 7
    addi x21, x0, 8
    sw   x20, 0(x0)             # sentinel: mem[0] = 7

    # ------------------------------------------------------------------
    # 1. BEQ taken. Static not-taken prediction must mispredict.
    # rs1 is forwarded from WB and rs2 is forwarded from MEM.
    # Waveform: redirect_pc_request_ex = 1, followed by IF/ID and ID/EX
    # valid bits being cleared. Both wrong-path instructions must vanish.
    # ------------------------------------------------------------------
    addi x29, x0, 1
    addi x1,  x0, 5
    addi x2,  x0, 5
    beq  x1,  x2, beq_taken
    addi x20, x0, 99            # wrong path: register write
    sw   x20, 0(x0)             # wrong path: memory write

beq_taken:
    addi x30, x0, 7
    bne  x20, x30, fail
    lw   x22, 0(x0)
    bne  x22, x30, fail

    # ------------------------------------------------------------------
    # 2. BEQ not taken. No redirect or flush is expected, and both
    # sequential instructions must execute normally.
    # ------------------------------------------------------------------
    addi x29, x0, 2
    addi x1,  x0, 5
    addi x2,  x0, 6
    beq  x1,  x2, fail
    addi x10, x0, 10
    addi x11, x0, 11
    addi x30, x0, 10
    bne  x10, x30, fail
    addi x30, x0, 11
    bne  x11, x30, fail

    # ------------------------------------------------------------------
    # 3. BNE taken with two wrong-path register writes.
    # ------------------------------------------------------------------
    addi x29, x0, 3
    addi x1,  x0, 5
    addi x2,  x0, 6
    bne  x1,  x2, bne_taken
    addi x20, x0, 99            # wrong path
    addi x21, x0, 99            # wrong path

bne_taken:
    addi x30, x0, 7
    bne  x20, x30, fail
    addi x30, x0, 8
    bne  x21, x30, fail

    # ------------------------------------------------------------------
    # 4. BNE not taken.
    # ------------------------------------------------------------------
    addi x29, x0, 4
    addi x1,  x0, 5
    addi x2,  x0, 5
    bne  x1,  x2, fail
    addi x10, x0, 12
    addi x30, x0, 12
    bne  x10, x30, fail

    # ------------------------------------------------------------------
    # 5. Signed BLT taken with a load-to-branch dependency.
    # Exactly one load-use stall is expected before the redirect.
    # ------------------------------------------------------------------
    addi x29, x0, 5
    addi x2,  x0, 1
    addi x3,  x0, -1
    sw   x3,  4(x0)             # mem[4] = -1
    lw   x1,  4(x0)             # x1 = -1
    blt  x1,  x2, blt_taken
    addi x20, x0, 99            # wrong path
    addi x21, x0, 99            # wrong path

blt_taken:
    addi x30, x0, 7
    bne  x20, x30, fail
    addi x30, x0, 8
    bne  x21, x30, fail

    # ------------------------------------------------------------------
    # 6. Signed BLT not taken: 2 < -1 is false.
    # ------------------------------------------------------------------
    addi x29, x0, 6
    addi x1,  x0, 2
    addi x2,  x0, -1
    blt  x1,  x2, fail

    # ------------------------------------------------------------------
    # 7. Signed BGE taken: -1 >= -2 is true.
    # ------------------------------------------------------------------
    addi x29, x0, 7
    addi x1,  x0, -1
    addi x2,  x0, -2
    bge  x1,  x2, bge_taken
    addi x20, x0, 99            # wrong path
    addi x21, x0, 99            # wrong path

bge_taken:
    addi x30, x0, 7
    bne  x20, x30, fail
    addi x30, x0, 8
    bne  x21, x30, fail

    # ------------------------------------------------------------------
    # 8. Signed BGE not taken: -2 >= -1 is false.
    # ------------------------------------------------------------------
    addi x29, x0, 8
    addi x1,  x0, -2
    addi x2,  x0, -1
    bge  x1,  x2, fail

    # ------------------------------------------------------------------
    # 9. Unsigned BLTU taken: 1 < 0xffffffff is true.
    # ------------------------------------------------------------------
    addi x29, x0, 9
    addi x1,  x0, 1
    addi x2,  x0, -1
    bltu x1,  x2, bltu_taken
    addi x20, x0, 99            # wrong path
    addi x21, x0, 99            # wrong path

bltu_taken:
    addi x30, x0, 7
    bne  x20, x30, fail
    addi x30, x0, 8
    bne  x21, x30, fail

    # ------------------------------------------------------------------
    # 10. Unsigned BLTU not taken: 0xffffffff < 1 is false.
    # ------------------------------------------------------------------
    addi x29, x0, 10
    addi x1,  x0, -1
    addi x2,  x0, 1
    bltu x1,  x2, fail

    # ------------------------------------------------------------------
    # 11. Unsigned BGEU taken: 0xffffffff >= 1 is true.
    # ------------------------------------------------------------------
    addi x29, x0, 11
    addi x1,  x0, -1
    addi x2,  x0, 1
    bgeu x1,  x2, bgeu_taken
    addi x20, x0, 99            # wrong path
    addi x21, x0, 99            # wrong path

bgeu_taken:
    addi x30, x0, 7
    bne  x20, x30, fail
    addi x30, x0, 8
    bne  x21, x30, fail

    # ------------------------------------------------------------------
    # 12. Unsigned BGEU not taken: 1 >= 0xffffffff is false.
    # ------------------------------------------------------------------
    addi x29, x0, 12
    addi x1,  x0, 1
    addi x2,  x0, -1
    bgeu x1,  x2, fail

    # ------------------------------------------------------------------
    # 13. Backward branch loop. The same BLT is taken twice and then not
    # taken once. ADDI-to-BLT forwarding is required every iteration.
    # On taken iterations, the two sequential check instructions are
    # wrong-path instructions and must be flushed.
    # ------------------------------------------------------------------
    addi x29, x0, 13
    addi x5,  x0, 0
    addi x6,  x0, 3

backward_loop:
    addi x5, x5, 1
    blt  x5, x6, backward_loop
    addi x30, x0, 3
    bne  x5, x30, fail

    # ------------------------------------------------------------------
    # 14. Two consecutive taken branches at redirect targets.
    # Each branch must independently redirect and flush its two younger
    # wrong-path instructions.
    # ------------------------------------------------------------------
    addi x29, x0, 14
    beq  x0,  x0, branch_chain_1
    addi x20, x0, 99            # wrong path
    addi x21, x0, 99            # wrong path

branch_chain_1:
    beq  x0,  x0, branch_chain_2
    addi x20, x0, 98            # wrong path
    addi x21, x0, 98            # wrong path

branch_chain_2:
    addi x30, x0, 7
    bne  x20, x30, fail
    addi x30, x0, 8
    bne  x21, x30, fail

pass:
    addi x31, x0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    addi x31, x0, -1
fail_loop:
    jal  x0, fail_loop
