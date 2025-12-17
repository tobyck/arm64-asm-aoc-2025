.const
MEM_STATS: .byte 1

.text
.global _start, MEM_STATS

_start:
	mov x0, 40
	bl aoc_malloc
	mov x19, x0

	mov x0, 40
	bl aoc_malloc
	mov x20, x0

	mov x0, 40
	bl aoc_malloc
	mov x21, x0

	// free first two blocks
	mov x0, x19
	bl aoc_free
	mov x0, x20
	bl aoc_free

	// should use the first space in the same region
	mov x0, 8
	bl aoc_malloc
	
	mov x1, 50
	bl aoc_realloc

	bl aoc_free

	mov x0, x21
	bl aoc_free

	b exit_success
