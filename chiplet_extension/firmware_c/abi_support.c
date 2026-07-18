#include "abi_support.h"

volatile uint32_t abi_external_data = 0x2468ace0u;
volatile uint32_t abi_external_bss[3];
const uint32_t abi_rodata_table[4] = {0x11u, 0x2233u, 0x44556677u, 0x89abcdefu};

__attribute__((noinline)) static uint32_t abi_step(uint32_t value, uint32_t selector)
{
    switch (selector & 3u) {
    case 0: return value + 0x102u;
    case 1: return (value << 5) | (value >> 27);
    case 2: return value ^ 0xa5a55a5au;
    default: return value - 0x33u;
    }
}

uint32_t abi_nested_external(uint32_t seed, uint32_t depth)
{
    uint32_t value = seed;
    for (uint32_t index = 0; index < depth; ++index)
        value = abi_step(value, index);
    return value;
}

abi_packet_t abi_struct_transform(abi_packet_t input, uint32_t selector)
{
    abi_packet_t result = input;
    result.first = abi_step(input.first, selector);
    result.middle = (uint16_t)(input.middle ^ (uint16_t)selector);
    result.low = (uint8_t)(input.low + selector);
    result.high = (uint8_t)(input.high - selector);
    return result;
}

uint32_t abi_struct_checksum(abi_packet_t input)
{
    return input.first ^ ((uint32_t)input.middle << 8) ^
           ((uint32_t)input.low << 24) ^ input.high;
}
