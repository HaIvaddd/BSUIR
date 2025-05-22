.MODEL SMALL
.STACK 200h

.DATA
    ; Константы
    BUF_SIZE    EQU 1024            ; Размер буфера для чтения файла
    NEWLINE     EQU 13              ; Код возврата каретки (CR)
    DOLLAR      EQU '$'             ; Конец строки для вывода
    TEN         DW 10               ; Для преобразования строки в число

    ; Переменные
    CMD_LENGTH  DB ?                ; Длина командной строки
    CMD_LINE    DB 128 DUP(0)       ; Буфер для командной строки
    FILE_PATH   DB 128 DUP(0), DOLLAR  ; Путь к файлу
    K_STR       DB 16 DUP(0)        ; Строка для K (номер строки)
    N_STR       DB 16 DUP(0)        ; Строка для N (число запусков)
    ARGC        DW 0                ; Количество аргументов
    K_VALUE     DW 0                ; Числовое значение K
    N_VALUE     DW 0                ; Числовое значение N
    BUFFER      DB BUF_SIZE DUP(0)  ; Буфер для чтения файла
    FILE_HANDLE DW 0                ; Дескриптор файла
    PROG_NAME   DB 128 DUP(0),NEWLINE, 10, DOLLAR     ; Имя программы для запуска
    LINE_COUNT  DW 0                ; Счётчик строк при чтении файла
    CURR_LEN    DW 0                ; Текущая длина строки

    ; Буферы для EXEC
	EXEC_PARAM  DB 12 DUP(0)        ; Блок параметров (EPB) — 12 байт
    EXEC_CMDLINE DB 2 DUP(0)        ; Командная строка (длина + данные)
    EXEC_ENV    DW 0                ; Сегмент окружения (0 = текущее окружение)
    EXEC_FCB1   DB 16 DUP(0)        ; FCB 1 (пустой)
    EXEC_FCB2   DB 16 DUP(0)        ; FCB 2 (пустой)

    ; Сообщения
    MSG_WELCOME DB 'Launch a program N times from K-th line in file', NEWLINE, 10, DOLLAR
    MSG_OPENING DB 'Opening file: $'
    MSG_LAUNCH  DB NEWLINE, 10, 'Launching program: $'
    MSG_DONE    DB NEWLINE, 10, 'Program completed.', NEWLINE, 10, DOLLAR
    MSG_ERR_ARGC DB NEWLINE, 10, 'Error: Need 3 arguments (file_path K N)', NEWLINE, 10, DOLLAR
    MSG_ERR_K   DB NEWLINE, 10, 'Error: Invalid K value!', NEWLINE, 10, DOLLAR
    MSG_ERR_N   DB NEWLINE, 10, 'Error: Invalid N value!', NEWLINE, 10, DOLLAR
    MSG_ERR_FILE DB NEWLINE, 10, 'Error opening file (code: $'
    MSG_ERR_READ DB NEWLINE, 10, 'Error reading file (code: $'
    MSG_ERR_CLOSE DB NEWLINE, 10, 'Error closing file (code: $'
    MSG_ERR_EXEC DB NEWLINE, 10, 'Error launching program (code: $'
    MSG_ERR_INVALID_PROG DB NEWLINE, 10, 'Error: Invalid program name!', NEWLINE, 10, DOLLAR
    MSG_DEBUG_PROG DB NEWLINE, 10, 'Attempting to launch: $'
	MSG_ERR_MEMORY DB NEWLINE, 10, 'Error resizing memory (code: $'
	MSG_AVAILABLE_MEMORY DB NEWLINE, 10, 'Available memory (paragraphs): $'
	MSG_AVAILABLE_MEMORY_BEFORE DB NEWLINE, 10, 'Available memory before (paragraphs): $'
	MSG_AVAILABLE_MEMORY_AFTER DB NEWLINE, 10, 'Available memory after (paragraphs): $'
	MSG_RETURNED DB NEWLINE, 10, 'Returned from EXEC call', NEWLINE, 10, DOLLAR
	MSG_ERR_ALLOC_OVERLAY DB NEWLINE, 10, 'Error allocating memory for overlay (code: $'
	MSG_ERR_ALLOC_STACK DB NEWLINE, 10, 'Error allocating stack for child program (code: $'

.CODE
START:
    ; Инициализация сегментов
    PUSH DS
    MOV AX, @DATA
    MOV ES, AX

    ; Копирование командной строки из PSP
    MOV AL, DS:[80h]
    MOV ES:[CMD_LENGTH], AL
    MOV SI, 81h
    MOV DI, OFFSET CMD_LINE
    MOV CL, ES:[CMD_LENGTH]
    XOR CH, CH
    JCXZ NO_ARGS
    CLD
    REP MOVSB

