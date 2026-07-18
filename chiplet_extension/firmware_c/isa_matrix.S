    .section .text
    .align 2
    .globl isa_matrix
isa_matrix:
    addi sp, sp, -16
    sw ra, 12(sp)
    li t0, 0
    li t1, 1
    li t2, 2

    # Every supported immediate and register ALU operation.
    addi t3, t1, 7
    slti t3, t1, 2
    sltiu t3, t1, 2
    xori t3, t1, 0x55
    ori t3, t1, 0x20
    andi t3, t3, 0x1f
    slli t3, t1, 3
    srli t3, t3, 1
    srai t3, t3, 1
    add t3, t1, t2
    sub t3, t2, t1
    sll t3, t1, t2
    slt t3, t1, t2
    sltu t3, t1, t2
    xor t3, t1, t2
    srl t3, t2, t1
    sra t3, t2, t1
    or t3, t1, t2
    and t3, t1, t2

    # Taken and not-taken outcomes for every supported branch relation.
    beq t1, t1, 1f
    addi t0, t0, 64
1:  addi t0, t0, 1
    beq t1, t2, 2f
    addi t0, t0, 1
2:  bne t1, t2, 3f
    addi t0, t0, 64
3:  addi t0, t0, 1
    bne t1, t1, 4f
    addi t0, t0, 1
4:  blt t1, t2, 5f
    addi t0, t0, 64
5:  addi t0, t0, 1
    blt t2, t1, 6f
    addi t0, t0, 1
6:  bge t2, t1, 7f
    addi t0, t0, 64
7:  addi t0, t0, 1
    bge t1, t2, 8f
    addi t0, t0, 1
8:  bltu t1, t2, 9f
    addi t0, t0, 64
9:  addi t0, t0, 1
    bltu t2, t1, 10f
    addi t0, t0, 1
10: bgeu t2, t1, 11f
    addi t0, t0, 64
11: addi t0, t0, 1
    bgeu t1, t2, 12f
    addi t0, t0, 1
12:
    # Signed/unsigned loads and all store widths at multiple byte offsets.
    li t3, 0x80ff7f01
    sw t3, 0(sp)
    lb t4, 3(sp)
    lbu t4, 3(sp)
    lh t4, 2(sp)
    lhu t4, 2(sp)
    lw t4, 0(sp)
    sb t1, 1(sp)
    sh t2, 2(sp)
    sw t3, 4(sp)

    # All register and immediate CSR access forms use mcause as scratch state.
    li t3, 0x12
    csrrw t4, mcause, t3
    csrrs t4, mcause, t1
    csrrc t4, mcause, t1
    csrrwi t4, mcause, 3
    csrrsi t4, mcause, 4
    csrrci t4, mcause, 1
    csrw mcause, zero

    mv a0, t0
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
