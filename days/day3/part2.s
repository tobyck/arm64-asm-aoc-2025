.const
MEM_STATS: .byte 1
no_input_msg: .asciz "Input file must be passed as an argument\n"

.data
max_joltage: .zero 13                   // 12 batteries (as chars) + null byte

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

    mov x9, 0                           // x9 = total joltage (answer)

    adrp x10, max_joltage@PAGE
    add x10, x10, max_joltage@PAGEOFF

    mov x12, x0                         // x12 = address of current char
line_length_counter_loop:
    ldrb w13, [x12], 1
    cmp w13, '\n'
    bne line_length_counter_loop        // loop until \n
    sub x13, x12, x0                    // w13 = length of each line (incl \n)

    mov x12, x0                         // x12 = address of current char

line_loop:
    sub w14, w13, 1                     // w14 = number of digits remaining to the right

next_char_in_line:
    ldrb w15, [x12], 1                  // w15 = char in line
    cbz w15, print_answer
    cmp w15, '\n'
    beq next_line
    sub w14, w14, 1                     // dec. num. of rem. digits to right

    mov w17, 0
check_joltages_loop:
    cmp w17, 11                         // end loop when at index 11
    bgt next_char_in_line
    ldrb w18, [x10, x17]                // char in current max joltage
    cmp w15, w18                        // compare current char in line with ^
    bgt try_insert_joltage              // insert into max if greater than existing
    add w17, w17, 1                     // otherwise go to next digit in max and test that
    b check_joltages_loop
try_insert_joltage:
    mov w20, 11
    sub w21, w20, w17                   // w21 = min digits remaining
    cmp w14, w21                        // if not enough digits remaining in line
    cinc w17, w17, lt                   // try next digit in max
    blt check_joltages_loop
    strb w15, [x10, x17]                // if there are enough remaining, store it in max
clear_next_joltages_loop:               // clear all digits in max past the one just inserted
    add w17, w17, 1
    cmp w17, 11
    bgt next_char_in_line               // go to next char once rest of digits are zeroed
    strb wzr, [x10, x17]                // store 0 in current char
    b clear_next_joltages_loop          // repeat until end of max joltage string

next_line:
    mov x0, x10                         // x0 = max joltage for line as string
    bl str_to_int                       // x0 = max joltage as int
    add x9, x9, x0                      // add to total
    mov x11, 0                          // x11 = counter for iterating max jolt. string
clear_max_joltage_loop:
    strb wzr, [x10, x11]                // store 0 in current char
    add x11, x11, 1                     // inc. offset for next iter.
    cmp x11, 12                         // break loop and go to next line once all zeroed
    blt clear_max_joltage_loop
    b line_loop

print_answer:
    mov x0, x9
    bl print_intln

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
