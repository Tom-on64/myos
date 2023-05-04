org 0x0
bits 16

%define ENDL 0x0a, 0x0d

start:
    mov si, msg
    call puts

.halt:
    cli
    hlt

;
; Prints a message to the screen
; Args:
;   - ds si : String pointer
;
puts: 
    push ds
    push si
    .loop:
        lodsb
        or al, al
        jz .done
        mov ah, 0x0e
        int 10h
        jmp .loop
    .done:
        pop si
        pop ds
        ret

msg: db "Hello, World!", ENDL, 0

times 510-($-$$) db 0
dw 0AA55h