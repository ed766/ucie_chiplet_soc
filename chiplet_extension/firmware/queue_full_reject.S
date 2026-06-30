# Submit one active and four queued descriptors while the link is held, then reject the sixth.
addi x1, x0, 0x100
addi x2, x0, 0
sw x2, 0x08(x1)
addi x2, x0, 80
sw x2, 0x0c(x1)
addi x2, x0, 2
sw x2, 0x10(x1)
addi x2, x0, 0x301
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x2, x0, 2
sw x2, 0x08(x1)
addi x2, x0, 82
sw x2, 0x0c(x1)
addi x2, x0, 0x302
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x2, x0, 4
sw x2, 0x08(x1)
addi x2, x0, 84
sw x2, 0x0c(x1)
addi x2, x0, 0x303
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x2, x0, 6
sw x2, 0x08(x1)
addi x2, x0, 86
sw x2, 0x0c(x1)
addi x2, x0, 0x304
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x2, x0, 8
sw x2, 0x08(x1)
addi x2, x0, 88
sw x2, 0x0c(x1)
addi x2, x0, 0x305
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
addi x2, x0, 10
sw x2, 0x08(x1)
addi x2, x0, 90
sw x2, 0x0c(x1)
addi x2, x0, 0x306
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
lw x3, 0x50(x1)
sw x3, 0(x0)
lw x3, 0x38(x1)
sw x3, 4(x0)
lw x3, 0x3c(x1)
sw x3, 8(x0)
ebreak
