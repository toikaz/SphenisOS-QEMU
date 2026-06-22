[bits 16]
[org 0x7e00]

jmp kernel_start
jmp print_string
jmp read_line
jmp find_file
jmp app_exit_gate
jmp do_mkf
jmp do_rm
jmp do_mkdir
jmp disk_op

kernel_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFF0
    sti
    mov [boot_drive_k], dl

    call install_apps
    call load_config
    call do_clear

    mov si, def_path_name
    mov di, current_path_name
    mov cx, 5
    rep movsb

    mov si, welcome_msg
    call print_string

login_screen:
    mov si, login_p
    call print_string
    mov di, user_input
    call read_line
    mov si, pass_p
    call print_string
    mov di, pass_input
    call read_line_mask
    call check_auth
    jnc .auth_err_label

    mov si, auto_file_name
    mov di, arg_part
    call copy_string_internal
    call do_plb

    jmp main_loop

.auth_err_label:
    mov si, auth_err
    call print_string
    jmp login_screen

main_loop:
    call draw_status_bar

    mov al, '['
    call print_char_raw
    mov si, user_input
    call print_string_raw
    mov si, prompt_mid
    call print_string_raw
    mov al, '/'
    call print_char_raw
    mov si, current_path_name
    call print_string_raw
    mov al, ' '
    call print_char_raw

    mov si, user_input
    mov di, default_user
    call str_compare_logic
    jc .is_root
    mov al, '$'
    jmp .print_end

.is_root:
    mov al, '#'

.print_end:
    call print_char_raw
    mov al, ' '
    call print_char_raw

    mov di, cmd_buffer
    call read_line
    call parse_cmd
    call execute_command
    jmp main_loop

draw_status_bar:
    pusha
    mov ah, 03h
    mov bh, 0
    int 10h
    push dx

    mov ax, 0600h
    mov bh, 0x70
    mov cx, 0000h
    mov dx, 004Fh
    int 10h

    mov ah, 02h
    mov bh, 0
    mov dh, 0
    mov dl, 1
    int 10h
    mov si, root_path
    call print_string_raw
    mov si, current_path_name
    call print_string_raw

    mov ah, 02h
    mov bh, 0
    mov dh, 0
    mov dl, 35
    int 10h
    mov si, status_name
    call print_string_raw

    mov ah, 02h
    mov dl, 71
    int 10h
    call get_time_only

    pop dx
    mov ah, 02h
    mov bh, 0
    int 10h
    popa
    ret

get_time_only:
    mov ah, 02h
    int 1Ah
    mov al, ch
    call print_bcd
    mov al, ':'
    call print_char_raw
    mov al, cl
    call print_bcd
    ret

do_input:
    mov si, arg_part
    call print_string
    mov di, plb_var_buffer
    call read_line
    ret

do_if:
    mov si, plb_var_buffer
    mov di, arg_part
    call str_compare_logic
    jc .match
    mov byte [if_flag], 0
    ret
.match:
    mov byte [if_flag], 1
    ret

do_ls:
    call load_fat
    mov bx, 0x1000
.loop:
    cmp byte [bx], 0
    je .done
    cmp byte [bx+12], 0x10
    jne .p
    mov al, '/'
    call print_char
.p:
    mov si, bx
    call print_fixed_string
    mov al, ' '
    call print_char
    mov al, '('
    call print_char
    mov al, [bx+13]
    add al, '0'
    call print_char
    mov si, sz_suffix
    call print_string_raw
    call print_newline
    add bx, 16
    jmp .loop
.done: ret

do_cd:
    mov si, arg_part
    cmp byte [si], 0
    je .root
    cmp byte [si], '.'
    jne .find
    cmp byte [si+1], '.'
    je .root
.find:
    call find_file_ptr
    test di, di
    jz .err
    cmp byte [di+12], 0x10
    jne .notd

    pusha
    mov si, di
    mov di, current_path_name
    mov cx, 11
    rep movsb
    mov byte [di], 0
    popa

    mov al, [di+11]
    mov [cur_dir_sec], al
    ret
.root:
    mov byte [cur_dir_sec], 35
    mov si, def_path_name
    mov di, current_path_name
    mov cx, 5
    rep movsb
    ret
.notd:
    mov si, err_not_dir
    call print_string
    ret
.err:
    mov si, unknown_msg
    call print_string
    ret

