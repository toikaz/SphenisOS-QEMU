[BITS 16]
[ORG 0x5000]

%define COLOR_BG  0x17
%define COLOR_WIN 0x70
%define COLOR_HDR 0x1F

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

init_desktop:
    mov ax, 0x0003
    int 0x10
    mov byte [selected_index], 0

main_render:
    call draw_background
    call draw_taskbar
    call draw_app_window

ui_loop:
    call update_clock
    mov ah, 0x01
    int 0x16
    jz ui_loop
    
    mov ah, 0x00
    int 0x16

    cmp ah, 0x48        ; Стрелка Вверх
    je move_up
    cmp ah, 0x50        ; Стрелка Вниз
    je move_down
    cmp al, 's'         ; Вызов меню Пуск
    je open_start_menu
    cmp al, 'S'
    je open_start_menu
    cmp al, 13          ; ENTER
    je run_selected
    jmp ui_loop

move_up:
    dec byte [selected_index]
    and byte [selected_index], 3
    call draw_app_window
    jmp ui_loop

move_down:
    inc byte [selected_index]
    cmp byte [selected_index], 3
    jne .ok
    mov byte [selected_index], 0
.ok:
    call draw_app_window
    jmp ui_loop

open_start_menu:
    ; Отрисовка окна меню
    mov ax, 0x0600
    mov bh, COLOR_WIN
    mov ch, 18
    mov cl, 0
    mov dh, 23
    mov dl, 15
    int 0x10

    mov dh, 19
    mov dl, 1
    call set_cursor
    mov si, msg_m1
    call print_string

    mov dh, 21
    mov dl, 1
    call set_cursor
    mov si, msg_m_back
    call print_string

.wait_m:
    mov ah, 0x00
    int 0x16
    cmp al, '1'
    je exit_to_shell
    cmp al, 27          ; ESC - закрыть меню
    je main_render
    jmp .wait_m

run_selected:
    mov al, [selected_index]
    cmp al, 0
    je start_sys_info
    cmp al, 1
    je start_gfx_paint
    cmp al, 2
    je inject_pong
    jmp ui_loop

; ==========================================
; SYSTEM INFO
; ==========================================
start_sys_info:
    mov ax, 0x0003
    int 0x10

    mov dh, 2
    mov dl, 5
    call set_cursor
    mov si, msg_info_hdr
    call print_string

    mov dh, 5
    mov dl, 5
    call set_cursor
    mov si, msg_author_label
    call print_string
    mov si, msg_toika
    call print_string

    mov dh, 7
    mov dl, 5
    call set_cursor
    mov si, msg_cpu
    call print_string
    
    xor eax, eax
    cpuid
    mov [cpu_vendor], ebx
    mov [cpu_vendor+4], edx
    mov [cpu_vendor+8], ecx
    mov si, cpu_vendor
    call print_string

    mov dh, 9
    mov dl, 5
    call set_cursor
    mov si, msg_ram_info
    call print_string
    int 0x12
    call print_int
    mov si, msg_kb
    call print_string

    mov dh, 13
    mov dl, 5
    call set_cursor
    mov si, msg_press_key
    call print_string
    mov ah, 0x00
    int 0x16
    jmp init_desktop

; ==========================================
; PAINT (5 цветов: 1-5)
; ==========================================
start_gfx_paint:
    mov ax, 0x0013
    int 0x10
.p_loop:
    call draw_cursor_gfx
    mov ah, 0x00
    int 0x16
    push ax
    call draw_cursor_gfx
    pop ax
    cmp al, 27
    je init_desktop
    cmp al, ' '
    je .draw
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
    je .u
    cmp ah, 0x50
    je .d
    cmp ah, 0x4B
    je .l
    cmp ah, 0x4D
    je .r
    jmp .p_loop

.c1:
    mov byte [cur_color], 1
    jmp .p_loop
.c2:
    mov byte [cur_color], 2
    jmp .p_loop
.c3:
    mov byte [cur_color], 4
    jmp .p_loop
.c4:
    mov byte [cur_color], 14
    jmp .p_loop
.c5:
    mov byte [cur_color], 15
    jmp .p_loop

.u:
    dec word [cur_y]
    jmp .p_loop
.d:
    inc word [cur_y]
    jmp .p_loop
.l:
    dec word [cur_x]
    jmp .p_loop
.r:
    inc word [cur_x]
    jmp .p_loop

.draw:
    mov ax, 0xA000
    mov es, ax
    mov ax, [cur_y]
    mov dx, 320
    mul dx
    add ax, [cur_x]
    mov di, ax
    mov al, [cur_color]
    mov [es:di], al
    jmp .p_loop

