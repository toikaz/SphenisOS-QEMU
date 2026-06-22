[BITS 16]
[ORG 0x5000]

start:
    pusha
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov ax, 0x0003
    int 0x10

    mov ah, 0x01
    mov cx, 0x2607
    int 0x10

    mov word [score], 0
    mov word [head_pos], 0x0C28
    mov word [head_idx], 0
    mov word [tail_idx], 0
    mov byte [direction], 'd'

    call draw_ui
    call spawn_apple

.game_loop:
    mov ah, 0x00
    int 0x1A
    mov bx, dx
    add bx, 2
.wait:
    int 0x1A
    cmp dx, bx
    jne .wait

    mov ah, 0x01
    int 0x16
    jz .move
    mov ah, 0x00
    int 0x16

    cmp al, 'w'
    je .set_u
    cmp al, 's'
    je .set_d
    cmp al, 'a'
    je .set_l
    cmp al, 'd'
    je .set_r
    cmp al, 27
    je .exit
    jmp .move

.set_u: cmp byte [direction], 's'
    je .move
    mov byte [direction], 'w'
    jmp .move
.set_d: cmp byte [direction], 'w'
    je .move
    mov byte [direction], 's'
    jmp .move
.set_l: cmp byte [direction], 'd'
    je .move
    mov byte [direction], 'a'
    jmp .move
.set_r: cmp byte [direction], 'a'
    je .move
    mov byte [direction], 'd'
    jmp .move

.move:
    mov bx, [head_idx]
    shl bx, 1
    mov ax, [head_pos]
    mov [history + bx], ax

    inc word [head_idx]
    and word [head_idx], 0xFF

    mov dx, [head_pos]
    mov al, [direction]
    cmp al, 'w'
    je .up
    cmp al, 's'
    je .down
    cmp al, 'a'
    je .left
    cmp al, 'd'
    je .right

.up:    dec dh
    jmp .chk
.down:  inc dh
    jmp .chk
.left:  dec dl
    jmp .chk
.right: inc dl
    jmp .chk

.chk:
    cmp dl, 80
    jae .dead
    cmp dh, 1
    jb .dead
    cmp dh, 25
    jae .dead

    mov ah, 0x02
    xor bh, bh
    int 0x10
    mov ah, 0x08
    int 0x10

    cmp al, '0'
    je .dead

    mov [head_pos], dx
    cmp al, '@'
    je .eat

    mov bx, [tail_idx]
    shl bx, 1
    mov dx, [history + bx]
    call clear_p

    inc word [tail_idx]
    and word [tail_idx], 0xFF
    jmp .draw

.eat:
    inc word [score]
    call update_score_ui
    call spawn_apple

.draw:
    mov dx, [head_pos]
    mov al, '0'
    mov bl, 0x0A
    call draw_p
    jmp .game_loop

.dead:
    call draw_game_over_box
    mov ah, 0x00
    int 0x16

.exit:
    mov ax, 0x0003
    int 0x10
    popa
    retf


draw_ui:
    mov ax, 0x0600
    mov bh, 0x1F
    mov cx, 0x0000
    mov dx, 0x004F
    int 0x10

    mov dh, 0
    mov dl, 1
    call set_cursor
    mov si, s_text
    call p_str
    call update_score_ui
    ret

update_score_ui:
    mov dh, 0
    mov dl, 8
    call set_cursor
    mov ax, [score]

    mov bl, 10
    div bl
    add ax, 0x3030
    mov bx, ax

    mov ah, 0x0E
    mov al, bl
    int 0x10
    mov al, bh
    int 0x10
    ret

draw_game_over_box:
    mov ax, 0x0600
    mov bh, 0x4F
    mov ch, 10
    mov cl, 30
    mov dh, 14
    mov dl, 50
    int 0x10

    mov dh, 12
    mov dl, 35
    call set_cursor
    mov si, m_over
    call p_str
    ret

set_cursor:
    mov ah, 0x02
    xor bh, bh
    int 0x10
    ret

draw_p:
    call set_cursor
    mov ah, 0x09
    mov cx, 1
    int 0x10
    ret

clear_p:
    call set_cursor
    mov ah, 0x09
    mov al, ' '
    mov bl, 0x00
    mov cx, 1
    int 0x10
    ret

spawn_apple:
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov cx, 78
    div cx
    inc dl
    mov [tmp_x], dl

    mov ax, bx
    xor dx, dx
    mov cx, 22
    div cx
    add dl, 2
    mov [tmp_y], dl

    mov dh, [tmp_y]
    mov dl, [tmp_x]

    call set_cursor
    mov ah, 0x08
    int 0x10
    cmp al, '0'
    je spawn_apple

    mov al, '@'
    mov bl, 0x0C
    call draw_p
    ret

p_str:
    mov ah, 0x0E
.l: lodsb
    test al, al
    jz .e
    int 0x10
    jmp .l
.e: ret

section .data
head_pos    dw 0
direction   db 0
head_idx    dw 0
tail_idx    dw 0
score       dw 0
tmp_x       db 0
tmp_y       db 0
m_over      db ' GAME OVER! ', 0
s_text      db 'SCORE: ', 0
history     times 256 dw 0