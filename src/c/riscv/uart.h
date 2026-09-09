#ifndef RISCV_UART_H
#define RISCV_UART_H

#include <stddef.h>
#include <stdint.h>

/* Configure and enable the UART with a precomputed baud-rate divider. */
void uart_init(uint32_t baud_divider);
void uart_deinit(void);
void uart_wait_tx_idle(void);

/* Blocking single-byte transmit and receive operations. */
void uart_putchar(char character);
char uart_getchar(void);

/* Non-blocking receive. Returns 1 when a byte was read, otherwise 0. */
int uart_try_getchar(char *character);

/* Blocking buffer operations. */
void uart_write(const void *data, size_t length);
void uart_read(void *data, size_t length);

/* Send a null-terminated string without automatic newline conversion. */
void uart_puts(const char *string);

#endif
