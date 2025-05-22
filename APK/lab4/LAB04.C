#include <dos.h>
#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <string.h>

#define RTC_ADDR 0x70
#define RTC_DATA 0x71

#define RTC_SECONDS 0x00
#define RTC_ALARM_SECONDS 0x01
#define RTC_MINUTES 0x02
#define RTC_ALARM_MINUTES 0x03
#define RTC_HOURS 0x04
#define RTC_ALARM_HOURS 0x05
#define RTC_DAY_OF_WEEK 0x06
#define RTC_DAY_OF_MONTH 0x07
#define RTC_MONTH 0x08
#define RTC_YEAR 0x09
#define RTC_REG_A 0x0A
#define RTC_REG_B 0x0B
#define RTC_REG_C 0x0C
#define RTC_REG_D 0x0D 

#define RTC_A_UIP 0x80
#define RTC_A_RATE_MASK 0x0F

#define RTC_B_SET 0x80
#define RTC_B_PIE 0x40
#define RTC_B_AIE 0x20
#define RTC_B_UIE 0x10
#define RTC_B_SQWE 0x08
#define RTC_B_DM 0x04
#define RTC_B_24HR 0x02
#define RTC_B_DSE 0x01

#define RTC_C_IRQF 0x80
#define RTC_C_PF 0x40
#define RTC_C_AF 0x20
#define RTC_C_UF 0x10

#define PIC1_CMD 0x20
#define PIC1_DATA 0x21
#define PIC2_CMD 0xA0
#define PIC2_DATA 0xA1
#define PIC_EOI 0x20

#define IRQ8_MASK 0x01

char bcdData[6];
unsigned char currentTime[6];

volatile int delayActive = 0;
volatile unsigned long delayCounter = 0;
volatile unsigned long delayTargetMs = 0;
volatile unsigned int currentRateDivider = 1024;

volatile int alarmArmed = 0;
volatile int alarmTriggered = 0;

char* months[] = {
    "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
    "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"
};

void interrupt (*oldRTC_ISR)();

int rtcInterruptsActive = 0;

void Menu();
void ShowTime();
int ReadRTCRegister(int reg);
void WriteRTCRegister(int reg, int value);
void WaitForRTCUpdateEnd();
int BCDToDec(int bcd);
int DecToBCD(int dec);
void SetTime();
void EnterDateTime();
void MyDelay(unsigned long delayMs);
void SetDelayRate();
void EnterAlarmTime();
void SetAlarm();
void ResetAlarm();
void InstallRTC_ISR();
void RemoveRTC_ISR();
void interrupt newRTC_ISR();
void ClearInputBuffer();

int main() {
    int regB = 0;
    disable();
    regB = ReadRTCRegister(RTC_REG_B);

    if (!(regB & RTC_B_24HR)) {
        WaitForRTCUpdateEnd();
        WriteRTCRegister(RTC_REG_B, regB | RTC_B_24HR);
    }
    enable();

    Menu();

    ResetAlarm();
    if (rtcInterruptsActive > 0) {
        RemoveRTC_ISR();
    }

    printf("\nExiting...\n");
    return 0;
}

