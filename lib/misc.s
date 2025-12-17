.const
mem_stats_sep: .asciz "====================\n"
bytes_allocated_msg: .asciz " bytes allocated\n"
bytes_freed_msg: .asciz " bytes freed\n"
bytes_leaked_msg: .asciz " bytes leaked\n"

.text
.global load_file, exit_success, exit_failure

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
