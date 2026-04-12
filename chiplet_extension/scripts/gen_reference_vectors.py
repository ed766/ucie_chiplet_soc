#!/usr/bin/env python3
"""Generate AES-backed reference vectors for tb_soc_chiplets."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes


AES_KEY = bytes.fromhex("00112233445566778899aabbccddeeff")
WRONG_KEY = bytes(16)
WORDS_PER_BLOCK = 2
DMA_SOURCE_PREFIX = 0x1000_0000_0000_0000


def encrypt_block(key: bytes, block_words: list[int]) -> list[int]:
    block_value = block_words[0] | (block_words[1] << 64)
    block_bytes = block_value.to_bytes(16, byteorder="big")
    cipher = Cipher(algorithms.AES(key), modes.ECB())
    encryptor = cipher.encryptor()
    result = encryptor.update(block_bytes) + encryptor.finalize()
    cipher_value = int.from_bytes(result, byteorder="big")
    return [
        cipher_value & ((1 << 64) - 1),
        (cipher_value >> 64) & ((1 << 64) - 1),
    ]


def dma_source_word(index: int) -> int:
    return DMA_SOURCE_PREFIX | index


def legacy_reference_words(test_name: str, total_words: int) -> list[int]:
    wrong_key_mode = test_name == "soc_wrong_key"
    misalign_mode = test_name == "soc_misalign"
    key = WRONG_KEY if wrong_key_mode else AES_KEY

    words: list[int] = []
    plain_word = 0
    while len(words) < total_words:
        block_words = [plain_word, plain_word + 1]
        plain_word += WORDS_PER_BLOCK
        if misalign_mode:
            block_words = [block_words[1], block_words[0]]
        words.extend(encrypt_block(key, block_words))
    return words[:total_words]


def dma_image_for_test(test_name: str) -> dict[int, int]:
    plans: dict[str, list[tuple[int, int, int]]] = {
        "dma_queue_smoke": [(8, 32, 4)],
        "dma_queue_back_to_back": [(8, 32, 4), (16, 40, 8)],
        "dma_queue_full_reject": [(8, 64, 4), (12, 68, 4), (16, 72, 4), (20, 76, 4)],
        "dma_completion_fifo_drain": [(96, 144, 4), (100, 148, 4), (104, 152, 4)],
        "dma_irq_masking": [(24, 56, 4)],
        "dma_odd_len_reject": [],
        "dma_range_reject": [],
        "dma_timeout_error": [],
        "dma_retry_recover_queue": [(64, 96, 4), (80, 112, 4)],
        "dma_power_sleep_resume_queue": [(72, 112, 8)],
        "dma_comp_fifo_full_stall": [(120, 160, 4), (124, 164, 4), (128, 168, 4), (132, 172, 4), (136, 176, 4)],
        "dma_irq_pending_then_enable": [(140, 196, 4)],
        "dma_comp_pop_empty": [],
        "dma_reset_mid_queue": [],
        "dma_tag_reuse": [(20, 80, 4), (24, 84, 4)],
        "dma_power_state_retention_matrix": [(32, 88, 4)],
        "dma_crypto_only_submit_blocked": [],
        "mem_bank_parallel_service": [(32, 96, 8)],
        "mem_src_bank_conflict": [(40, 104, 8)],
        "mem_dst_bank_conflict": [(48, 112, 8)],
        "mem_read_while_dma": [(56, 120, 8)],
        "mem_write_while_dma_reject": [(64, 128, 8)],
        "mem_parity_src_detect": [],
        "mem_parity_dst_maint_detect": [],
        "mem_sleep_retained_bank": [],
        "mem_sleep_nonretained_bank": [],
        "mem_nonretained_readback_poison_clean": [],
        "mem_invalid_clear_on_write": [],
        "mem_deep_sleep_retention_matrix": [],
        "mem_crypto_only_cfg_access": [],
        "mem_bug_parity_skip": [],
        "dma_bug_done_early": [(80, 128, 8)],
    }
    if test_name not in plans:
        raise KeyError(test_name)

    image: dict[int, int] = {}
    for src_base, dst_base, length in plans[test_name]:
        block_words: list[int] = []
        dst_index = dst_base
        for offset in range(length):
            block_words.append(dma_source_word(src_base + offset))
            if len(block_words) == WORDS_PER_BLOCK:
                for word in encrypt_block(AES_KEY, block_words):
                    image[dst_index] = word
                    dst_index += 1
                block_words = []
    return image


def write_rows(rows: list[tuple[int, int]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["index", "word_hex"])
        for idx, word in rows:
            writer.writerow([idx, f"{word:016x}"])


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate expected ciphertext vectors for tb_soc_chiplets.")
    parser.add_argument("--test", required=True, help="Named SoC test.")
    parser.add_argument("--output", required=True, help="Destination CSV path.")
    parser.add_argument("--words", type=int, default=512, help="Number of 64-bit expected words to emit.")
    args = parser.parse_args()

    output_path = Path(args.output)

    if args.test.startswith(("dma_", "mem_")):
        image = dma_image_for_test(args.test)
        write_rows(sorted(image.items()), output_path)
        return 0

    rows = list(enumerate(legacy_reference_words(args.test, args.words)))
    write_rows(rows, output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
