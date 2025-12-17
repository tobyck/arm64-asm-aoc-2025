// probs overcomplicated this for aoc but oh well i've learnt a lot
//
// key points about this allocator:
//	- mmap/munmap only, no brk
//	- mappings have a header
//	- blocks have boundry tags
//	- forward and backward coalescing of free blocks
//
// layout details:
// 	region = a contiguous span of pages mapped by mmap:
//		[header][block][block][block]...
//		- header:
//			- size (8 bytes)
//			- pointer to next region (8 bytes)
// 	block = a single allocation made by a call to mem_alloc:
//		[header][user payload][footer]
//		- header:
//			- size (8 bytes - 1 bit)
//			- "is block free" flag (1 bit)
//			- base address of mapping (8 bytes)

.set MIN_BLOCK_SIZE, 32
.set BLOCK_HEADER_SIZE, 16
.set BLOCK_FOOTER_SIZE, 8

.const
block_overflow_msg: .asciz "Allocator error: block overflows region.\n"
mmap_error_msg:	.asciz "Allocator error: mmap failed.\n"
munmap_error_msg: .asciz "Allocator error: munmap failed.\n"

.data
head_region: .zero 8 // pointer to first region
bytes_allocated: .quad 0
bytes_freed: .quad 0

.text
.global mem_copy, mem_alloc, mem_realloc, mem_free, bytes_allocated, bytes_freed

// args:
//	x0 = dest ptr
// 	x1 = src ptr
//	x2 = length
// returns:
//	x0 = dest ptr
mem_copy:
	mov x3, x0
	add x4, x1, x2					// x5 = address for x3 to stop at
.Lmem_copy_loop:
	ldr q0, [x1], 128
	str q0, [x3], 128			
	cmp x1, x4
	blt .Lmem_copy_loop
	ret

// args:
//	x0 = (optional) address to re-allocate
//	x1 = number of bytes to allocate
// returns:
//	x0 = allocated pointer (or 0 if x1 = 0)
// will error and exit on failure
mem_alloc_internal:
	// return null if requested bytes = 0
	cbnz x1, .Lmem_alloc_arg_ok
	mov x1, 0
	ret
.Lmem_alloc_arg_ok:
	stp fp, lr, [sp, -16]!
	mov fp, sp

	// x10 = required block size
	add x10, x1, 39					// 16 for header + 8 for footer + 15 for padding
	bic x10, x10, 15

	mov x14, x0						// preserve x0

	// if no regions mapped yet, make a new mapping
	adrp x11, head_region@PAGE
	add x11, x11, head_region@PAGEOFF
	ldr x12, [x11]					// x12 = addr of head region
	cbz x12, .Lmem_alloc_new_mapping

	mov x1, x12						// x1 will store ptr to current region
.Lmem_alloc_search_regions_loop:
	ldr x2, [x1]					// x2 = size of region
	ldr x3, [x1, 8]					// x3 = ptr to next region
	sub x4, x2, 16 					// x4 = usable size of region (header is 16 bytes)
	cmp x10, x4 					// cmp requested size w/ usable size in this region
	bgt .Lmem_alloc_next_region

	add x15, x1, 16					// x4 = addr of current block
.Lmem_alloc_walk_blocks_loop:
	ldr x5, [x15]					// x5 = first half of block header
	lsr x6, x5, 1					// x6 = block size (lsr 1 to drop flag)
	tbnz x5, 0, .Lmem_alloc_next_block	// walk to next if block is allocated
	cmp x10, x6						// cmp req'd size w/ size of block
	bgt .Lmem_alloc_next_block			// skip if not req'd size is greater

	sub x7, x6, x10					// x7 = size of remaining free block
	cmp x7, MIN_BLOCK_SIZE
	blt .Lmem_alloc_only_set_free_flag	// if rem. size is < min. then block size stays the same

	lsl x7, x7, 1					// shift left for flag
	bic x7, x7, 1					// set x7 lsb low (x7 = 1st 1/2 of header of rem. free block)
	add x9, x15, x10				// address to write header to
	stp x7, x1, [x9]				// store header
	sub x9, x6, 8					// x9 = old footer offset from x15
	str x7, [x15, x9]				// store footer

	lsl x5, x10, 1					// insert block size in high bits of x5
	orr x5, x5, 1					// flag new block is now allocated
	stp x5, x1, [x15]				// store header
	sub x9, x10, BLOCK_FOOTER_SIZE	// x9 = new footer offset from x15
	b .Lmem_alloc_end