void Menu() {
    char choice;
    do {
        system("cls");
        ShowTime();

        printf("\n--- MENU ---\n");
        printf("1 - Set Time/Date\n");
        printf("2 - Set Delay (ms)\n");
        printf("3 - Set Alarm Time\n");
        printf("4 - Reset Alarm\n");
        printf("5 - Set Delay Rate (current: %d Hz)\n", currentRateDivider);
        printf("0 - Exit\n");

        if (alarmArmed) {
            printf("\nSTATUS: Alarm is ARMED.\n");
        }
        if (alarmTriggered) {
            printf("\n!!!! ALARM !!!! ALARM !!!! ALARM !!!!\n");
            alarmTriggered = 0;
        }

        printf("\nEnter choice: ");

        delay(50);

        if (kbhit()) {
             choice = getch();

            switch (choice) {
                case '1':
                    SetTime();
                    break;
                case '2':
                    {
                        unsigned long ms;
                        printf("\nEnter delay in milliseconds: ");
                        if (scanf("%lu", &ms) == 1) {
                             ClearInputBuffer();
                             printf("Starting %lu ms delay...\n", ms);
                             MyDelay(ms);
                             printf("Delay finished.\n");
                             printf("Press any key to continue...");
                             getch();
                        } else {
                             ClearInputBuffer();
                             printf("Invalid input.\n");
                             delay(1000);
                        }
                    }
                    break;
                case '3':
                    SetAlarm();
                    break;
                case '4':
                    ResetAlarm();
                    printf("Alarm reset.\n");
                    delay(1000);
                    break;
                case '5':
                    SetDelayRate();
                     break;
                case '0':
                    break;
                default:
                    printf("\nInvalid choice. Please try again.\n");
                    delay(1000);
                    break;
            }
        } else {
            choice = ' ';
        }

        if (alarmTriggered) {
             printf("\n!!!! ALARM !!!! Press any key to acknowledge.\n");
             getch();
             alarmTriggered = 0;
        }


    } while (choice != '0');
}

int ReadRTCRegister(int reg) {
    outp(RTC_ADDR, reg);
    return inp(RTC_DATA);
}

void WriteRTCRegister(int reg, int value) {
    outp(RTC_ADDR, reg);
    outp(RTC_DATA, value);
}

void WaitForRTCUpdateEnd() {
    while (ReadRTCRegister(RTC_REG_A) & RTC_A_UIP);
}

int BCDToDec(int bcd) {
    return ((bcd >> 4) * 10) + (bcd & 0x0F);
}

int DecToBCD(int dec) {
    return ((dec / 10) << 4) | (dec % 10);
}

void ShowTime() {
    int decData[6];
    int i;

    disable();
    WaitForRTCUpdateEnd();
    currentTime[0] = ReadRTCRegister(RTC_SECONDS);
    currentTime[1] = ReadRTCRegister(RTC_MINUTES);
    currentTime[2] = ReadRTCRegister(RTC_HOURS);
    currentTime[3] = ReadRTCRegister(RTC_DAY_OF_MONTH);
    currentTime[4] = ReadRTCRegister(RTC_MONTH);
    currentTime[5] = ReadRTCRegister(RTC_YEAR);
    enable();

    for (i = 0; i < 6; i++) {
        decData[i] = BCDToDec(currentTime[i]);
    }

    printf("Time: %02d:%02d:%02d\n", decData[2], decData[1], decData[0]);
    printf("Date: %02d %s %d\n", decData[3], months[decData[4] - 1], decData[5] + 2000);
}

void SetTime() {
    int regB = 0;
    int value_to_write_set = 0;
    int value_to_write_clear = 0;
    
    system("cls");
    EnterDateTime();

    printf("\nSetting new time...\n");

    disable();

    WaitForRTCUpdateEnd();

    regB = ReadRTCRegister(RTC_REG_B);
    value_to_write_set = regB | RTC_B_SET;

    WriteRTCRegister(RTC_REG_B, value_to_write_set);

    regB = ReadRTCRegister(RTC_REG_B);

    WriteRTCRegister(RTC_YEAR, bcdData[5]);
    WriteRTCRegister(RTC_MONTH, bcdData[4]);
    WriteRTCRegister(RTC_DAY_OF_MONTH, bcdData[3]);
    WriteRTCRegister(RTC_HOURS, bcdData[2]);
    WriteRTCRegister(RTC_MINUTES, bcdData[1]);
    WriteRTCRegister(RTC_SECONDS, bcdData[0]);

    regB = ReadRTCRegister(RTC_REG_B);
    
    value_to_write_clear = regB & ~RTC_B_SET;

    WriteRTCRegister(RTC_REG_B, value_to_write_clear);

    regB = ReadRTCRegister(RTC_REG_B);

    enable();

    printf("Time set successfully.\n");
    delay(1500);
}

