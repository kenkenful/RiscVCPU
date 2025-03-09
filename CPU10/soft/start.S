	.text
	.align 2
	.global _start
	.global _end
	.extern main

	intr_stack_top = 0x2bff
	user_stack_top = 0x2fff

_start:
	j  init_reg

_end:
	j  _end

init_reg:
	li  x1, 0
	li  x2, 0
	li  x3, 0
	li  x4, 0
	li  x5, 0
	li  x6, 0
	li  x7, 0
	li  x8, 0
	li  x9, 0
	li  x10, 0
	li  x11, 0
	li  x12, 0
	li  x13, 0
	li  x14, 0
	li  x15, 0
	li  x16, 0
	li  x17, 0
	li  x18, 0
	li  x19, 0
	li  x20, 0
	li  x21, 0
	li  x22, 0
	li  x23, 0
	li  x24, 0
	li  x25, 0
	li  x26, 0
	li  x27, 0
	li  x28, 0
	li  x29, 0
	li  x30, 0
	li  x31, 0
	li	sp, user_stack_top

call_main:
	call  main
   	j  _end


    .globl trap_vectors
    .type trap_vectors,@function
    .balign 4
trap_vectors:
    j   undefined_handler
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler    
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler
    .balign 4
    j   timer_handler       
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler  
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler
    .balign 4
    j   undefined_handler
    .size trap_vectors,.-trap_vectors

    .balign 4
undefined_handler:
    mret

    .balign 4
timer_handler:
    addi  sp, sp, -4*17
    sw    ra, 0*4(sp)
    sw    a0, 1*4(sp)
    sw    a1, 2*4(sp)
    sw    a2, 3*4(sp)
    sw    a3, 4*4(sp)
    sw    a4, 5*4(sp)
    sw    a5, 6*4(sp)
    sw    a6, 7*4(sp)
    sw    a7, 8*4(sp)
    sw    t0, 9*4(sp)
    sw    t1, 10*4(sp)
    sw    t2, 11*4(sp)
    sw    t3, 12*4(sp)
    sw    t4, 13*4(sp)
    sw    t5, 14*4(sp)
    sw    t6, 15*4(sp)
    sw    s0, 16*4(sp)

    mv    s0, sp
    la    sp, intr_stack_top
    jal   Timer
    mv    sp, s0

    lw    ra, 0*4(sp)
    lw    a0, 1*4(sp)
    lw    a1, 2*4(sp)
    lw    a2, 3*4(sp)
    lw    a3, 4*4(sp)
    lw    a4, 5*4(sp)
    lw    a5, 6*4(sp)
    lw    a6, 7*4(sp)
    lw    a7, 8*4(sp)
    lw    t0, 9*4(sp)
    lw    t1, 10*4(sp)
    lw    t2, 11*4(sp)
    lw    t3, 12*4(sp)
    lw    t4, 13*4(sp)
    lw    t5, 14*4(sp)
    lw    t6, 15*4(sp)
    lw    s0, 16*4(sp)
    addi  sp, sp, 4*17
    mret
    .size timer_handler,.-timer_handler

    .equ   MIE_MTIE, 0x80
    .equ   MSTATUS_MIE, 0x8

    .global EnableTimer
    .type EnableTimer,@function
    .balign 4
EnableTimer:
    li    t0, MIE_MTIE
    csrrs zero, mie, t0
    ret
    .size EnableTimer,.-EnableTimer

    .global EnableInt
    .type EnableInt,@function
EnableInt:
    li    t0, MSTATUS_MIE
    csrrs zero, mstatus, t0
    ret
    .size EnableInt,.-EnableInt

    .global DisableInt
    .type DisableInt,@function
DisableInt:
    li    t0, MSTATUS_MIE
    csrrc zero, mstatus, t0
    ret
    .size DisableInt,.-DisableInt

    .global SetTrapVectors
    .type SetTrapVectors,@function
SetTrapVectors:
    csrw  mtvec, a0
    ret
    .size SetTrapVectors,.-SetTrapVectors

    .globl switch_context
    .globl load_context
    .type switch_context,@function
    .balign 4
switch_context:
    addi  sp, sp, -4*13
    sw    s0, 0*4(sp)
    sw    s1, 1*4(sp)
    sw    s2, 2*4(sp)
    sw    s3, 3*4(sp)
    sw    s4, 4*4(sp)
    sw    s5, 5*4(sp)
    sw    s6, 6*4(sp)
    sw    s7, 7*4(sp)
    sw    s8, 8*4(sp)
    sw    s9, 9*4(sp)
    sw    s10, 10*4(sp)
    sw    s11, 11*4(sp)
    sw    ra, 12*4(sp)
    sw    sp, (a1)

load_context:
    lw    sp, (a0)
    lw    s0, 0*4(sp)
    lw    s1, 1*4(sp)
    lw    s2, 2*4(sp)
    lw    s3, 3*4(sp)
    lw    s4, 4*4(sp)
    lw    s5, 5*4(sp)
    lw    s6, 6*4(sp)
    lw    s7, 7*4(sp)
    lw    s8, 8*4(sp)
    lw    s9, 9*4(sp)
    lw    s10, 10*4(sp)
    lw    s11, 11*4(sp)
    lw    ra, 12*4(sp)
    addi  sp, sp, 4*13
    ret
    .size switch_context,.-switch_context