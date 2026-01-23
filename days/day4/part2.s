.const
MEM_STATS: .byte 1
no_input_msg: .asciz "Input file must be passed as an argument\n"

.data
adj_chars: .space 9 // 8 + null byte
coords_to_remove: .space 24

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

	mov w26, 0 							// w26 = final answer

	mov w1, '\n'
	bl index_of
	mov w23, w0							// w23 = width of grid
	add w24, w23, 1						// w24 = width incl. newline

	adrp x0, coords_to_remove@PAGE
	add x0, x0, coords_to_remove@PAGEOFF
	mov w1, 2
	bl list_init
	mov x25, x0
	
next_iteration:
	mov w20, 0							// w20 = answer for iteration
	mov w21, 0							// w21 = current x coord
	mov w22, 0							// w22 = current y coord

check_coord:
	madd w9, w24, w22, w21				// w9 = offset of cur. char in buffer
	add x9, x9, x19						// x9 = addr. of current char
	ldrb w9, [x9]						// w9 = current char
	cmp w9, '@'
	bne next_column						// skip if not at a roll of paper

	// get list of adj. chars in x0
	mov x0, x19
	mov w1, w23
	mov w2, w23
	mov w3, w21
	mov w4, w22
	adrp x5, adj_chars@PAGE
	add x5, x5, adj_chars@PAGEOFF
	bl get_all_adj_chars

	mov w9, 0							// w9 will count how many @'s are adjacent
count_paper_rolls_loop:
	ldrb w10, [x0], 1					// w10 = adjacent char
	cbz w10, next_column				// end loop when null byte reached
	cmp w10, '@'
	cinc w9, w9, eq						// increment counter
	b count_paper_rolls_loop

next_column:
	cmp w9, 4
	bge not_reachable
	add w20, w20, 1
	mov x0, x25							// x0 = list of coords to remove later
	orr w1, w22, w21, lsl 8				// w1 = x and y cooord
	bl list_push_reg
not_reachable:
	add w21, w21, 1						// increment x coord
	cmp w21, w23
	blt check_coord						// check next coord if still in bounds

next_row:
	mov w21, 0							// reset x coord
	add w22, w22, 1						// increment y coord
	cmp w22, w23
	blt check_coord						// check next coord if still in bounds

	cmp w20, 0
	beq print_answer

	add w26, w26, w20

	ldr x9, [x25]						// x9 = addr. of data
	ldr w10, [x25, 12]					// w10 = list length
	mov w11, 0							// loop counter

clear_reachable_loop:
	lsl w12, w11, 1						// w12 = offset of coords
	add x12, x12, x9					// x12 = addr. of coords
	ldrsb w13, [x12], 1
	ldrsb w14, [x12]
	madd w13, w13, w24, w14				// w13 = offset of char in input
	add x13, x13, x19					// x13 = address of char
	mov w14, '.'
	strb w14, [x13]						// store '.' where roll of paper was
	add w11, w11, 1
	cmp w11, w10
	blt clear_reachable_loop

	mov x0, x25
	bl list_clear

	b next_iteration

print_answer:
	mov w0, w26
	bl print_intln

	// free input buffer
	mov x0, x19
	bl mem_free

	b exit_success