do_pwd:
    mov si, root_path
    call print_string_raw
    mov si, current_path_name
    call print_string_raw
    call print_newline
    ret

do_mkdir:
    mov si, arg_part
    cmp byte [si], 0
    je .err
    call load_fat
    mov di, 0x1000
.find_slot:
    cmp byte [di], 0
    je .found_slot
    add di, 16
    jmp .find_slot
.found_slot:
    push di
    mov si, arg_part
    mov cx, 11
    rep movsb

    mov al, [last_used_sec]
    inc al
    mov [last_used_sec], al
    call save_config_internal

    pop di
    mov [di+11], al
    mov byte [di+12], 0x10
    mov byte [di+13], 1

    pusha
    mov cl, al
    mov di, 0x9000
    push es
    push ds
    pop es
    xor ax, ax
    mov cx, 256
    rep stosw
    pop es
    mov cl, [last_used_sec]
    mov ah, 03h
    mov al, 1
    mov bx, 0x9000
    call disk_op
    popa

    call save_fat
    mov si, ok_msg
    call print_string
    ret
.err:
    mov si, unknown_msg
    call print_string
    ret

execute_command:
    mov si, cmd_part
    cmp byte [si], 0
    je .done
    mov bx, cmd_table
.search:
    mov di, [bx]
    test di, di
    jz .not_found
    call str_compare
    jc .found
    add bx, 4
    jmp .search
.found:
    call [bx+2]
    ret
.not_found:
    mov si, unknown_msg
    call print_string
.done:
    ret

do_run:
    mov si, arg_part
    call find_file
    test al, al
    jz not_found_run

    mov cl, al
    mov ah, 0x02
    mov al, 16
    mov bx, 0x5000
    call disk_op
    jc disk_error_run

    pusha
    push ds
    push es

    mov [kernel_sp_temp], sp
    mov [kernel_ss_temp], ss

    xor ax, ax
    mov ds, ax
    mov es, ax

    call 0x0000:0x5000

    jmp app_exit_gate

not_found_run:
    mov si, unknown_msg
    call print_string
    ret

disk_error_run:
    mov si, disk_err_msg
    call print_string
    ret

app_exit_gate:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, [kernel_ss_temp]
    mov sp, [kernel_sp_temp]
    sti

    pop es
    pop ds
    popa
    call do_clear
    ret

do_plb:
    mov si, arg_part
    call find_file
    test al, al
    jz .err

    mov cl, al
    mov ah, 0x02
    mov al, 1
    mov bx, 0x9000
    call disk_op

    mov si, 0x9000
    mov byte [if_flag], 1
    mov byte [exit_flag], 0

.line_loop:
    cmp byte [si], 0
    je .done
    cmp byte [exit_flag], 1
    je .done

    mov di, cmd_buffer
.copy_cmd:
    lodsb
    cmp al, 13
    je .process_line
    cmp al, 10
    je .process_line
    test al, al
    jz .process_line_final
    stosb
    jmp .copy_cmd

.process_line_final:
    mov byte [di], 0
    call .internal_execute
    jmp .done

.process_line:
    mov byte [di], 0
    push si
    call .internal_execute
    pop si

.skip_nl:
    cmp byte [si], 10
    je .inc_si
    cmp byte [si], 13
    je .inc_si
    jmp .line_loop

.inc_si:
    inc si
    jmp .skip_nl

.done:
    mov byte [if_flag], 1
    mov byte [exit_flag], 0
    ret
.err:
    mov si, unknown_msg
    call print_string
    ret

.internal_execute:
    push si
    call parse_cmd
    mov si, cmd_part
    mov di, c_if
    call str_compare_logic
    jc .handle_if
    mov di, c_if_ex
    call str_compare_logic
    jc .handle_if_exist

    cmp byte [if_flag], 0
    je .skip_and_reset
    call execute_command
    jmp .exec_done

.skip_and_reset:
    mov byte [if_flag], 1
    jmp .exec_done

.handle_if:
    call do_if
    jmp .exec_done

.handle_if_exist:
    call do_if_exist

.exec_done:
    pop si
    ret

do_info:
    mov si, info_ver_os
    call print_string
    mov si, info_ver_plb
    call print_string
    ret

do_pause:
    mov si, pause_msg
    call print_string
    mov ah, 0
    int 0x16
    call print_newline
    ret

