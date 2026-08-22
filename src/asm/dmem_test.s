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

    # Use an aligned data-memory region starting at byte address 128.
    addi x20, x0, 128

    # ------------------------------------------------------------------
    # 1. Full-word store and synchronous load.
    # The store also checks ALU-to-store-data forwarding. The branch
    # immediately following LW checks load-use stall and WB forwarding.
    # ------------------------------------------------------------------
    addi x29, x0, 1
    lui  x1, 0x12345
    addi x1, x1, 0x678          # x1 = 0x12345678
    sw   x1, 0(x20)
    lw   x2, 0(x20)
    bne  x2, x1, fail

    # ------------------------------------------------------------------
    # 2. Consecutive stores followed by consecutive synchronous loads.
    # This checks that each DMEM response remains aligned with its WB
    # destination register and control signals.
    # ------------------------------------------------------------------
    addi x29, x0, 2
    addi x3, x0, 11
    addi x4, x0, 22
    addi x5, x0, 33
    sw   x3,  4(x20)
    sw   x4,  8(x20)
    sw   x5, 12(x20)

    lw   x6,  4(x20)
    lw   x7,  8(x20)
    lw   x8, 12(x20)
    addi x9, x0, 11
    bne  x6, x9, fail
    addi x9, x0, 22
    bne  x7, x9, fail
    addi x9, x0, 33
    bne  x8, x9, fail

    # ------------------------------------------------------------------
    # 3. Byte write strobes for all four byte lanes.
    # The four SB instructions must assemble the word 0x44332211.
    # ------------------------------------------------------------------
    addi x29, x0, 3
    sw   x0, 16(x20)
    addi x1, x0, 0x11
    sb   x1, 16(x20)
    addi x1, x0, 0x22
    sb   x1, 17(x20)
    addi x1, x0, 0x33
    sb   x1, 18(x20)
    addi x1, x0, 0x44
    sb   x1, 19(x20)

    lw   x2, 16(x20)
    lui  x3, 0x44332
    addi x3, x3, 0x211          # x3 = 0x44332211
    bne  x2, x3, fail

    addi x1, x0, 0x11
    lbu  x2, 16(x20)
    bne  x2, x1, fail
    addi x1, x0, 0x22
    lbu  x2, 17(x20)
    bne  x2, x1, fail
    addi x1, x0, 0x33
    lbu  x2, 18(x20)
    bne  x2, x1, fail
    addi x1, x0, 0x44
    lbu  x2, 19(x20)
    bne  x2, x1, fail

    # ------------------------------------------------------------------
    # 4. Signed and unsigned byte loads, plus byte-lane preservation.
    # Replacing byte lane 1 with 0x80 must produce 0x44338011.
    # ------------------------------------------------------------------
    addi x29, x0, 4
    addi x1, x0, -128
    sb   x1, 17(x20)

    lb   x2, 17(x20)            # Expected 0xffffff80.
    bne  x2, x1, fail

    lbu  x2, 17(x20)            # Expected 0x00000080.
    addi x3, x0, 128
    bne  x2, x3, fail

    lw   x2, 16(x20)
    lui  x3, 0x44338
    addi x3, x3, 0x011          # x3 = 0x44338011
    bne  x2, x3, fail

    # ------------------------------------------------------------------
    # 5. Half-word write strobes for both half-word lanes.
    # The two SH instructions must assemble the word 0x80011234.
    # ------------------------------------------------------------------
    addi x29, x0, 5
    sw   x0, 32(x20)
    lui  x1, 0x1
    addi x1, x1, 0x234          # x1 = 0x00001234
    sh   x1, 32(x20)
    lui  x2, 0x8
    addi x2, x2, 1              # x2 = 0x00008001
    sh   x2, 34(x20)

    lw   x3, 32(x20)
    lui  x4, 0x80011
    addi x4, x4, 0x234          # x4 = 0x80011234
    bne  x3, x4, fail

    # ------------------------------------------------------------------
    # 6. Signed and unsigned half-word loads from both lanes.
    # ------------------------------------------------------------------
    addi x29, x0, 6
    lh   x3, 32(x20)
    bne  x3, x1, fail           # 0x1234 is positive.

    lhu  x3, 32(x20)
    bne  x3, x1, fail

    lui  x4, 0xffff8
    addi x4, x4, 1              # x4 = 0xffff8001
    lh   x3, 34(x20)
    bne  x3, x4, fail

    lhu  x3, 34(x20)
    bne  x3, x2, fail           # Expected 0x00008001.

    # ------------------------------------------------------------------
    # 7. Load result consumed by an ALU instruction immediately after LW.
    # Exactly one load-use stall is expected, then WB-to-EX forwarding.
    # ------------------------------------------------------------------
    addi x29, x0, 7
    addi x1, x0, 37
    sw   x1, 40(x20)
    lw   x2, 40(x20)
    add  x3, x2, x2
    addi x4, x0, 74
    bne  x3, x4, fail

    # ------------------------------------------------------------------
    # 8. Load result used immediately as store data.
    # This checks load-use stall, WB forwarding to rs2, and a subsequent
    # synchronous read of the stored value.
    # ------------------------------------------------------------------
    addi x29, x0, 8
    addi x1, x0, 90
    sw   x1, 44(x20)
    lw   x2, 44(x20)
    sw   x2, 48(x20)
    lw   x3, 48(x20)
    bne  x3, x1, fail

    # ------------------------------------------------------------------
    # 9. A store followed immediately by a load from the same address.
    # The load must observe the value written by the preceding store.
    # ------------------------------------------------------------------
    addi x29, x0, 9
    addi x1, x0, 123
    sw   x1, 52(x20)
    lw   x2, 52(x20)
    bne  x2, x1, fail

pass:
    addi x31, x0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    addi x31, x0, -1
fail_loop:
    jal  x0, fail_loop
