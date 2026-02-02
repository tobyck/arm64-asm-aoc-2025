.const
MEM_STATS: .byte 1
no_input_msg: .asciz "Input file must be passed as an argument\n"

.data
fresh_ranges: .space 24

.text
.global _start, MEM_STATS

_start:
    cmp x0, 2                  // check filename is provided (x0 = argc)
    bge load_input
    adrp x0, no_input_msg@PAGE
    add x0, x0, no_input_msg@PAGEOFF
    bl print_str
    b exit_failure
load_input:
    ldr x0, [x1, 8]            // x0 = argv[1] (x1 = argv)
    bl load_file               // x0 now points to buffer
    mov x19, x0                // preserve pointer to input buffer

    adrp x0, fresh_ranges@PAGE
    add x0, x0, fresh_ranges@PAGEOFF
    mov x23, x0
    mov w1, 16
    bl list_init

    mov x20, x19                // x20 = current point in file

scan_lines_loop:
    // if a new line is encountered instead of a number, all ranges have been scanned
    ldrb w9, [x20]
    cmp w9, '\n'
    beq count_total

    mov x0, x20
    bl str_to_int               // parse first int (start of range)
    mov x21, x0                 // save int in x21
    add x20, x20, x1            // add number of chars read + 1 to current addr
    add x20, x20, 1
    mov x0, x20
    bl str_to_int               // parse second int (end of range)
    mov x22, x0
    add x20, x20, x1            // move next addr. to start of next line
    add x20, x20, 1

    // start of range is in x21 and end of range is in x22
scanned_line:

    ldr x25, [x23]              // pointer to current range
    mov x27, x25                // store for resetting later
    mov w26, 0                  // current index in list

scan_ranges_loop:
    ldr w11, [x23, 12]          // list length

    cmp w26, w11                // compare current index with list length
    mov w24, 1
    csel w24, w24, wzr, eq      // if end of list reached, flag in w24
    beq push_range              // and push the (potentially new) range

    ldp x12, x13, [x25], 16     // load range from list

    // check if ranges don't overlap
    cmp x21, x13
    bgt scan_ranges_loop_next
    cmp x22, x12
    blt scan_ranges_loop_next

    // merge the two ranges
    cmp x21, x12
    csel x21, x21, x12, lt
    cmp x22, x13
    csel x22, x22, x13, gt

    // delete the range that was read from the list
    mov x0, x23
    mov w1, w26
    bl list_remove

    mov x25, x27                // reset pointer to current range in list
    mov w26, 0                  // reset index in list of ranges
    b scan_ranges_loop

push_range:
    // push new range to fresh_ranges
    mov x0, x23
    mov x1, x21
    mov x2, x22
    bl list_push

    // if we got here after reaching the end of the list, read next line in input
    cbnz w24, scan_lines_loop

scan_ranges_loop_next:
    add w26, w26, 1             // increment index in list
    b scan_ranges_loop

count_total:
    ldr x9, [x23]               // address of current range
    ldr w10, [x23, 12]          // list length
    mov x11, 0                  // current index
    mov x0, 0                   // answer
count_total_loop:
    cmp w11, w10
    beq print_answer            // print answer when end of list reached
    ldp x13, x12, [x9], 16      // load range from list
    sub x13, x12, x13           // x13 = range_top - range_bottom
    add x13, x13, 1             // x13--
    add x0, x0, x13             // answer += x13
    add x11, x11, 1             // index++
    b count_total_loop
print_answer:
    bl print_intln

    mov x0, x23
    bl list_free

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
