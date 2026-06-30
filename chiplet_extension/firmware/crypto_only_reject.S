# Attempt a DMA submission in CRYPTO_ONLY and record SUBMIT_RESULT.
addi x1, x0, 0x100
addi x2, x0, 0
sw x2, 0x08(x1)
addi x2, x0, 32
sw x2, 0x0c(x1)
addi x2, x0, 4
sw x2, 0x10(x1)
addi x2, x0, 0x155
sw x2, 0x14(x1)
addi x2, x0, 1
sw x2, 0x00(x1)
lw x3, 0x50(x1)
sw x3, 0(x0)
ebreak
