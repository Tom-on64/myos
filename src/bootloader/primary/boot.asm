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
    ; Setup data segments
    mov ax, 0                   ; Can't modify some regs directly
    mov ds, ax
    mov es, ax

    ; Setup the stack
    mov ss, ax
    mov sp, 0x7c00

    push es 
    push word .after
    retf
    .after: 
        ; Read from the disk
        mov [ebr_drive_number], dl

        ; Print loading message
        mov si, msg
        call puts

        push es
        mov ah, 08h
        int 13h
        jc diskError
        pop es

        and cl, 0x3F
        xor ch, ch
        mov [bdb_sectors_per_track], cx

        inc dh
        mov [bdb_heads], dh

        ; Read FAT dir
        mov ax, [bdb_sectors_per_fat]
        mov bl, [bdb_fat_count]
        xor bh, bh
        mul bx                              ; ax = (fats * SectorsPerFat)
        add ax, [bdb_reserved_sectors]      ; ax = LBA of root
        push ax

        mov ax, [bdb_sectors_per_track]
        shl ax, 5                           ; ax *= 32
        xor dx, dx                          ; dx = 0
        div word [bdb_bytes_per_sector]     ; amount of sectors to read

        test dx, dx                         ; if (dx != 0) ax++
        jz .rootDirAfter
        inc ax
    .rootDirAfter:
        mov cl, al                          ; cl = amount of we need to read
        pop ax                              ; ax = LBA of root
        mov dl, [ebr_drive_number]          ; dl = driveNumber
        mov bx, buffer                      ; es:bx = buffer
        call diskRead

        ; find kernel.bin
        xor bx, bx                          ; bx = 0
        mov di, buffer
    .searchKernel:
        mov si, fileKernelBin
        mov cx, 11
        push di
        repe cmpsb
        pop di
        je .foundKernel

        add di, 32
        inc bx
        cmp bx, [bdb_dir_entries_count]
        jl .searchKernel
        jmp kernelNotFound
    .foundKernel:
        mov ax, [di + 26]
        mov [kernelCluster], ax

        mov ax, [bdb_reserved_sectors]
        mov bx, buffer
        mov cl, [bdb_sectors_per_fat]
        call diskRead

        ; Read kernel and proccess FAT
        mov bx, KERNEL_LOAD_SEGMENT
        mov es, bx
        mov bx, KERNEL_LOAD_OFFSET
    .loadKernelLoop:
        ; Read nex kernel cluster
        mov ax, [kernelCluster]
        add ax, 31                      ; HARDCODED OFFSET - TODO: rewrite
        mov cl, 1
        mov dl, [ebr_drive_number]
        call diskRead

        add bx, [bdb_bytes_per_sector]  ; WARNING: Will overflow if kernel.bin > 64kB

        mov ax, [kernelCluster]
        mov cx, 3
        mul cx
        mov cx, 2
        div cx

        mov si, buffer
        add si, ax
        mov ax, [ds:si]

        or dx, dx
        jz .even
    .odd:
        shr ax, 4
        jmp .nextClusterAfter
    .even:
        and ax, 0x0FFF
    .nextClusterAfter:
        cmp ax, 0x0FF8
        jae .readFinish

        mov [kernelCluster], ax
        jmp .loadKernelLoop
    .readFinish:
        ; jump to our kernel
        mov dl, [ebr_drive_number]                  ; boot device in dl
        mov ax, KERNEL_LOAD_SEGMENT                 ; set segment reg
        mov ds, ax
        mov es, ax

        jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET  ; Far Jump

        ; Shouldn't run
        jmp waitForKeyReboot

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
; Prints an error about reading from the disk
;
diskError:
    mov si, diskErrorMsg
    call puts

    jmp waitForKeyReboot

;
; Prints an error about reading from the disk
;
kernelNotFound:
    mov si, kernelNotFoundMsg
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
msg:                db "Loading...", ENDL, 0
diskErrorMsg:       db "ERROR: Failed to read from disk!", ENDL, 0
kernelNotFoundMsg:  db "ERROR: second.bin not found!", ENDL, 0
fileKernelBin:      db "SECOND  BIN"
kernelCluster:      dw 0

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET  equ 0

times 510-($-$$) db 0
dw 0AA55h               ; Magic Number :)

buffer: