.const
MEM_STATS: .byte 1
no_input_msg: .asciz "Input file must be passed as an argument\n"

.data
adj_chars: .space 9 // 8 + null byte
coords_to_remove: .space 24

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

    mov w20, 0                          // total removed
    mov w21, -1                         // removed on current iteration
    add x27, x19, x1                    // addr of null byte in input

    mov w1, '\n'
    bl index_of
    mov w25, w0                         // w25 = width of grid (which is the same as the height)
    add w26, w0, 1                      // width incl. new line

next_iteration:
    cmp w21, 0                          // print answer when no more can be removed
    beq print_answer

    mov w21, 0                          // reset number removed on this iteration
    mov x22, x19                        // addr of current char in input
    mov w23, 0                          // x coord
    mov w24, 0                          // y coord

char_loop:
    cmp x22, x27                        // new iteration when end of input reached
    bge next_iteration

    ldrb w9, [x22], 1                   // current char
    cmp w9, '\n'                        // if char is new line,
    csel w23, wzr, w23, eq              // x = 0
    cinc w24, w24, eq                   // y++
    beq char_loop

    cmp w9, '@'
    bne next_char

    mov x0, x19
    mov w1, w25
    mov w2, w25
    mov w3, w23
    mov w4, w24
    adrp x5, adj_chars@PAGE
    add x5, x5, adj_chars@PAGEOFF
    str xzr, [x5]                       // clear adj_chars for following simd tricks
    bl get_all_adj_chars

    // ceebs explaining this simd stuff but basically it puts the number of adj. rolls in w9
    ld1 {v0.8b}, [x0]
    movi v1.8b, 0x40
    cmeq v0.8b, v0.8b, v1.8b
    ushr v0.8b, v0.8b, 7
    uaddlv h0, v0.8b
    fmov w9, h0

    // loop early if >= 4
    cmp w9, 4
    bge next_char

    // replace with '.' in buffer
    madd w9, w26, w24, w23
    add x9, x9, x19
    mov w10, '.'
    strb w10, [x9]

    // increment counters for how many have been removed
    add w20, w20, 1
    add w21, w21, 1

next_char:
    add w23, w23, 1                     // x++
    b char_loop

print_answer:
    mov w0, w20
    bl print_intln

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
