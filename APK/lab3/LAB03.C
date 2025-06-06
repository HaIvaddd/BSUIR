#include <dos.h>
#include <stdio.h>
#include <conio.h>

#define TIMER_0_DATA 0x40
#define TIMER_1_DATA 0x41
#define TIMER_2_DATA 0x42
#define TIMER_CONTROL  0x43

#define SPEAKER_PORT   0x61

#define TIMER_CLK      1193182L

unsigned int last_timer2_divisor = 0;

void enable_speaker() {
    outportb(SPEAKER_PORT, inportb(SPEAKER_PORT) | 0x03);
}

void disable_speaker() {
    outportb(SPEAKER_PORT, inportb(SPEAKER_PORT) & ~0x03);
}

void play_sound(unsigned int frequency, unsigned int duration_ms) {
    unsigned int divisor;

    if (frequency == 0) {
        disable_speaker();
        delay(duration_ms);
        return;
    }

    divisor = TIMER_CLK / frequency;
    last_timer2_divisor = divisor;


    outportb(TIMER_CONTROL, 0xB6);

    outportb(TIMER_2_DATA, divisor & 0xFF);
    outportb(TIMER_2_DATA, (divisor >> 8) & 0xFF);

    enable_speaker();
    delay(duration_ms);
    disable_speaker();
}

char *byte_to_binary(unsigned char byte) {
    static char binary_str[9];
    int i;

    for (i = 0; i < 8; i++) {
        binary_str[7 - i] = ((byte >> i) & 1) ? '1' : '0';
    }
    binary_str[8] = '\0';
    return binary_str;
}

void display_timer_info(int channel) {
    unsigned char status_word, status_control_word, low_byte, high_byte;
    unsigned int count, ce_value;


    printf("Timer channel %d information:\n", channel);

    switch (channel) {
        case 0: status_control_word = 0xE2; break;
        case 1: status_control_word = 0xE4; break;
        case 2: status_control_word = 0xE8; break;
        default: status_control_word = 0xE2; break;
    }
    outportb(TIMER_CONTROL, status_control_word);
    status_word = inportb(TIMER_0_DATA + channel);
    printf("  Status word (binary): %s\n", byte_to_binary(status_word));

    outportb(TIMER_CONTROL, (channel << 6) | 0x00);
    low_byte = inportb(TIMER_0_DATA + channel);
    high_byte = inportb(TIMER_0_DATA + channel);
    count = (high_byte << 8) | low_byte;

    if (channel == 2) {
        ce_value = last_timer2_divisor;
        printf("  Counter Equivalent (CE) (hexadecimal): %X (based on last sound frequency)\n", ce_value);
    } else {
        ce_value = count;
        printf("  Current counter value (hexadecimal): %X\n", count);
        printf("  Counter Equivalent (CE) (hexadecimal): %X (current counter value as approximation)\n", ce_value);
    }
    printf("\n");
}

int main() {
    clrscr();
    printf("Demonstration of 8253/8254 timer and speaker operation.\n\n");

    printf("Playing melody:\n");

    play_sound(261, 400);
    play_sound(261, 400);
    play_sound(392, 400);
    play_sound(392, 400);
    play_sound(440, 400);
    play_sound(440, 400);
    play_sound(392, 800);
    play_sound(0, 200);

    play_sound(349, 400);
    play_sound(349, 400);
    play_sound(330, 400);
    play_sound(330, 400);
    play_sound(294, 400);
    play_sound(294, 400);
    play_sound(261, 400);
    play_sound(0, 200);

    printf("\nMelody finished.\n\n");

    printf("Timer channel information:\n");
    display_timer_info(0);
    display_timer_info(1);
    display_timer_info(2);

    printf("Press any key to exit...\n");
    getch();
    return 0;
}
