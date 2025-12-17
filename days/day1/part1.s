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
	mov x24, x22						// x24 = address of int start
find_int_end_loop:
	ldrb w25, [x22], 1					// w25 = char
	cmp w25, '\n'
	bne find_int_end_loop				// loop until newline found
	strb wzr, [x22, -1]					// replace new line with null byte
	mov x0, x24							// x0 = address of now null terminated str
	bl str_to_int						// x0 is now the int
	cmp w23, 'L'
	neg x9, x0
	csel x0, x9, x0, eq					// negate int if turning left
	add w20, w20, w0					// add to position
	mov w9, 100
	sdiv w10, w20, w9					// w10 = position / 100
	msub w20, w10, w9, w20				// position = remainder (could be negative)
	cmp w20, 0
	bge positive_remainder
	add w20, w20, w9					// add 100 if remainder is negative
positive_remainder:
	cbnz w20, line_loop					// repeat early if position not 0
	add w21, w21, 1						// otherwise increment counter
	b line_loop
	
print_answer:
	mov x0, x21
	bl print_intln

	// free input buffer
	mov x0, x19
	bl mem_free

	b exit_success
