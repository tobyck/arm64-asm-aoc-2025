.const
mem_stats_sep: .asciz "====================\n"
bytes_allocated_msg: .asciz " bytes allocated\n"
bytes_freed_msg: .asciz " bytes freed\n"
bytes_leaked_msg: .asciz " bytes leaked\n"

.text
.global exit_success, exit_failure

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

