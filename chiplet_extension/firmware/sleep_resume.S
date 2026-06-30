# Submit work and poll while the testbench applies a SLEEP/RUN transition.
addi x1, x0, 0x100
addi x2, x0, 1
sw x2, 0x18(x1)
addi x2, x0, 0
sw x2, 0x08(x1)
addi x2, x0, 48
sw x2, 0x0c(x1)
addi x2, x0, 8
sw x2, 0x10(x1)
addi x2, x0, 0x177
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
poll_sleep_irq:
lw x3, 0x1c(x1)
beq x3, x0, poll_sleep_irq
lw x4, 0x38(x1)
sw x4, 0(x0)
sw x2, 0x44(x1)
ebreak
