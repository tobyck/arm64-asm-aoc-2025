.const
mem_stats_sep: .asciz "====================\n"
bytes_allocated_msg: .asciz " bytes allocated\n"
bytes_freed_msg: .asciz " bytes freed\n"
bytes_leaked_msg: .asciz " bytes leaked\n"
list_push_reg_invalid_size: .asciz "list_push_reg: List has wrong element size. Must be 1, 2, 4, or 8.\n"

adj_offsets:
    .byte -1, -1
    .byte  0, -1
    .byte  1, -1
    .byte -1,  0
    .byte  1,  0
    .byte -1,  1
    .byte  0,  1
    .byte  1,  1

.set LIST_INIT_CAP, 8

.text
.global list_init, list_ensure_capacity, list_push_reg, list_clear, list_free
.global get_all_adj_chars
.global load_file
.global exit_success, exit_failure
.global break

// list struct:
//  u64 pointer to data (offset = 0)
//  u32 element size    (offset = 8)
//  u32 list length     (offset = 12)
//  u32 list capacity   (offset = 16)
//  4 bytes padding
//  = 24 bytes total

// args:
//  x0 = address to write struct
//  w1 = element size
// returns x0
list_init:
    stp fp, lr, [sp, -16]!
    stp x19, xzr, [sp, -16]!

    // align to 1, 2, 4, or 8 bytes
    cmp w1, 3
    blt .Llist_init_skip_align
    mov w9, 3
    mov w10, 7
    cmp w1, 4
    csel w9, w9, w10, le
    add w1, w1, w9
    bic w1, w1, w9
.Llist_init_skip_align:

    mov w9, LIST_INIT_CAP

    str w1, [x0, 8]         // store element size in struct
    str wzr, [x0, 12]       // store length = 0
    str w9, [x0, 16]        // store capacity = LIST_INIT_CAP

    mov x19, x0             // preserve struct pointer
    mul w0, w1, w9          // w0 = LIST_INIT_CAP * element size
    bl mem_alloc

    str x0, [x19]           // store data pointer in struct
    mov x0, x19             // return struct pointer

    ldr x19, [sp], 16
    ldp fp, lr, [sp], 16
    ret

// args:
//  x0 = address of list struct
//  w1 = capacity
list_ensure_capacity:
    ldr w11, [x0, 16]       // w11 = capacity

    cmp w1, w11             // return early if already enough capacity
    ble .Llist_ensure_capacity_return

    stp fp, lr, [sp, -16]!
    stp x19, x20, [sp, -16]!

    ldr w10, [x0, 8]        // w10 = element size

    str w1, [x0, 16]        // store new capacity
    mul w1, w1, w10         // w1 = new size of memory allocation
    mov x19, x0
    ldr x0, [x0]

    bl mem_realloc          // x0 = (potentially) new pointer

    str x0, [x19]           // store new pointer

    ldp x19, x20, [sp], 16
    ldp fp, lr, [sp], 16
.Llist_ensure_capacity_return:
    ret
    

// args:
//  x0 = address of list struct
//  x1 = register to write
list_push_reg:
    stp fp, lr, [sp, -16]!
    sub sp, sp, 48
    stp x19, x20, [sp]
    stp x21, x22, [sp, 16]
    stp x23, x24, [sp, 32]

    ldr w20, [x0, 8]        // w20 = element size
    ldr w21, [x0, 12]       // w21 = length

    // preserve args
    mov x24, x0
    mov x23, x1

    add w22, w21, 1         // ensure capacity of length + 1
    mov w1, w22
    bl list_ensure_capacity

    ldr x19, [x24]          // x19 = data pointer

    madd x13, x20, x21, x19 // x13 = addr. to write to (element size * length + base ptr)

    cmp w20, 1
    beq .Llist_push_reg_strb
    cmp w20, 2
    beq .Llist_push_reg_strh
    cmp w20, 4
    beq .Llist_push_reg_strw
    cmp w20, 8
    bne .Llist_push_reg_invalid_size
    b .Llist_push_reg_strx

.Llist_push_reg_strb:
    strb w23, [x13]
    b .List_push_reg_end
.Llist_push_reg_strh:
    strh w23, [x13]
    b .List_push_reg_end
.Llist_push_reg_strw:
    str w23, [x13]
    b .List_push_reg_end
.Llist_push_reg_strx:
    str x23, [x13]

.List_push_reg_end:
    str w22, [x24, 12]

    ldp x19, x20, [sp]
    ldp x21, x22, [sp, 16]
    ldp x23, x24, [sp, 32]
    add sp, sp, 48
    ldp fp, lr, [sp], 16
    ret

.Llist_push_reg_invalid_size:
    adrp x0, list_push_reg_invalid_size@PAGE
    add x0, x0, list_push_reg_invalid_size@PAGEOFF
    bl print_str
    b exit_failure

