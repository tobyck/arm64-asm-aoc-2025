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
    ldr x0, [x1, 8]                     // x0 = argv[1] (x1 = argv)
    bl load_file                        // x0 now points to buffer
    mov x19, x0                         // preserve pointer to input buffer

    mov w20, 50                         // w20 = dial position
    mov w21, 0                          // w21 = answer
    mov x22, x0                         // x22 = address to read next char from

line_loop:
    bl break
    ldrb w23, [x22], 1                  // w23 = L or R
    cbz w23, print_answer               // print answer when null byte reached
    mov x0, x22                         // x0 = address of int start
    bl str_to_int                       // x0 is now the int
    add x22, x22, x1                    // x22 += number of chars read for int
    add x22, x22, 1
    neg x9, x0                          // either x0 or x9 will be added depending on dir.
    cmp w23, 'L'
    csel x0, x9, x0, eq                 // negate int if turning left
    add w20, w20, w0                    // add to position
    mov w9, 100
    sdiv w10, w20, w9                   // w10 = position / 100
    msub w20, w10, w9, w20              // position = remainder (could be negative)
    cmp w20, 0
    bge positive_remainder
    add w20, w20, w9                    // add 100 if remainder is negative
positive_remainder:
    cbnz w20, line_loop                 // repeat early if position not 0
    add w21, w21, 1                     // otherwise increment answer
    b line_loop
    
print_answer:
    mov x0, x21
    bl print_intln

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