do_timeout:
    mov si, arg_part
    xor ax, ax
    xor bx, bx
.parse_num:
    lodsb
    test al, al
    jz .start_wait
    sub al, '0'
    imul bx, 10
    add bx, ax
    jmp .parse_num
.start_wait:
    test bx, bx
    jz .done
.wait_loop:
    mov cx, 0x000F
    mov dx, 0x4240
    mov ah, 0x86
    int 0x15
    dec bx
    jnz .wait_loop
.done: ret

do_sysfetch:
    mov si, neo_dragon_top
    call print_string
    mov si, neo_user_prefix
    call print_string
    mov si, user_input
    call print_string
    call print_newline
    mov si, neo_dragon_bot
    call print_string
    ret

do_mkf:
    mov si, arg_part
    cmp byte [si], 0
    je .err
    call load_fat
    mov di, 0x1000
.find:
    cmp byte [di], 0
    je .found
    add di, 16
    jmp .find
.found:
    push di
    mov si, arg_part
    mov cx, 11
    rep movsb
    mov al, [last_used_sec]
    inc al
    mov [last_used_sec], al
    call save_config_internal

    pop di
    mov [di+11], al
    mov byte [di+12], 0
    mov byte [di+13], 1
    call save_fat
    mov si, ok_msg
    call print_string
    ret
.err:
    mov si, unknown_msg
    call print_string
    ret

do_poweroff:
    mov ax, 5301h
    xor bx, bx
    int 15h
    mov ax, 5307h
    mov bx, 0001h
    mov cx, 0003h
    int 15h
    mov ax, 2000h
    mov dx, 604h
    out dx, ax
    call print_newline
    mov si, safe_to_off_msg
    call print_string
    cli
.halt_loop:
    hlt
    jmp .halt_loop

do_snano:
    call find_file
    test al, al
    jz .not_f
    mov [tmp_sec], al
    call do_clear
    mov si, snano_header
    call print_string
    mov di, 0x9000
    xor cx, cx
.edit_loop:
    mov ah, 0
    int 0x16
    cmp al, 27
    je .exit
    cmp ah, 0x3C
    je .save
    cmp al, 13
    je .newline
    cmp al, 8
    je .backspace
    stosb
    inc cx
    call print_char
    jmp .edit_loop
.backspace:
    test cx, cx
    jz .edit_loop
    dec di
    dec cx
    mov ah, 0x0e
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .edit_loop
.newline:
    mov al, 13
    stosb
    mov al, 10
    stosb
    add cx, 2
    call print_newline
    jmp .edit_loop
.save:
    mov byte [di], 0
    mov cl, [tmp_sec]
    mov ah, 0x03
    mov al, 1
    mov bx, 0x9000
    call disk_op
.exit:
    call do_clear
    ret
.not_f:
    mov si, unknown_msg
    call print_string
    ret

do_type:
    call find_file
    test al, al
    jz .not_f
    mov cl, al
    mov ah, 0x02
    mov al, 1
    mov bx, 0x9000
    call disk_op
    mov si, 0x9000
    mov cx, 512
.print_loop:
    lodsb
    test al, al
    jz .done
    call print_char
    loop .print_loop
.done:
    call print_newline
    ret
.not_f:
    mov si, unknown_msg
    call print_string
    ret

do_echo:
    mov si, arg_part
    call print_string
    call print_newline
    ret

do_useradd:
    mov si, arg_part
    cmp byte [si], 0
    je .err
    call load_users
    mov di, 0x2000
    mov cx, 16
    rep movsb
    call save_users
    mov si, ok_msg
    call print_string
    ret
.err: mov si, unknown_msg
    call print_string
    ret

do_userdel:
    mov si, arg_part
    mov di, default_user
    call str_compare_logic
    jnc .root_err
    call load_users
    mov di, 0x2000
    mov cx, 256
    xor ax, ax
    rep stosw
    call save_users
    mov si, ok_msg
    call print_string
    ret
.root_err:
    mov si, root_prot_msg
    call print_string
    ret

do_passwd:
    mov si, pass_p
    call print_string
    mov di, 0x2010
    call read_line
    call save_users
    mov si, ok_msg
    call print_string
    ret

