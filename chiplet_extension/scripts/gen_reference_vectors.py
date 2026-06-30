#!/usr/bin/env python3
"""Generate AES-backed reference vectors for tb_soc_chiplets."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

from dma_golden_model import (
    AES_KEY,
    DMA_DESCRIPTOR_PLANS,
    DmaDescriptor,
    build_dma_golden,
    build_dma_golden_from_descriptors,
    write_debug_traces,
    write_destination_image,
)


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
    if test_name not in DMA_DESCRIPTOR_PLANS:
        raise KeyError(test_name)
    return dict(build_dma_golden(test_name).destination_image)


def dynamic_dma_descriptors(args: argparse.Namespace) -> tuple[DmaDescriptor, ...] | None:
    if args.dma_src_base < 0 or args.dma_dst_base < 0 or args.dma_len_words <= 0:
        return None
    queue_pressure = args.queue_pressure
    if queue_pressure in {"full_queue", "five"}:
        count = 5 if queue_pressure == "five" else 4
        return tuple(
            DmaDescriptor(
                args.dma_src_base + idx * args.dma_len_words,
                args.dma_dst_base + idx * args.dma_len_words,
                args.dma_len_words,
                0x5100 + idx,
            )
            for idx in range(count)
        )
    first = DmaDescriptor(args.dma_src_base, args.dma_dst_base, args.dma_len_words, args.dma_tag)
    if queue_pressure == "pair" and args.dma2_src_base >= 0 and args.dma2_dst_base >= 0 and args.dma2_len_words > 0:
        second = DmaDescriptor(args.dma2_src_base, args.dma2_dst_base, args.dma2_len_words, args.dma2_tag)
        return (first, second)
    return (first,)


def write_rows(rows: list[tuple[int, int]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["index", "word_hex"])
        for idx, word in rows:
            writer.writerow([idx, f"{word:016x}"])


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate expected ciphertext vectors for tb_soc_chiplets.")
    parser.add_argument("--test", default="", help="Named SoC test.")
    parser.add_argument("--output", default="", help="Destination CSV path.")
    parser.add_argument("--words", type=int, default=512, help="Number of 64-bit expected words to emit.")
    parser.add_argument("--trace-dir", default="", help="Optional directory for descriptor/plaintext/ciphertext/packet traces.")
    parser.add_argument("--selftest", action="store_true", help="Run Python golden-model self-tests and exit.")
    parser.add_argument("--dma-src-base", type=int, default=-1)
    parser.add_argument("--dma-dst-base", type=int, default=-1)
    parser.add_argument("--dma-len-words", type=int, default=-1)
    parser.add_argument("--dma-tag", type=lambda value: int(value, 0), default=0x5000)
    parser.add_argument("--dma2-src-base", type=int, default=-1)
    parser.add_argument("--dma2-dst-base", type=int, default=-1)
    parser.add_argument("--dma2-len-words", type=int, default=-1)
    parser.add_argument("--dma2-tag", type=lambda value: int(value, 0), default=0x5001)
    parser.add_argument("--queue-pressure", choices=("single", "pair", "full_queue", "five"), default="single")
    args = parser.parse_args()

    if args.selftest:
        import dma_golden_model

        dma_golden_model.selftest()
        return 0

    if not args.test or not args.output:
        parser.error("--test and --output are required unless --selftest is used")

    output_path = Path(args.output)

    dynamic_descriptors = dynamic_dma_descriptors(args)
    if dynamic_descriptors is not None:
        result = build_dma_golden_from_descriptors(dynamic_descriptors)
        write_destination_image(result, output_path)
        if args.trace_dir:
            write_debug_traces(result, Path(args.trace_dir), output_path.stem)
        return 0

    if args.test in DMA_DESCRIPTOR_PLANS:
        result = build_dma_golden(args.test)
        write_destination_image(result, output_path)
        if args.trace_dir:
            write_debug_traces(result, Path(args.trace_dir), output_path.stem)
        return 0

    rows = list(enumerate(legacy_reference_words(args.test, args.words)))
    write_rows(rows, output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
