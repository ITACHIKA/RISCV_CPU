// 1st stage bootloader
#include "riscv/io_cmoda7.h"
#include "riscv/uart.h"

#define START_ADDRESS 0x00001000u

__attribute__((noreturn))
static void jump_to_user(uint32_t address)
{
    __asm__ volatile (
        "jalr x0, 0(%0)"
        :
        : "r"(address)
        : "memory"
    );

    __builtin_unreachable();
}

void main()
{
    uart_init(868U); // 115200 baud for 100 MHz clock
    const char* bootloader_message = "RISCV 1st stage Bootloader.\r\n";
    uart_write(bootloader_message, 30U);
    const char* wait_message = "Waiting for download...\r\n";
    uart_write(wait_message, 26U);
    uint8_t charbuf;
    uint32_t byte_offset = 0U;
    while(1)
    {
        if(uart_try_getchar((char*)&charbuf)) {
            if(charbuf == 0xFF) // start of handshake
            {
                uart_putchar(0xFE);
                uint32_t program_size = 0U;
                // after handshake, the bootloader will receive program size
                // the program size is sent in 4 bytes little endian
                for(uint8_t i=0; i<4; i++){
                    charbuf = uart_getchar();
                    program_size |= ((uint32_t)charbuf << (i*8));
                }
                for(uint32_t i=0;i<program_size;i++){
                    charbuf = uart_getchar();
                    *((volatile uint8_t *)(START_ADDRESS + byte_offset)) = charbuf;
                    byte_offset++;
                }
                SYSCTRL->SYSCTRL_BOOTMODE = 0x00000001u; // set boot mode to user program
                jump_to_user(START_ADDRESS);
            }
        }
    }
}