do_clear:
    mov ax, 0x0600
    mov bh, [sys_color]
    mov cx, 0x0100
    mov dx, 0x184F
    int 0x10
    mov ah, 0x02
    mov bh, 0
    mov dh, 1
    mov dl, 0
    int 0x10
    ret

do_rm:
    call find_file_ptr
    test di, di
    jz .not_f
    mov byte [di], 0
    call save_fat
    mov si, ok_msg
    call print_string
    ret
.not_f: mov si, unknown_msg
    call print_string
    ret

do_whoami:
    mov si, user_input
    call print_string
    call print_newline
    ret

do_setcolor:
    mov si, arg_part
    lodsb
    sub al, '0'
    mov [sys_color], al
    call save_config_internal
    call do_clear
    mov si, ok_msg
    call print_string
    ret

do_time:
    call get_time_only
    call print_newline
    ret

do_date:
    mov ah, 0x04
    int 0x1A
    mov al, dl
    call print_bcd
    mov al, '/'
    call print_char
    mov al, dh
    call print_bcd
    mov al, '/'
    call print_char
    mov al, cl
    call print_bcd
    call print_newline
    ret

do_help:
    mov si, help_header
    call print_string
    mov si, help_table
    call print_string
    ret

do_reboot:
    db 0xea
    dw 0x0000
    dw 0xffff

print_bcd:
    push ax
    shr al, 4
    add al, '0'
    call print_char_raw
    pop ax
    and al, 0x0F
    add al, '0'
    call print_char_raw
    ret

print_string:
    mov ah, 0x0e
.l: lodsb
    test al, al
    jz .d
    int 0x10
    jmp .l
.d: ret

print_string_raw:
    mov ah, 0x0e
.l: lodsb
    test al, al
    jz .d
    int 0x10
    jmp .l
.d: ret

read_line:
    xor cl, cl
.loop:
    mov ah, 0
    int 0x16
    cmp al, 0x0D
    je .done
    cmp al, 0x08
    je .back
    stosb
    inc cl
    mov ah, 0x0e
    int 0x10
    jmp .loop
.back:
    test cl, cl
    jz .loop
    dec cl
    dec di
    mov ah, 0x0e
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .loop
.done:
    mov al, 0
    stosb
    call print_newline
    ret

read_line_mask:
    xor cl, cl
.l: mov ah, 0
    int 0x16
    cmp al, 0x0D
    je .d
    stosb
    inc cl
    mov al, '*'
    call print_char
    jmp .l
.d: mov byte [di], 0
    call print_newline
    ret

str_compare:
    pusha
    mov si, cmd_part
.l: mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .n
    test al, al
    jz .y
    inc si
    inc di
    jmp .l
.y: popa
    stc
    ret
.n: popa
    clc
    ret

parse_cmd:
    mov si, cmd_buffer
    mov di, cmd_part
.l1: lodsb
    cmp al, ' '
    je .s
    cmp al, 0
    je .e
    stosb
    jmp .l1
.s: mov al, 0
    stosb
    mov di, arg_part
.l2: lodsb
    stosb
    test al, al
    jnz .l2
    ret
.e: mov al, 0
    stosb
    mov byte [arg_part], 0
    ret

disk_op:
    pusha
    xor dx, dx
    mov dl, al
    mov [dap_cnt], dx
    cmp ah, 0x02
    je .is_r
    mov byte [dap_op], 0x43
    jmp .d
.is_r:
    mov byte [dap_op], 0x42
.d:
    mov [dap_buf_off], bx
    mov dx, es
    mov [dap_buf_seg], dx
    xor eax, eax
    mov al, cl
    mov dword [dap_lba], eax
    mov dword [dap_lba+4], 0
    mov ah, [dap_op]
    mov si, dap_k
    mov dl, [boot_drive_k]
    int 0x13
    popa
    ret

load_fat:
    mov ah, 0x02
    mov al, 1
    mov cl, [cur_dir_sec]
    mov bx, 0x1000
    call disk_op
    ret

save_fat:
    mov ah, 0x03
    mov al, 1
    mov cl, [cur_dir_sec]
    mov bx, 0x1000
    call disk_op
    ret

load_users:
    mov ah, 0x02
    mov al, 1
    mov cl, 36
    mov bx, 0x2000
    call disk_op
    ret

save_users:
    mov ah, 0x03
    mov al, 1
    mov cl, 36
    mov bx, 0x2000
    call disk_op
    ret

