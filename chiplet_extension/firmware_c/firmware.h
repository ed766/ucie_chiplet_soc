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

#define TIMER_BASE        0x000001a0u
#define TIMER_MTIME_LO    0x00u
#define TIMER_MTIME_HI    0x04u
#define TIMER_MTIMECMP_LO 0x08u
#define TIMER_MTIMECMP_HI 0x0cu

extern volatile uint32_t irq_seen;
extern volatile uint32_t timer_irq_seen;
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

static inline void timer_write(uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)(TIMER_BASE + offset) = value;
}

static inline uint32_t timer_read(uint32_t offset)
{
    return *(volatile uint32_t *)(uintptr_t)(TIMER_BASE + offset);
}

static inline uint64_t read_mtime(void)
{
    uint32_t high0, low, high1;
    do {
        high0 = timer_read(TIMER_MTIME_HI);
        low = timer_read(TIMER_MTIME_LO);
        high1 = timer_read(TIMER_MTIME_HI);
    } while (high0 != high1);
    return ((uint64_t)high1 << 32) | low;
}

static inline void set_mtimecmp(uint64_t value)
{
    timer_write(TIMER_MTIMECMP_HI, 0xffffffffu);
    timer_write(TIMER_MTIMECMP_LO, (uint32_t)value);
    timer_write(TIMER_MTIMECMP_HI, (uint32_t)(value >> 32));
}

static inline void enable_machine_timer_irq(void)
{
    uint32_t value = 0x80u;
    __asm__ volatile ("csrs mie, %0" :: "r"(value));
    value = 0x8u;
    __asm__ volatile ("csrs mstatus, %0" :: "r"(value));
}

static inline void disable_global_irq(void)
{
    uint32_t value = 0x8u;
    __asm__ volatile ("csrc mstatus, %0" :: "r"(value));
}

static inline void enable_global_irq(void)
{
    uint32_t value = 0x8u;
    __asm__ volatile ("csrs mstatus, %0" :: "r"(value));
}

static inline uint32_t read_mcycle(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, mcycle" : "=r"(value));
    return value;
}

static inline uint32_t read_minstret(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, minstret" : "=r"(value));
    return value;
}

static inline void write_mcycle(uint32_t value)
{
    __asm__ volatile ("csrw mcycle, %0" :: "r"(value));
}

static inline void write_minstret(uint32_t value)
{
    __asm__ volatile ("csrw minstret, %0" :: "r"(value));
}

static inline void wait_for_interrupt(void)
{
    __asm__ volatile ("wfi" ::: "memory");
}

#endif
