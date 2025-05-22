.model small
.stack 100h

.data
    helloMessage DB 'Hello, World!', 13, 10, '$'

.code
main proc
    mov ax, @data
    MOV ds, ax

    MOV dx, offset helloMessage
    MOV ah, 9
    INT 21h
    
    MOV ax, 4C00h
    INT 21h
main endp

end main