void EnterDateTime() {
    int values[6];
    int yearOffset = 2000;

    printf("--- Enter New Date and Time ---\n");

    do {
        printf("Enter Year (00-99): ");
        scanf("%d", &values[0]); ClearInputBuffer();
    } while (values[0] < 0 || values[0] > 99);
    bcdData[5] = DecToBCD(values[0]);

    do {
        printf("Enter Month (1-12): ");
        scanf("%d", &values[1]); ClearInputBuffer();
    } while (values[1] < 1 || values[1] > 12);
    bcdData[4] = DecToBCD(values[1]);

    do {
        printf("Enter Day (1-31): ");
        scanf("%d", &values[2]); ClearInputBuffer();
    } while (values[2] < 1 || values[2] > 31);
    bcdData[3] = DecToBCD(values[2]);

    do {
        printf("Enter Hours (0-23): ");
        scanf("%d", &values[3]); ClearInputBuffer();
    } while (values[3] < 0 || values[3] > 23);
    bcdData[2] = DecToBCD(values[3]);

    do {
        printf("Enter Minutes (0-59): ");
        scanf("%d", &values[4]); ClearInputBuffer();
    } while (values[4] < 0 || values[4] > 59);
    bcdData[1] = DecToBCD(values[4]);

    do {
        printf("Enter Seconds (0-59): ");
        scanf("%d", &values[5]); ClearInputBuffer();
    } while (values[5] < 0 || values[5] > 59);
    bcdData[0] = DecToBCD(values[5]);
}

void EnterAlarmTime() {
    int values[3];

    printf("--- Enter Alarm Time ---\n");

    do {
        printf("Enter Hours (0-23): ");
        scanf("%d", &values[0]); ClearInputBuffer();
    } while (values[0] < 0 || values[0] > 23);
    bcdData[2] = DecToBCD(values[0]);

    do {
        printf("Enter Minutes (0-59): ");
        scanf("%d", &values[1]); ClearInputBuffer();
    } while (values[1] < 0 || values[1] > 59);
    bcdData[1] = DecToBCD(values[1]);

    do {
        printf("Enter Seconds (0-59): ");
        scanf("%d", &values[2]); ClearInputBuffer();
    } while (values[2] < 0 || values[2] > 59);
    bcdData[0] = DecToBCD(values[2]);
}

void InstallRTC_ISR() {
    disable();
    if (rtcInterruptsActive == 0) {
        oldRTC_ISR = getvect(0x70);
        setvect(0x70, newRTC_ISR);

        outp(PIC2_DATA, inp(PIC2_DATA) & ~IRQ8_MASK);
        ReadRTCRegister(RTC_REG_C);
    }
    rtcInterruptsActive++;
    enable();
}

void RemoveRTC_ISR() {
    disable();
    rtcInterruptsActive--;
    if (rtcInterruptsActive == 0 && oldRTC_ISR != NULL) {
        outp(PIC2_DATA, inp(PIC2_DATA) | IRQ8_MASK);

        setvect(0x70, oldRTC_ISR);
        oldRTC_ISR = NULL;
    }
     else if (rtcInterruptsActive < 0) {
         rtcInterruptsActive = 0;
     }
    enable();
}

void MyDelay(unsigned long delayMs) {
    unsigned long targetTicks;
    int regB, regB_after = 0;
    if (delayMs == 0) return;

    targetTicks = (delayMs * currentRateDivider) / 1000;
    if (targetTicks == 0) targetTicks = 1;

    InstallRTC_ISR();

    disable();
    delayCounter = 0;
    delayTargetMs = targetTicks;
    delayActive = 1;

    regB = ReadRTCRegister(RTC_REG_B);
    WriteRTCRegister(RTC_REG_B, regB | RTC_B_PIE);
    enable();

    while (delayActive) {

        if (kbhit() && getch() == 27) {
             printf("\nDelay interrupted by user.\n");
             delayActive = 0;
             break;
        }
    }

    disable();
    regB_after = ReadRTCRegister(RTC_REG_B);
    if (!(regB_after & RTC_B_AIE)) {
         WriteRTCRegister(RTC_REG_B, regB_after & ~RTC_B_PIE);
    } else {
         WriteRTCRegister(RTC_REG_B, regB_after & ~RTC_B_PIE);
    }
    delayActive = 0;
    enable();

    RemoveRTC_ISR();
}