.Lmem_alloc_only_set_free_flag:
	orr x5, x5, 1					// change flag of existing header
	stp x5, x1, [x15]				// store header
	sub x9, x6, 8					// x9 = offset of footer from x15
	b .Lmem_alloc_end

.Lmem_alloc_next_block:
	add x15, x15, x6				// addr of current block += current block size
	add x7, x1, x2					// x7 = region addr + region size = end of region
	cmp x15, x7
	beq .Lmem_alloc_next_region		// go to next region if we've gone through all blocks
	bgt .Lallocator_block_overflow	// error if block goes beyond region boundry
	b .Lmem_alloc_walk_blocks_loop		// otherwise go to next block in the same region

.Lmem_alloc_next_region:
	cbz x3, .Lmem_alloc_new_mapping	// make new mapping if we've searched all regions
	mov x1, x3						// addr of current region = addr of next region
	b .Lmem_alloc_search_regions_loop

.Lallocator_block_overflow:
	adrp x0, block_overflow_msg@PAGE
	add x0, x0, block_overflow_msg@PAGEOFF
	bl print_str
	b exit_failure

.Lmem_alloc_new_mapping:
	mov x9, x1						// x9 = addr of current current tail region

	mov x0, 0						// addr = null
	add x1, x10, 16					// x1 = desired block size + 16 for region header
	add x1, x1, 4095
	bic x1, x1, 4095				// align to page size
	mov x13, x1						// save x1 for later (it gets zeroed by mmap)
	mov x2, 0b11					// prot flags = prot_read | prot_write
	mov x3, 0x1002					// mapping flags = map_anon | map_private
	mov x4, -1						// fd = -1 (i.e. not backed by file)
	mov x5, 0						// offset = 0 (n/a since fd = -1)
	mov x16, 197					// syscall = mmap
	svc 0

mem_alloc_mmap_return_breakpoint:		// I have a feeling this will come in handy...

	// error if small value is returned
	cmp x0, 4096
	bgt .Lmem_alloc_mmap_ok
	adrp x0, mmap_error_msg@PAGE
	add x0, x0, mmap_error_msg@PAGEOFF
	bl print_str
	b exit_failure
.Lmem_alloc_mmap_ok:
	cbz x12, .Lmem_alloc_update_head
.Lmem_alloc_update_tail:
	str x0, [x9, 8]					// store ptr to this region in header of tail region
	b .Lmem_alloc_mmap_continue
.Lmem_alloc_update_head:
	str x0, [x11]					// store region pointer in head_region
.Lmem_alloc_mmap_continue:

	mov x15, x0						// copy region base to x15
	stp x13, xzr, [x15], 16			// store region header for this region (and x15 = block start)

	// store boundry tags of remaining free block

	sub x1, x13, x10				// x1 = region size - block size
	sub x1, x1, 16					// x1 -= 16 to account for region header (x1 = rem. free space)
	lsl x1, x1, 1
	bic x1, x1, 1					// x1 = header of remaining free block

	add x2, x15, x10					// address to write block header
	stp x1, x5, [x2]				// store block header
	sub x3, x13, 8					// x3 = offset of footer from x0 (should be at the end of the mapping)
	str x2, [x0, x3]				// store block footer

	// store allocated block boundry tags

	lsl x5, x10, 1					// shift block size by 1 to make space for flag
	orr x5, x5, 1					// flag that block is allocated (x2 now = 1st 1/2 of header)
	stp x5, x0, [x15]				// store block header
	sub x9, x10, BLOCK_FOOTER_SIZE	// x9 = offset of block footer from x15

.Lmem_alloc_end:
	add x0, x15, BLOCK_HEADER_SIZE	// x0 = start of useable memory (return value)

	cbz x14, .Lmem_alloc_store_footer

	mov x1, x14						// x1 = address of old memory
	ldr x2, [x1, -16]				// x2 = size of old memory block
	sub x2, x2, 24					// x2 = usable memory in old block (amt. to copy)
	bl mem_copy
