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

	mov w20, 50							// w20 = dial position
	mov w21, 0							// w21 = answer
	mov x22, x0							// x22 = address to read next char from

line_loop:
	ldrb w23, [x22], 1					// w23 = L or R
	cbz w23, print_answer				// print answer when null byte reached
	mov x0, x22							// x0 = address of int start
	bl str_to_int						// x0 is now the int
	add x22, x22, x1					// x22 += number of chars read for int
	cmp w23, 'L'
	mov w9, 1
	mov w10, -1
	csel w11, w10, w9, eq				// x11 = -1 if x0 < 0 else 1
increment_loop:
	add w20, w20, w11					// increment/decrement position
	sub x0, x0, 1						// decrement loop counter
	mov w9, 100
	sdiv w10, w20, w9					// w10 = position / 100
	msub w20, w10, w9, w20				// position = remainder (could be negative)
	cmp w20, 0
	bge positive_remainder
	add w20, w20, w9					// add 100 if remainder is negative
positive_remainder:
	cmp w20, 0
	cinc w21, w21, eq					// if (position == 0) answer++
	cbz x0, line_loop					// go to next line if we've effectively done the full rot.
	b increment_loop					// otherwise continue incrementing/decrementing
	
print_answer:
	mov x0, x21
	bl print_intln

	// free input buffer
	mov x0, x19
	bl mem_free

	b exit_success
