#!/usr/bin/env python3
"""Generate file-backed AES reference vectors for tb_soc_chiplets."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes


AES_KEY = bytes.fromhex("00112233445566778899aabbccddeeff")
WRONG_KEY = bytes(16)
WORDS_PER_BLOCK = 2


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


def reference_words(test_name: str, total_words: int) -> list[int]:
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate expected ciphertext vectors for tb_soc_chiplets.")
    parser.add_argument("--test", required=True, help="Named SoC test.")
    parser.add_argument("--output", required=True, help="Destination CSV path.")
    parser.add_argument("--words", type=int, default=512, help="Number of 64-bit expected words to emit.")
    args = parser.parse_args()

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    rows = reference_words(args.test, args.words)
    with output_path.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["index", "word_hex"])
        for idx, word in enumerate(rows):
            writer.writerow([idx, f"{word:016x}"])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
