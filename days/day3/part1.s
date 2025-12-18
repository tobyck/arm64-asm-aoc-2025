.const
MEM_STATS: .byte 1
no_input_msg: .asciz "Input file must be passed as an argument\n"

.text
.global _start, MEM_STATS

_start:
	cmp x0, 2							// check filename is provided (x0 = argc)
	bge load_input
	adrp x0, no_input_msg@PAGE
	add x0, x0, no_input_msg@PAGEOFF
	bl print_str
	b exit_failure
load_input:
	ldr x0, [x1, 8]						// x0 = argv[1] (x1 = argv)
	bl load_file						// x0 now points to buffer
	mov x19, x0							// preserve pointer to input buffer

	mov w9, 0 							// x9 = total (answer)
	mov x10, x0 						// x11 = first digit address
next_line:
	mov w11, 0 							// x10 = max on line
next_first_digit:
	ldrb w12, [x10], 1 					// w12 = digit 1 as char
	cmp w12, '\n'
	add w13, w9, w11					// w13 = what x9 would be if add max
	csel w9, w13, w9, eq				// add max on line to total if \n found
	beq next_line
	cbz w12, print_answer				// print answer when null byte reached
	sub w12, w12, '0' 					// w12 = digit 1
	mov w13, 10
	mul w12, w12, w13 					// w12 *= 10
	mov x13, x10						// x13 = address of digit 2
next_second_digit:
	ldrb w14, [x13], 1					// w14 = digit 1 as char
	cmp w14, '\n'
	beq next_first_digit				// move to next line when newline found
	sub w14, w14, '0'					// w14 = digit 1
	add w15, w12, w14					// w12 = possible number
	cmp w15, w11
	csel w11, w15, w11, gt				// update w11 if w12 is bigger than prev. max
	b next_second_digit

print_answer:
	mov x0, x9
	bl print_intln

	// free input buffer
	mov x0, x19
	bl mem_free

	b exit_success
