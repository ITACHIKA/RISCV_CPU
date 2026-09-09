#include "io_cmoda7.h"
#include "uart.h"

void uart_init(uint32_t baud_divider)
{
    UART->UARTCFGCLR = UARTCFG_MASTER_ENABLE |
                       UARTCFG_TX_ENABLE |
                       UARTCFG_RX_ENABLE;

    if(baud_divider == 0u) {
        return;
    }

    UART->UARTBAUD = baud_divider & 0xFFFFu;
    UART->UARTCFGSET = UARTCFG_MASTER_ENABLE |
                       UARTCFG_TX_ENABLE |
                       UARTCFG_RX_ENABLE;
}

void uart_deinit(void)
{
    UART->UARTCFGSET = UARTCFG_DEINIT;
}

void uart_wait_tx_idle(void)
{
    while((UART->UARTSTATUS & UARTSTATUS_TX_IDLE) == 0u) {
    }
}

void uart_putchar(char character)
{
    while((UART->UARTSTATUS & UARTSTATUS_TX_FIFO_FULL) != 0u) {
    }

    UART->UARTTXDAT = (uint32_t)(uint8_t)character;
}

char uart_getchar(void)
{
    while((UART->UARTSTATUS & UARTSTATUS_RX_FIFO_EMPTY) != 0u) {
    }

    return (char)(UART->UARTRXDAT & 0xFFu);
}

int uart_try_getchar(char *character)
{
    if(character == NULL) {
        return 0;
    }

    if((UART->UARTSTATUS & UARTSTATUS_RX_FIFO_EMPTY) != 0u) {
        return 0;
    }

    *character = (char)(UART->UARTRXDAT & 0xFFu);
    return 1;
}

void uart_write(const void *data, size_t length)
{
    const uint8_t *bytes = (const uint8_t *)data;
    size_t index;

    if(bytes == NULL) {
        return;
    }

    for(index = 0u; index < length; index++) {
        uart_putchar((char)bytes[index]);
    }
}

void uart_read(void *data, size_t length)
{
    uint8_t *bytes = (uint8_t *)data;
    size_t index;

    if(bytes == NULL) {
        return;
    }

    for(index = 0u; index < length; index++) {
        bytes[index] = (uint8_t)uart_getchar();
    }
}

void uart_puts(const char *string)
{
    if(string == NULL) {
        return;
    }

    while(*string != '\0') {
        uart_putchar(*string);
        string++;
    }
}
