# Submit two descriptors and record their completion tags in retirement order.
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
addi x2, x0, 4
sw x2, 0x08(x1)
addi x2, x0, 40
sw x2, 0x0c(x1)
addi x2, x0, 4
sw x2, 0x10(x1)
addi x2, x0, 0x102
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
poll_first:
lw x3, 0x38(x1)
beq x3, x0, poll_first
sw x3, 0(x0)
sw x2, 0x44(x1)
poll_second:
lw x3, 0x38(x1)
beq x3, x0, poll_second
sw x3, 4(x0)
sw x2, 0x44(x1)
ebreak
