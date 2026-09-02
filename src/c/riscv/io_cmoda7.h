#ifndef IO_CMODA7_H
#define IO_CMODA7_H

#include <stdint.h>

#define __I  volatile const
#define __O  volatile
#define __IO volatile

typedef struct {
    __IO uint32_t LED1;
    __I  uint32_t BTN1;
} GPIO_t;

#define GPIO_BASE 0x10000000u
#define GPIO ((GPIO_t *)GPIO_BASE)

typedef struct {
    __I  uint32_t UARTCFG;
    __O  uint32_t UARTCFGSET;
    __O  uint32_t UARTCFGCLR;
    __IO uint32_t UARTBAUD;
    __I  uint32_t UARTSTATUS;
    __O  uint32_t UARTTXDAT;
    __I  uint32_t UARTRXDAT;
} UART_t;

#define UARTCFG_MASTER_ENABLE_OFFET 0U
#define UARTCFG_MASTER_ENABLE (1UL<<UARTCFG_MASTER_ENABLE_OFFET)
#define UARTCFG_TX_ENABLE_OFFSET 1U
#define UARTCFG_TX_ENABLE (1UL<<UARTCFG_TX_ENABLE_OFFSET)
#define UARTCFG_RX_ENABLE_OFFSET 2U
#define UARTCFG_RX_ENABLE (1UL<<UARTCFG_RX_ENABLE_OFFSET)

#define UART_BASE 0x10001000u
#define UART ((UART_t *)UART_BASE)

#endif