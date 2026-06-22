[bits 16]
[org 0x7c00]

start:
    jmp 0:init

init:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    mov [boot_drive], dl

    mov ah, 0x41
    mov bx, 0x55aa
    int 0x13

    mov si, dap
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    jmp 0:0x7e00

disk_error:
    mov ah, 0x0e
    mov al, 'E'
    int 0x10
    jmp $

boot_drive db 0

dap:
    db 0x10
    db 0
    dw 120
    dw 0x7e00
    dw 0
    dq 1

times 446-($-$$) db 0
db 0x80, 0, 1, 0, 0x0B, 0, 0x3F, 0
dd 1, 0xFFFF
times 16*3 db 0
dw 0xaa55