NO_ARGS:
    POP AX
    MOV AX, @DATA
    MOV DS, AX

    ; Получение PSP
    MOV AH, 62h
    INT 21h
    MOV ES, BX          ; ES = PSP

    ; Освобождение памяти
    MOV BX, 1000         ; Запрашиваем 1000 параграфов (16000 байт) для текущей программы
    MOV AH, 4Ah
    INT 21h
    JNC memory_ok
    MOV DX, OFFSET MSG_ERR_MEMORY
	push ax
    MOV AH, 09h
    INT 21h
	pop ax
    CALL PRINT_NUM
    MOV AX, 4C01h
    INT 21h
memory_ok:

    ; Вывод приветственного сообщения
    MOV DX, OFFSET MSG_WELCOME
    MOV AH, 09h
    INT 21h

    ; Парсинг командной строки
    CALL PARSE_CMDLINE
    CMP [ARGC], 3
    JE SKIP_ARGC_ERROR_PROC
	call ARGC_ERROR_PROC
	SKIP_ARGC_ERROR_PROC:
    ; Преобразование K и N в числа
    MOV SI, OFFSET K_STR
    CALL STR_TO_NUM
    CMP AX, 0
    JNE SKIP_K_ERROR_PROC1
	CALL K_ERROR_PROC
	SKIP_K_ERROR_PROC1:
    CMP AX, 255
    JNA SKIP_K_ERROR_PROC2
	CALL K_ERROR_PROC
	SKIP_K_ERROR_PROC2:
    MOV [K_VALUE], AX

    MOV SI, OFFSET N_STR
    CALL STR_TO_NUM
    CMP AX, 0
    JNE SKIP_N_ERROR_PROC1
	CALL N_ERROR_PROC
	SKIP_N_ERROR_PROC1:
    CMP AX, 255
    JNA SKIP_N_ERROR_PROC2
	CALL N_ERROR_PROC
	SKIP_N_ERROR_PROC2:
    MOV [N_VALUE], AX

    ; Вывод имени файла
	MOV DX, OFFSET MSG_OPENING
    MOV AH, 09h
    INT 21h
    MOV DX, OFFSET FILE_PATH
    INT 21h

    ; Открытие файла
    MOV AH, 3Dh
    MOV AL, 0
    MOV DX, OFFSET FILE_PATH
    INT 21h
    JNC skip_open_error
    CALL OPEN_ERROR_PROC
skip_open_error:
    MOV [FILE_HANDLE], AX

    ; Чтение файла и поиск K-й строки
    CALL FIND_K_LINE
    CMP BYTE PTR [PROG_NAME], 0
    JE CLOSE_FILE

    ; Проверка корректности PROG_NAME
    MOV SI, OFFSET PROG_NAME
CHECK_PROG_NAME:
    CMP BYTE PTR [SI], 0
    JE PROG_NAME_OK
    CMP BYTE PTR [SI], ' '
    JE INVALID_PROG_NAME
    INC SI
    JMP CHECK_PROG_NAME
INVALID_PROG_NAME:
    CALL INVALID_PROG_NAME_PROC
PROG_NAME_OK:

    ; Вывод имени программы
    MOV DX, OFFSET MSG_LAUNCH
    MOV AH, 09h
    INT 21h
    MOV DX, OFFSET PROG_NAME
    INT 21h

    ; Запуск программы N раз
    MOV CX, [N_VALUE]
LAUNCH_LOOP:
    PUSH CX
    CALL LAUNCH_PROGRAM
    POP CX
    LOOP LAUNCH_LOOP

CLOSE_FILE:
    MOV AH, 3Eh
    MOV BX, [FILE_HANDLE]
    INT 21h
    JNC skip_close_error
    CALL CLOSE_ERROR_PROC
skip_close_error:

    MOV DX, OFFSET MSG_DONE
    MOV AH, 09h
    INT 21h
    MOV AX, 4C00h
    INT 21h

; ======== Процедуры обработки ошибок ========
ARGC_ERROR_PROC PROC
    MOV DX, OFFSET MSG_ERR_ARGC
    MOV AH, 09h
    INT 21h
    MOV AX, 4C01h
    INT 21h
ARGC_ERROR_PROC ENDP

