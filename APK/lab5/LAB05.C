#include <dos.h>
#include <stdio.h>
#include <conio.h>

#define KBD_DATA_PORT 0x60
#define KBD_STATUS_PORT 0x64

#define KBD_CMD_SET_LEDS 0xED
#define KBD_RES_ACK 0xFA
#define KBD_RES_RESEND 0xFE

#define KBD_STAT_OUT_BUF_FULL 0x01
#define KBD_STAT_IN_BUF_FULL 0x02

volatile int exit_flag = 0;
volatile int response_received = 0;
volatile unsigned char kbd_response_code = 0;
volatile int expecting_response = 0;

void interrupt (*old_int9)();

void interrupt new_int9();
unsigned long get_bios_ticks(void);
void clear_kbd_buffer(void);
int wait_for_kbd_ready(unsigned long timeout_ms);
int send_kbd_byte(unsigned char byte_to_send);
int set_leds(unsigned char led_mask);
void morse_dot(void);
void morse_dash(void);
void morse_gap_intra_char(void);
void morse_gap_inter_char(void);
void morse_s(void);
void morse_o(void);

#define DOT_DURATION 800
#define DASH_DURATION (DOT_DURATION * 3)
#define GAP_INTRA (DOT_DURATION)
#define GAP_INTER (DOT_DURATION * 3)
#define GAP_WORD (DOT_DURATION * 7)
#define LED_ON 0x04

#define KBD_RESPONSE_TIMEOUT 1500

unsigned long get_bios_ticks(void) {
    unsigned long ticks;
    disable();
    ticks = *(unsigned long far *)0x0040006CL;
    enable();
    return ticks;
}

void clear_kbd_buffer(void) {
    unsigned char temp;
    int count = 0;
    cprintf(" Clearing KBD buffer...\r\n");
    while ((inp(KBD_STATUS_PORT) & KBD_STAT_OUT_BUF_FULL) && (count < 10)) {
        delay(1);
        temp = inp(KBD_DATA_PORT);
        cprintf("  Cleared byte: 0x%02X\r\n", temp);
        count++;
    }
     if (count > 0) {
        cprintf(" KBD buffer cleared (%d bytes).\r\n", count);
     } else {
         cprintf(" KBD buffer was empty.\r\n");
     }
}

void interrupt new_int9() {
    unsigned char status;
    unsigned char scan_code;

    status = inp(KBD_STATUS_PORT);

    if (status & KBD_STAT_OUT_BUF_FULL) {
        scan_code = inp(KBD_DATA_PORT);

        if (expecting_response) {
            cprintf(" INT9: Got response 0x%02X while expecting.\r\n", scan_code);
            kbd_response_code = scan_code;
            response_received = 1;
            expecting_response = 0;
        } else {
            cprintf(" Key Scan Code: 0x%02X \r\n", scan_code);
            if (scan_code == 0x01) {
                cprintf(" ESC detected!\r\n");
                exit_flag = 1;
            }
        }
    }
    old_int9();
}


int wait_for_kbd_ready(unsigned long timeout_ms) {
    unsigned long start_ticks;
    unsigned long ticks_to_wait;
    unsigned long current_ticks;
    unsigned long elapsed_ticks;

    start_ticks = get_bios_ticks();
    ticks_to_wait = (timeout_ms * 18UL) / 1000UL;
    if (ticks_to_wait == 0) ticks_to_wait = 1;

    while (inp(KBD_STATUS_PORT) & KBD_STAT_IN_BUF_FULL) {
        current_ticks = get_bios_ticks();

        if (current_ticks >= start_ticks) {
            elapsed_ticks = current_ticks - start_ticks;
        } else {
            elapsed_ticks = (0xFFFFFFFFL - start_ticks) + current_ticks + 1;
        }

        if (elapsed_ticks >= ticks_to_wait) {
            cprintf(" Error: Timeout waiting for KBD ready to receive!\r\n");
            return 0;
        }
        delay(1);
    }
    return 1;
}

int send_kbd_byte(unsigned char byte_to_send) {
    int retries = 0;
    unsigned long start_ticks;
    unsigned long ticks_to_wait;
    unsigned long current_ticks;
    unsigned long elapsed_ticks;

#define SEND_KBD_MAX_RETRIES 3

    ticks_to_wait = (KBD_RESPONSE_TIMEOUT * 18UL) / 1000UL;
     if (ticks_to_wait == 0) ticks_to_wait = 1;

send_retry:
    cprintf(" Attempting to send 0x%02X (try %d)...\r\n", byte_to_send, retries + 1);

    if (!wait_for_kbd_ready(KBD_RESPONSE_TIMEOUT)) {
        return 0;
    }

    response_received = 0;
    kbd_response_code = 0;
    expecting_response = 1;
    cprintf("  Set expecting_response=1\r\n");


    cprintf("  Sending 0x%02X ... ", byte_to_send);
    outp(KBD_DATA_PORT, byte_to_send);
    cprintf(" Sent.\r\n");


    start_ticks = get_bios_ticks();
    cprintf("  Waiting for response...\r\n");

    while (!response_received) {
        if (exit_flag) {
             cprintf("  Exit flag detected during wait.\r\n");
             expecting_response = 0; 
             return 0;
        }

        current_ticks = get_bios_ticks();
        if (current_ticks >= start_ticks) {
            elapsed_ticks = current_ticks - start_ticks;
        } else {
            elapsed_ticks = (0xFFFFFFFFL - start_ticks) + current_ticks + 1;
        }

        if (elapsed_ticks >= ticks_to_wait) {
            cprintf(" Error: Timeout waiting for KBD response to 0x%02X!\r\n", byte_to_send);
            expecting_response = 0;
            return 0;
        }
         delay(5);
    }

    cprintf("  Response received: 0x%02X.\r\n", kbd_response_code);

    if (kbd_response_code == KBD_RES_RESEND) {
        retries++;
        if (retries < SEND_KBD_MAX_RETRIES) {
            cprintf("  Response is 0xFE, retrying send...\r\n");
             delay(10);
            goto send_retry;
        } else {
            cprintf(" Error: Max retries exceeded for byte 0x%02X after 0xFE response.\r\n");
            return 0;
        }
    } else if (kbd_response_code == KBD_RES_ACK) {
        cprintf("  Response is 0xFA (ACK). Send successful.\r\n");
        return 1;
    } else {
        cprintf(" Error: Unexpected KBD response 0x%02X for byte 0x%02X.\r\n", kbd_response_code, byte_to_send);
        return 0;
    }
#undef SEND_KBD_MAX_RETRIES
}


