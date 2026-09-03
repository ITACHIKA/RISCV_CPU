#include "riscv/io_cmoda7.h"

int main() {
    while(1)
    {
        while((GPIO->BTN1 & 0x00000001u) == 0u) { // unpressed
            // wait
        }
        GPIO->LED1 ^= 0x00000001u; // toggle LED state
        while((GPIO->BTN1 & 0x00000001u) != 0u) { // pressed
            // wait
        }
    }
}