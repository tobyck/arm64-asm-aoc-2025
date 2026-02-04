.const
MEM_STATS: .byte 1
no_input_msg: .asciz "Input file must be passed as an argument\n"

.data
numbers_list: .space 24

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

    adrp x0, numbers_list@PAGE
    add x0, x0, numbers_list@PAGEOFF
    mov w1, 2
    mov x20, x0
    bl list_init

    mov x21, x19                // current address in input
    mov w23, 0                  // number of numbers across
    mov w24, 1                  // whether to count number of numbers across

parse_numbers_loop:
    // consume whitespace
    ldrb w9, [x21]
    cmp w9, ' '
    cinc x21, x21, eq
    beq parse_numbers_loop

    cmp w9, '\n'
    csel w24, wzr, w24, eq      // if it hasn't been done already, flag to stop counting numbers across
    cinc x21, x21, eq
    beq parse_numbers_loop

    cmp w9, '+'
    beq do_calcs
    cmp w9, '*'
    beq do_calcs
    
    mov x0, x21
    bl str_to_int
    add x21, x21, x1            // add number of bytes read to pointer in input
    cmp w24, 1                  // if we're still counting,
    cinc w23, w23, eq           // increment number of numbers across

    mov w1, w0                  // int from str_to_int
    mov x0, x20                 // numbers_list
    bl list_push

    b parse_numbers_loop

do_calcs:
    lsl w23, w23, 1             // w23 = stride

    ldr x11, [x20]              // address in numbers list to start at
    ldr w14, [x20, 12]          // length of numbers list
    add x14, x11, x14, lsl 1    // address immediately after the end of the list

    mov x15, 0 // grand total

    b skip_add

next_column:
    add x15, x15, x10           // add answer to grand total
    add x11, x11, 2             // start the next iteration from the next column along
skip_add:
    ldrb w9, [x21], 1           // load next char from input
    cmp w9, '\n'
    beq print_answer            // a \n at this point is eof so print answer
    cmp w9, ' '
    beq skip_add                // consume whitespace
    mov x10, 0                  // reset answer for current column
    mov x12, x11                // reset pointer to current number (which has now advanced)

solve_column_loop:
    cmp x12, x14
    bge next_column             // when pointer to current number goes beyond list, do next equation

    ldrh w13, [x12]             // load number from list
    add x12, x12, x23           // advance pointer for next iteration
    cmp w9, '+'
    bne multiply
    add x10, x10, x13           // add case
    b solve_column_loop
multiply:
    cbz x10, init_answer
    mul x10, x10, x13           // multiply case
    b solve_column_loop
init_answer:
    mov w10, w13                // init case for multiply
    b solve_column_loop

print_answer:
    mov x0, x15
    bl print_intln

    mov x0, x20
    bl list_free

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
