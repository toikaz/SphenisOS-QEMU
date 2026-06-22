[BITS 16]
[ORG 0x5000]

start:
    pusha
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [boot_drive], dl

    mov ax, 0003h
    int 10h

    mov si, piano_msg
    call print_string

    mov di, song_buffer

main_loop:
    mov ah, 00h
    int 16h

    cmp al, 27
    je exit_piano
    cmp al, 's'
    je save_to_disk
    cmp al, 'p'
    je load_and_play

    cmp al, '1'
    je .n1
    cmp al, '2'
    je .n2
    cmp al, '3'
    je .n3
    cmp al, '4'
    je .n4
    cmp al, '5'
    je .n5
    cmp al, '6'
    je .n6
    cmp al, '7'
    je .n7
    cmp al, '8'
    je .n8
    cmp al, '9'
    je .n9
    cmp al, '0'
    je .n0
    jmp main_loop

.n1: mov ax, 4560
    jmp .play
.n2: mov ax, 4063
    jmp .play
.n3: mov ax, 3619
    jmp .play
.n4: mov ax, 3416
    jmp .play
.n5: mov ax, 3043
    jmp .play
.n6: mov ax, 2711
    jmp .play
.n7: mov ax, 2415
    jmp .play
.n8: mov ax, 2280
    jmp .play
.n9: mov ax, 2031
    jmp .play
.n0: mov ax, 1809
    jmp .play

.play:
    stosw
    call play_sound
    jmp main_loop

save_to_disk:
    mov ax, 0
    stosw

    mov ah, 03h
    mov al, 1
    mov ch, 0
    mov dh, 0
    mov cl, 145
    mov dl, [boot_drive]
    mov bx, song_buffer
    int 13h

    mov si, msg_save
    call print_string
    jmp main_loop

load_and_play:
    mov si, msg_load
    call print_string

    mov ah, 02h
    mov al, 1
    mov ch, 0
    mov dh, 0
    mov cl, 145
    mov dl, [boot_drive]
    mov bx, song_buffer
    int 13h
    jc .error_disk

    mov si, song_buffer
.next:
    lodsw
    test ax, ax
    jz .done
    call play_sound
    jmp .next

.done:
    mov si, msg_done
    call print_string
    jmp main_loop

.error_disk:
    mov si, msg_err
    call print_string
    jmp main_loop

play_sound:
    push ax
    mov al, 0B6h
    out 43h, al
    pop ax
    out 42h, al
    mov al, ah
    out 42h, al

    in al, 61h
    or al, 03h
    out 61h, al

    mov cx, 0002h
    mov dx, 4B40h
    mov ah, 86h
    int 15h

    in al, 61h
    and al, 0FCh
    out 61h, al
    ret

print_string:
    mov ah, 0Eh
.l: lodsb
    test al, al
    jz .d
    int 10h
    jmp .l
.d: ret

exit_piano:
    popa
    retf

boot_drive db 0
piano_msg  db 'PIANO: 1-0 keys | S=Save | P=Play', 13, 10, 0
msg_save   db 13, 10, 'Music saved to sector 145!', 13, 10, 0
msg_load   db 13, 10, 'Loading from disk...', 13, 10, 0
msg_done   db 'Done playing.', 13, 10, 0
msg_err    db 'Disk read error!', 13, 10, 0

song_buffer: times 512 db 0