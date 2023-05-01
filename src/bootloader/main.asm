org 0x7c00
bits 16

%define ENDL 0x0a, 0x0d

;
; Headers
;

; FAT12
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880 
bdb_media_descriptor_type:  db 0F0h
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0
                            db 0
ebr_signature:              db 29h
ebr_volume_id:              db 69h, 42h, 00h, 64h
ebr_volume_label:           db 'MYOS       '
ebr_system_id:              db 'FAT12   '

;
; Code
;

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
        int 10h
        jmp .loop
    .done:
        pop si
        pop ds
        ret

;
; Main - This label is the program entry point
;
main: 
    ; Setup data segments
    mov ax, 0                   ; Can't modify some regs directly
    mov ds, ax
    mov es, ax

    ; Setup the stack
    mov ss, ax
    mov sp, 0x7c00

    ; Read from the disk
    mov [ebr_drive_number], dl
    mov ax, 1                   ; LBA=1
    mov cl, 1                   ; 1 sector to read
    mov bx, 0x07e00             ; Data should be after the bootloader
    call diskRead

    ; Print the msg
    mov si, msg
    call puts

    cli
    hlt

;
; Prints an error about reading from the disk
;
diskError:
    mov si, diskErrorMsg
    call puts

    jmp waitForKeyReboot

;
; Reboot system after a keypress
;
waitForKeyReboot:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0
    .halt: 
        cli
        hlt

;
; Converts LBA adress to a CHS address
; Args:
;   - ax : LBA Address
; Returns:
;   - cx : [0-5]: Sector
;   - cx : [6-15]: Cylinder
;   - dh : Head
;
lbaToChs:
    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack
    inc dx                              ; dx = LBA % SectorsPerTrack + 1
    mov cx, dx                          ; cx = sector
    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads
                                        ; dx = (LBA / SectorsPerTrack) % Heads
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8bits)
    shl ah, 6                           ; left shift (<<)
    or cl, ah                           ; cl = cylinder (higher 2bits)

    pop ax
    mov dl, al
    pop ax
    ret

;
; Reads sectors from disk
; Args:
;   - ax : LBA address
;   - cl : number of sectors to read (max 128)
;   - dl : drive number
;   - es bx : memory address to store read data
;
diskRead:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx                             ; Save CX because lbaToChs overrides CL
    call lbaToChs                       ; Convert LBA to CHS
    pop ax                              ; AL = number of sectors to read

    mov ah, 02h
    mov di, 3                           ; times to repeat
    .loop:
        pusha                           ; Save all registers (just in case)
        stc                             ; Set carry flag

        int 13h                         ; Carry flag cleared = success
        jnc .done
        ; Failed

        popa
        call diskReset

        dec di
        test di, di
        jnz .loop
    .fail:
        jmp diskError                   ; All attempts failed :(

    .done:
        popa

        pop di
        pop dx
        pop cx
        pop bx
        pop ax

        ret

;
; Resets disk controller
; Args:
;   - dl : drive number
;
diskReset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc diskError

; Variables
msg:            db "Hello, World!", ENDL, 0
diskErrorMsg:   db "ERROR: Failed to read from disk!", ENDL, 0

times 510-($-$$) db 0
dw 0AA55h