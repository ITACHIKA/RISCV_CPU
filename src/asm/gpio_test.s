.section .text
.globl _start

_start:
    # MMIO register map:
    #   0x10000000: LED output register
    #   0x10000004: button input register
    lui  x1, 0x10000           # x1 = GPIO base address 0x10000000

    # Start with the LED on. The Cmod A7 button is active-high:
    #   0 = released
    #   1 = pressed
    addi x4, x0, 1             # x4 = current LED state
    sw   x4, 0(x1)

# Wait for a possible press (0 -> 1).
wait_press:
    lw   x2, 4(x1)
    andi x2, x2, 1
    beq  x2, x0, wait_press    # Still released.

    xori x4, x4, 1             # Toggle the LED state.
    sw   x4, 0(x1)             # Write the new state to the LED.

# Do not allow another toggle until the button has been released.
wait_release:
    lw   x2, 4(x1)
    andi x2, x2, 1
    bne  x2, x0, wait_release  # Still pressed.
    jal  x0, wait_press