load_config:
    mov ah, 0x02
    mov al, 1
    mov cl, 37
    mov bx, 0x3000
    call disk_op

    mov al, [0x3000]
    cmp al, 0
    je .skip_color
    mov [sys_color], al
.skip_color:

    mov al, [0x3001]
    cmp al, 150
    jb .skip_sec
    mov [last_used_sec], al
.skip_sec:
    ret

save_config_internal:
    pusha
    mov di, 0x3000
    mov al, [sys_color]
    mov [di], al
    mov al, [last_used_sec]
    mov [di+1], al
    mov ah, 0x03
    mov al, 1
    mov cl, 37
    mov bx, 0x3000
    call disk_op
    popa
    ret

check_auth:
    call load_users
    cmp byte [0x2000], 0
    je .check_default_root
    mov si, user_input
    mov di, 0x2000
    call str_compare_logic
    jnc .fail
    mov si, pass_input
    mov di, 0x2010
    call str_compare_logic
    jnc .fail
    stc
    ret
.check_default_root:
    mov si, user_input
    mov di, default_user
    call str_compare_logic
    jnc .fail
    mov si, pass_input
    mov di, default_pass
    call str_compare_logic
    jnc .fail
    stc
    ret
.fail: clc
    ret

copy_string_internal:
.loop:
    lodsb
    stosb
    test al, al
    jnz .loop
    ret

str_compare_logic:
    pusha
.l: mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .n
    test al, al
    jz .y
    inc si
    inc di
    jmp .l
.y: popa
    stc
    ret
.n: popa
    clc
    ret

find_file_ptr:
    call load_fat
    mov di, 0x1000
.loop:
    cmp byte [di], 0
    je .fail
    push di
    mov si, arg_part
    call str_compare_fs
    pop di
    jc .match
    add di, 16
    jmp .loop
.match: ret
.fail: xor di, di
    ret

str_compare_fs:
    mov cx, 11
.l: mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .n
    test al, al
    jz .y
    inc si
    inc di
    loop .l
.y: stc
    ret
.n: clc
    ret

find_file:
    call find_file_ptr
    test di, di
    jz .none
    mov al, [di+11]
    ret
.none: xor al, al
    ret

print_fixed_string:
    mov cx, 11
.l: lodsb
    test al, al
    jz .d
    mov ah, 0x0e
    int 0x10
    loop .l
.d: ret

print_char:
    mov ah, 0x0e
    int 0x10
    ret

print_char_raw:
    mov ah, 0x0e
    int 0x10
    ret

print_newline:
    mov si, newline
    call print_string
    ret

do_write:
    mov si, arg_part
    mov di, write_filename_tmp
.w_name:
    lodsb
    cmp al, ' '
    je .w_name_ok
    test al, al
    jz .w_ret
    stosb
    jmp .w_name
.w_name_ok:
    mov byte [di], 0
    push si
    mov si, write_filename_tmp
    call find_file
    test al, al
    jz .w_pop_err
    mov [write_target_sec], al
    mov cl, al
    mov ah, 02h
    mov al, 1
    mov bx, 0x9000
    call disk_op
    mov di, 0x9000
.w_find_e:
    cmp byte [di], 0
    je .w_copy
    inc di
    jmp .w_find_e
.w_copy:
    pop si
.w_loop:
    lodsb
    test al, al
    jz .w_fin
    stosb
    jmp .w_loop
.w_fin:
    mov ax, 0x0A0D
    stosw
    mov byte [di], 0
    mov cl, [write_target_sec]
    mov ah, 03h
    mov al, 1
    mov bx, 0x9000
    call disk_op
    ret
.w_pop_err:
    pop si
.w_ret:
    ret


do_if_exist:
    mov si, arg_part
    call find_file
    test al, al
    jnz .exists
    mov byte [if_flag], 0
    ret
.exists:
    mov byte [if_flag], 1
    ret

do_exit:
    mov byte [exit_flag], 1
    ret

do_fclear:
    mov si, arg_part
    call find_file
    test al, al
    jz .not_found
    mov [tmp_sec], al
    mov di, 0x9000
    mov byte [di], 0
    mov cl, [tmp_sec]
    mov ah, 03h
    mov al, 1
    mov bx, 0x9000
    call disk_op
    mov si, ok_msg
    call print_string
    ret
.not_found:
    mov si, unknown_msg
    call print_string
    ret

