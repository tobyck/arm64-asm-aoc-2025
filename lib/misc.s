.const
mem_stats_sep: .asciz "====================\n"
bytes_allocated_msg: .asciz " bytes allocated\n"
bytes_freed_msg: .asciz " bytes freed\n"
bytes_leaked_msg: .asciz " bytes leaked\n"

adj_offsets:
    .byte -1, -1
	.byte  0, -1
	.byte  1, -1
	.byte -1,  0
	.byte  1,  0
	.byte -1,  1
	.byte  0,  1
	.byte  1,  1

.text
.global get_all_adj_chars, load_file, exit_success, exit_failure

// args:
//	x0 = pointer to grid
//	w1 = width of grid (excl. newline)
//	w2 = height
//	w3 = x coordinate
//	w4 = y coordinate
//	x5 = pointer to where to write adj items
// returns:
//	x0 = x5
//	x1 = number of adjacent chars
get_all_adj_chars:
	mov x6, 8
	add w7, w1, 1				// width incl. newline
	adrp x9, adj_offsets@PAGE
	add x9, x9, adj_offsets@PAGEOFF
	mov x12, x5

.Lgaac_loop:
	cbz w6, .Lgaac_return
	sub w6, w6, 1

	ldrsb w10, [x9], 1			// x offset
	ldrsb w11, [x9], 1			// y ^
	add w10, w3, w10			// x coord of adj. char
	add w11, w4, w11			// y ^
	
	// check in bounds
	cmp w10, 0
	blt .Lgaac_loop
	cmp w10, w1
	bge .Lgaac_loop
	cmp w11, 0
	blt .Lgaac_loop
	cmp w11, w2
	bge .Lgaac_loop

	madd w10, w11, w7, w10		// offset into grid string
	ldrb w10, [x0, x10]			// adj. char
	strb w10, [x5], 1			// store in output

	b .Lgaac_loop
.Lgaac_return:
	strb wzr, [x5]				// store null byte
	mov x0, x12					// return buffer holding adj chars
	sub x1, x5, x12				// return number of adj. chars
	ret

// arg: x0 = filename
// returns x0: pointer to buffer
load_file:
	stp fp, lr, [sp, -16]!
	mov fp, sp
	stp x19, x20, [sp, -16]!
	sub sp, sp, 144		// space for stat struct
						// x0 (filename) already set by caller
	mov x1, 0 			// read only
	mov x16, 5 			// syscall = open
	svc 0

	mov x19, x0 		// preserve fd
						// x0 (fd) already set by above syscall
	mov x1, sp	 		// x1 = address of stat struct
	mov x16, 189 		// syscall = fstat
	svc 0

	ldr x0, [sp, 72]	// x0 = file size
	add x0, x0, 1		// +1 for null byte
	mov x20, x0			// preserve for later read syscall
	bl mem_alloc

	mov x2, x20			// x2 = number of bytes to read
	mov x1, x0			// x1 = pointer to buffer
	mov x20, x0			// also preserve for return value
	mov x0, x19			// x0 = fd
	mov x16, 3			// syscall = read
	svc 0

	strb wzr, [x20, x0]	// store null byte

	mov x0, x19			// x0 = fd
	mov x16, 6			// syscall = close
	svc 0

	mov x0, x20			// return value = pointer to buffer

	add sp, sp, 144
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
	mov x0, 1		// status code = 0
	b exit