K_ERROR_PROC PROC
    MOV DX, OFFSET MSG_ERR_K
    MOV AH, 09h
    INT 21h
    MOV AX, 4C01h
    INT 21h
K_ERROR_PROC ENDP

N_ERROR_PROC PROC
    MOV DX, OFFSET MSG_ERR_N
    MOV AH, 09h
    INT 21h
    MOV AX, 4C01h
    INT 21h
N_ERROR_PROC ENDP

OPEN_ERROR_PROC PROC
    MOV DX, OFFSET MSG_ERR_FILE
    MOV AH, 09h
    INT 21h
    CALL PRINT_NUM
    MOV AX, 4C01h
    INT 21h
OPEN_ERROR_PROC ENDP

READ_ERROR_PROC PROC
    MOV DX, OFFSET MSG_ERR_READ
    MOV AH, 09h
    INT 21h
    CALL PRINT_NUM
    JMP CLOSE_FILE
READ_ERROR_PROC ENDP

CLOSE_ERROR_PROC PROC
    MOV DX, OFFSET MSG_ERR_CLOSE
    MOV AH, 09h
    INT 21h
    CALL PRINT_NUM
    MOV AX, 4C01h
    INT 21h
CLOSE_ERROR_PROC ENDP

EXEC_ERROR_PROC PROC
    PUSH AX
	MOV DX, OFFSET MSG_ERR_EXEC
    MOV AH, 09h
    INT 21h
	POP AX
    CALL PRINT_NUM
    MOV AX, 4C01h
    INT 21h
EXEC_ERROR_PROC ENDP

INVALID_PROG_NAME_PROC PROC
    MOV DX, OFFSET MSG_ERR_INVALID_PROG
    MOV AH, 09h
    INT 21h
    MOV AX, 4C01h
    INT 21h
INVALID_PROG_NAME_PROC ENDP

; ======== Парсинг командной строки ========
PARSE_CMDLINE PROC
    PUSH SI
    PUSH DI
    PUSH BX

    MOV SI, OFFSET CMD_LINE
    MOV CL, [CMD_LENGTH]
    XOR CH, CH
    JCXZ CMD_DONE

    XOR BX, BX
    MOV DI, OFFSET FILE_PATH

SKIP_SPACES:
    CMP CX, 0
    JE CMD_DONE
    CMP BYTE PTR [SI], ' '
    JNE START_PARAM
    INC SI
    DEC CX
    JMP SKIP_SPACES

START_PARAM:
    CALL COPY_STRING
    INC BX
    CMP BX, 1
    JE FIRST_PARAM
    CMP BX, 2
    JE SECOND_PARAM
    CMP BX, 3
    JA CMD_DONE

FIRST_PARAM:
    MOV DI, OFFSET K_STR
    JMP CHECK_NEXT

SECOND_PARAM:
    MOV DI, OFFSET N_STR
    JMP CHECK_NEXT

CHECK_NEXT:
    CMP CX, 0
    JE CMD_DONE
    CMP BYTE PTR [SI], ' '
    JNE CMD_DONE
    INC SI
    DEC CX
    JZ CMD_DONE
    CMP BYTE PTR [SI], ' '
    JE CHECK_NEXT
    JMP START_PARAM

CMD_DONE:
    MOV [ARGC], BX
    POP BX
    POP DI
    POP SI
    RET

COPY_STRING:
    CMP CX, 0
    JE COPY_DONE
    CMP BYTE PTR [SI], ' '
    JE COPY_DONE
    CMP BYTE PTR [SI], NEWLINE
    JE COPY_DONE
    MOV AL, [SI]
    MOV [DI], AL
    INC SI
    INC DI
    DEC CX
    JMP COPY_STRING
COPY_DONE:
    MOV BYTE PTR [DI], 0
    RET
PARSE_CMDLINE ENDP

; ======== Преобразование строки в число ========
STR_TO_NUM PROC
    PUSH SI
    XOR AX, AX
    XOR BX, BX

NEXT_DIGIT:
    MOV BL, [SI]
    CMP BL, 0
    JE NUM_DONE
    CMP BL, '0'
    JB NUM_ERROR
    CMP BL, '9'
    JA NUM_ERROR
    SUB BL, '0'
    MUL WORD PTR [TEN]
    ADD AX, BX
    INC SI
    JMP NEXT_DIGIT

NUM_ERROR:
    XOR AX, AX
NUM_DONE:
    POP SI
    RET
STR_TO_NUM ENDP

; ======== Поиск K-й строки в файле ========
FIND_K_LINE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

