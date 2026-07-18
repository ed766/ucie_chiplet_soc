#ifndef CHIPLET_FIRMWARE_H
#define CHIPLET_FIRMWARE_H

#include <stdint.h>

#define DMA_BASE 0x00000100u
#define DMA_CTRL          0x00u
#define DMA_SRC           0x08u
#define DMA_DST           0x0cu
#define DMA_LEN           0x10u
#define DMA_TAG           0x14u
#define DMA_IRQ_ENABLE    0x18u
#define DMA_IRQ_STATUS    0x1cu
#define DMA_COMP_Q_STATUS 0x34u
#define DMA_COMP_TAG      0x38u
#define DMA_COMP_STATUS   0x3cu
#define DMA_COMP_WORDS    0x40u
#define DMA_COMP_POP      0x44u
#define DMA_REJECT_COUNT  0x50u
#define DMA_PARITY_COUNT  0x60u
#define DMA_INVALID_COUNT 0x70u
#define DMA_INJECT_ADDR   0x7cu
#define DMA_INJECT_CMD    0x80u

extern volatile uint32_t irq_seen;
extern volatile uint32_t trap_count;

static inline void mmio_write(uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)(DMA_BASE + offset) = value;
}

static inline uint32_t mmio_read(uint32_t offset)
{
    return *(volatile uint32_t *)(uintptr_t)(DMA_BASE + offset);
}

static inline void local_write(uint32_t index, uint32_t value)
{
    // 0x8000 aliases the core's local SRAM index zero without invoking C null-pointer UB.
    *(volatile uint32_t *)(uintptr_t)(0x00008000u + index * 4u) = value;
}

static inline void submit(uint32_t src, uint32_t dst, uint32_t words, uint32_t tag)
{
    mmio_write(DMA_SRC, src);
    mmio_write(DMA_DST, dst);
    mmio_write(DMA_LEN, words);
    mmio_write(DMA_TAG, tag);
    mmio_write(DMA_CTRL, 1u);
}

static inline uint32_t wait_completion(void)
{
    uint32_t tag;
    do {
        tag = mmio_read(DMA_COMP_TAG);
    } while (tag == 0u);
    return tag;
}

static inline uint32_t completion_count(void)
{
    return (mmio_read(DMA_COMP_Q_STATUS) >> 6) & 7u;
}

static inline void enable_machine_external_irq(void)
{
    uint32_t value = 0x800u;
    __asm__ volatile ("csrw mie, %0" :: "r"(value));
    value = 0x8u;
    __asm__ volatile ("csrs mstatus, %0" :: "r"(value));
}

#endif