void SetDelayRate() {
    int choice, rate_code = -1;
    int regA = 0;
    unsigned int new_rate = currentRateDivider;

    printf("\n--- Set Periodic Interrupt Rate ---\n");
    printf("Select frequency (default 1024 Hz):\n");
    printf("1 - 8192 Hz (~0.12 ms)\n");
    printf("2 - 4096 Hz (~0.24 ms)\n");
    printf("3 - 2048 Hz (~0.48 ms)\n");
    printf("4 - 1024 Hz (~0.97 ms)\n");
    printf("5 -  512 Hz (~1.95 ms)\n");
    printf("6 -  256 Hz (~3.90 ms)\n");
    printf("0 - Cancel\n");
    printf("Enter choice: ");

    scanf("%d", &choice); ClearInputBuffer();

    switch(choice) {
        case 1: rate_code = 0x03; new_rate = 8192; break;
        case 2: rate_code = 0x04; new_rate = 4096; break;
        case 3: rate_code = 0x05; new_rate = 2048; break;
        case 4: rate_code = 0x06; new_rate = 1024; break;
        case 5: rate_code = 0x07; new_rate = 512; break;
        case 6: rate_code = 0x08; new_rate = 256; break;
        case 0: return;
        default: printf("Invalid choice.\n"); delay(1000); return;
    }

    disable();
    WaitForRTCUpdateEnd();
    regA = ReadRTCRegister(RTC_REG_A);
    WriteRTCRegister(RTC_REG_A, (regA & ~RTC_A_RATE_MASK) | rate_code);
    currentRateDivider = new_rate;                       
    enable();

    printf("Rate set to %d Hz.\n", currentRateDivider);
    delay(1500);
}

void SetAlarm() {
    int regB = 0;

    system("cls");
    EnterAlarmTime();

    InstallRTC_ISR();

    disable();
    WaitForRTCUpdateEnd();

    WriteRTCRegister(RTC_ALARM_HOURS, bcdData[2]);
    WriteRTCRegister(RTC_ALARM_MINUTES, bcdData[1]);
    WriteRTCRegister(RTC_ALARM_SECONDS, bcdData[0]);

    regB = ReadRTCRegister(RTC_REG_B);
    WriteRTCRegister(RTC_REG_B, regB | RTC_B_AIE);

    alarmArmed = 1;
    alarmTriggered = 0;
    ReadRTCRegister(RTC_REG_C);

    enable();

    printf("Alarm set for %02d:%02d:%02d.\n", BCDToDec(bcdData[2]), BCDToDec(bcdData[1]), BCDToDec(bcdData[0]));
    delay(1500);
}

void ResetAlarm() {
    int regB = 0;

    if (!alarmArmed && !alarmTriggered) return;

    disable();
    regB = ReadRTCRegister(RTC_REG_B);
    WriteRTCRegister(RTC_REG_B, regB & ~RTC_B_AIE);

    alarmArmed = 0;
    alarmTriggered = 0;
    ReadRTCRegister(RTC_REG_C);

    enable();
    RemoveRTC_ISR();
}

void interrupt newRTC_ISR() {
    unsigned char regC_value;

    regC_value = ReadRTCRegister(RTC_REG_C);

    if ((regC_value & RTC_C_PF) && delayActive) {
        delayCounter++;
        if (delayCounter >= delayTargetMs) {
            delayActive = 0;
        }
    }

    if ((regC_value & RTC_C_AF) && alarmArmed) {
        alarmTriggered = 1;
        alarmArmed = 0;
    }

    outp(PIC2_CMD, PIC_EOI);
    outp(PIC1_CMD, PIC_EOI);
}

void ClearInputBuffer() {
    int c;
    while ((c = getchar()) != '\n' && c != EOF);
}