int set_leds(unsigned char led_mask) {
    int success_cmd, success_mask;

    cprintf("--- Setting LEDs to 0x%02X ---\r\n", led_mask);
    success_cmd = send_kbd_byte(KBD_CMD_SET_LEDS);
    if (!success_cmd || exit_flag) { /* Проверяем и флаг выхода */
        cprintf(" Error or Exit: Failed to send SET_LEDS command (0xED).\r\n");
        cprintf("--- Set LEDs failed ---\r\n");
        return 0;
    }
    cprintf("  Command 0xED sent successfully (ACK received).\r\n");
    delay(50);

    success_mask = send_kbd_byte(led_mask);
    if (!success_mask || exit_flag) { /* Проверяем и флаг выхода */
        cprintf(" Error or Exit: Failed to send LED mask (0x%02X).\r\n", led_mask);
        cprintf("--- Set LEDs failed ---\r\n");
        return 0;
    }
    cprintf("  Mask 0x%02X sent successfully (ACK received).\r\n", led_mask);
    cprintf("--- Set LEDs successful ---\r\n");

    if (led_mask != 0) {
         printf("===> SIMULATED: LED ON <===\n");
    } else {
         printf("===> SIMULATED: LED OFF <===\n");
    }
    fflush(stdout);

    return 1;
}


void morse_dot(void) {
    if (exit_flag) return;
    cprintf("."); fflush(stdout);
    if (set_leds(LED_ON)) {
        delay(DOT_DURATION);
    }
    if (exit_flag) return;
    set_leds(0);
}

void morse_dash(void) {
     if (exit_flag) return;
    cprintf("-"); fflush(stdout);
    if (set_leds(LED_ON)) {
        delay(DASH_DURATION);
    }
     if (exit_flag) return;
    set_leds(0);
}

void morse_gap_intra_char(void) {
    if (exit_flag) return;
    delay(GAP_INTRA);
}

void morse_gap_inter_char(void) {
     if (exit_flag) return;
    delay(GAP_INTER);
     cprintf(" "); fflush(stdout);
}

void morse_s(void) {
    if (exit_flag) return; morse_dot();
    if (exit_flag) return; morse_gap_intra_char();
    if (exit_flag) return; morse_dot();
    if (exit_flag) return; morse_gap_intra_char();
    if (exit_flag) return; morse_dot();
}

void morse_o(void) {
    if (exit_flag) return; morse_dash();
    if (exit_flag) return; morse_gap_intra_char();
    if (exit_flag) return; morse_dash();
    if (exit_flag) return; morse_gap_intra_char();
    if (exit_flag) return; morse_dash();
}


int main() {
    clrscr();
    printf("Keyboard LED Morse SOS Simulation (Once)\n");
    printf("Then waits and prints key scan codes.\n");
    printf("Press ESC to exit.\n");
    printf("Communication log:\n");

    disable();
    old_int9 = getvect(0x09);
    setvect(0x09, new_int9);
    enable();

    clear_kbd_buffer();

    printf("\n--- Starting SOS Sequence ---\n");

    if (!exit_flag) { cprintf("S"); fflush(stdout); morse_s(); }
    if (!exit_flag) { morse_gap_inter_char(); }

    if (!exit_flag) { cprintf("O"); fflush(stdout); morse_o(); }
    if (!exit_flag) { morse_gap_inter_char(); }

    if (!exit_flag) { cprintf("S"); fflush(stdout); morse_s(); }

    printf("\n--- SOS Sequence Finished ---\n");

    if (!exit_flag) {
      printf("\nNow waiting for key presses (Scan codes will be printed)...\n");
      printf("Press ESC to exit.\n");
    }

    while (!exit_flag) {
        delay(100);
    }

    printf("\nExiting program...\n");

    printf("Attempting final SIMULATED LED OFF...\n");
    set_leds(0);


    disable();
    setvect(0x09, old_int9);
    enable();

    printf("Original interrupt handler restored. Bye!\n");

    return 0;
}