.Lmem_alloc_store_footer:
	str x5, [x15, x9]
	
	// increment bytes_allocated counter
	adrp x1, bytes_allocated@PAGE
	add x1, x1, bytes_allocated@PAGEOFF
	ldr x2, [x1]
	add x2, x2, x10
	str x2, [x1]

	ldp fp, lr, [sp], 16
	ret

// args: x0 = address to free
// returns: nada
mem_free:
	ldr x5, [x0, -8]				// x5 = base pointer
	ldr x6, [x5]					// x6 = size of region
	add x7, x5, x6					// x7 = addr past end of region
	sub x7, x7, 8					// x7 = addr of last footer
	
	sub x1, x0, 24					// start at footer of previous block

	// set current block to free
	ldr x2, [x1, 8]					// x2 = current block header
	bic x2, x2, 1					// x2 = new header
	str x2, [x1, 8]					// store new header
	lsr x9, x2, 1					// x3 = current block size
	str x2, [x1, x9]				// store new footer

	mov x2, 0						// x2 will count total new size

.Lfree_forward_merge_loop:
	ldr x3, [x1, 8]					// x3 = next block's header
	// break if allocated
	tbnz x3, 0, .Lfree_break_foward_merge_loop
	add x2, x2, x3, lsr 1			// add block size to total
	add x1, x1, x3, lsr 1			// move forward to next block's footer
	cmp x1, x7						// stop at last footer
	beq .Lfree_break_foward_merge_loop
	bgt .Lallocator_block_overflow	// error if last footer lands beyond region
	b .Lfree_forward_merge_loop		// loop

.Lfree_break_foward_merge_loop:
	mov x4, x1						// x4 = addr of footer to update

	add x7, x5, 16					// x7 = addr of header of first block in region
	sub x1, x0, 16					// start next loop at header of current block
.Lfree_back_merge_loop:
	cmp x1, x7						// break when very first header reached
	beq .Lfree_check_for_munmap
	ldr x3, [x1, -8]				// x3 = footer of previous block
	// breack if allocated
	tbnz x3, 0, .Lfree_check_for_munmap
	add x2, x2, x3, lsr 1			// add block size to total
	sub x1, x1, x3, lsr 1			// move backwards to previous block's header
	b .Lfree_back_merge_loop

.Lfree_check_for_munmap:
	sub x7, x6, 16					// x6 = usable space in region
	cmp x2, x7						// cmp size of coalesced block and usable region space
	bne .Lfree_update_boundry_tags	// update boundry tags if > 1 blocks still in region

	mov x0, x5						// address
	mov x1, x6						// length
	mov x16, 73						// syscall = munmap
	svc 0

	cbnz x0, .Lfree_munmap_error
	b .Lfree_ret
.Lfree_munmap_error:
	adrp x0, munmap_error_msg@PAGE
	add x0, x0, munmap_error_msg@PAGEOFF
	bl print_str
	b exit_failure

.Lfree_update_boundry_tags:
	lsl x2, x2, 1					// new value for footer and 1st 1/2 of header
	str x2, [x1]					// store header
	str x2, [x4]					// store footer

.Lfree_ret:
	// increment bytes_freed counter
	adrp x1, bytes_freed@PAGE
	add x1, x1, bytes_freed@PAGEOFF
	ldr x2, [x1]
	add x2, x2, x9
	str x2, [x1]

	ret

// arg: x0 = number of bytes to allocate
// returns x0: address
mem_alloc:
	stp fp, lr, [sp, -16]!
	mov fp, sp

	mov x1, x0
	mov x0, 0
	bl mem_alloc_internal

	ldp fp, lr, [sp], 16

	ret

// see args for internal mem_alloc
mem_realloc:
	stp fp, lr, [sp, -16]!
	mov fp, sp

	mov x16, x0
	mov x17, x1
	
	bl mem_free

	mov x0, x16
	mov x1, x17
	bl mem_alloc_internal

	ldp fp, lr, [sp], 16

	ret
