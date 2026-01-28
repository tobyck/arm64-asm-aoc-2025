.set LIST_INIT_CAP, 8

.text
.global list_init, list_ensure_capacity, list_push, list_clear, list_free

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
//
//	This function has 3 overloads which are selected based on element size:
//	1. x1 = register to push
//	2. x1 = first register to push
//	   x2 = second register to push
//	3. x1 = address of memory to push
//	   x2 = number of bytes to push
list_push:
    stp fp, lr, [sp, -16]!
    sub sp, sp, 64
    stp x19, x20, [sp]
    stp x21, x22, [sp, 16]
    stp x23, x24, [sp, 32]
	str x25, [sp, 48]

    ldr w20, [x0, 8]        // w20 = element size
    ldr w21, [x0, 12]       // w21 = length

    // preserve args
    mov x23, x0
    mov x24, x1
	mov x25, x2

    add w22, w21, 1         // ensure capacity of length + 1
    mov w1, w22
    bl list_ensure_capacity

    ldr x19, [x23]          // x19 = data pointer

    madd x13, x20, x21, x19 // x13 = addr. to write to (element size * length + base ptr)

    cmp w20, 1
    beq .Llist_push_reg_strb
    cmp w20, 2
    beq .Llist_push_reg_strh
    cmp w20, 4
    beq .Llist_push_reg_strw
    cmp w20, 8
    beq .Llist_push_reg_str
    cmp w20, 16
    beq .Llist_push_reg_stp
	b .Llist_push_from_addr

.Llist_push_reg_strb:
    strb w24, [x13]
    b .List_push_reg_end
.Llist_push_reg_strh:
    strh w24, [x13]
    b .List_push_reg_end
.Llist_push_reg_strw:
    str w24, [x13]
    b .List_push_reg_end
.Llist_push_reg_str:
    str x24, [x13]
    b .List_push_reg_end
.Llist_push_reg_stp:
	stp x24, x25, [x13]
    b .List_push_reg_end
.Llist_push_from_addr:
	mov x0, x13
	mov x1, x24
	mov x2, x25
	bl mem_copy

.List_push_reg_end:
    str w22, [x23, 12]

    ldp x19, x20, [sp]
    ldp x21, x22, [sp, 16]
    ldp x23, x24, [sp, 32]
	ldr x25, [sp, 48]
    add sp, sp, 64
    ldp fp, lr, [sp], 16
    ret

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
