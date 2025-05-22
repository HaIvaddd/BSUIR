.MODEL SMALL
.STACK 100h

.DATA
    ; Константы
    BUF_SIZE    EQU 1024        ; Размер буфера
    NEWLINE     EQU 13          ; Код возврата каретки
    DOLLAR      EQU '$'         ; Конец строки
    TEN         DW 10           ; Для преобразования строки в число

    ; Переменные PSP
    CMD_LENGTH  DB ?            ; Длина командной строки
    CMD_LINE    DB 128 DUP(0)   ; Буфер для командной строки

    ; Переменные программы
    FILE_PATH   DB 128 DUP(0), DOLLAR  ; Путь к файлу
    MAX_LEN_STR DB 16 DUP(0)    ; Максимальная длина (строка)
    MAX_LEN     DW 0            ; Максимальная длина (число)
    BUFFER      DB BUF_SIZE DUP(0)  ; Буфер для чтения файла
    FILE_HANDLE DW 0            ; Дескриптор файла
    LINE_COUNT  DW 0            ; Счётчик строк
    CURR_LEN    DW 0            ; Текущая длина строки
    ARGC        DW 0            ; Количество аргументов

    ; Сообщения
    MSG_WELCOME DB 'Count lines shorter than specified length in a file', NEWLINE, 10, DOLLAR
    MSG_USAGE   DB 'Usage: lab5.exe <file_path> <max_length>', NEWLINE, 10, DOLLAR
    MSG_OPENING DB 'Opening file: $'
    MSG_RESULT  DB NEWLINE, 10, 'Lines shorter than $'
    MSG_RESULT2 DB ' chars: $'
    MSG_END     DB NEWLINE, 10, 'Program completed.', NEWLINE, 10, DOLLAR
    MSG_ERR_ARGC DB NEWLINE, 10, 'Error: Invalid number of arguments!', NEWLINE, 10, DOLLAR
    MSG_ERR_FILE DB NEWLINE, 10, 'Error opening file (code: $'
    MSG_ERR_READ DB NEWLINE, 10, 'Error reading file (code: $'
    MSG_ERR_CLOSE DB NEWLINE, 10, 'Error closing file (code: $'
    MSG_ERR_LEN  DB NEWLINE, 10, 'Error: Invalid max length!', NEWLINE, 10, DOLLAR

.CODE
ARGC_ERROR:
    MOV DX, OFFSET MSG_ERR_ARGC
    MOV AH, 09h
    INT 21h
    MOV AX, 4C01h
    INT 21h

LEN_ERROR:
    MOV DX, OFFSET MSG_ERR_LEN
    MOV AH, 09h
    INT 21h
    MOV AX, 4C01h
    INT 21h

START:
    ; Сохраняем сегмент PSP
    PUSH DS              ; DS указывает на PSP
    MOV AX, @DATA
    MOV ES, AX           ; ES = сегмент данных

    ; Копируем командную строку из PSP
    MOV AL, DS:[80h]     ; Длина из PSP
    MOV ES:[CMD_LENGTH], AL
    MOV SI, 81h          ; Начало строки в PSP
    MOV DI, OFFSET CMD_LINE
    MOV CL, ES:[CMD_LENGTH]
    XOR CH, CH
    JCXZ NO_ARGS
    CLD
    REP MOVSB            ; Копируем строку в CMD_LINE

NO_ARGS:
    ; Устанавливаем DS на сегмент данных
    POP AX               ; Восстанавливаем DS (не нужно, просто очищаем стек)
    MOV AX, @DATA
    MOV DS, AX           ; DS = .DATA

    ; Вывод приветственного сообщения
    MOV DX, OFFSET MSG_WELCOME
    MOV AH, 09h
    INT 21h

    ; Парсинг командной строки
    CALL PARSE_CMDLINE
    CMP [ARGC], 2
    JNE ARGC_ERROR

    ; Преобразование максимальной длины в число
    CALL STR_TO_NUM
    CMP AX, 0
    JE LEN_ERROR
    MOV [MAX_LEN], AX

    ; Вывод имени файла
    MOV DX, OFFSET MSG_OPENING
    MOV AH, 09h
    INT 21h
    MOV DX, OFFSET FILE_PATH
    INT 21h

    ; Открытие файла
    MOV AH, 3Dh         ; Функция открытия файла
    MOV AL, 0           ; Режим: только чтение
    MOV DX, OFFSET FILE_PATH
    INT 21h
    JC OPEN_ERROR
    MOV [FILE_HANDLE], AX

    ; Чтение и подсчёт строк
