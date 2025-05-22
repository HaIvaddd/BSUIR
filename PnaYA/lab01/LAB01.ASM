.MODEL SMALL
.STACK 100h

BUF_SIZE    EQU 200         
MAX_WORDS   EQU 70          

.DATA
    buffer db BUF_SIZE dup(?)  
    words dw MAX_WORDS dup(?)     
    lengths db MAX_WORDS dup(?)   
    newline db 0Dh, 0Ah, '$'
    prompt_input db "Enter a string: $"
    prompt_output db "Sorted words: $"
    error_no_words db "No words to sort in the string.$"

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    LEA DX, prompt_input
    MOV AH, 09h
    INT 21h

    LEA DI, buffer       ; DI points to the beginning of the buffer
    LEA BX, words        ; BX points to the array of word addresses
    LEA SI, lengths      ; SI points to the array of word lengths
    MOV CX, 0            ; Word counter
    MOV DL, 0            ; Current word length
    MOV BP, 0            ; "Inside word" flag (0 = no, 1 = yes)

INPUT_LOOP:
    MOV AH, 01h          
    INT 21h
    CMP AL, 0Dh          
    JE END_INPUT

    CMP DI, OFFSET buffer + BUF_SIZE - 2 ; Check for buffer overflow 
    JA END_INPUT

    CMP AL, ' '         
    JE END_WORD

    MOV [DI], AL        
    INC DI

    CMP BP, 1            
    JE CONTINUE          

    ; new word
    MOV BP, 1            
    MOV AX, DI          
    CMP AX, OFFSET buffer
    JE SKIP_DEC
    DEC AX               ; Move back one position to point to the first letter of the word
SKIP_DEC:
    MOV [BX], AX         ; Store the word address
    ADD BX, 2            ; Move to the next position for word address 
    MOV DL, 1            ; Initialize word length
    JMP INPUT_LOOP

CONTINUE:
    INC DL               ; Increment word length
    JMP INPUT_LOOP

END_WORD:
    CMP BP, 1           
    JNE INPUT_LOOP
    MOV BP, 0            ; End current word
    MOV [SI], DL         ; Store the word length
    INC SI               ; Move to the next position for word length 
    INC CX               ; Increment word counter
    MOV DL, 0            ; Reset word length for the next word

    ; Add '$' terminator to the end of the word
    MOV AL, '$'
    MOV [DI], AL
    INC DI

    JMP INPUT_LOOP

END_INPUT:
    CMP BP, 1            ; If input ended in the middle of a word
    JNE SORT_WORDS
    MOV [SI], DL         ; Store the length of the last word
    INC CX               ; Increment word counter

    MOV AL, '$'
    MOV [DI], AL
    INC DI

SORT_WORDS:
    ;Bubble Sort
    MOV BX, CX
    CMP BX, 1
    JBE DONE_SORT      ; If 0 or 1 word, no sorting needed

    DEC BX              ; Outer loop

SORT_OUTER:
    MOV SI, 0            ; Starting index for elements

SORT_INNER:
    MOV DI, SI
    INC DI
    CMP DI, CX           ; If end of array reached, next iteration of outer loop
    JGE NEXT_PASS

    MOV AL, [SI + offset lengths]  
    CMP AL, [DI + offset lengths]
    JBE NO_SWAP           

    ;Swap word addresses
    PUSH SI
    PUSH DI
    
    ADD SI, SI
    ADD DI, DI
    
    MOV AX, [SI + offset words]   
    XCHG AX, [DI + offset words]  
    MOV [SI + offset words], AX
    
    POP DI
    POP SI
    
    ;Swap word lengths
    MOV AL, [SI + lengths]    
    XCHG AL, [DI + lengths]   
    MOV lengths[SI], AL   

NO_SWAP:
    INC SI
    JMP SORT_INNER       

NEXT_PASS:
    DEC BX
    JNZ SORT_OUTER       

DONE_SORT:

    MOV DX, OFFSET newline
    MOV AH, 09h
    INT 21h
    
    ;Display output
    MOV DX, OFFSET prompt_output
    MOV AH, 09h
    INT 21h

    MOV DX, OFFSET newline
    MOV AH, 09h
    INT 21h

    LEA DI, words        ; DI to word addresses
    MOV SI, 0            ; Word counter for output

PRINT_LOOP:
    CMP SI, CX           ; If all words printed, exit
    JGE DONE
    
    MOV DX, [DI]
    MOV AH, 09h
    INT 21h

    MOV DL, ' '          
    MOV AH, 02h
    INT 21h
    
    ADD DI, 2
    INC SI               
    JMP PRINT_LOOP

DONE:
    MOV AX, 4C00h        
    INT 21h

NO_WORDS_OUTPUT:
    ;Display no words error message
    MOV DX, OFFSET error_no_words
    MOV AH, 09h
    INT 21h
    JMP DONE

END START
