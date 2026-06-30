# Complete with IRQ masked, then enable the pending completion interrupt.
addi x1, x0, 0x100
addi x2, x0, 0
sw x2, 0x18(x1)
sw x2, 0x08(x1)
addi x2, x0, 64
sw x2, 0x0c(x1)
addi x2, x0, 4
sw x2, 0x10(x1)
addi x2, x0, 0x201
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
wait_completion:
lw x3, 0x38(x1)
beq x3, x0, wait_completion
lw x4, 0x1c(x1)
sw x4, 0(x0)
sw x2, 0x18(x1)
nop
nop
lw x4, 0x1c(x1)
sw x4, 4(x0)
lw x4, 0x38(x1)
sw x4, 8(x0)
sw x2, 0x44(x1)
addi x2, x0, 3
sw x2, 0x1c(x1)
ebreak
