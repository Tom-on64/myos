org 0x7c00
bits 16

%define ENDL 0x0a, 0x0d

start:
    jmp main

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
    int 0x10
    jmp .loop
.done:
    pop si
    pop ds
    ret

main: 
    mov ax, 0
    mov ds, ax
    mov es, ax

    mov ss, ax
    mov sp, 0x7c00

    mov si, msg
    call puts
    mov si, msg2
    call puts

    hlt

.halt:
    jmp .halt

msg: db "Hello, World!", ENDL, 0
msg2: db "Test", ENDL, 0

times 510-($-$$) db 0
dw 0AA55h