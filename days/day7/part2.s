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
    ldr x0, [x1, 8]             // x0 = argv[1] (x1 = argv)
    bl load_file                // x0 now points to buffer
    mov x19, x0                 // preserve pointer to input buffer

    mov x20, x19                // address to read next char from
    add x23, x19, x1            // address to stop at
                                
    mov w1, '\n'                
    bl index_of                 
    add w21, w0, 1              // stride to read next/prev row
                                
    lsl x0, x0, 3               // x0 *= 8
    mov x27, x0
    bl mem_alloc                // will store how many ways a beam can be reached
    mov x25, x0                 // pointer to list
    add x27, x0, x27            // address past end of list
                                
    mov w24, '|'                // const
                                
    mov w26, 0                  // x coord
                                
loop:                           
    cmp x20, x23                // print answer at eof
    bge count_total            
    ldrb w9, [x20]              // load char
    cmp w9, '\n'                
    mov w10, -1
    csel w26, w10, w26, eq      // reset x coord when \n reached
    cmp w9, 'S'                 
    beq found_s                 // mark first | below S
    sub x10, x20, x21           // x10 = current_addr - stride
    ldrb w11, [x10]             // w11 = char above current one
    cmp w9, '^'                 
    beq split                   // split if current char is '^'
    cmp w11, '|'                // if not '|' or '^' then loop
    bne loop_next               
    strb w24, [x20]             // continue straight tachyon beams down
    b loop_next                 
                                
found_s:                        
    strb w24, [x20, x21]        // *(current_addr + stride) = '|'
    mov w9, 1                   
    str x9, [x25, x26, lsl 3]   // store that starting beam can be reached in 1 way
    b loop_next                 
                                
split:                          
    cmp w11, '|'                // if no '|' above then nothing's being split
    bne loop_next               

    ldr x9, [x25, x26, lsl 3]   // current timeline count

    sub w10, w26, 1             // w10 = x_coord - 1
    ldr x11, [x25, x10, lsl 3]  // current count to left
    add x11, x11, x9            // add current timeline count
    str x11, [x25, x10, lsl 3]  // update it in list

    add w10, w26, 1             // ditto with right side
    ldr x11, [x25, x10, lsl 3]
    add x11, x11, x9
    str x11, [x25, x10, lsl 3]

    str xzr, [x25, x26, lsl 3]  // set timeline count for old beam to 0

    strb w24, [x20, -1]         // store '|' to left
    strb w24, [x20, 1]          // ditto to right

loop_next:                      
    add x20, x20, 1             // advance address to read next char from
    add w26, w26, 1             // advance x coord
    b loop

count_total:
    mov x9, 0                   // total
    mov x10, x25                // current address to read timeline count from

count_total_loop:
    ldr x11, [x10], 8           // read timeline count
    add x9, x9, x11             // add to total
    cmp x10, x27
    blt count_total_loop        // keep looping until whole list has been read

    // print sum
    mov x0, x9
    bl print_intln

    // free list of timeline counts
    mov x0, x25
    bl mem_free

    // free input buffer
    mov x0, x19
    bl mem_free

    b exit_success
