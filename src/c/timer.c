// Timer test
#include "riscv/io_cmoda7.h"
#include "riscv/uart.h"

static void uart_write_hex32(uint32_t value)
{
    static const char hex[] = "0123456789ABCDEF";

    uart_puts("0x");

    for (int shift = 28; shift >= 0; shift -= 4) {
        uart_putchar(hex[(value >> shift) & 0xFU]);
    }

    uart_puts("\r\n");
}

void main()
{
    uart_init(868);
    TIMER->TIMERCFGSET = TIMERCFG_MASTER_ENABLE;
    uint8_t previous_button_state = 0U;
    while(1)
    {
        uint8_t current_button_state = (uint8_t)(GPIO->BTN1 & 0x00000001u);
        if(current_button_state && !previous_button_state) {
            // uint32_t timer_value = TIMER->TIMERTIMELOW;
            // while((UART->UARTSTATUS & UARTSTATUS_TX_FIFO_FULL) != 0U) {
            //     // wait until TX FIFO is not full
            // }
            uart_write_hex32(TIMER->TIMERTIMELOW);
        }
        previous_button_state = current_button_state;
    }
}