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

#endif