; ==========================================
; PONG INJECTION
; ==========================================
inject_pong:
    mov ax, 0x0003
    int 0x10
    mov ax, 0x0040
    mov es, ax
    mov di, 0x001E
    mov si, c_p_fix
.l:
    lodsb
    test al, al
    jz .d
    mov ah, 0x1E
    stosw
    jmp .l
.d:
    mov ax, 0x1C0D
    stosw
    mov word [es:0x1A], 0x001E
    mov word [es:0x1C], di
    retf

; ==========================================
; СИСТЕМНЫЕ СЕРВИСЫ
; ==========================================

draw_background:
    mov ax, 0x0600
    mov bh, COLOR_BG
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    ret

draw_taskbar:
    mov ax, 0x0600
    mov bh, COLOR_WIN
    mov cx, 0x1800
    mov dx, 0x184F
    int 0x10
    mov dh, 24
    mov dl, 1
    call set_cursor
    mov si, msg_taskbar
    call print_string
    ret

draw_app_window:
    mov ax, 0x0600
    mov bh, COLOR_WIN
    mov ch, 7
    mov cl, 20
    mov dh, 15
    mov dl, 60
    int 0x10
    mov ax, 0x0600
    mov bh, COLOR_HDR
    mov ch, 7
    mov cl, 20
    mov dh, 7
    mov dl, 60
    int 0x10
    mov dh, 7
    mov dl, 31
    call set_cursor
    mov si, win_title
    call print_string
    
    mov dh, 10
    mov dl, 25
    call set_cursor
    mov al, 0
    call check_sel
    mov si, app_1
    call print_string

    mov dh, 11
    mov dl, 25
    call set_cursor
    mov al, 1
    call check_sel
    mov si, app_2
    call print_string

    mov dh, 12
    mov dl, 25
    call set_cursor
    mov al, 2
    call check_sel
    mov si, app_3
    call print_string
    ret

check_sel:
    cmp al, [selected_index]
    je .y
    mov si, nosel_mark
    call print_string
    ret
.y:
    mov si, sel_mark
    call print_string
    ret

update_clock:
    pusha
    mov ah, 0x02
    int 0x1A
    mov dh, 24
    mov dl, 72
    call set_cursor
    mov al, ch
    call print_bcd
    mov al, ':'
    call print_char
    mov al, cl
    call print_bcd
    popa
    ret

print_bcd:
    push ax
    shr al, 4
    add al, '0'
    call print_char
    pop ax
    and al, 0x0F
    add al, '0'
    call print_char
    ret

set_cursor:
    mov ah, 0x02
    xor bh, bh
    int 0x10
    ret

print_char:
    mov ah, 0x0e
    int 0x10
    ret

print_string:
    mov ah, 0x0e
.l:
    lodsb
    test al, al
    jz .d
    int 0x10
    jmp .l
.d:
    ret

print_int:
    xor cx, cx
    mov bx, 10
.pl:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .pl
.pd:
    pop ax
    add al, '0'
    mov ah, 0x0e
    int 0x10
    loop .pd
    ret

draw_cursor_gfx:
    mov ax, 0xA000
    mov es, ax
    mov ax, [cur_y]
    mov dx, 320
    mul dx
    add ax, [cur_x]
    mov di, ax
    mov al, [es:di]
    xor al, 0x0F
    mov [es:di], al
    ret

exit_to_shell:
    mov ax, 0x0003
    int 0x10
    retf

; --- ДАННЫЕ ---
selected_index db 0
cur_x dw 160
cur_y dw 100
cur_color db 15
win_title    db 'SPHENIS EXPLORER', 0
app_1        db '1. SYSINFO', 0
app_2        db '2. GFXPAINT', 0
app_3        db 'By Toika', 0
sel_mark     db '> ', 0
nosel_mark   db '  ', 0
msg_taskbar  db '[S] Start   Arrows:Move   Enter:Run', 0
msg_m1       db ' 1. Exit Shell', 0
msg_m_back   db ' ESC. Back', 0

msg_info_hdr    db '--- INFO ---', 0
msg_author_label db 'Dev: ', 0
msg_toika       db 'Toika', 0
msg_cpu         db 'CPU: ', 0
cpu_vendor      db '            ', 0
msg_ram_info    db 'RAM: ', 0
msg_kb          db ' KB', 0
msg_press_key   db 'Press any key...', 0
c_p_fix         db 'run sp_menu.bin', 0
