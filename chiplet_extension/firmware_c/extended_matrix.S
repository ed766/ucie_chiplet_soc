    .section .text
    .align 2
    .globl operand_corner_matrix
operand_corner_matrix:
    addi sp, sp, -16
    sw ra, 12(sp)
    li t0, 0
    li t1, -1
    li t2, 0x80000000
    li t3, 0x7fffffff
    add t4, t0, t1
    sub t4, t0, t1
    li t5, 1
    add t4, t3, t5
    sub t4, t2, t5
    slt t4, t2, t3
    sltu t4, t2, t3
    slli t4, t1, 0
    slli t4, t1, 31
    srli t4, t1, 31
    srai t4, t2, 31
    xor t4, t2, t3
    or t4, t0, t1
    and t4, t2, t3
    li t0, -1
    li t1, 1
    blt t0, t1, 1f
    li a0, 0
1:
    sw t1, 0(sp)
    lb t4, 0(sp)
    lbu t4, 1(sp)
    lh t4, 0(sp)
    lhu t4, 2(sp)
    sb t3, 3(sp)
    sh t3, 2(sp)
    li a0, 0x4f504552
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

    .globl csr_state_matrix
csr_state_matrix:
    li t0, 0x88
    csrrw t1, mstatus, t0
    csrrs zero, mstatus, zero
    csrrc zero, mstatus, zero
    li t0, 0x800
    csrw mie, t0
    csrr t1, mie
    la t0, trap_entry
    csrw mtvec, t0
    csrr t1, mtvec
    csrr t1, mepc
    csrw mepc, zero
    csrr t1, mcause
    csrrwi zero, mcause, 0
    csrrsi zero, mcause, 0
    csrrci zero, mcause, 0
    li t0, 0x13579bdf
    csrrw t1, mscratch, t0
    li t2, 0x000000f0
    csrrs t3, mscratch, t2
    li t4, 0x0000000f
    csrrc t5, mscratch, t4
    csrrwi t1, mscratch, 3
    csrrsi t2, mscratch, 4
    csrrci t3, mscratch, 1
    li a0, 0x43535253
    ret
