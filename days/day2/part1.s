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

	mov x20, x0 						// x20 = current address
	mov x23, 0							// x23 = answer

next_range:
	ldrb w9, [x20]
	cbz w9, print_answer				// print answer when null byte found
	mov x0, x20
	bl str_to_int
	mov x21, x0							// x21 = start of range		
	add x20, x20, x1
	add x20, x20, 1						// advance pointer to next int
	mov x0, x20
	bl str_to_int
	mov x22, x0							// x22 = end of range
	add x20, x20, x1
	add x20, x20, 1						// advance pointer to next int

	sub x21, x21, 1						// start at num. before so it can be inc'd in the loop
next_in_range:
	add x21, x21, 1
	cmp x21, x22
	bgt next_range						// go to next range if end if at end of this range
	adrp x0, int_as_str@PAGE
	add x0, x0, int_as_str@PAGEOFF
	mov x1, 21
	mov x2, x21
	bl int_to_str						// x0 = str, x1 = length
	tbnz x1, 0, next_in_range			// skip if length is odd
	mov x9, 2
	udiv x10, x1, x9					// w10 = length / 2
	add x10, x10, x0					// x10 = addr of last char in 1st half
	add x1, x1, x0						// x1 = addr of last char in 2nd half
next_char:
	ldrb w11, [x10, -1]!				// w11 = char in first half
	ldrb w12, [x1, -1]!					// w12 = char in second half
	cmp w11, w12
	bne next_in_range					// go to next number if chars don't match
	cmp x10, x0
	bne next_char						// if does match, go to next pair of chars if not at start yet
										// by this point an invalid product id has been found
	add x23, x23, x21					// add to total
	b next_in_range

print_answer:
	mov x0, x23
	bl print_intln

	// free input buffer
	mov x0, x19
	bl mem_free

	b exit_success
