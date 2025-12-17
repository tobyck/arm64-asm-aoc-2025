.set MAX_INT_AS_STR_LEN, 21

.data
int_as_str: .space MAX_INT_AS_STR_LEN

.text
.global int_to_str, int_as_str, print_int, print_intln

// args:
// 	x0 = address of buffer
//	x1 = size of buffer
// 	x2 = int
// returns:
// 	x0 = address of buffer
//	x1 = string length (excl. null byte)
// internal:
//	x3 = address to write next char to
//	x4 = flag for if number is negative (1 if neg)
//  x5 = see comments, used for a few things
// 	x6 = 10
int_to_str:
	// x3 = x0 + x1 (address of byte immediately after buffer)
	mov x3, x0					// x3 = x0
	add x3, x3, x1				// x3 += x1

	// store null byte at the end but move x3 down by 1 first
	strb wzr, [x3, -1]!

	mov x7, x3

	// by default flag that number is non-negative
	mov x4, 0

	// skip to normal logic for non-negative numbers
	cmp	x2,	0
	bge .Lint_to_str_loop

	// we end up here for negative numbers
	mov x4, 1 					// flag that the number is negative
	neg x2, x2  				// negate it before we proceed with the normal logic
.Lint_to_str_loop:
	mov x5, x2 					// remember what x2 was in x5
	mov x6, 10
	udiv x2, x2, x6 			// x2 /= 10
	msub x5, x2, x6, x5 		// remainder (in x5) = old x2 - quotient * 10
	add x5, x5, '0' 			// turn digit into its ascii code
	strb w5, [x3, -1]!			// decrement address and store char in buffer
	cbnz x2, .Lint_to_str_loop	// continue until quotient = 0

	// skip to normal end stage if number wasn't negative
	cmp x4, 1
	bne .Lint_to_str_end

	// otherwise store a '-' before the number in the buffer
	mov w5, '-'
	strb w5, [x3, -1]!
.Lint_to_str_end:
	mov x0, x3 					// x0 = address of first char in string
	sub x1, x7, x3				// x1 = addr of end - addr of start
	ret

// args:
//	x0 = the int
print_int:
	stp fp, lr, [sp, -16]!
	mov fp, sp

	mov x2, x0
	adrp x0, int_as_str@PAGE
	add x0, x0, int_as_str@PAGEOFF
	mov x1, MAX_INT_AS_STR_LEN
	bl int_to_str
	bl print_str

	ldp fp, lr, [sp], 16
	ret

print_intln:
	stp fp, lr, [sp, -16]!
	mov fp, sp

	bl print_int
	bl print_br

	ldp fp, lr, [sp], 16
	ret
