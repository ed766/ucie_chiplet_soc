# Submit one descriptor, poll its IRQ, record completion fields, then pop it.
addi x1, x0, 0x100
addi x2, x0, 1
sw x2, 0x18(x1)
addi x2, x0, 0
sw x2, 0x08(x1)
addi x2, x0, 32
sw x2, 0x0c(x1)
addi x2, x0, 4
sw x2, 0x10(x1)
addi x2, x0, 0x101
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
poll_irq:
lw x3, 0x1c(x1)
beq x3, x0, poll_irq
lw x4, 0x38(x1)
sw x4, 0(x0)
lw x4, 0x3c(x1)
sw x4, 4(x0)
lw x4, 0x40(x1)
sw x4, 8(x0)
lw x5, 0(x0)
sw x5, 12(x0)
sw x2, 0x44(x1)
addi x2, x0, 3
sw x2, 0x1c(x1)
ebreak
