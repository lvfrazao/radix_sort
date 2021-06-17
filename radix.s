bits 64
default rel
extern malloc ; From libc
extern free ; From libc
global radix_sort ; Our sorting function
%define RADIX 256

%macro MemClearDigitCount 0
    ; Uses 256 bit registers to clear 32 bytes at a time
    ; digit_counts is 64
    ; digit_counts in rcx
    vpxor ymm0, ymm0, ymm0
    xor rdi, rdi
%%memclr_head:
    vmovdqa [rcx + rdi], ymm0
    add rdi, 32
    cmp rdi, 2048
    jne %%memclr_head
%endmacro

%macro CalcCountIndex 1
    ; uint64_t count_index = (arr[i] >> (8 * cur_digit)) & (RADIX - 1);
    ; We will use rsi to hold the digit we're current examining
    shrx rsi, rsi, r9
    movzx rsi, sil
%endmacro

%macro CountSortbyDigit 1
    ; %1 = which digit in a 64bit 256 radix number I want to countsort on
    ; rax is our temp / intermediate array
    ; rdx is our array to sort
    ; rcx is digit_counts
    ; r8 is our array len
    lea rcx, [digit_counts] ; Need for PIC
    lea r9, [%1 * 8]    ; Used for calculating the count_index
    MemClearDigitCount

    ; rdi will hold the array index
    xor rdi, rdi
%%count_sort_head:
    cmp rdi, r8
    je %%count_sort_end
    mov rsi, [rdx + rdi * 8] ; Load arr[i] into rsi

    ; uint64_t count_index = (arr[i] >> (8 * cur_digit)) & (RADIX - 1);
    ; We will use r11 to hold the digit we're current examining
    shrx r11, rsi, r9
    movzx r11, r11b

    ; digit_counts[count_index]++;
    inc qword [rcx + r11 * 8]
    inc rdi
    jmp %%count_sort_head
%%count_sort_end:

    ; rdi will be the array index
    mov rdi, 1
    ; for (uint16_t digit = 1; digit < 256; digit++)
%%cumulative_sum_head:
    cmp rdi, 256
    je %%cumulative_sum_end
    
    ; digit_counts[digit] += digit_counts[digit - 1];
    mov rsi, [rcx + rdi * 8 - 8]
    add [rcx + rdi * 8], rsi

    inc rdi
    jmp %%cumulative_sum_head
%%cumulative_sum_end:

    ; for (size_t i = arr_len; i > 0; i--)
    mov rdi, r8
    dec rdi
%%write_to_intermediate_head:
    ; intermediate_arr[--digit_counts[count_index]] = arr[i];
    ; rdi is the loop counter i
    ; r11 is the count_index
    ; rcx is the digit_counts array
    ; rax is the intermediate_arr

    ; Load arr[i] into rsi
    mov rsi, [rdx + rdi * 8]

    ; uint64_t count_index = (arr[i] >> (8 * cur_digit)) & (RADIX - 1);
    ; We will use r11 to hold the digit we're current examining
    shrx r11, rsi, r9
    movzx r11, r11b

    ; --digit_counts[count_index]
    mov r10, [rcx + r11 * 8]
    dec r10
    mov [rcx + r11 * 8], r10

    mov [rax + r10 * 8], rsi

    dec rdi
    jnz %%write_to_intermediate_head
%%write_to_intermediate_end:
    ; Final iteration of write_to_intermediate
    ; Took out the final iteration in order to remove a call to test rdi, rdi
    
    ; Load arr[i] into rsi
    mov rsi, [rdx + rdi * 8]

    ; uint64_t count_index = (arr[i] >> (8 * cur_digit)) & (RADIX - 1);
    shrx r11, rsi, r9
    movzx r11, r11b

    ; --digit_counts[count_index]
    mov r10, [rcx + r11 * 8]
    dec r10
    mov [rcx + r11 * 8], r10

    mov [rax + r10 * 8], rsi

    ; Now we need to switch our pointers
    ; uint64_t *temp = arr;
    ; arr = intermediate_arr;
    ; intermediate_arr = temp;
    xchg rax, rdx

%endmacro

SECTION .text
; Radix Sort
; int radix_sort(uint64_t *arr, size_t arr_len)
; Per C caling conventions:
; uint64_t *arr   -> is in rdi
; size_t arr_len  -> is in rsi
; The return value is 0 for success, anything else is failure
radix_sort:
    push rbp
    mov rbp, rsp

    ; The biggest sin of this algorithm is that it requires us to allocate
    ; another array of the same size as the original array we're sorting
    ; uint64_t *intermediate_arr = malloc(sizeof(uint64_t) * arr_len);
    push rdi
    push rsi

    ; Setup the parameters for malloc
    ; Move the array len into the position of param 1
    ; Multiple the array len by the sizeof(uint64) (8 bytes)
    mov rdi, rsi
    shl rdi, 3
    call malloc wrt ..plt ; I hate PIC

    pop r8 ; contains the array length
    pop rdx ; contains the original array pointer
    ; My newly malloc'ed array pointer is in rax

.error_chk_malloc:
    or rax, 0
    jz .exit_malloc_failure

.count_sort_by_digit:
    ; We could do the count sort on a loop - but its **maybe** better to unroll
    ; the loop to avoid branching? - Its more code, but less branching, not sure
    ; what performs better TBH.
    CountSortbyDigit 0
    CountSortbyDigit 1
    CountSortbyDigit 2
    CountSortbyDigit 3
    CountSortbyDigit 4
    CountSortbyDigit 5
    CountSortbyDigit 6
    CountSortbyDigit 7

.exit_success:
    mov rdi, rax
    call free wrt ..plt; Free our intermediate array
    xor rax, rax
    leave
    ret
.exit_malloc_failure:
    mov rax, 1
    leave
    ret

SECTION .bss
align 32 ; need in order to do aligned move using SSE/AVX
; 256 * 8 bytes = 2048 bytes to hold all digit counts
; size_t digit_counts[RADIX] = {0}
digit_counts: resq RADIX; we keep counts for 256 digits of a 64bit 256 radix number
