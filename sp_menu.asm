[BITS 16]
[ORG 0x5000]

start:
    pusha
    mov [boot_drive], dl
    mov ax, cs
    mov ds, ax
    mov es, ax

show_menu:
    mov ax, 0x0003
    int 0x10

    mov si, msg_menu_hdr
    call print_string
    call print_newline

    mov si, msg_opt1
    call print_string
    call print_newline

    mov si, msg_opt2
    call print_string
    call print_newline

    mov si, msg_opt3
    call print_string
    call print_newline

    mov si, msg_select
    call print_string

.wait_key:
    mov ah, 0x00
    int 0x16
    cmp al, '1'
    je start_pong
    cmp al, '2'
    je start_paint
    cmp al, '3'
    je exit_to_shell
    jmp .wait_key

start_pong:
    mov ax, 0x0003
    int 0x10
    mov word [ball_pos], 0x0C28
    mov byte [ball_dx], 1
    mov byte [ball_dy], 1
    mov byte [p1_y], 10
    mov byte [p2_y], 10

.game_loop:
    mov ah, 0x00
    int 0x1A
    mov bx, dx
    add bx, 1
.wait:
    int 0x1A
    cmp dx, bx
    jne .wait

    mov dx, [ball_pos]
    call clear_pixel
    call clear_p1
    call clear_p2

    mov ah, 0x01
    int 0x16
    jz .ai
    mov ah, 0x00
    int 0x16
    cmp al, 'w'
    je .p1_u
    cmp al, 's'
    je .p1_d
    cmp al, 27
    je show_menu

.p1_u:
    sub byte [p1_y], 1
    jmp .ai
.p1_d:
    add byte [p1_y], 1

.ai:
    mov dh, [ball_pos + 1]
    mov al, [p2_y]
    add al, 2
    cmp al, dh
    jl .ai_d
    jg .ai_u
    jmp .m_ball
.ai_u:
    dec byte [p2_y]
    jmp .m_ball
.ai_d:
    inc byte [p2_y]

.m_ball:
    mov dx, [ball_pos]
    add dl, [ball_dx]
    add dh, [ball_dy]
    cmp dh, 0
    je .b_y
    cmp dh, 24
    je .b_y
    jmp .ch_p
.b_y:
    neg byte [ball_dy]
.ch_p:
    cmp dl, 1
    jne .ch_ai
    mov al, dh
    sub al, [p1_y]
    cmp al, 0
    jl .g_over
    cmp al, 5
    jge .g_over
    neg byte [ball_dx]
    jmp .app
.ch_ai:
    cmp dl, 78
    jne .app
    mov al, dh
    sub al, [p2_y]
    cmp al, 0
    jl .g_over
    cmp al, 5
    jge .g_over
    neg byte [ball_dx]
.app:
    mov [ball_pos], dx
    call draw_p1
    call draw_p2
    mov dx, [ball_pos]
    mov al, 'O'
    mov bl, 0x0F
    call draw_pixel
    jmp .game_loop

.g_over:
    jmp show_menu

start_paint:
    mov ax, 0x0003
    int 0x10
    mov byte [cur_x], 40
    mov byte [cur_y], 12
    mov byte [cur_color], 0x0F

.p_main:
    mov ah, 0x02
    xor bh, bh
    xor dx, dx
    int 0x10
    mov ah, 0x09
    mov al, '0'
    mov bl, [cur_color]
    mov cx, 1
    int 0x10

    mov ah, 0x02
    mov dh, [cur_y]
    mov dl, [cur_x]
    int 0x10

    mov ah, 0x00
    int 0x16

    cmp al, 27
    je show_menu
    cmp al, ' '
    je .draw
    cmp al, 'c'
    je .clear_screen
    cmp al, 's'
    je .save_disk
    cmp al, 'l'
    je .load_disk

    cmp al, '1'
    je .c1
    cmp al, '2'
    je .c2
    cmp al, '3'
    je .c3
    cmp al, '4'
    je .c4
    cmp al, '5'
    je .c5

    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    jmp .p_main

