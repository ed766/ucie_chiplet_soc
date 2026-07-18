    .section .text.start
    .globl _start
_start:
    la sp, __stack_top
    la t0, trap_entry
    csrw mtvec, t0
    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:
    call main
    ebreak

    .align 2
    .globl trap_entry
trap_entry:
    addi sp, sp, -64
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    sw a0, 32(sp)
    sw a1, 36(sp)
    sw a2, 40(sp)
    sw a3, 44(sp)
    sw a4, 48(sp)
    sw a5, 52(sp)
    sw a6, 56(sp)
    sw a7, 60(sp)

    csrr t0, mcause
    blt t0, zero, 3f
    la t1, trap_count
    lw t2, 0(t1)
    addi t2, t2, 1
    sw t2, 0(t1)
    csrr t1, mepc
    addi t1, t1, 4
    csrw mepc, t1
    j 4f
3:
    la t1, irq_seen
    li t2, 1
    sw t2, 0(t1)
    li t1, 0x11c
    li t2, 3
    sw t2, 0(t1)
4:
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    lw a0, 32(sp)
    lw a1, 36(sp)
    lw a2, 40(sp)
    lw a3, 44(sp)
    lw a4, 48(sp)
    lw a5, 52(sp)
    lw a6, 56(sp)
    lw a7, 60(sp)
    addi sp, sp, 64
    mret
