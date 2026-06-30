# Queue five four-word descriptors, fill the completion FIFO, then release retire stall.
addi x1, x0, 0x100
addi x2, x0, 0
sw x2, 0x08(x1)
addi x2, x0, 96
sw x2, 0x0c(x1)
addi x2, x0, 4
sw x2, 0x10(x1)
addi x2, x0, 0x401
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x2, x0, 4
sw x2, 0x08(x1)
addi x2, x0, 100
sw x2, 0x0c(x1)
addi x2, x0, 0x402
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x2, x0, 8
sw x2, 0x08(x1)
addi x2, x0, 104
sw x2, 0x0c(x1)
addi x2, x0, 0x403
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x2, x0, 12
sw x2, 0x08(x1)
addi x2, x0, 108
sw x2, 0x0c(x1)
addi x2, x0, 0x404
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x2, x0, 16
sw x2, 0x08(x1)
addi x2, x0, 112
sw x2, 0x0c(x1)
addi x2, x0, 0x405
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x4, x0, 0x41c
wait_stall:
lw x3, 0x4c(x1)
beq x3, x4, stalled
beq x0, x0, wait_stall
stalled:
sw x3, 0(x0)
lw x3, 0x38(x1)
sw x3, 4(x0)
sw x2, 0x44(x1)
wait_fifth_retire:
lw x3, 0x48(x1)
beq x3, x0, drain_rest
beq x0, x0, wait_fifth_retire
drain_rest:
lw x3, 0x38(x1)
sw x3, 8(x0)
sw x2, 0x44(x1)
lw x3, 0x38(x1)
sw x3, 12(x0)
sw x2, 0x44(x1)
lw x3, 0x38(x1)
sw x3, 16(x0)
sw x2, 0x44(x1)
lw x3, 0x38(x1)
sw x3, 20(x0)
sw x2, 0x44(x1)
ebreak