cmd_table:
    dw c_fclr,      do_fclear
    dw c_exit,      do_exit
    dw c_write,     do_write
    dw c_cd,        do_cd
    dw c_mkdir,     do_mkdir
    dw c_poweroff,  do_poweroff
    dw c_run,       do_run
    dw c_plb,       do_plb
    dw c_ls,        do_ls
    dw c_mkf,       do_mkf
    dw c_snano,     do_snano
    dw c_type,      do_type
    dw c_echo,      do_echo
    dw c_neof,      do_sysfetch
    dw c_uadd,      do_useradd
    dw c_udel,      do_userdel
    dw c_pass,      do_passwd
    dw c_clear,     do_clear
    dw c_reboot,    do_reboot
    dw c_rm,        do_rm
    dw c_whoami,    do_whoami
    dw c_setc,      do_setcolor
    dw c_time,      do_time
    dw c_date,      do_date
    dw c_pwd,       do_pwd
    dw c_tout,      do_timeout
    dw c_pause,     do_pause
    dw c_info,      do_info
    dw c_help,      do_help
    dw c_input,     do_input
    dw c_if,        do_if
    dw 0

cur_dir_sec  db 35
current_path_name times 12 db 0
def_path_name db 'root', 0
auto_file_name db 'autorun.plb', 0
last_used_sec db 150
kernel_sp_temp dw 0
kernel_ss_temp dw 0
cmd_buffer   times 64 db 0
cmd_part     times 32 db 0
arg_part     times 32 db 0
user_input   times 16 db 0
pass_input   times 16 db 0
boot_drive_k db 0
tmp_sec      db 0
sys_color    db 0x07

dap_k:
    db 0x10
    db 0
dap_cnt: dw 1
dap_buf_off: dw 0
dap_buf_seg: dw 0
dap_lba: dq 0
dap_op: db 0

prompt_mid db '@sphenis] ', 0
welcome_msg  db 'SphenisOS v3.6.4', 13, 10, 0
login_p      db 'Login: ', 0
pass_p       db 'Password: ', 0
auth_err     db 'Auth Error!', 13, 10, 0
prompt       db '[sphenis]# ', 0
snano_header db '==SNANO===========================================[F2] Save=======[ESC] Exit====', 13, 10, 0
ok_msg       db 'OK', 13, 10, 0
unknown_msg  db 'Unknown command.', 13, 10, 0
disk_err_msg db 'Disk Error!', 13, 10, 0
root_prot_msg db 'Protected!', 13, 10, 0
newline      db 13, 10, 0
pause_msg    db 'Press any key to continue...', 0
root_path    db 'PATH: /', 0
status_name  db 'SphenisOS', 0
default_user db 'root', 0
default_pass db 'root', 0
sz_suffix    db ' sectors)', 0
err_not_dir  db 'Not a directory!', 13, 10, 0
safe_to_off_msg db 'It is now safe to turn off your computer.', 13, 10, 0
info_ver_os  db 'OS Version: SphenisOS v3.6.4', 13, 10, 0
info_ver_plb db 'Shell: Plumbum Script Interpreter v1.1', 13, 10, 0
write_filename_tmp times 12 db 0
write_target_sec   db 0
err_full_msg       db 'Error: Sector full!', 13, 10, 0

help_header  db 13, 10, ' COMMAND       DESCRIPTION            EXAMPLE', 13, 10
             db '-------------------------------------------------------', 13, 10, 0
help_table   db ' ls            List files             ls', 13, 10
             db ' mkf           Create file            mkf test.txt', 13, 10
             db ' snano         Multi-line editor      snano test.txt', 13, 10
             db ' type          Multi-line viewer      type test.txt', 13, 10
             db ' echo          Print text             echo hello!', 13, 10
             db ' sysfetch      System info            sysfetch', 13, 10
             db ' useradd       Add new user           useradd toika', 13, 10
             db ' userdel       Remove user            userdel toika', 13, 10
             db ' passwd        Change password        passwd', 13, 10
             db ' clear         Clear screen           clear', 13, 10
             db ' reboot        Restart system         reboot', 13, 10
             db ' rm            Remove file            rm test.txt', 13, 10
             db ' whoami        Current user           whoami', 13, 10
             db ' setcolor      Change text color      setcolor 2', 13, 10
             db ' time/date     BIOS Time/Date         time', 13, 10
             db ' plb           Run Script             plb script.plb', 13, 10
             db ' timeout       Wait X seconds         timeout 5', 13, 10
             db ' pause         Wait for key press     pause', 13, 10
             db ' info          System version info    info', 13, 10
             db ' poweroff      Shutdown PC            poweroff', 13, 10
             db ' run           Run .bin files         run hexview.bin', 13, 10, 0

