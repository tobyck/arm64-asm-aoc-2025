.const
MEM_STATS: .byte 1
no_input_msg: .asciz "Input file must be passed as an argument\n"

.text
.global _start, MEM_STATS

_start:
    cmp x0, 2                   // check filename is provided (x0 = argc)
    bge load_input
    adrp x0, no_input_msg@PAGE
    add x0, x0, no_input_msg@PAGEOFF
    bl print_str
    b exit_failure
load_input:
    ldr x0, [x1, 8]             // x0 = argv[1] (x1 = argv)
    bl load_file                // x0 now points to buffer
    mov x19, x0                 // preserve pointer to input buffer
    
    add x25, x0, x1             // address past end of input buffer

    mov w1, '\n'
    bl index_of
    add x20, x0, 1              // x20 = stride for reading next row

    add x26, x19, x20           // address past start of last column

    mov x23, 0                  // grand total
    mov w24, 10                 // constant

    mov x21, x19                // start for next column

    b skip_add_to_total

next_equation:
    add x23, x23, x12           // add equation answer to total
skip_add_to_total:
    mov w12, 0                  // current equation answer

next_column:
    cmp x21, x26                // print answer when all columns read
    bge print_answer
    mov x22, x21                // pointer to current char
    mov w10, 0                  // current int in column
    mov w13, 0                  // whether or not a digit has been seen in current column

loop:
    cmp x22, x25
    bge eval_column             // eval column when pointing past eof

    ldrb w9, [x22]              // load char

    cmp w9, '0'
    blt not_digit
    cmp w9, '9'
    bgt not_digit

    sub w9, w9, '0'             // convert to digit
    mul w10, w10, w24           // multiply current int by 10
    add w10, w10, w9            // add current digit
    mov w13, 1                  // flag that a digit has been seen in this column
    b next_row

not_digit:
    // store operator in w11 if present
    cmp w9, '+'
    csel w11, w9, w11, eq
    cmp w9, '*'
    csel w11, w9, w11, eq

next_row:
    add x22, x22, x20           // advance pointer to read next char from
    b loop

eval_column:
    add x21, x21, 1             // increase address of where to start reading next column
    cbz w13, next_equation      // go to next equation if no digits found in column
    cmp w11, '+'
    bne not_add
    add w12, w12, w10           // add case
    b next_column
not_add:
    cbnz w12, multiply
    mov w12, w10                // init case for multiplication
    b next_column
multiply:
    mul x12, x12, x10           // multiply case
    b next_column

print_answer:
    mov x0, x23
    bl print_intln

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
