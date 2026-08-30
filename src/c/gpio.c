#define LED_ADDR 0x40000000u
#define BTN_ADDR 0x40000004u

int main() {
    volatile unsigned int *led = (unsigned int *)LED_ADDR;
    volatile unsigned int *btn = (unsigned int *)BTN_ADDR;
    unsigned int led_state = 0;// init once
    while(1)
    {
        while((*btn & 0x00000001u) == 0u) { // unpressed
            // wait
        }
        *led ^= 0x00000001u; // toggle LED state
        while((*btn & 0x00000001u) != 0u) { // pressed
            // wait
        }
    }
}