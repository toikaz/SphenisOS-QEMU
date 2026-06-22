[BITS 16]
[ORG 0x5000]

start:
    pusha
    mov ax, cs
    mov ds, ax
    mov es, ax

    call print_newline
    mov si, welcome_msg
    call print_string
    call print_newline

main_loop:
    mov si, prompt
    call print_string

    mov di, buffer
    call read_string

    cmp byte [exit_flag], 1
    je exit_program

    cmp byte [buffer], 0
    je main_loop

    mov si, buffer
    call parse_input

    cmp dword [error_flag], 0
    jne .error

    mov si, result_msg
    call print_string

    mov eax, [result]
    test eax, eax
    jns .positive
    neg eax
    push eax
    mov ah, 0x0E
    mov al, '-'
    int 0x10
    pop eax
.positive:
    call print_number
    call print_newline
    jmp main_loop

.error:
    mov si, error_msg
    call print_string
    call print_newline
    jmp main_loop

exit_program:
    call print_newline
    mov si, exit_msg
    call print_string
    call print_newline

    popa
    retf



read_string:
    xor cx, cx
    mov byte [exit_flag], 0
.read_char:
    mov ah, 0
    int 0x16

    cmp al, 27
    je .exit_pressed
    cmp al, 0x08
    je .backspace
    cmp al, 0x0D
    je .done

    cmp al, '0'
    jb .check_ops
    cmp al, '9'
    ja .check_ops
    jmp .valid_char

.check_ops:
    cmp al, '-'
    je .valid_char
    cmp al, '+'
    je .valid_char
    cmp al, '*'
    je .valid_char
    cmp al, '/'
    je .valid_char
    cmp al, '^'
    je .valid_char
    cmp al, ' '
    je .valid_char
    jmp .read_char

.valid_char:
    mov ah, 0x0E
    int 0x10
    stosb
    inc cx
    cmp cx, 64
    jae .done
    jmp .read_char

.backspace:
    test cx, cx
    jz .read_char
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_char

.exit_pressed:
    mov byte [exit_flag], 1
.done:
    mov al, 0
    stosb
    call print_newline
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
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    ret


parse_number:
    xor eax, eax
    mov [number], eax
    mov byte [negative_flag], 0
    lodsb
    cmp al, '-'
    jne .not_neg
    mov byte [negative_flag], 1
    lodsb
    jmp .start
.not_neg:
    cmp al, '+'
    jne .start
    lodsb
.start:
    dec si
.read:
    lodsb
    cmp al, '0'
    jb .done
    cmp al, '9'
    ja .done
    sub al, '0'
    movzx ebx, al
    mov eax, [number]
    mov edx, 10
    mul edx
    jo .ovf
    add eax, ebx
    jc .ovf
    mov [number], eax
    jmp .read
.done:
    dec si
    cmp byte [negative_flag], 0
    je .pos
    neg dword [number]
.pos:
    ret
.ovf:
    mov dword [error_flag], 1
    ret

fold_term:
    mov eax, [result]
    mov ebx, [operand1]
    mov cl, [add_op]
    cmp cl, '+'
    je .add
    cmp cl, '-'
    je .sub
    ret
.add:
    add eax, ebx
    mov [result], eax
    ret
.sub:
    sub eax, ebx
    mov [result], eax
    ret

parse_input:
    mov dword [error_flag], 0
.skip:
    lodsb
    cmp al, ' '
    je .skip
    cmp al, 0
    je .err
    dec si
    call parse_number
    cmp dword [error_flag], 0
    jne .err
    mov eax, [number]
    mov [operand1], eax
    mov dword [result], 0
    mov byte [add_op], '+'
.expr_loop:
    lodsb
    cmp al, ' '
    je .expr_loop
    cmp al, 0
    je .done
    mov [operation], al
.skip2:
    lodsb
    cmp al, ' '
    je .skip2
    cmp al, 0
    je .err
    dec si
    call parse_number
    mov eax, [number]
    mov [operand2], eax
    mov al, [operation]
    cmp al, '*'
    je .muldiv
    cmp al, '/'
    je .muldiv
    cmp al, '^'
    je .muldiv
    call fold_term
    mov al, [operation]
    mov [add_op], al
    mov eax, [operand2]
    mov [operand1], eax
    jmp .expr_loop
.muldiv:
    call perform_op
    jmp .expr_loop
.done:
    call fold_term
    ret
.err:
    mov dword [error_flag], 1
    ret

perform_op:
    mov eax, [operand1]
    mov ebx, [operand2]
    mov cl, [operation]
    cmp cl, '*'
    je .mul
    cmp cl, '/'
    je .div
    cmp cl, '^'
    je .pow
    ret
.mul:
    imul ebx
    mov [operand1], eax
    ret
.div:
    test ebx, ebx
    jz .err
    cdq
    idiv ebx
    mov [operand1], eax
    ret
.pow:
    mov ecx, ebx
    mov eax, 1
    mov ebx, [operand1]
.pow_l:
    jecxz .pow_d
    imul ebx
    dec ecx
    jmp .pow_l
.pow_d:
    mov [operand1], eax
    ret
.err:
    mov dword [error_flag], 1
    ret

print_number:
    pusha
    test eax, eax
    jnz .not_zero
    mov ah, 0x0E
    mov al, '0'
    int 0x10
    jmp .done
.not_zero:
    mov edi, number_buffer + 10
    mov byte [edi], 0
    dec edi
    mov ebx, 10
.conv:
    xor edx, edx
    div ebx
    add dl, '0'
    mov [edi], dl
    dec edi
    test eax, eax
    jnz .conv
    inc edi
    mov si, di
.print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .print
.done:
    popa
    ret

welcome_msg db 'Sphenis Calc (+ - * / ^)', 0x0D, 0x0A, 'Press ESC to exit', 0x0D, 0x0A, 0
prompt      db '> ', 0
result_msg  db '= ', 0
error_msg   db 'Error!', 0
exit_msg    db 'Returning to Console...', 0

error_flag    dd 0
number        dd 0
operand1      dd 0
operand2      dd 0
operation     db 0
result        dd 0
negative_flag db 0
exit_flag     db 0
add_op        db 0
number_buffer times 11 db 0
buffer        times 65 db 0