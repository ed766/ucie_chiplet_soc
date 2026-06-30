#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { WORDS_PER_FLIT = 4 };

static uint8_t crc8_words(const uint64_t words[WORDS_PER_FLIT]) {
    uint8_t crc = 0;
    const uint8_t poly = 0x07;

    for (int word = WORDS_PER_FLIT - 1; word >= 0; --word) {
        for (int bit = 63; bit >= 0; --bit) {
            uint8_t data_bit = (uint8_t)((words[word] >> bit) & 1u);
            uint8_t feedback = (uint8_t)(data_bit ^ ((crc >> 7) & 1u));
            crc = (uint8_t)(crc << 1);
            if (feedback) {
                crc ^= poly;
            }
        }
    }

    return crc;
}

static int parse_word(const char *text, uint64_t *value) {
    char *end = NULL;
    *value = strtoull(text, &end, 0);
    return end != text && *end == '\0';
}

static int run_self_test(void) {
    const uint64_t zero[WORDS_PER_FLIT] = {0, 0, 0, 0};
    const uint64_t ascending[WORDS_PER_FLIT] = {1, 2, 3, 4};
    const uint64_t mixed[WORDS_PER_FLIT] = {
        UINT64_C(0x0123456789abcdef),
        UINT64_C(0xfedcba9876543210),
        UINT64_C(0x1111222233334444),
        UINT64_C(0xdeadbeefcafef00d),
    };

    struct {
        const char *name;
        const uint64_t *words;
        uint8_t expected;
    } tests[] = {
        {"zero_payload", zero, 0x00},
        {"ascending_payload", ascending, 0x26},
        {"mixed_payload", mixed, 0xfa},
    };

    for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); ++i) {
        uint8_t observed = crc8_words(tests[i].words);
        if (observed != tests[i].expected) {
            fprintf(stderr, "CRC self-test failed: %s observed=0x%02x expected=0x%02x\n",
                    tests[i].name, observed, tests[i].expected);
            return 1;
        }
    }

    printf("C_REF_RESULT|status=PASS|checks=3|model=flit_crc8\n");
    return 0;
}

int main(int argc, char **argv) {
    uint64_t words[WORDS_PER_FLIT];

    if (argc == 1 || (argc == 2 && strcmp(argv[1], "--self-test") == 0)) {
        return run_self_test();
    }

    if (argc != WORDS_PER_FLIT + 1) {
        fprintf(stderr, "usage: %s [--self-test] | <word0> <word1> <word2> <word3>\n", argv[0]);
        return 2;
    }

    for (int i = 0; i < WORDS_PER_FLIT; ++i) {
        if (!parse_word(argv[i + 1], &words[i])) {
            fprintf(stderr, "invalid 64-bit word: %s\n", argv[i + 1]);
            return 2;
        }
    }

    printf("crc=0x%02x\n", crc8_words(words));
    return 0;
}