neo_dragon_top db '       \ _^ /   ,^,', 13, 10
               db '       \>@@</   ((', 13, 10, 0
neo_user_prefix db '        (..)    );)       USER: ', 0
neo_dragon_bot  db '         vv\^^^^ /        OS: SphenisOS', 13, 10
                db '        /==  ))) )        Build: 12.10.11_16', 13, 10
                db '       ( ==/ )=< \        Shell: Plumbum', 13, 10
                db '      {{{)=(}}}(_}}}', 13, 10, 0

plb_var_buffer times 64 db 0
if_flag        db 0
c_input        db 'input', 0
c_if           db 'if', 0
c_exit         db 'exit', 0
c_write        db 'write', 0
exit_flag      db 0
c_cd           db 'cd', 0
c_mkdir        db 'mkdir', 0
c_run          db 'run', 0
c_poweroff     db 'poweroff',0
c_plb          db 'plb', 0
c_ls           db 'ls', 0
c_fclr         db 'fclear', 0
c_mkf          db 'mkf', 0
c_snano        db 'snano', 0
c_type         db 'type', 0
c_echo         db 'echo', 0
c_neof         db 'sysfetch', 0
c_uadd         db 'useradd', 0
c_udel         db 'userdel', 0
c_pass         db 'passwd', 0
c_clear        db 'clear', 0
c_reboot       db 'reboot', 0
c_rm           db 'rm', 0
c_whoami       db 'whoami', 0
c_setc         db 'setcolor', 0
c_time         db 'time', 0
c_date         db 'date', 0
c_pwd          db 'pwd', 0
c_tout         db 'timeout', 0
c_pause        db 'pause', 0
c_if_ex        db 'if_exist', 0
c_info         db 'info', 0
c_help         db 'help', 0

install_apps:
    mov al, 2
    mov cl, 40
    mov bx, app_desktop_data
    call write_sector_to_disk
    mov al, 2
    mov cl, 56
    mov bx, app_pong_data
    call write_sector_to_disk
    mov al, 2
    mov cl, 72
    mov bx, app_third_data
    call write_sector_to_disk
    mov al, 2
    mov cl, 88
    mov bx, app_fourth_data
    call write_sector_to_disk
    mov al, 2
    mov cl, 104
    mov bx, app_fifth_data
    call write_sector_to_disk
    mov al, 2
    mov cl, 120
    mov bx, app_sixth_data
    call write_sector_to_disk

    call load_fat
    mov di, 0x1000
    mov si, name_desktop
    call copy_entry_full
    mov di, 0x1010
    mov si, name_pong
    call copy_entry_full
    mov di, 0x1020
    mov si, name_third
    call copy_entry_full
    mov di, 0x1030
    mov si, name_fourth
    call copy_entry_full
    mov di, 0x1040
    mov si, name_fifth
    call copy_entry_full
    mov di, 0x1050
    mov si, name_sixth
    call copy_entry_full
    call save_fat
    ret

copy_entry_full:
    mov cx, 11
    rep movsb
    lodsb
    mov [di], al
    mov byte [di+1], 0
    mov byte [di+2], 2
    ret

write_sector_to_disk:
    mov ah, 0x03
    call disk_op
    ret

name_desktop db "sp_menu.bin", 40
name_pong    db "sp_calc.bin", 56
name_third   db "desktop.bin", 72
name_fourth  db "spsnake.bin", 88
name_fifth   db "spspace.bin", 104
name_sixth   db "sppiano.bin", 120

align 512
app_desktop_data: incbin "sp_menu.bin"
    align 512
app_pong_data:    incbin "sp_calc.bin"
    align 512
app_third_data:   incbin "desktop.bin"
    align 512
app_fourth_data:  incbin "hexview.bin"
    align 512
app_fifth_data:   incbin "spspace.bin"
    align 512
app_sixth_data:   incbin "sppiano.bin"
    align 512
times 512 db 0