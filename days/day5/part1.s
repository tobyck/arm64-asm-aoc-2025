.const
MEM_STATS: .byte 1
no_input_msg: .asciz "Input file must be passed as an argument\n"

.data
fresh_ranges: .space 24

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
    ldr x0, [x1, 8]             // x0 = argv[1] (x1 = argv)
    bl load_file                // x0 now points to buffer
    mov x19, x0                 // preserve pointer to input buffer

    mov w20, 0                  // answer

    // this list will store pairs of 8 byte registers (start and end of a range)
    adrp x0, fresh_ranges@PAGE
    add x0, x0, fresh_ranges@PAGEOFF
    mov x23, x0
    mov w1, 16
    bl list_init

    mov x21, x19

scan_ranges_loop:
    // if a new line is encountered instead of a number, all ranges have been scanned
    ldrb w9, [x21]
    cmp w9, '\n'
    beq end_range_scan

    mov x0, x21
    bl str_to_int               // parse first int (start of range)
    mov x22, x0                 // save int in x22
    add x21, x21, x1            // add number of chars read + 1 to current addr
    add x21, x21, 1
    mov x0, x21
    bl str_to_int               // parse second int (end of range)
    add x21, x21, x1            // move next addr. to start of next line
    add x21, x21, 1
    mov x2, x0                  // x2 = range end
    mov x1, x22                 // x1 = range start
    mov x0, x23                 // x0 = list to push to
    bl list_push                // push pair to list
    b scan_ranges_loop          // scan the next range

end_range_scan:
    add x21, x21, 1             // add one to current addr. to account for new line

iterate_ingredients:
    // print answer when null byte reached
    ldrb w9, [x21, -1]
    cmp w9, 0
    beq print_answer
    
    // parse ingredient ID into x0
    mov x0, x21
    bl str_to_int
    add x21, x21, x1
    add x21, x21, 1

    ldr x9, [x23]               // x9 will store addr. of current range in list
    ldr w12, [x23, 12]          // w12 = list length
    mov w13, 0                  // w13 = loop counter
iterate_ranges:
    // go to next ingredient once all ranges have been checked for this ingredient
    cmp w13, w12
    beq iterate_ingredients

    // load range start and end into x10 and x11
    ldp x10, x11, [x9], 16

    // don't count if below bottom of range
    cmp x0, x10
    blt next_range

    // likewise if above range
    cmp x0, x11
    bgt next_range

    // otherwise, it's in a range, so increment answer and go to next ingredient
    add w20, w20, 1
    b iterate_ingredients
next_range:
    // test next range
    add w13, w13, 1
    b iterate_ranges

print_answer:
    mov w0, w20
    bl print_intln

    mov x0, x23
    bl list_free

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
