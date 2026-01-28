.const
newline: .asciz "\n"

.text
.global index_of, str_cmp, str_n_cmp, str_to_int, print_str, print_br, str_len

// args:
//  x0 = string
//  w1 = char
// returns:
//  x0 = index of char in string
index_of:
    mov x2, x0
.Lindex_of_loop:
    ldrb w3, [x0]
    cbz w3, .Lindex_of_not_found
    cmp w3, w1
    cinc x0, x0, ne
    beq .Lindex_of_return_index
    b .Lindex_of_loop
.Lindex_of_not_found:
    mov x0, -1
    ret
.Lindex_of_return_index:
    sub x0, x0, x2
    ret

// args:
//  x0 = first string
//  x1 = second string
// returns x0:
//  - 0 if strings are equal
//  - negative number if first string < second string
//  - positive number if vice versa
// could optimise by comparing 8 bytes at a time but can't be bothered rn
str_cmp:
    mov x3, x0                      // x3 and x4 will address current chars
    mov x4, x1
.Lstr_cmp_loop:
    ldrb w5, [x3]                   // x11 and x12 = current chars
    ldrb w6, [x4]

    subs w0, w5, w6                 // compare two current chars
    bne .Lstr_cmp_return            // return x0 if not equal

    cbz w5, .Lstr_cmp_return        // return if null byte found

    add x3, x3, 1                   // move to next chars
    add x4, x4, 1

    b .Lstr_cmp_loop
.Lstr_cmp_return:
    ret

// same as str_cmp but with x2 = length
str_n_cmp:
    cbz x2, .Lstr_n_cmp_return_zero

    mov x3, x0                      // x9 and x4 will address current chars
    mov x4, x1
.Lstr_n_cmp_loop:
    ldrb w5, [x3]                   // x11 and x12 = current chars
    ldrb w6, [x4]

    subs w0, w5, w6                 // compare two current chars
    bne .Lstr_n_cmp_return          // return x0 if not equal

    cbz w5, .Lstr_n_cmp_return      // return if null byte found

    add x3, x3, 1                   // move to next chars
    add x4, x4, 1

    subs x2, x2, 1                  // decrement counter
    bne .Lstr_n_cmp_loop            // loop until counter = 0
.Lstr_n_cmp_return_zero:
    mov w0, 0
.Lstr_n_cmp_return:
    ret

// args:
//  x0 = address of buffer
// returns:
//  x0 = the int
//  x1 = number of chars read (excl. null byte)
// internal:
//  x0 = current address to read from
//  x1 = the int as it's built
//  x2 = is the number negative? (0 or 1)
//  x3 = the char/digit read
//  x4 = 10
str_to_int:
    // intialise registers (see comments above)
    mov x1, 0
    mov w2, 0
    add x5, x0, 1

    ldrb w3, [x0] // read first char into x3

    // if we encounter a '+' allow it, advance x0 and continue normally
    cmp x3, '+'
    beq .Lstr_to_int_advance_one

    // if the first char is not '+' or '-' continue straight into the loop,
    // if it's a non-digit, it will be detected there and 0 will be returned
    cmp x3, '-'
    bne .Lstr_to_int_parse_loop

    // if the first char is '-'
    mov w2, 1 // flag that it's negative
.Lstr_to_int_advance_one:
    add x0, x0, 1 // advance x0
.Lstr_to_int_parse_loop:
    ldrb w3, [x0], 1 // read next char into x3 and inc x0
    cbz w3, .Lstr_to_int_end

    // if char is not '0'-'9' then end
    cmp x3, '0'
    blt .Lstr_to_int_end
    cmp x3, '9'
    bgt .Lstr_to_int_end

    sub x3, x3, '0' // convert ascii code to int
    mov x4, 10
    mul x1, x1, x4  // int *= 10
    add x1, x1, x3  // int += digit

    b .Lstr_to_int_parse_loop
.Lstr_to_int_end:
    sub x3, x0, x5
    mov x0, x1
    mov x1, x3
    cbz w2, .Lstr_to_int_return
    neg x0, x0
.Lstr_to_int_return:
    ret

// args:
//  x0 = address to write from 
// internal:
//  x1 = current address to read from when scanning
//  w2 = current byte when scanning
print_str:
    mov x1, x0
.Lprint_str_scan_loop:
    ldrb w2, [x1]               // read next byte
    cbz w2, .Lprint_str_syscall // make syscall when null byte is found
    add x1, x1, 1               // advance address to next read from
    b .Lprint_str_scan_loop     // repeat
.Lprint_str_syscall:
    sub x2, x1, x0              // num of bytes to write = end of buffer - start
    mov x1, x0                  // address of buffer = x0
    mov x0, 1                   // fd = stdout
    mov x16, 4                  // syscall = write
    svc 0
    ret

// print [line]br[eak]
print_br:
    stp fp, lr, [sp, -16]!

    adrp x0, newline@PAGE
    add x0, x0, newline@PAGEOFF
    bl print_str

    ldp fp, lr, [sp], 16

    ret

// arg: x0 = null-terminated string
// returns w0: length of string excluding null byte
//
// thanks to this long post: https://stackoverflow.com/a/57676035/18516526
// and specifically this implementation from glibc which I tried to roughly port:
// https://codebrowser.dev/glibc/glibc/sysdeps/aarch64/strlen.S.html
str_len:
    mov w9, 0                   // length counter
    mov w12, 16                 // constant csel 

.Lstr_len_align_loop:
    tst x0, 0xf                 // test if address is 16-byte aligned
    beq .Lstr_len_vector_loop   // start scanning 16 bytes at a time once addr. is aligned
    // until it is aligned we scan byte by byte
    ldrb w10, [x0], 1           // load next char and advance pointer to next
    cmp w10, 0
    beq .Lstr_len_end           // return if null byte found
    add w9, w9, 1               // otherwise increment counter
    b .Lstr_len_align_loop      // and repeat

.Lstr_len_vector_loop:
    ld1 {v0.16b}, [x0], 16      // load 16 bytes
    cmeq v0.16b, v0.16b, 0      // set 0 bytes to FF and non-zero bytes to 00
    shrn v0.8b, v0.8h, 4        // shift each byte by 4 bits and pack into lower half of vec (64 bits)
    fmov x10, d0                // extract lower 64 bits of vec into scalar registers
    rbit x11, x10               // reverse bits and count leading zeroes to find...
    clz x11, x11                // index of null byte
    lsr x11, x11, 2             // divide by 4 (since essentially each lane got reduced to 4 bits)
    cmp x10, 0
    csel w11, w12, w11, eq      // w11 = amount to inc. by (16 if no null, otherwise index of null)
    add w9, w9, w11             // increase counter
    beq .Lstr_len_vector_loop   // loop if null byte not found

.Lstr_len_end:
    mov w0, w9                  // return string length
    ret
