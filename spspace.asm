[BITS 16]
[ORG 0x5000]

SCREEN_WIDTH    equ 80
SCREEN_HEIGHT   equ 25
GAME_WIDTH      equ 30
GAME_HEIGHT     equ 18
GAME_LEFT       equ 25
GAME_TOP        equ 3
PLAYER_CHAR     equ 0xDB
ASTEROID_CHAR   equ 0xB1
MAX_ASTEROIDS   equ 10
ASTEROID_SPEED  equ 2
VIDEO_MEM       equ 0xB800

start:
    pusha
    push ds
    push es

    mov ax, cs
    mov ds, ax

    mov ax, 0x0003
    int 0x10

    mov ah, 0x01
    mov cx, 0x2607
    int 0x10

    mov ax, VIDEO_MEM
    mov es, ax

    xor ax, ax
    int 0x1A
    mov [random_seed], dx

    mov ax, GAME_LEFT
    add ax, GAME_WIDTH/2
    mov [player_x], ax

    mov ax, GAME_TOP
    add ax, GAME_HEIGHT-2
    mov [player_y], ax

    call init_asteroids
    call draw_static_elements
    call draw_player

game_loop:
    cmp byte [exit_flag], 1
    je final_exit

    cmp byte [game_over], 1
    je game_over_screen

    mov cx, 1
    call delay

    call check_keyboard

    inc byte [tick_counter]
    cmp byte [tick_counter], ASTEROID_SPEED
    jl .skip_asteroid_update

    mov byte [tick_counter], 0
    call update_asteroids
    call check_collisions

.skip_asteroid_update:
    call update_screen
    jmp game_loop

game_over_screen:
    mov ax, 0x0003
    int 0x10

    mov dh, 12
    mov dl, 22
    call set_cursor

    mov si, game_over_msg
    call print_string

    mov dh, 14
    mov dl, 34
    call set_cursor

    mov si, score_msg
    call print_string
    mov ax, [score]
    call print_number

    mov ah, 0x00
    int 0x16
    jmp final_exit

final_exit:
    mov ax, 0x0003
    int 0x10
    pop es
    pop ds
    popa
    ret


init_asteroids:
    mov di, asteroid_active
    mov cx, MAX_ASTEROIDS
    xor al, al
    rep stosb
    ret

check_keyboard:
    mov ah, 0x01
    int 0x16
    jz .done

    mov ah, 0x00
    int 0x16

    cmp ah, 0x4B
    je .move_left
    cmp ah, 0x4D
    je .move_right
    cmp al, 27
    je .escape
    ret
.escape:
    mov byte [exit_flag], 1
    ret
.move_left:
    mov ax, [player_x]
    cmp ax, GAME_LEFT+1
    jle .done
    call erase_player
    dec word [player_x]
    call draw_player
    ret
.move_right:
    mov ax, [player_x]
    cmp ax, GAME_LEFT+GAME_WIDTH-2
    jge .done
    call erase_player
    inc word [player_x]
    call draw_player
.done:
    ret

draw_player:
    mov ax, [player_y]
    mov bx, 160
    mul bx
    mov bx, [player_x]
    shl bx, 1
    add ax, bx
    mov di, ax
    mov ax, 0x0A00 | PLAYER_CHAR
    stosw
    ret

erase_player:
    mov ax, [player_y]
    mov bx, 160
    mul bx
    mov bx, [player_x]
    shl bx, 1
    add ax, bx
    mov di, ax
    mov ax, 0x0720
    stosw
    ret

update_asteroids:
    call random
    and ax, 0x0F
    cmp ax, 2
    jg .update_existing

    mov cx, MAX_ASTEROIDS
    mov di, 0
.find_slot:
    cmp byte [asteroid_active + di], 0
    je .spawn
    inc di
    loop .find_slot
    jmp .update_existing

.spawn:
    mov byte [asteroid_active + di], 1
    call random
    xor dx, dx
    mov cx, GAME_WIDTH-2
    div cx
    add dx, GAME_LEFT+1

    mov si, di
    shl si, 1
    mov [asteroid_x + si], dx
    mov word [asteroid_y + si], GAME_TOP+1

.update_existing:
    mov cx, MAX_ASTEROIDS
    xor di, di
