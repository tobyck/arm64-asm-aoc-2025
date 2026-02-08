.const
MEM_STATS: .byte 1
no_input_msg: .asciz "Input file must be passed as an argument\n"

.text
.global _start, MEM_STATS

_start:
    cmp x0, 2                           // check filename is provided (x0 = argc)
    bge load_input
    adrp x0, no_input_msg@PAGE
    add x0, x0, no_input_msg@PAGEOFF
    bl print_str
    b exit_failure
load_input:
    ldr x0, [x1, 8]         // x0 = argv[1] (x1 = argv)
    bl load_file            // x0 now points to buffer
    mov x19, x0             // preserve pointer to input buffer

    mov x20, x19            // address to read next char from
    add x23, x19, x1        // address to stop at

    mov w1, '\n'
    bl index_of
    add w21, w0, 1          // stride to read next/prev row
    
    mov w22, 0              // number of splits
    mov w24, '|'            // const

loop:
    cmp x20, x23            // print answer at eof
    bge print_answer
    ldrb w9, [x20]          // load char
    cmp w9, 'S'
    beq found_s             // mark first | below S
    sub x10, x20, x21       // x10 = current_addr - stride
    ldrb w11, [x10]         // w11 = char above current one
    cmp w9, '^'
    beq split               // split if current char is '^'
    cmp w11, '|'            // if not '|' or '^' then loop
    bne loop_next
    strb w24, [x20]         // continue straight tachyon beams down
    b loop_next

found_s:
    strb w24, [x20, x21]    // *(current_addr + stride) = '|'
    b loop_next

split:
    cmp w11, '|'            // if no | above then nothing's being split
    bne loop_next
    strb w24, [x20, -1]     // store | to left
    strb w24, [x20, 1]      // ditto to right
    add w22, w22, 1         // increment counter of number of splits

loop_next:
    add x20, x20, 1         // advance address to read next char from
    b loop

print_answer:
    mov w0, w22
    bl print_intln

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