READ_LOOP:
    MOV AH, 3Fh         ; Чтение из файла
    MOV BX, [FILE_HANDLE]
    MOV CX, BUF_SIZE
    MOV DX, OFFSET BUFFER
    INT 21h
    JC READ_ERROR
    CMP AX, 0           ; Если ничего не прочитано, конец файла
    JE CHECK_LAST_LINE

    ; Обработка буфера
    PUSH AX
    CALL PROCESS_BUFFER
    POP AX
    JMP READ_LOOP
	
CHECK_LAST_LINE:
    ; Если достигнут конец файла и есть незавершённая строка
    CMP [CURR_LEN], 0
    JE CLOSE_FILE        ; Если CURR_LEN = 0, строки нет
    MOV AX, [CURR_LEN]
    CMP AX, MAX_LEN
    JAE CLOSE_FILE       ; Если >= 10, не считаем
    INC [LINE_COUNT]     ; Учитываем строку > 10

CLOSE_FILE:
    MOV AH, 3Eh         ; Закрытие файла
    MOV BX, [FILE_HANDLE]
    INT 21h
    JC CLOSE_ERROR

    ; Вывод результата
    MOV DX, OFFSET MSG_RESULT
    MOV AH, 09h
    INT 21h
    MOV AX, [MAX_LEN]
    CALL PRINT_NUM
    MOV DX, OFFSET MSG_RESULT2
    MOV AH, 09h
    INT 21h
    MOV AX, [LINE_COUNT]
    CALL PRINT_NUM

    ; Завершение
    MOV DX, OFFSET MSG_END
    MOV AH, 09h
    INT 21h
    MOV AX, 4C00h
    INT 21h

OPEN_ERROR:
    MOV DX, OFFSET MSG_ERR_FILE
    MOV AH, 09h
    INT 21h
    CALL PRINT_NUM
    JMP EXIT

READ_ERROR:
    MOV DX, OFFSET MSG_ERR_READ
    MOV AH, 09h
    INT 21h
    CALL PRINT_NUM
    JMP CLOSE_FILE

CLOSE_ERROR:
    MOV DX, OFFSET MSG_ERR_CLOSE
    MOV AH, 09h
    INT 21h
    CALL PRINT_NUM

EXIT:
    MOV AX, 4C01h
    INT 21h
	

	
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
    JNE SECOND_PARAM
    MOV DI, OFFSET MAX_LEN_STR
    JMP CHECK_NEXT

SECOND_PARAM:
    CMP BX, 2
    JA CMD_DONE

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
    MOV SI, OFFSET MAX_LEN_STR
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

; ======== Обработка буфера ========
PROCESS_BUFFER PROC
    PUSH SI
    PUSH CX
    MOV SI, OFFSET BUFFER
    MOV CX, AX           ; Число прочитанных байт

CHECK_CHAR:
    CMP BYTE PTR [SI], NEWLINE  ; CR (13)
    JE LINE_END_CR
    CMP BYTE PTR [SI], 0Ah      ; LF (10)
    JE LINE_END_LF
    INC [CURR_LEN]              ; Увеличиваем длину строки
    JMP NEXT_CHAR

LINE_END_CR:
    ; Проверяем, идёт ли за CR символ LF
    CMP CX, 1                   ; Если это последний символ в буфере
    JE LINE_END                 ; Обрабатываем как конец строки
    CMP BYTE PTR [SI+1], 0Ah    ; Если следующий символ LF
    JNE LINE_END                ; Если нет, считаем как конец строки
    INC SI                      ; Пропускаем CR
    DEC CX                      ; Уменьшаем счётчик
    JMP LINE_END_LF             ; Переходим к обработке LF

LINE_END_LF:
    ; Если это LF после CR, уже обработано
   CMP [CURR_LEN], 0           ; Если длина = 0 (пустая строка после CR)
   JE RESET_LEN                ; Пропускаем

LINE_END:
    MOV AX, [CURR_LEN]
    CMP AX, [MAX_LEN]                  ; Сравниваем с MAX_LEN
    JAE RESET_LEN               ; Если >= MAX_LEN, не считаем
    INC [LINE_COUNT]            ; Считаем, если < MAX_LEN 
RESET_LEN:
    MOV [CURR_LEN], 0           ; Сбрасываем длину

NEXT_CHAR:
    INC SI
    LOOP CHECK_CHAR

    ; Обработка обрыва строки концом буфера
    CMP CX, 0
    JNE END_PROC
    CMP [CURR_LEN], 0
    JE END_PROC
    ; Сохраняем незавершённую длину для следующего буфера
    ; Не добавляем к LINE_COUNT, пока строка не завершена

END_PROC:
    POP CX
    POP SI
    RET
PROCESS_BUFFER ENDP

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