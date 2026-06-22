[BITS 16]
[ORG 0x8000]

; Точка входа
start:
    ; Очистка экрана и настройка
    mov ax, 0x0003
    int 0x10
    
    mov si, msg_intro
    call print_string

getInput:
    mov di, code_buffer
.read_char:
    mov ah, 00h
    int 16h
    cmp al, 13          ; ENTER - запуск
    je allocateWorkspace
    cmp al, 27          ; ESC - выход
    je exit_app
    
    stosb               ; Сохраняем код
    call print_char
    jmp .read_char

allocateWorkspace:
    mov byte [di], 0    ; Терминатор строки
    mov word [programCounter], code_buffer
    
    ; Выделение 30КБ под память BF (в сегменте данных приложения)
    mov di, memory_space
    mov cx, 30000
    xor al, al
    rep stosb
    
    mov word [dataPointer], memory_space

runCode:
    mov si, [programCounter]
    lodsb
    test al, al
    jz exit_app         ; Конец программы
    mov [programCounter], si

    cmp al, '>'
    je .inc_ptr
    cmp al, '<'
    je .dec_ptr
    cmp al, '+'
    je .inc_cell
    cmp al, '-'
    je .dec_cell
    cmp al, '.'
    je .out_cell
    cmp al, '['
    je .jump_forward
    cmp al, ']'
    je .jump_backward
    jmp runCode

.inc_ptr: inc word [dataPointer]; jmp runCode
.dec_ptr: dec word [dataPointer]; jmp runCode
.inc_cell: mov bx, [dataPointer]; inc byte [bx]; jmp runCode
.dec_cell: mov bx, [dataPointer]; dec byte [bx]; jmp runCode
.out_cell: mov bx, [dataPointer]; mov al, [bx]; call print_char; jmp runCode

.jump_forward:
    mov bx, [dataPointer]
    cmp byte [bx], 0
    jne runCode
    ; Логика пропуска цикла (упрощенно)
    jmp runCode

.jump_backward:
    ; Логика возврата цикла
    jmp runCode

exit_app:
    ; Возврат в ядро SphenisOS
    ; Используем конструкцию, которую ядро ожидает при возврате
    mov ax, 0x0003
    int 0x10
    retf                ; Возврат в ядро (app_exit_gate)

print_char:
    mov ah, 0x0e
    int 0x10
    ret

print_string:
    mov ah, 0x0e
.l: lodsb
    test al, al
    jz .d
    int 0x10
    jmp .l
.d: ret

msg_intro db 'Brainfuck Interpreter for SphenisOS', 13, 10, 'Code: ', 0
programCounter dw 0
dataPointer    dw 0
code_buffer    times 256 db 0
memory_space   times 30000 db 0