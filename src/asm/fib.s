.section .text
.globl _start

# Compute and store the first 100 Fibonacci numbers: F(0) through F(99).
#
# The RV32I datapath naturally performs arithmetic modulo 2^32.  Therefore
# values starting at F(48) are the low 32 bits of the mathematical Fibonacci
# number.  This is intentional and does not affect the branch-predictor test.
#
# DMEM layout:
#   0x8000_0000 + 4*n = F(n) mod 2^32, for 0 <= n < 100
#
# Status/debug registers:
#   x31 = 0 while running, 1 when complete
#   x29 = 1 while computing, 2 when complete
#   x12 = F(100) mod 2^32 on completion
#   x13 = F(101) mod 2^32 on completion
#
# Expected predictor behavior after reset:
#   Dynamic conditional branches = 100
#   Outcomes                     = 99 taken, 1 not taken
#   Mispredictions               = 2
#     - first taken execution: cold BTB / weakly-not-taken BHT
#     - final not-taken loop exit: BHT predicts taken
#   Prediction accuracy          = 98 percent
#
# The current hw_perf_counter branch_count counts predicted-taken events,
# rather than resolved branch instructions, so it should read approximately
# 99 for this workload.  Stop the testbench when x31 becomes 1; the CPU has no
# halt instruction and will otherwise continue executing beyond this program.

_start:
    addi x31, x0, 0             # Running.
    addi x29, x0, 1             # Fibonacci phase.

    lui  x10, 0x80000           # x10 = DMEM write pointer, 0x8000_0000.
    addi x11, x0, 100           # Number of values left to store.
    addi x12, x0, 0             # a = F(0).
    addi x13, x0, 1             # b = F(1).

fibonacci_loop:
    sw   x12, 0(x10)            # Store the current Fibonacci value.
    add  x14, x12, x13          # next = a + b, modulo 2^32.
    addi x12, x13, 0            # a = b.
    addi x13, x14, 0            # b = next.
    addi x10, x10, 4            # Advance to the next DMEM word.
    addi x11, x11, -1           # One fewer value remains.
    bne  x11, x0, fibonacci_loop

    addi x29, x0, 2             # Measurement-complete marker.
    addi x31, x0, 1             # Testbench/ILA completion trigger.

complete_padding:
    .rept 32
    addi x0, x0, 0
    .endr
