.section .text
.globl _start

_start:
    # x31 is the test status: 0 = running, 1 = pass, -1 = fail.
    addi x31, x0, 0

    # DMEM is mapped at 0x8000_0000. Keep its base address in x27.
    lui  x27, 0x80000

    # Initialize data memory used by the load/store tests.
    addi x3, x0, 55
    addi x5, x27, 16
    sw   x3, 0(x27)            # DMEM[0]  = 55
    sw   x3, 0(x5)             # DMEM[16] = 55

    # ------------------------------------------------------------------
    # MEM forwarding must have priority over WB forwarding.
    # ------------------------------------------------------------------
    addi x1, x0, 1
    addi x1, x1, 1
    add  x2, x1, x0            # x2 = 2 from the newer MEM producer
    addi x30, x0, 2
    bne  x2, x30, fail

    # ------------------------------------------------------------------
    # Forward rs1 from MEM and rs2 from WB in the same cycle.
    # ------------------------------------------------------------------
    addi x13, x0, 13
    addi x14, x0, 14
    add  x15, x14, x13         # x15 = 27
    addi x30, x0, 27
    bne  x15, x30, fail

    # ------------------------------------------------------------------
    # WB-to-EX forwarding with one independent instruction in between.
    # ------------------------------------------------------------------
    addi x16, x0, 16
    addi x8,  x0, 0
    add  x17, x16, x0          # x17 = 16
    addi x30, x0, 16
    bne  x17, x30, fail

    # ------------------------------------------------------------------
    # WB-to-ID register-file bypass with two intervening instructions.
    # ------------------------------------------------------------------
    addi x7,  x0, 7
    addi x8,  x0, 0
    addi x9,  x0, 0
    add  x10, x7, x0           # x10 = 7
    addi x30, x0, 7
    bne  x10, x30, fail

    # ------------------------------------------------------------------
    # Load-use: the loaded value is used by both EX operands.
    # Exactly one stall is expected, followed by WB forwarding to both.
    # ------------------------------------------------------------------
    lw   x18, 0(x27)           # x18 = 55
    add  x19, x18, x18         # x19 = 110
    addi x30, x0, 110
    bne  x19, x30, fail

    # ------------------------------------------------------------------
    # Load-use on store data (rs2).
    # ------------------------------------------------------------------
    lw   x20, 0(x27)           # x20 = 55
    sw   x20, 20(x27)          # DMEM[20] = 55
    lw   x21, 20(x27)
    addi x30, x0, 55
    bne  x21, x30, fail

    # ------------------------------------------------------------------
    # Load-use on a store base address (rs1).
    # ------------------------------------------------------------------
    addi x22, x27, 32
    sw   x22, 8(x27)           # DMEM[8] = 0x8000_0020
    lw   x22, 8(x27)           # x22 = 0x8000_0020
    sw   x3, 0(x22)            # DMEM[32] = 55
    lw   x23, 32(x27)
    addi x30, x0, 55
    bne  x23, x30, fail

    # ------------------------------------------------------------------
    # Load-to-branch dependency and taken-branch flushing.
    # Both younger wrong-path instructions must be flushed.
    # ------------------------------------------------------------------
    addi x24, x0, 7
    sw   x24, 36(x27)          # sentinel: DMEM[36] = 7
    lw   x22, 0(x27)           # x22 = 55
    beq  x22, x3, load_branch_taken
    addi x24, x0, 99           # wrong path: must not write x24
    sw   x24, 36(x27)          # wrong path: must not change sentinel

load_branch_taken:
    lw   x24, 36(x27)
    addi x30, x0, 7
    bne  x24, x30, fail

    # ------------------------------------------------------------------
    # ALU-to-branch forwarding on a taken branch.
    # Verify that wrong-path register writes are flushed.
    # ------------------------------------------------------------------
    addi x25, x0, 5
    addi x26, x0, 0
    addi x6,  x0, 1
    bne  x6,  x0, alu_branch_taken
    addi x25, x0, 99           # wrong path
    addi x26, x0, 99           # wrong path

alu_branch_taken:
    addi x30, x0, 5
    bne  x25, x30, fail
    bne  x26, x0, fail

    # ------------------------------------------------------------------
    # JAL link value and flushing. x25 must receive the JAL PC + 4.
    # LUI/ADDI construct the expected return address without a pseudo-op.
    # ------------------------------------------------------------------
    addi x26, x0, 7
    sw   x26, 40(x27)          # sentinel: DMEM[40] = 7

    lui   x30, %hi(jal_return)
    addi  x30, x30, %lo(jal_return)
    jal   x25, jal_target

jal_return:
    addi x26, x0, 99           # wrong path
    sw   x26, 40(x27)          # wrong path

jal_target:
    bne  x25, x30, fail
    lw   x26, 40(x27)
    addi x30, x0, 7
    bne  x26, x30, fail

    # ------------------------------------------------------------------
    # JALR base forwarding, link value, and flushing.
    # The ADDI immediately before JALR produces its rs1 target address.
    # ------------------------------------------------------------------
    addi x26, x0, 7
    sw   x26, 44(x27)          # sentinel: DMEM[44] = 7

    lui   x30, %hi(jalr_return)
    addi  x30, x30, %lo(jalr_return)

    lui   x28, %hi(jalr_target)
    addi  x28, x28, %lo(jalr_target)
    jalr  x29, 0(x28)

jalr_return:
    addi x26, x0, 99           # wrong path
    sw   x26, 44(x27)          # wrong path

jalr_target:
    bne  x29, x30, fail
    lw   x26, 44(x27)
    addi x30, x0, 7
    bne  x26, x30, fail

    # ------------------------------------------------------------------
    # SLT result forwarding. SLT itself receives rs1 from WB and rs2
    # from MEM; the following ADD receives the SLT result from MEM.
    # ------------------------------------------------------------------
    addi x1, x0, 1
    addi x2, x0, 2
    slt  x3, x1, x2            # x3 = 1
    add  x4, x3, x3            # x4 = 2
    addi x30, x0, 2
    bne  x4, x30, fail

    # ------------------------------------------------------------------
    # x0 must never be written or treated as a forwarding producer.
    # A load to x0 must not cause a load-use stall for a subsequent x0 read.
    # ------------------------------------------------------------------
    addi x0, x0, 123
    add  x28, x0, x0
    bne  x28, x0, fail
    lw   x0, 0(x27)
    add  x28, x0, x0
    bne  x28, x0, fail

    # ------------------------------------------------------------------
    # False-hazard check. The immediate low bits decode as rs2 = x5, but
    # ADDI does not use rs2, so load_use_stall_if must remain deasserted.
    # This case must be checked in the waveform because an unnecessary
    # stall would not change the architectural result.
    # ------------------------------------------------------------------
    lw   x5, 0(x27)
    addi x6, x0, 5
    addi x30, x0, 5
    bne  x6, x30, fail

pass:
    addi x31, x0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    addi x31, x0, -1
fail_loop:
    jal  x0, fail_loop
