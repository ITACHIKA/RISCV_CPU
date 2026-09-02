#include "riscv/io_cmoda7.h"

void main()
{
    UART->UARTCFGSET = UARTCFG_MASTER_ENABLE | UARTCFG_TX_ENABLE | UARTCFG_RX_ENABLE;
    UART->UARTBAUD = 868U; // 115200 baud for 100 MHz clock
    while(1)
    {
        while((GPIO->BTN1 & 0x00000001u) == 0U) { // unpressed
            // wait
        }
        UART->UARTTXDAT = 'A';
        while((GPIO->BTN1 & 0x00000001u) == 1U) { // pressed
            // wait
        }
    }
}