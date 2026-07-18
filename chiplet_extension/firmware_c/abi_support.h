#ifndef CHIPLET_ABI_SUPPORT_H
#define CHIPLET_ABI_SUPPORT_H

#include <stdint.h>

typedef struct {
    uint32_t first;
    uint16_t middle;
    uint8_t low;
    uint8_t high;
} abi_packet_t;

extern volatile uint32_t abi_external_data;
extern volatile uint32_t abi_external_bss[3];
extern const uint32_t abi_rodata_table[4];

uint32_t abi_nested_external(uint32_t seed, uint32_t depth);
abi_packet_t abi_struct_transform(abi_packet_t input, uint32_t selector);
uint32_t abi_struct_checksum(abi_packet_t input);

#endif
