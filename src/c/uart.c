#include "riscv/io_cmoda7.h"

void main()
{
    UART->UARTCFGSET = UARTCFG_MASTER_ENABLE | UARTCFG_TX_ENABLE | UARTCFG_RX_ENABLE;
    UART->UARTBAUD = 868U; // 115200 baud for 100 MHz clock
    uint8_t previous_button_state = 0U;
    while(1)
    {
        uint8_t current_button_state = (uint8_t)(GPIO->BTN1 & 0x00000001u);
        if(current_button_state && !previous_button_state) {
            UART->UARTTXDAT = 'A';
        }
        previous_button_state = current_button_state;
        if((UART->UARTSTATUS & UARTSTATUS_RX_FIFO_EMPTY) == 0U) { // RX FIFO not empty
            char received_char = (char)(UART->UARTRXDAT & 0xFFu);
            UART->UARTTXDAT = received_char; // echo back the received character
            if(received_char == '1') {
                GPIO->LED1 = 0x00000001u; // turn on LED
            } else if(received_char == '0') {
                GPIO->LED1 = 0x00000000u; // turn off LED
            }
        }
    }
}