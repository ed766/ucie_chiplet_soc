# Corrupt source parity through maintenance injection, then submit the affected descriptor.
addi x1, x0, 0x100
addi x2, x0, 0
sw x2, 0x7c(x1)
addi x2, x0, 5
sw x2, 0x80(x1)
nop
nop
nop
nop
addi x2, x0, 0
sw x2, 0x08(x1)
addi x2, x0, 112
sw x2, 0x0c(x1)
addi x2, x0, 4
sw x2, 0x10(x1)
addi x2, x0, 0x601
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
wait_error:
lw x3, 0x38(x1)
beq x3, x0, wait_error
lw x4, 0x3c(x1)
sw x4, 0(x0)
lw x4, 0x60(x1)
sw x4, 4(x0)
sw x2, 0x44(x1)
ebreak