.move_loop:
    cmp byte [asteroid_active + di], 0
    je .next

    mov si, di
    shl si, 1

    mov ax, [asteroid_y + si]
    mov bx, 160
    mul bx
    mov bx, [asteroid_x + si]
    shl bx, 1
    add ax, bx
    mov bx, ax
    mov word [es:bx], 0x0720

    inc word [asteroid_y + si]

    mov ax, [asteroid_y + si]
    cmp ax, GAME_TOP+GAME_HEIGHT
    jl .next

    mov byte [asteroid_active + di], 0
    inc word [score]

.next:
    inc di
    cmp di, MAX_ASTEROIDS
    jl .move_loop
    ret

check_collisions:
    mov cx, MAX_ASTEROIDS
    xor di, di
.loop:
    cmp byte [asteroid_active + di], 0
    je .skip
    mov si, di
    shl si, 1
    mov ax, [asteroid_x + si]
    mov dx, [asteroid_y + si]
    cmp ax, [player_x]
    jne .skip
    cmp dx, [player_y]
    jne .skip
    mov byte [game_over], 1
.skip:
    inc di
    cmp di, MAX_ASTEROIDS
    jl .loop
    ret

draw_static_elements:
    xor di, di
    mov cx, 2000
    mov ax, 0x0720
    rep stosw

    mov di, 1*160 + 34*2
    mov si, title_msg
    mov ah, 0x0E
    call draw_string_v

    mov di, 2*160 + 36*2
    mov si, score_msg
    mov ah, 0x0A
    call draw_string_v

    call draw_border
    ret

update_screen:
    mov ax, [score]
    mov di, 2*160 + 43*2
    call draw_num_v

    mov cx, MAX_ASTEROIDS
    xor si, si
.loop:
    cmp byte [asteroid_active + si], 0
    je .next
    mov bx, si
    shl bx, 1
    mov ax, [asteroid_y + bx]
    mov dx, 160
    mul dx
    mov dx, [asteroid_x + bx]
    shl dx, 1
    add ax, dx
    mov di, ax
    mov ax, 0x0C00 | ASTEROID_CHAR
    stosw
.next:
    inc si
    loop .loop
    ret

draw_border:
    mov di, GAME_TOP*160 + GAME_LEFT*2
    mov cx, GAME_WIDTH
    mov ax, 0x0B3D
.top: stosw
    loop .top

    mov di, (GAME_TOP+GAME_HEIGHT)*160 + GAME_LEFT*2
    mov cx, GAME_WIDTH
    mov ax, 0x0B3D
.bot: stosw
    loop .bot
    ret

draw_string_v:
.l: lodsb
    test al, al
    jz .d
    stosw
    jmp .l
.d: ret

draw_num_v:
    pusha
    mov bx, 10
    xor cx, cx
.div: xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div
.pr: pop dx
    add dl, '0'
    mov al, dl
    mov ah, 0x0A
    stosw
    loop .pr
    popa
    ret

set_cursor:
    mov bh, 0
    mov ah, 0x02
    int 0x10
    ret

print_string:
    mov ah, 0x0E
    xor bh, bh
.l: lodsb
    test al, al
    jz .d
    int 0x10
    jmp .l
.d: ret

print_number:
    pusha
    mov bx, 10
    xor cx, cx
.d: xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .d
.p: pop dx
    add dl, '0'
    mov al, dl
    mov ah, 0x0E
    int 0x10
    loop .p
    popa
    ret

random:
    push dx
    mov ax, [random_seed]
    mov dx, 8405h
    mul dx
    add ax, 1
    mov [random_seed], ax
    pop dx
    ret

delay:
    push ax
    push cx
    push dx
.l1: push cx
    mov ah, 0x00
    int 0x1A
    mov bx, dx
.l2: mov ah, 0x00
    int 0x1A
    cmp dx, bx
    je .l2
    pop cx
    loop .l1
    pop dx
    pop cx
    pop ax
    ret

player_x       dw 0
player_y       dw 0
asteroid_x     times MAX_ASTEROIDS dw 0
asteroid_y     times MAX_ASTEROIDS dw 0
asteroid_active times MAX_ASTEROIDS db 0
score          dw 0
game_over      db 0
random_seed    dw 1234
tick_counter   db 0
exit_flag      db 0

title_msg      db 'SPACE ARCADE', 0
score_msg      db 'Score: ', 0
game_over_msg  db 'GAME OVER!', 0