READ_LOOP:
    MOV AH, 3Fh
    MOV BX, [FILE_HANDLE]
    MOV CX, BUF_SIZE
    MOV DX, OFFSET BUFFER
    INT 21h
    JNC skip_read_error
    CALL READ_ERROR_PROC
skip_read_error:
    CMP AX, 0
    JE END_FILE

    MOV CX, AX
    MOV SI, OFFSET BUFFER
    XOR DI, DI

CHECK_CHAR:
    CMP BYTE PTR [SI], NEWLINE
    JE LINE_END_CR
    CMP BYTE PTR [SI], 0Ah
    JE LINE_END_LF
    CMP DI, 127
    JAE NEXT_CHAR
    MOV AL, [SI]
    MOV [PROG_NAME + DI], AL
    INC DI
    JMP NEXT_CHAR

LINE_END_CR:
    CMP CX, 1
    JE LINE_END
    CMP BYTE PTR [SI+1], 0Ah
    JNE LINE_END
    INC SI
    DEC CX
    JMP LINE_END_LF

LINE_END_LF:
    CMP DI, 0
    JE RESET_LINE
LINE_END:
    INC [LINE_COUNT]
    MOV AX, [LINE_COUNT]
    CMP AX, [K_VALUE]
    JNE RESET_LINE
    MOV BYTE PTR [PROG_NAME + DI], 0
    JMP END_PROC

RESET_LINE:
    XOR DI, DI
    MOV BYTE PTR [PROG_NAME], 0

NEXT_CHAR:
    INC SI
    LOOP CHECK_CHAR
    JMP READ_LOOP

END_FILE:
    MOV BYTE PTR [PROG_NAME], 0

END_PROC:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
FIND_K_LINE ENDP

; ======== Запуск программы ========
LAUNCH_PROGRAM PROC
	PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES
    PUSH DS
    PUSH SS
    PUSH SP
    PUSHF

    ; Подготовка параметров для EXEC
    MOV AX, @DATA
    MOV ES, AX
    MOV DS, AX

    ; Настройка строки параметров
    MOV SI, OFFSET EXEC_CMDLINE
    MOV BYTE PTR [SI], 0        ; Длина командной строки = 0
    MOV BYTE PTR [SI+1], 0Dh    ; Завершающий CR (0Dh)

    ; Настройка EXEC_PARAM
    ; +00h: Сегмент окружения
    MOV AX, 0                   ; Используем текущее окружение
    MOV [EXEC_ENV], AX
    MOV AX, [EXEC_ENV]
    MOV WORD PTR [EXEC_PARAM], AX

    ; +02h: Офсет и сегмент командной строки
    MOV AX, OFFSET EXEC_CMDLINE
    MOV WORD PTR [EXEC_PARAM+2], AX
    MOV AX, DS
    MOV WORD PTR [EXEC_PARAM+4], AX

    ; +06h: Офсет и сегмент первого FCB
    MOV AX, OFFSET EXEC_FCB1
    MOV WORD PTR [EXEC_PARAM+6], AX
    MOV AX, DS
    MOV WORD PTR [EXEC_PARAM+8], AX

    ; +0Ah: Офсет и сегмент второго FCB
    MOV AX, OFFSET EXEC_FCB2
    MOV WORD PTR [EXEC_PARAM+0Ah], AX
    MOV AX, DS
    MOV WORD PTR [EXEC_PARAM+0Ch], AX

    ; Отладочный вывод
    MOV DX, OFFSET MSG_DEBUG_PROG
    MOV AH, 09h
    INT 21h
    MOV DX, OFFSET PROG_NAME
    INT 21h

    ; Запуск программы
    MOV AX, 4B00h
    MOV BX, OFFSET EXEC_PARAM
    MOV DX, OFFSET PROG_NAME
    INT 21h
    JNC skip_exec_error
    CALL EXEC_ERROR_PROC
skip_exec_error:

    ; Восстановление флагов и регистров
	POPF
    POP SP
    POP SS
    POP DS
    POP ES

    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
	
	MOV AX, @DATA
    MOV DS, AX
	
    RET
LAUNCH_PROGRAM ENDP

; ======== Вывод числа ========
PRINT_NUM PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV BX, 10
    XOR CX, CX

DIV_LOOP:
    XOR DX, DX
    DIV BX
    PUSH DX
    INC CX
    CMP AX, 0
    JNE DIV_LOOP

PRINT_LOOP:
    POP DX
    ADD DL, '0'
    MOV AH, 02h
    INT 21h
    LOOP PRINT_LOOP

    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUM ENDP

END START