.c1:
    mov byte [cur_color], 0x09
    jmp .p_main
.c2:
    mov byte [cur_color], 0x0A
    jmp .p_main
.c3:
    mov byte [cur_color], 0x0C
    jmp .p_main
.c4:
    mov byte [cur_color], 0x0E
    jmp .p_main
.c5:
    mov byte [cur_color], 0x0F
    jmp .p_main

.clear_screen:
    mov ax, 0x0003
    int 0x10
    jmp .p_main

.up:
    dec byte [cur_y]
    jmp .p_main
.down:
    inc byte [cur_y]
    jmp .p_main
.left:
    dec byte [cur_x]
    jmp .p_main
.right:
    inc byte [cur_x]
    jmp .p_main

.draw:
    mov ah, 0x09
    mov al, '0'
    mov bl, [cur_color]
    mov cx, 1
    int 0x10
    jmp .p_main

.save_disk:
    push es
    mov ax, 0xB800
    mov ds, ax
    xor si, si
    mov ax, cs
    mov es, ax
    mov di, screen_buffer
    mov cx, 2000
    rep movsw
    mov ax, cs
    mov ds, ax
    mov ah, 0x03
    mov al, 8
    mov cl, 136
    mov ch, 0
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, screen_buffer
    int 0x13
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    pop es
    jmp .p_main

.load_disk:
    mov ah, 0x02
    mov al, 8
    mov cl, 136
    mov ch, 0
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, screen_buffer
    int 0x13
    push es
    mov ax, cs
    mov ds, ax
    mov si, screen_buffer
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov cx, 2000
    rep movsw
    pop es
    mov ax, cs
    mov ds, ax
    jmp .p_main

exit_to_shell:
    mov ax, 0x0003
    int 0x10
    popa
    retf

draw_p1:
    mov cx, 5
    mov dh, [p1_y]
    mov dl, 0
.l1:
    push cx
    mov al, '#'
    mov bl, 0x0A
    call draw_pixel
    inc dh
    pop cx
    loop .l1
    ret

draw_p2:
    mov cx, 5
    mov dh, [p2_y]
    mov dl, 79
.l2:
    push cx
    mov al, '#'
    mov bl, 0x0C
    call draw_pixel
    inc dh
    pop cx
    loop .l2
    ret

clear_p1:
    mov cx, 5
    mov dh, [p1_y]
    mov dl, 0
.c1:
    push cx
    call clear_pixel
    inc dh
    pop cx
    loop .c1
    ret

clear_p2:
    mov cx, 5
    mov dh, [p2_y]
    mov dl, 79
.c2:
    push cx
    call clear_pixel
    inc dh
    pop cx
    loop .c2
    ret

draw_pixel:
    mov ah, 0x02
    xor bh, bh
    int 0x10
    mov ah, 0x09
    mov cx, 1
    int 0x10
    ret

clear_pixel:
    mov ah, 0x02
    xor bh, bh
    int 0x10
    mov ah, 0x09
    mov al, ' '
    mov bl, 0x00
    mov cx, 1
    int 0x10
    ret

print_string:
    mov ah, 0x0E
.lp:
    lodsb
    test al, al
    jz .dn
    int 0x10
    jmp .lp
.dn:
    ret

print_newline:
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    ret

boot_drive db 0
ball_pos  dw 0
ball_dx   db 0
ball_dy   db 0
p1_y      db 0
p2_y      db 0
cur_x     db 0
cur_y     db 0
cur_color db 0

msg_menu_hdr db '--- SPHENIS EXPLORER ---', 0
msg_opt1     db '1. Ping Pong', 0
msg_opt2     db '2. Paint (0-Brush)', 0
msg_opt3     db '3. Exit to Shell', 0
msg_select   db 'Select: ', 0

align 16
screen_buffer: times 4096 db 0