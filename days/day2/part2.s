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
	mov x25, 0							// x23 = answer

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
	mov x23, x0
	mov x24, x1
	add x13, x0, x1						// x13 = address of null byte
	mov x9, 1							// x9 will store current divisor

next_divisor:
	add x9, x9, 1						// add 1 to divisor
	cmp x9, x24
	bgt next_in_range					// go to next in range if divisor > length
	udiv x10, x24, x9					// x10 = length / divisor (section length)
	msub x11, x10, x9, x24				// x11 = remainder
	cbnz x11, next_divisor				// skip if not divisible

	mov x11, x23						// x11 = address of first string
	add x12, x23, x10					// x12 = address of second string
next_cmp:
	cmp x12, x13						// add to total if all sections checked
	bge add_to_total
	mov x0, x11
	mov x1, x12
	mov x2, x10							// x2 = length of section
	bl str_n_cmp
	cbnz x0, next_divisor				// go to next divisor if not equal
	add x12, x12, x10					// otherwise check next section
	b next_cmp

add_to_total:
	add x25, x25, x21
	b next_in_range

print_answer:
	mov x0, x25
	bl print_intln

	// free input buffer
	mov x0, x19
	bl mem_free

	b exit_success
