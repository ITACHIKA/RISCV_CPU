.section .text
.globl _start

# Long-running branch-predictor and performance-counter workload.
#
# Register convention:
#   x31 = 0 while the workload is running
#   x31 = 1 when all measured phases have completed
#   x29 = current phase number (1 through 6)
#
# Each measured phase executes 1024 instances of a test branch and 1024
# instances of its loop-control branch.  The hot branch PCs deliberately use
# different PC[6:2] values so that the five phases do not alias in the 32-entry
# BHT.  The two hot branches within each phase also use different PC[4:2]
# values, avoiding an intra-phase collision in the 8-entry BTB.
#
# Expected results for the current predictor after reset:
#
#   Phase  Pattern             Control-flow instructions   Mispredictions
#     1    always not taken             2048                      2
#     2    always taken                 2048                      3
#     3    taken/not-taken              2048                   1026
#     4    taken,taken,taken,NT         2048                    259
#     5    repeated JAL                  2048                      3
#                                    --------                 ------
#   Total                               10240                   1293
#
# Expected aggregate prediction accuracy:
#
#   (10240 - 1293) / 10240 = 87.373046875 percent
#
# The current hw_perf_counter branch input is connected to predicted_taken,
# not to an actual branch-retirement event.  Consequently branch_count is
# expected to be 8696 at the end of phase 5, not 10240.  branch_miss_count is
# still expected to be 1293 for this workload.  Sample the counters when x29
# becomes 6 (or when x31 becomes 1), before the trailing instructions have had
# time to affect cycle_count and retired_instr_count.

_start:
    addi x31, x0, 0
    addi x29, x0, 0
    addi x3,  x0, 1             # Constant used by the always-NT branch.

    # ------------------------------------------------------------------
    # Phase 1: always-not-taken conditional branch.
    #
    # The BEQ is never taken and remains correctly predicted not taken.
    # The loop BNE has 1023 taken outcomes followed by one not-taken exit;
    # starting from weakly-NT, it misses once at entry and once at exit.
    # Expected phase misses: 2.
    # Hot BHT indices: 2 and 5.
    # ------------------------------------------------------------------
    .balign 128
phase_1:
    addi x29, x0, 1
    addi x1,  x0, 1024
phase_1_loop:
    beq  x0,  x3, unexpected
    addi x0,  x0, 0
    addi x1,  x1, -1
    bne  x1,  x0, phase_1_loop

    # ------------------------------------------------------------------
    # Phase 2: always-taken conditional branch.
    #
    # The BEQ misses only on its first cold execution.  Its BTB entry and
    # BHT counter then predict all remaining executions correctly.  The
    # loop branch again misses at entry and exit.
    # Expected phase misses: 3.
    # Hot BHT indices: 9 and 12.
    # ------------------------------------------------------------------
    .balign 128
phase_2:
    addi x29, x0, 2
    addi x1,  x0, 1024
    .rept 7
    addi x0, x0, 0
    .endr
phase_2_loop:
    beq  x0,  x0, phase_2_taken
    addi x0,  x0, 0             # Wrong path after a taken prediction.
phase_2_taken:
    addi x1,  x1, -1
    bne  x1,  x0, phase_2_loop

    # ------------------------------------------------------------------
    # Phase 3: strictly alternating taken/not-taken pattern.
    #
    # Outcomes are T, NT, T, NT, ... .  A local 2-bit counter initialized
    # to weakly-NT alternates between weakly-NT and weakly-T, so every test
    # branch is mispredicted.  The loop branch contributes two more misses.
    # Expected phase misses: 1024 + 2 = 1026.
    # Hot BHT indices: 16 and 19.
    # ------------------------------------------------------------------
    .balign 128
phase_3:
    addi x29, x0, 3
    addi x1,  x0, 1024
    addi x2,  x0, 1
    .rept 12
    addi x0, x0, 0
    .endr
phase_3_loop:
    xori x2,  x2, 1
    beq  x2,  x0, phase_3_join
    addi x0,  x0, 0             # Executed on each not-taken outcome.
phase_3_join:
    addi x1,  x1, -1
    bne  x1,  x0, phase_3_loop

    # ------------------------------------------------------------------
    # Phase 4: 75-percent-taken branch.
    #
    # Outcomes repeat T, T, T, NT.  After the initial taken miss, the BHT
    # predicts taken.  Every fourth not-taken outcome then misses, while
    # the following taken outcome keeps the counter in the taken half.
    # Expected phase misses: 1 + 256 + 2 loop misses = 259.
    # Hot BHT indices: 24 and 27.
    # ------------------------------------------------------------------
    .balign 128
phase_4:
    addi x29, x0, 4
    addi x1,  x0, 1024
    addi x2,  x0, 0
    .rept 19
    addi x0, x0, 0
    .endr
phase_4_loop:
    addi x2,  x2, 1
    andi x4,  x2, 3
    bne  x4,  x0, phase_4_join
    addi x0,  x0, 0             # Executed every fourth iteration.
phase_4_join:
    addi x1,  x1, -1
    bne  x1,  x0, phase_4_loop

    # ------------------------------------------------------------------
    # Phase 5: repeatedly execute one direct JAL.
    #
    # The first JAL misses because the BTB is cold.  All later JALs hit
    # the BTB and predict their target.  The loop BNE contributes its
    # normal entry and exit misses.
    # Expected phase misses: 3.
    # Hot BHT/BTB positions: JAL index 29, loop branch index 0.
    # ------------------------------------------------------------------
    .balign 128
phase_5:
    addi x29, x0, 5
    addi x1,  x0, 1024
    .rept 27
    addi x0, x0, 0
    .endr
phase_5_loop:
    jal  x0, phase_5_target
    addi x0, x0, 0             # Wrong path on the cold JAL execution.
phase_5_target:
    addi x1,  x1, -1
    bne  x1,  x0, phase_5_loop

    # Measurement-complete markers.  Use either transition as an ILA
    # trigger.  There is deliberately no final branch loop, because such a
    # loop would continue changing the branch prediction counters.
    addi x29, x0, 6
    addi x31, x0, 1

complete_padding:
    .rept 32
    addi x0, x0, 0
    .endr

unexpected:
    addi x31, x0, -1
    addi x29, x0, -1
    .rept 32
    addi x0, x0, 0
    .endr

