# Exercise a valid wait-stated access followed by an invalid MMIO read.
addi x1, x0, 0x100
lw x2, 0x04(x1)
sw x2, 0(x0)
lw x3, 0x88(x1)
lw x4, 0x01(x1)
ebreak
