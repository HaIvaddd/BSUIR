#include <dos.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <conio.h>

#define MASTER_BASE_VECTOR 0x08
#define SLAVE_BASE_VECTOR  0xB8

void print_byte(char far* screen, unsigned char byte) {
    int bit;
    int i;

    for (i = 0; i < 8; ++i) {
        bit = byte % 2;
        byte = byte >> 1;
        *screen = '0' + bit;
        screen += 2;
    }
}

void print(void) {
    char far* screen = (char far*)MK_FP(0xB800, 0);

    print_byte(screen, inp(0x21));
    screen += 18;

    print_byte(screen, inp(0xA1));

    screen += 142;

    outp(0x20, 0x0A);
    print_byte(screen, inp(0x20));
    screen += 18;

    outp(0xA0, 0x0A);
    print_byte(screen, inp(0xA0));

    screen += 142;

    outp(0x20, 0x0B);
    print_byte(screen, inp(0x20));
    screen += 18;

    outp(0xA0, 0x0B);
    print_byte(screen, inp(0xA0));
}

void interrupt (*old_irq0_handler)(void);
void interrupt (*old_irq1_handler)(void);
void interrupt (*old_irq2_handler)(void);
void interrupt (*old_irq3_handler)(void);
void interrupt (*old_irq4_handler)(void);
void interrupt (*old_irq5_handler)(void);
void interrupt (*old_irq6_handler)(void);
void interrupt (*old_irq7_handler)(void);

void interrupt new_irq0_handler(void) { print(); old_irq0_handler(); outp(0x20, 0x20); }
void interrupt new_irq1_handler(void) { print(); old_irq1_handler(); outp(0x20, 0x20); }
void interrupt new_irq2_handler(void) { print(); old_irq2_handler(); outp(0x20, 0x20); }
void interrupt new_irq3_handler(void) { print(); old_irq3_handler(); outp(0x20, 0x20); }
void interrupt new_irq4_handler(void) { print(); old_irq4_handler(); outp(0x20, 0x20); }
void interrupt new_irq5_handler(void) { print(); old_irq5_handler(); outp(0x20, 0x20); }
void interrupt new_irq6_handler(void) { print(); old_irq6_handler(); outp(0x20, 0x20); }
void interrupt new_irq7_handler(void) { print(); old_irq7_handler(); outp(0x20, 0x20); }

void interrupt (*old_irq8_handler)(void);
void interrupt (*old_irq9_handler)(void);
void interrupt (*old_irq10_handler)(void);
void interrupt (*old_irq11_handler)(void);
void interrupt (*old_irq12_handler)(void);
void interrupt (*old_irq13_handler)(void);
void interrupt (*old_irq14_handler)(void);
void interrupt (*old_irq15_handler)(void);

void interrupt new_irq8_handler(void) { print(); old_irq8_handler(); outp(0xA0, 0x20); outp(0x20, 0x20); }
void interrupt new_irq9_handler(void) { print(); old_irq9_handler(); outp(0xA0, 0x20); outp(0x20, 0x20); }
void interrupt new_irq10_handler(void) { print(); old_irq10_handler(); outp(0xA0, 0x20); outp(0x20, 0x20); }
void interrupt new_irq11_handler(void) { print(); old_irq11_handler(); outp(0xA0, 0x20); outp(0x20, 0x20); }
void interrupt new_irq12_handler(void) { print(); old_irq12_handler(); outp(0xA0, 0x20); outp(0x20, 0x20); }
void interrupt new_irq13_handler(void) { print(); old_irq13_handler(); outp(0xA0, 0x20); outp(0x20, 0x20); }
void interrupt new_irq14_handler(void) { print(); old_irq14_handler(); outp(0xA0, 0x20); outp(0x20, 0x20); }
void interrupt new_irq15_handler(void) { print(); old_irq15_handler(); outp(0xA0, 0x20); outp(0x20, 0x20); }

void init_new_handlers(void) {
    old_irq0_handler = getvect(0x08);
    setvect(MASTER_BASE_VECTOR, new_irq0_handler);

    old_irq1_handler = getvect(0x09);
    setvect(MASTER_BASE_VECTOR + 1, new_irq1_handler);

    old_irq2_handler = getvect(0x0A);
    setvect(MASTER_BASE_VECTOR + 2, new_irq2_handler);

    old_irq3_handler = getvect(0x0B);
    setvect(MASTER_BASE_VECTOR + 3, new_irq3_handler);

    old_irq4_handler = getvect(0x0C);
    setvect(MASTER_BASE_VECTOR + 4, new_irq4_handler);

    old_irq5_handler = getvect(0x0D);
    setvect(MASTER_BASE_VECTOR + 5, new_irq5_handler);

    old_irq6_handler = getvect(0x0E);
    setvect(MASTER_BASE_VECTOR + 6, new_irq6_handler);

    old_irq7_handler = getvect(0x0F);
    setvect(MASTER_BASE_VECTOR + 7, new_irq7_handler);

    old_irq8_handler = getvect(0x70); 
    setvect(SLAVE_BASE_VECTOR, new_irq8_handler); 

    old_irq9_handler = getvect(0x71);
    setvect(SLAVE_BASE_VECTOR + 1, new_irq9_handler);

    old_irq10_handler = getvect(0x72);
    setvect(SLAVE_BASE_VECTOR + 2, new_irq10_handler);

    old_irq11_handler = getvect(0x73);
    setvect(SLAVE_BASE_VECTOR + 3, new_irq11_handler);

    old_irq12_handler = getvect(0x74);
    setvect(SLAVE_BASE_VECTOR + 4, new_irq12_handler);

    old_irq13_handler = getvect(0x75);
    setvect(SLAVE_BASE_VECTOR + 5, new_irq13_handler);

    old_irq14_handler = getvect(0x76);
    setvect(SLAVE_BASE_VECTOR + 6, new_irq14_handler);

    old_irq15_handler = getvect(0x77);
    setvect(SLAVE_BASE_VECTOR + 7, new_irq15_handler);

    disable();

    outp(0x20, 0x11);   
    outp(0x21, MASTER_BASE_VECTOR);      
    outp(0x21, 0x04);  
    outp(0x21, 0x01);

    outp(0xA0, 0x11);      
    outp(0xA1, SLAVE_BASE_VECTOR);     
    outp(0xA1, 0x02);  
    outp(0xA1, 0x01);   

    enable();
}

int main(void) {
    unsigned far* fp;

    init_new_handlers();
    clrscr();

    puts("                   -  MASK");
    puts("                   -  REQUEST");
    puts("                   -  SERVICE");
    puts("MASTER    SLAVE");

    freemem(_psp);
    keep(0, (_DS - _CS) + (_SP / 16) + 1);

    return EXIT_SUCCESS;
}
