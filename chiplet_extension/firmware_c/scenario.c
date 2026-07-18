#include "firmware.h"
#include "abi_support.h"

volatile uint32_t irq_seen;
volatile uint32_t timer_irq_seen;
volatile uint32_t trap_count;
volatile uint32_t initialized_data_word = 0x13579bdfu;
const uint8_t initialized_const_table[8] = {0x11u, 0x22u, 0x33u, 0x44u, 0x55u, 0x66u, 0x77u, 0x88u};
volatile uint32_t zero_bss_words[4];
extern uint32_t isa_matrix(void);
extern uint32_t operand_corner_matrix(void);
extern uint32_t csr_state_matrix(void);
__attribute__((weak)) uint32_t generated_cpu_stream(void) { return 0x47504355u; }

typedef struct {
    uint8_t lane0;
    uint8_t lane1;
    uint16_t half;
    uint32_t word;
} abi_record_t;

__attribute__((noinline)) static uint32_t abi_leaf(uint32_t a, uint32_t b)
{
    return (a << 3) ^ (b + 0x1234u);
}

__attribute__((noinline)) static uint32_t abi_nested(uint32_t seed)
{
    register uint32_t saved __asm__("s1") = seed ^ 0x55aa55aau;
    uint32_t stack_words[6] = {seed, seed + 1u, seed + 2u, seed + 3u, seed + 4u, seed + 5u};
    uint32_t (*fn)(uint32_t, uint32_t) = abi_leaf;
    return fn(stack_words[2], stack_words[5]) ^ saved;
}

#ifndef WORKLOAD_DESCRIPTORS
#define WORKLOAD_DESCRIPTORS 2
#endif
#ifndef WORKLOAD_LEN
#define WORKLOAD_LEN 4
#endif
#ifndef WORKLOAD_SRC_BANK
#define WORKLOAD_SRC_BANK 0
#endif
#ifndef WORKLOAD_DST_BANK
#define WORKLOAD_DST_BANK 0
#endif
#ifndef WORKLOAD_IRQ_MODE
#define WORKLOAD_IRQ_MODE 0
#endif
#ifndef WORKLOAD_ERROR
#define WORKLOAD_ERROR 0
#endif

__attribute__((noinline)) static uint32_t isa_exercise(uint32_t seed)
{
    volatile uint32_t *word_ptr = (volatile uint32_t *)(uintptr_t)0x2100u;
    volatile uint16_t *half_ptr = (volatile uint16_t *)(uintptr_t)0x2104u;
    volatile uint8_t *byte_ptr = (volatile uint8_t *)(uintptr_t)0x2106u;
    *word_ptr = seed ^ 0x55aa33ccu;
    *half_ptr = (uint16_t)(*word_ptr >> 3);
    *byte_ptr = (uint8_t)(*half_ptr + 7u);
    uint32_t value = ((*word_ptr & 0xff00ff00u) | *byte_ptr) + *half_ptr;
    uint32_t compare;
    __asm__ volatile ("sltu %0, %1, %2" : "=r"(compare) : "r"(value), "r"(seed));
    value += compare;
    value = (value << 3) ^ (value >> 5);
    if (value != seed) value += 1u; else value -= 1u;
    __asm__ volatile ("fence" ::: "memory");
    return value;
}

static void record_completion(uint32_t slot)
{
    local_write(slot, mmio_read(DMA_COMP_TAG));
    local_write(slot + 1u, mmio_read(DMA_COMP_STATUS));
    local_write(slot + 2u, mmio_read(DMA_COMP_WORDS));
}

