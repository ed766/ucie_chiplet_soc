# The testbench applies DEEP_SLEEP before this descriptor accesses source bank 0.
addi x1, x0, 0x100
addi x2, x0, 0
sw x2, 0x08(x1)
addi x2, x0, 116
sw x2, 0x0c(x1)
addi x2, x0, 4
sw x2, 0x10(x1)
addi x2, x0, 0x701
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
wait_invalid:
lw x3, 0x38(x1)
beq x3, x0, wait_invalid
lw x4, 0x3c(x1)
sw x4, 0(x0)
lw x4, 0x70(x1)
sw x4, 4(x0)
sw x2, 0x44(x1)
ebreak
