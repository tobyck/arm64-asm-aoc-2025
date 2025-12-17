.const
newline: .asciz "\n"

.text
.global print_str, print_br

// args:
// 	x0 = address to write from 
// internal:
//	x1 = current address to read from when scanning
// 	w2 = current byte when scanning
print_str:
	mov x1, x0
.Lprint_str_scan_loop:
	ldrb w2, [x1]				// read next byte
	cbz w2, .Lprint_str_syscall // make syscall when null byte is found
	add x1, x1, 1				// advance address to next read from
	b .Lprint_str_scan_loop		// repeat
.Lprint_str_syscall:
	sub x2, x1, x0 				// num of bytes to write = end of buffer - start
	mov x1, x0 					// address of buffer = x0
	mov x0, 1 					// fd = stdout
	mov x16, 4 					// syscall = write
	svc 0
	ret

// print [line]br[eak]
print_br:
	stp fp, lr, [sp, -16]!
	mov fp, sp

	adrp x0, newline@PAGE
	add x0, x0, newline@PAGEOFF
	bl print_str

	mov sp, fp
	ldp fp, lr, [sp], 16

	ret