int main(void)
{
    local_write(15u, isa_exercise((uint32_t)SCENARIO_ID + 1u));
#if SCENARIO_ID == 0
    mmio_write(DMA_IRQ_ENABLE, 1u);
    submit(0u, 32u, 4u, 0x101u);
    while (mmio_read(DMA_IRQ_STATUS) == 0u) { }
    record_completion(0u);
    local_write(3u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
    mmio_write(DMA_IRQ_STATUS, 3u);
#elif SCENARIO_ID == 1
    enable_machine_external_irq();
    mmio_write(DMA_IRQ_ENABLE, 0u);
    submit(0u, 64u, 4u, 0x201u);
    while (mmio_read(DMA_COMP_TAG) == 0u) { }
    local_write(0u, mmio_read(DMA_IRQ_STATUS));
    mmio_write(DMA_IRQ_ENABLE, 1u);
    while (irq_seen == 0u) { }
    local_write(1u, irq_seen);
    local_write(2u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 2
    mmio_write(DMA_IRQ_ENABLE, 1u);
    submit(0u, 32u, 4u, 0x101u);
    submit(4u, 40u, 4u, 0x102u);
    local_write(0u, wait_completion());
    mmio_write(DMA_COMP_POP, 1u);
    local_write(1u, wait_completion());
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 3
    for (uint32_t i = 0; i < 6u; ++i)
        submit(i * 2u, 80u + i * 2u, 2u, 0x301u + i);
    local_write(0u, mmio_read(DMA_REJECT_COUNT));
    local_write(1u, mmio_read(DMA_COMP_TAG));
    local_write(2u, mmio_read(DMA_COMP_STATUS));
    mmio_write(DMA_COMP_POP, 1u);
    for (uint32_t i = 0; i < 5u; ++i) {
        local_write(3u + i, wait_completion());
        mmio_write(DMA_COMP_POP, 1u);
    }
    submit(20u, 100u, 2u, 0x307u);
    local_write(8u, wait_completion());
    local_write(9u, mmio_read(DMA_COMP_STATUS));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 4
    mmio_write(DMA_IRQ_ENABLE, 1u);
    submit(0u, 104u, 4u, 0x501u);
    (void)wait_completion();
    local_write(0u, mmio_read(DMA_COMP_STATUS));
    local_write(1u, mmio_read(DMA_COMP_WORDS));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 5
    mmio_write(DMA_INJECT_ADDR, 0u);
    mmio_write(DMA_INJECT_CMD, 5u);
    for (volatile uint32_t i = 0; i < 4u; ++i) { }
    submit(0u, 112u, 4u, 0x601u);
    (void)wait_completion();
    local_write(0u, mmio_read(DMA_COMP_STATUS));
    local_write(1u, mmio_read(DMA_PARITY_COUNT));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 6
    submit(0u, 116u, 4u, 0x701u);
    (void)wait_completion();
    local_write(0u, mmio_read(DMA_COMP_STATUS));
    local_write(1u, mmio_read(DMA_INVALID_COUNT));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 7
    mmio_write(DMA_IRQ_ENABLE, 1u);
    submit(0u, 48u, 8u, 0x177u);
    while (mmio_read(DMA_IRQ_STATUS) == 0u) { }
    local_write(0u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 8
    mmio_write(DMA_IRQ_ENABLE, 0u);
    local_write(0u, mmio_read(0x04u));
    (void)*(volatile uint32_t *)(uintptr_t)0x188u;
    __asm__ volatile (".word 0xffffffff");
    __asm__ volatile ("lw zero, 1(%0)" :: "r"(DMA_BASE));
    local_write(1u, trap_count);
#elif SCENARIO_ID == 9
    mmio_write(DMA_IRQ_ENABLE, 1u);
    submit(0u, 120u, 4u, 0x181u);
    while (mmio_read(DMA_IRQ_STATUS) == 0u) { }
    local_write(0u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 10
    local_write(0u, isa_matrix());
    __asm__ volatile (".word 0x00002063"); /* Reserved branch funct3. */
    __asm__ volatile (".word 0x40001013"); /* Illegal SLLI funct7. */
    __asm__ volatile (".word 0x02000033"); /* Unsupported OP funct7. */
    __asm__ volatile (".word 0x30004073"); /* Reserved CSR operation mode. */
    __asm__ volatile (".word 0x34302073"); /* Unsupported CSR address. */
    __asm__ volatile ("sh zero, 0(%0)" :: "r"(DMA_BASE));
    __asm__ volatile ("ecall");
    __asm__ volatile ("lh zero, 1(%0)" :: "r"(DMA_BASE));
    __asm__ volatile ("sh zero, 1(%0)" :: "r"(DMA_BASE));
    (void)*(volatile uint32_t *)(uintptr_t)0x188u;
    *(volatile uint32_t *)(uintptr_t)0x188u = 0x5a5aa5a5u;
    local_write(1u, trap_count);
#elif SCENARIO_ID == 11
    local_write(0u, operand_corner_matrix());
#elif SCENARIO_ID == 12
    local_write(0u, csr_state_matrix());
#elif SCENARIO_ID == 13 || SCENARIO_ID == 14 || SCENARIO_ID == 15
    enable_machine_external_irq();
    mmio_write(DMA_IRQ_ENABLE, SCENARIO_ID == 15 ? 0u : 1u);
    submit(0u, 32u, 4u, 0x810u + SCENARIO_ID);
    while (mmio_read(DMA_COMP_TAG) == 0u) { }
    if (SCENARIO_ID == 15) mmio_write(DMA_IRQ_ENABLE, 1u);
    while (irq_seen == 0u) { }
    local_write(0u, irq_seen);
    local_write(1u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 16
    for (uint32_t i = 0; i < 8u; ++i) {
        mmio_write(DMA_IRQ_ENABLE, i & 1u);
        local_write(i, mmio_read(DMA_IRQ_ENABLE));
    }
#elif SCENARIO_ID == 17
    mmio_write(DMA_IRQ_ENABLE, 1u);
    submit(0u, 40u, 4u, 0x917u);
    while (mmio_read(DMA_COMP_TAG) == 0u) { }
    local_write(0u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 18
    (void)*(volatile uint32_t *)(uintptr_t)0x188u;
    *(volatile uint32_t *)(uintptr_t)0x188u = 0x12345678u;
    __asm__ volatile ("lw zero, 1(%0)" :: "r"(DMA_BASE));
    __asm__ volatile ("sh zero, 1(%0)" :: "r"(DMA_BASE));
    local_write(0u, trap_count);
#elif SCENARIO_ID == 19
    submit(0u, 64u, 2u, 0x901u);
    submit(1u, 41u, 4u, 0x902u);
    submit(4u, 49u, 8u, 0x903u);
    submit(1u, 64u, 16u, 0x904u);
    for (uint32_t i = 0; i < 4u; ++i) {
        local_write(i, wait_completion());
        mmio_write(DMA_COMP_POP, 1u);
    }
#elif SCENARIO_ID == 20
    enable_machine_external_irq();
    mmio_write(DMA_IRQ_ENABLE, 1u);
    for (uint32_t i = 0; i < 4u; ++i) submit(i * 2u, 32u + i * 8u, 2u, 0x920u + i);
    while (completion_count() != 4u) { }
    for (uint32_t i = 0; i < 4u; ++i) {
        local_write(i, wait_completion());
        mmio_write(DMA_COMP_POP, 1u);
    }
#elif SCENARIO_ID == 21
    submit(0u, 32u, 2u, 0x933u);
    local_write(0u, wait_completion()); mmio_write(DMA_COMP_POP, 1u);
    submit(2u, 40u, 2u, 0x933u);
    local_write(1u, wait_completion()); mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 22 || SCENARIO_ID == 23
    enable_machine_external_irq();
    mmio_write(DMA_IRQ_ENABLE, 1u);
    submit(0u, 112u, 4u, 0x940u + SCENARIO_ID);
    while (irq_seen == 0u) { }
    local_write(0u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 24
    local_write(0u, generated_cpu_stream());
#elif SCENARIO_ID == 25
    if (WORKLOAD_IRQ_MODE) {
        enable_machine_external_irq();
        mmio_write(DMA_IRQ_ENABLE, 3u);
    }
    if (WORKLOAD_ERROR == 1) {
        mmio_write(DMA_INJECT_ADDR, WORKLOAD_SRC_BANK);
        mmio_write(DMA_INJECT_CMD, 5u);
        for (volatile uint32_t delay = 0; delay < 4u; ++delay) { }
    }
    for (uint32_t i = 0; i < WORKLOAD_DESCRIPTORS; ++i) {
        uint32_t src = ((i * WORKLOAD_LEN) & 30u) | WORKLOAD_SRC_BANK;
        uint32_t dst = (32u + ((i * WORKLOAD_LEN) & 62u)) | WORKLOAD_DST_BANK;
        submit(src, dst, WORKLOAD_LEN, 0xa000u + i);
        local_write(i, wait_completion());
        if (WORKLOAD_IRQ_MODE) while (irq_seen == 0u) { }
        mmio_write(DMA_COMP_POP, 1u);
    }
#elif SCENARIO_ID == 26
    abi_record_t record = {initialized_const_table[0], initialized_const_table[7], 0x5aa5u, initialized_data_word};
    uint32_t failures = 0u;
    if (initialized_data_word != 0x13579bdfu) failures++;
    if (initialized_const_table[3] != 0x44u || initialized_const_table[7] != 0x88u) failures++;
    for (uint32_t i = 0; i < 4u; ++i) if (zero_bss_words[i] != 0u) failures++;
    if (record.lane0 != 0x11u || record.lane1 != 0x88u || record.half != 0x5aa5u) failures++;
    if (abi_external_data != 0x2468ace0u || abi_rodata_table[3] != 0x89abcdefu) failures++;
    for (uint32_t i = 0; i < 3u; ++i) if (abi_external_bss[i] != 0u) failures++;
    volatile int8_t *signed_bytes = (volatile int8_t *)(uintptr_t)0x2140u;
    signed_bytes[3] = -7;
    int32_t signed_observed;
    __asm__ volatile ("lb %0, 0(%1)" : "=r"(signed_observed) : "r"(&signed_bytes[3]));
    if (signed_observed != -7) failures++;
    *(volatile uint8_t *)(uintptr_t)0x2141u = 0xa5u;
    mmio_write(DMA_IRQ_ENABLE, 0u);
    if (mmio_read(DMA_IRQ_ENABLE) != 0u) failures++;
    local_write(0u, failures);
    local_write(1u, record.word);
    local_write(3u, (uint32_t)signed_observed);
#elif SCENARIO_ID == 27
    uint32_t abi_value = abi_nested(0x10203040u);
    abi_packet_t packet = {0x13579bdfu, 0x2468u, 0x35u, 0xcau};
    abi_packet_t transformed = abi_struct_transform(packet, 2u);
    local_write(0u, abi_value);
    local_write(1u, abi_nested(abi_value) ^ abi_nested_external(abi_value, 5u));
    local_write(2u, abi_struct_checksum(transformed));
#elif SCENARIO_ID == 28
    __asm__ volatile (".word 0x00003003"); /* Reserved load funct3. */
    __asm__ volatile (".word 0x00003023"); /* Reserved store funct3. */
    __asm__ volatile (".word 0x34302073"); /* Unsupported CSR. */
    __asm__ volatile ("sh zero, 0(%0)" :: "r"(DMA_BASE));
    local_write(0u, trap_count);
#elif SCENARIO_ID == 29
    __asm__ volatile (".word 0x0020006f"); /* JAL to PC+2: instruction-address misaligned. */
    __asm__ volatile (".word 0x00000163"); /* Taken BEQ to PC+2. */
    __asm__ volatile ("jal t0, 1f\n1:" ::: "t0");
    uint32_t (*odd_fn)(uint32_t, uint32_t) =
        (uint32_t (*)(uint32_t, uint32_t))((uintptr_t)abi_leaf | 1u);
    local_write(0u, trap_count);
    local_write(1u, odd_fn(3u, 4u) ^ abi_nested(3u));
#elif SCENARIO_ID == 30
    *(volatile uint32_t *)(uintptr_t)0x3ffcu = 0xa55aa55au;
    local_write(0u, *(volatile uint32_t *)(uintptr_t)0x3ffcu);
    *(volatile uint8_t *)(uintptr_t)0x3fffu = 0x3cu;
    __asm__ volatile ("lw zero, 0(%0)" :: "r"((uintptr_t)0x4000u));
    __asm__ volatile ("sw zero, 0(%0)" :: "r"((uintptr_t)0x4000u));
    local_write(1u, trap_count);
#elif SCENARIO_ID == 31
    uint32_t old_mtvec, aligned_mtvec, aligned_mepc, masked_status, masked_mie;
    __asm__ volatile ("csrr %0, mtvec" : "=r"(old_mtvec));
    __asm__ volatile ("csrw mtvec, %0" :: "r"(old_mtvec | 3u));
    __asm__ volatile ("csrr %0, mtvec" : "=r"(aligned_mtvec));
    __asm__ volatile ("csrw mepc, %0" :: "r"(0x123u));
    __asm__ volatile ("csrr %0, mepc" : "=r"(aligned_mepc));
    __asm__ volatile ("csrw mstatus, %0" :: "r"(0xffffffffu));
    __asm__ volatile ("csrr %0, mstatus" : "=r"(masked_status));
    __asm__ volatile ("csrw mie, %0" :: "r"(0xffffffffu));
    __asm__ volatile ("csrr %0, mie" : "=r"(masked_mie));
    __asm__ volatile ("csrrc zero, mstatus, %0" :: "r"(masked_status));
    __asm__ volatile ("csrw mtvec, %0" :: "r"(old_mtvec));
    __asm__ volatile (".word 0x34301073");
    local_write(0u, aligned_mtvec & 3u);
    local_write(1u, aligned_mepc);
    local_write(2u, masked_status);
    local_write(3u, masked_mie);
    local_write(4u, trap_count);
#elif SCENARIO_ID == 32 || SCENARIO_ID == 33
    enable_machine_external_irq();
    __asm__ volatile ("ecall");
    for (volatile uint32_t delay = 0; delay < 32u; ++delay) { }
    local_write(0u, irq_seen);
    local_write(1u, trap_count);
#elif SCENARIO_ID == 34
    enable_machine_external_irq();
    for (volatile uint32_t delay = 0; delay < 64u; ++delay) { }
    local_write(0u, irq_seen);
#elif SCENARIO_ID == 35
    mmio_write(DMA_IRQ_ENABLE, 1u);
    local_write(0u, mmio_read(DMA_IRQ_ENABLE));
    (void)*(volatile uint32_t *)(uintptr_t)0x188u;
    *(volatile uint32_t *)(uintptr_t)0x188u = 0x12345678u;
    local_write(1u, trap_count);
#elif SCENARIO_ID == 36
    enable_machine_external_irq();
    mmio_write(DMA_IRQ_ENABLE, 1u);
    submit(0u, 32u, 4u, 0xb001u);
    while (irq_seen == 0u) { }
    local_write(0u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 37
    enable_machine_timer_irq();
    uint64_t now = read_mtime();
    set_mtimecmp(now + 200u);
    while (timer_irq_seen == 0u) { }
    local_write(0u, timer_irq_seen);
    local_write(1u, (uint32_t)now);
    local_write(2u, timer_read(TIMER_MTIME_LO));
    set_mtimecmp(read_mtime() - 1u);
    enable_global_irq();
    while (timer_irq_seen < 2u) { }
    local_write(3u, timer_irq_seen);
#elif SCENARIO_ID == 38
    disable_global_irq();
    uint32_t mtie = 0x80u;
    __asm__ volatile ("csrs mie, %0" :: "r"(mtie));
    set_mtimecmp(read_mtime() + 80u);
    for (volatile uint32_t delay = 0; delay < 160u; ++delay) { }
    local_write(0u, timer_irq_seen);
    enable_global_irq();
    while (timer_irq_seen == 0u) { }
    local_write(1u, timer_irq_seen);
#elif SCENARIO_ID == 39
    enable_machine_timer_irq();
    set_mtimecmp(read_mtime() + 120u);
    local_write(0u, mmio_read(DMA_IRQ_ENABLE));
    while (timer_irq_seen == 0u) { }
    local_write(1u, timer_irq_seen);
#elif SCENARIO_ID == 40
    enable_machine_external_irq();
    enable_machine_timer_irq();
    mmio_write(DMA_IRQ_ENABLE, 1u);
    set_mtimecmp(read_mtime() + 180u);
    submit(0u, 32u, 4u, 0xc040u);
    while (irq_seen == 0u || timer_irq_seen == 0u) { }
    local_write(0u, irq_seen);
    local_write(1u, timer_irq_seen);
    local_write(2u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 41
    enable_machine_timer_irq();
    set_mtimecmp(read_mtime() + 240u);
    uint32_t before = read_minstret();
    wait_for_interrupt();
    uint32_t after = read_minstret();
    local_write(0u, timer_irq_seen);
    local_write(1u, after - before);
#elif SCENARIO_ID == 42
    enable_machine_external_irq();
    mmio_write(DMA_IRQ_ENABLE, 1u);
    submit(0u, 48u, 8u, 0xc042u);
    wait_for_interrupt();
    local_write(0u, irq_seen);
    local_write(1u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 43
    enable_machine_timer_irq();
    set_mtimecmp(read_mtime() + 500u);
    wait_for_interrupt();
    local_write(0u, timer_irq_seen);
    local_write(1u, timer_read(TIMER_MTIME_LO));
#elif SCENARIO_ID == 44
    write_mcycle(0xfffffffcu);
    uint32_t cycle_before = read_mcycle();
    for (volatile uint32_t delay = 0; delay < 8u; ++delay) { }
    uint32_t cycle_after = read_mcycle();
    write_minstret(0xfffffffcu);
    uint32_t instret_before = read_minstret();
    __asm__ volatile ("addi zero, zero, 0\naddi zero, zero, 0\naddi zero, zero, 0\naddi zero, zero, 0");
    uint32_t instret_after = read_minstret();
    local_write(0u, cycle_before);
    local_write(1u, cycle_after);
    local_write(2u, instret_before);
    local_write(3u, instret_after);
#elif SCENARIO_ID == 45
    enable_machine_external_irq();
    mmio_write(DMA_IRQ_ENABLE, 1u);
    uint32_t start_cycle = read_mcycle();
    uint32_t start_instret = read_minstret();
    submit(0u, 64u, 8u, 0xc045u);
    while (irq_seen == 0u) { }
    local_write(0u, read_mcycle() - start_cycle);
    local_write(1u, read_minstret() - start_instret);
    local_write(2u, mmio_read(DMA_COMP_TAG));
    mmio_write(DMA_COMP_POP, 1u);
#elif SCENARIO_ID == 46
    uint32_t mip_value, cycle_high, instret_high;
    timer_write(TIMER_MTIME_HI, 0u);
    timer_write(TIMER_MTIME_LO, 0x100u);
    __asm__ volatile ("csrr %0, mip" : "=r"(mip_value));
    __asm__ volatile ("csrw mip, zero");
    __asm__ volatile ("csrw mcycleh, %0" :: "r"(0x1234u));
    __asm__ volatile ("csrr %0, mcycleh" : "=r"(cycle_high));
    __asm__ volatile ("csrw minstreth, %0" :: "r"(0x5678u));
    __asm__ volatile ("csrr %0, minstreth" : "=r"(instret_high));
    __asm__ volatile ("ebreak");
    local_write(0u, mip_value);
    local_write(1u, cycle_high);
    local_write(2u, instret_high);
    local_write(3u, trap_count);
#else
#error Unsupported SCENARIO_ID
#endif
    return 0;
}