// takes x0: pointer to list struct
list_clear:
    stp fp, lr, [sp, -16]!
    stp x19, x20, [sp, -16]!

    str wzr, [x0, 12]       // zero length
    mov w9, LIST_INIT_CAP
    str w9, [x0, 16]        // reset capacity

    mov x19, x0             // preserve struct pointer
    ldr x0, [x0]            // x0 = pointer to data
    ldr w1, [x19, 8]        // w1 = element size
    mul w1, w1, w9          // x1 = size of allocation
    bl mem_realloc
    str x0, [x19]           // store new pointer in struct
    
    ldp x19, x20, [sp], 16
    ldp fp, lr, [sp], 16
    ret

// arg: x0 = list struct
// returns: nothing
list_free:
    stp fp, lr, [sp, -16]!

    ldr x0, [x0]
    bl mem_free

    ldp fp, lr, [sp], 16
    ret

// args:
//  x0 = pointer to grid
//  w1 = width of grid (excl. newline)
//  w2 = height
//  w3 = x coordinate
//  w4 = y coordinate
//  x5 = pointer to where to write adj items
// returns:
//  x0 = x5
//  x1 = number of adjacent chars
get_all_adj_chars:
    mov x6, 8
    add w7, w1, 1               // width incl. newline
    adrp x9, adj_offsets@PAGE
    add x9, x9, adj_offsets@PAGEOFF
    mov x12, x5

.Lgaac_loop:
    cbz w6, .Lgaac_return
    sub w6, w6, 1

    ldrsb w10, [x9], 1          // x offset
    ldrsb w11, [x9], 1          // y ^
    add w10, w3, w10            // x coord of adj. char
    add w11, w4, w11            // y ^
    
    // check in bounds
    cmp w10, 0
    blt .Lgaac_loop
    cmp w10, w1
    bge .Lgaac_loop
    cmp w11, 0
    blt .Lgaac_loop
    cmp w11, w2
    bge .Lgaac_loop

    madd w10, w11, w7, w10      // offset into grid string
    ldrb w10, [x0, x10]         // adj. char
    strb w10, [x5], 1           // store in output

    b .Lgaac_loop
.Lgaac_return:
    strb wzr, [x5]              // store null byte
    mov x0, x12                 // return buffer holding adj chars
    sub x1, x5, x12             // return number of adj. chars
    ret

// args:
//  x0 = filename
//  x1 = length of file
// returns x0: pointer to buffer
load_file:
    stp fp, lr, [sp, -16]!
    stp x19, x20, [sp, -16]!
    str x21, [sp, -16]!
    sub sp, sp, 144     // space for stat struct
                        // x0 (filename) already set by caller
    mov x1, 0           // read only
    mov x16, 5          // syscall = open
    svc 0

    mov x19, x0         // preserve fd
                        // x0 (fd) already set by above syscall
    mov x1, sp          // x1 = address of stat struct
    mov x16, 189        // syscall = fstat
    svc 0

    ldr x0, [sp, 72]    // x0 = file size
    mov x21, x0         // preserve for return value
    add x0, x0, 1       // +1 for null byte
    mov x20, x0         // preserve for later read syscall
    bl mem_alloc

    mov x2, x20         // x2 = number of bytes to read
    mov x1, x0          // x1 = pointer to buffer
    mov x20, x0         // also preserve for return value
    mov x0, x19         // x0 = fd
    mov x16, 3          // syscall = read
    svc 0

    strb wzr, [x20, x0] // store null byte

    mov x0, x19         // x0 = fd
    mov x16, 6          // syscall = close
    svc 0

    // set return values
    mov x0, x20
    mov x1, x21

    add sp, sp, 144
    ldr x21, [sp], 16
    ldp x19, x20, [sp], 16
    ldp fp, lr, [sp], 16
    ret

exit:
    adrp x1, MEM_STATS@PAGE
    add x1, x1, MEM_STATS@PAGEOFF
    ldr w1, [x1]
    cbz w1, .Lexit_syscall

    mov x19, x0

    adrp x0, mem_stats_sep@PAGE
    add x0, x0, mem_stats_sep@PAGEOFF
    bl print_str

    adrp x0, bytes_allocated@PAGE
    add x0, x0, bytes_allocated@PAGEOFF
    ldr x0, [x0]
    mov x20, x0
    bl print_int

    adrp x0, bytes_allocated_msg@PAGE
    add x0, x0, bytes_allocated_msg@PAGEOFF
    bl print_str

    adrp x0, bytes_freed@PAGE
    add x0, x0, bytes_freed@PAGEOFF
    ldr x0, [x0]
    mov x21, x0
    bl print_int

    adrp x0, bytes_freed_msg@PAGE
    add x0, x0, bytes_freed_msg@PAGEOFF
    bl print_str

    sub x0, x20, x21
    bl print_int

    adrp x0, bytes_leaked_msg@PAGE
    add x0, x0, bytes_leaked_msg@PAGEOFF
    bl print_str

    mov x0, x19
.Lexit_syscall:
    mov x16, 1
    svc 0

exit_success:
    mov x0, 0
    b exit

exit_failure:
    mov x0, 1       // status code = 0
    b exit

break:
    ret
