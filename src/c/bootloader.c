// 1st stage bootloader
#include "riscv/io_cmoda7.h"
#include "riscv/uart.h"

#define START_ADDRESS 0x00001000u
#define MAX_PROGRAM_SIZE 0x00007000u

#define DOWNLOAD_READY       0xFEu
#define DOWNLOAD_SUCCESS     0xFDu
#define DOWNLOAD_CRC_ERROR   0xFCu
#define DOWNLOAD_SIZE_ERROR  0xFBu

static uint32_t uart_read_u32_le(void)
{
    uint32_t value = 0u;

    for(uint32_t index = 0u; index < 4u; ++index) {
        const uint8_t byte = (uint8_t)uart_getchar();
        value |= (uint32_t)byte << (index * 8u);
    }

    return value;
}

static uint32_t crc32_update(uint32_t crc, uint8_t byte)
{
    crc ^= (uint32_t)byte;

    for(uint32_t bit = 0u; bit < 8u; ++bit) {
        const uint32_t mask = 0u - (crc & 1u);
        crc = (crc >> 1u) ^ (0xEDB88320u & mask);
    }

    return crc;
}

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
    while(1)
    {
        if(uart_try_getchar((char*)&charbuf)) {
            if(charbuf == 0xFF) // start of handshake
            {
                uart_putchar((char)DOWNLOAD_READY);

                // Header fields are transmitted as 32-bit little-endian values.
                const uint32_t program_size = uart_read_u32_le();
                const uint32_t expected_crc = uart_read_u32_le();

                if(program_size == 0u || program_size > MAX_PROGRAM_SIZE) {
                    uart_putchar((char)DOWNLOAD_SIZE_ERROR);
                    continue;
                }

                uint32_t calculated_crc = 0xFFFFFFFFu;
                volatile uint8_t *program =
                    (volatile uint8_t *)START_ADDRESS;

                for(uint32_t offset = 0u; offset < program_size; ++offset) {
                    const uint8_t byte = (uint8_t)uart_getchar();
                    program[offset] = byte;
                    calculated_crc = crc32_update(calculated_crc, byte);
                }

                calculated_crc ^= 0xFFFFFFFFu;

                if(calculated_crc != expected_crc) {
                    uart_putchar((char)DOWNLOAD_CRC_ERROR);
                    continue;
                }

                SYSCTRL->SYSCTRL_BOOTMODE = 0x00000001u; // set boot mode to user program
                uart_putchar((char)DOWNLOAD_SUCCESS);
                uart_wait_tx_idle();
                uart_deinit();
                jump_to_user(START_ADDRESS);
            }
        }
    }
}
