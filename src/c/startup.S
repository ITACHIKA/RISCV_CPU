.section .text.start, "ax", @progbits
.globl _start
.type _start, @function

_start:
    # The stack grows downward from the end of DMEM.
    la   sp, __stack_top

    # Copy initialized data from its IMEM load address to its DMEM runtime
    # address. The linker keeps all boundaries word aligned.
    la   t0, __data_load_start
    la   t1, __data_start
    la   t2, __data_end

.Lcopy_data:
    beq  t1, t2, .Lclear_bss_begin
    lw   t3, 0(t0)
    sw   t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    jal  x0, .Lcopy_data

    # C requires every object in .bss to start at zero.
.Lclear_bss_begin:
    la   t0, __bss_start
    la   t1, __bss_end

.Lclear_bss:
    beq  t0, t1, .Lcall_main
    sw   x0, 0(t0)
    addi t0, t0, 4
    jal  x0, .Lclear_bss

.Lcall_main:
    jal  ra, main

    # There is no operating system to receive the return value from main.
.Lhang:
    jal  x0, .Lhang

.size _start, . - _start
