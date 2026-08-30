#include "riscv/io.h"

int main() {
    while(1)
    {
        while((BTN & 0x00000001u) == 0u) { // unpressed
            // wait
        }
        LED ^= 0x00000001u; // toggle LED state
        while((BTN & 0x00000001u) != 0u) { // pressed
            // wait
        }
    }
}