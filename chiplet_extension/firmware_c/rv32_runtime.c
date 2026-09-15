#include <stdint.h>
#include <stddef.h>

void *memcpy(void *destination, const void *source, size_t length)
{
    uint8_t *dst = (uint8_t *)destination;
    const uint8_t *src = (const uint8_t *)source;
    for (size_t index = 0; index < length; ++index) dst[index] = src[index];
    return destination;
}

void *memset(void *destination, int value, size_t length)
{
    uint8_t *dst = (uint8_t *)destination;
    for (size_t index = 0; index < length; ++index) dst[index] = (uint8_t)value;
    return destination;
}

uint32_t __mulsi3(uint32_t lhs, uint32_t rhs)
{
    uint32_t result = 0u;
    while (rhs != 0u) {
        if (rhs & 1u) result += lhs;
        lhs <<= 1;
        rhs >>= 1;
    }
    return result;
}

static uint32_t unsigned_divmod(uint32_t dividend, uint32_t divisor, uint32_t *remainder)
{
    uint32_t quotient = 0u;
    uint32_t rem = 0u;
    if (divisor == 0u) {
        *remainder = dividend;
        return 0xffffffffu;
    }
    for (int bit = 31; bit >= 0; --bit) {
        uint32_t high = rem >> 31;
        rem = (rem << 1) | ((dividend >> bit) & 1u);
        if (high || rem >= divisor) {
            rem -= divisor;
            quotient |= 1u << bit;
        }
    }
    *remainder = rem;
    return quotient;
}

uint32_t __udivsi3(uint32_t lhs, uint32_t rhs)
{
    uint32_t remainder;
    return unsigned_divmod(lhs, rhs, &remainder);
}

uint32_t __umodsi3(uint32_t lhs, uint32_t rhs)
{
    uint32_t remainder;
    (void)unsigned_divmod(lhs, rhs, &remainder);
    return remainder;
}

int32_t __divsi3(int32_t lhs, int32_t rhs)
{
    uint32_t lhs_mag = lhs < 0 ? 0u - (uint32_t)lhs : (uint32_t)lhs;
    uint32_t rhs_mag = rhs < 0 ? 0u - (uint32_t)rhs : (uint32_t)rhs;
    uint32_t remainder;
    uint32_t quotient = unsigned_divmod(lhs_mag, rhs_mag, &remainder);
    if (rhs == 0) return -1;
    if ((uint32_t)lhs == 0x80000000u && rhs == -1) return lhs;
    return (lhs < 0) != (rhs < 0) ? (int32_t)(0u - quotient) : (int32_t)quotient;
}

int32_t __modsi3(int32_t lhs, int32_t rhs)
{
    uint32_t lhs_mag = lhs < 0 ? 0u - (uint32_t)lhs : (uint32_t)lhs;
    uint32_t rhs_mag = rhs < 0 ? 0u - (uint32_t)rhs : (uint32_t)rhs;
    uint32_t remainder;
    (void)unsigned_divmod(lhs_mag, rhs_mag, &remainder);
    if (rhs == 0) return lhs;
    if ((uint32_t)lhs == 0x80000000u && rhs == -1) return 0;
    return lhs < 0 ? (int32_t)(0u - remainder) : (int32_t)remainder;
}
