.286
.model small
.stack 100h

.data
    array       DW 30 DUP(?)        
    buffer      DB 7, ?, 7 DUP(?)   
    count       DW 0                
    max_val     DW ?                
    min_val     DW ?                
    result      DB 12 DUP(?)        

    msg1        DB 'Enter array size (1-30): $'
    msg2        DB 0Dh,0Ah,'Enter number: $'
    msg3        DB 0Dh,0Ah,'Result: $'
    err1        DB 0Dh,0Ah,'Overflow error!$'
    err2        DB 0Dh,0Ah,'Invalid input!$'
    err_div0    DB 0Dh,0Ah,'Division by zero!$'

.code
main PROC
    mov ax, @data
    mov ds, ax

    mov dx, OFFSET msg1
    call PrintStr
    call InputNum
    cmp ax, 1            
    jl exit_invalid
    cmp ax, 30
    ja exit_invalid
    mov count, ax

    mov cx, count       
    mov si, 0           

    mov dx, OFFSET msg2
    call PrintStr
    call InputNum       
    mov array[si], ax
    mov max_val, ax       
    mov min_val, ax       
    add si, 2
    dec cx                
    jz calculation_part   

input_loop:
    mov dx, OFFSET msg2
    call PrintStr
    call InputNum           
    mov array[si], ax

    cmp ax, max_val
    jle check_min_inline 
    mov max_val, ax      

check_min_inline:
    cmp ax, min_val
    jge next_elem_inline 
    mov min_val, ax      

next_elem_inline:
    add si, 2
    loop input_loop

calculation_part:
    mov ax, max_val
    cmp ax, 0
    je div_zero_err

    call IntToStrWithFraction 

    mov dx, OFFSET msg3
    call PrintStr
    mov dx, OFFSET result
    call PrintStr
    jmp exit

div_zero_err:
    mov dx, OFFSET err_div0
    call PrintStr
    jmp exit

exit_invalid:
    mov dx, OFFSET err2
    call PrintStr
    jmp exit

exit:
    mov ax, 4C00h
    int 21h
main ENDP

InputNum PROC
    push bx
    push cx
    push dx
    push si

    mov dx, OFFSET buffer
    mov ah, 0Ah
    int 21h
    mov dl, 0Dh 
    mov ah, 02h
    int 21h
    mov dl, 0Ah
    mov ah, 02h
    int 21h

    mov si, OFFSET buffer + 1 
    mov cl, [si]          
    xor ch, ch            
    jcxz invalid_input    

    mov si, OFFSET buffer + 2 
    xor ax, ax            
    mov bx, 1             

    cmp BYTE PTR [si], '-'
    jne parse_loop
    mov bx, -1
    inc si
    dec cx                
    jcxz invalid_input    

parse_loop:
    cmp cx, 0
    je convert_done       

    mov dl, [si]          
    cmp dl, '0'
    jl invalid_input
    cmp dl, '9'
    jg invalid_input

    sub dl, '0'           
    mov dh, 0             

    push dx               
    mov dx, 10            
    imul dx               
    jo overflow_err       
    pop dx                
    add ax, dx            
    jc overflow_err       

    inc si
    dec cx
    jmp parse_loop

convert_done:
    imul bx               
    jo overflow_err       
    jmp input_end

overflow_err:
    mov dx, OFFSET err1
    call PrintStr
    jmp exit 

invalid_input:
    mov dx, OFFSET err2
    call PrintStr
    jmp exit 

input_end:
    pop si
    pop dx
    pop cx
    pop bx
    ret
InputNum ENDP

PrintStr PROC
    mov ah, 09h
    int 21h
    ret
PrintStr ENDP

IntToStrWithFraction PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, OFFSET result 

    mov ax, max_val
    sub ax, min_val       

    mov bx, 1000
    imul bx               
                          
    mov bx, max_val
    idiv bx               
    
    mov bx, 1000
    xor dx, dx            
    div bx                

    push dx               

    mov bx, 10
    xor cx, cx            
convert_int_loop:
    xor dx, dx            
    div bx                
    push dx               
    inc cx
    test ax, ax           
    jnz convert_int_loop

    cmp cx, 0
    jne store_int_loop
    push ax ; push 0
    inc cx

store_int_loop:
    pop dx                
    add dl, '0'           
    mov [si], dl          
    inc si
    loop store_int_loop

    mov BYTE PTR [si], '.'
    inc si

    pop ax                
    mov di, si            
    add di, 2             
                          
    mov cx, 3             
    mov bx, 10
frac_loop:
    xor dx, dx
    div bx                
    add dl, '0'           
    mov [di], dl          
    dec di
    loop frac_loop

    add si, 3
    mov BYTE PTR [si], '$'

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
IntToStrWithFraction ENDP

END main
