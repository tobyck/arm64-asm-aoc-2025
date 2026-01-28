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

    // solution goes here

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
