#!/usr/bin/env python3
"""Independent Python golden model for DMA crypto transactions.

The RTL scoreboards consume the final destination-image CSV, but this model
also emits descriptor, plaintext, packet-ordering, and ciphertext traces for
debugging and documentation.  It intentionally models the architectural DMA
transaction path rather than reusing any DUT code.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes


AES_KEY = bytes.fromhex("00112233445566778899aabbccddeeff")
DMA_SOURCE_PREFIX = 0x1000_0000_0000_0000
WORDS_PER_AES_BLOCK = 2
WORDS_PER_FLIT_PAYLOAD = 4


@dataclass(frozen=True)
class DmaDescriptor:
    src_base: int
    dst_base: int
    len_words: int
    tag: int


@dataclass(frozen=True)
class GoldenTransaction:
    desc_index: int
    tag: int
    src_index: int
    dst_index: int
    plaintext: int
    ciphertext: int
    aes_block_index: int
    block_word_index: int
    outbound_packet: int
    return_packet: int


@dataclass(frozen=True)
class GoldenResult:
    descriptors: tuple[DmaDescriptor, ...]
    transactions: tuple[GoldenTransaction, ...]
    destination_image: dict[int, int]


def dma_source_word(index: int) -> int:
    return DMA_SOURCE_PREFIX | index


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


DMA_DESCRIPTOR_PLANS: dict[str, tuple[DmaDescriptor, ...]] = {
    "dma_queue_smoke": (DmaDescriptor(8, 32, 4, 0x1101),),
    "dma_queue_back_to_back": (
        DmaDescriptor(8, 32, 4, 0x1102),
        DmaDescriptor(16, 40, 8, 0x1103),
    ),
    "dma_queue_full_reject": (
        DmaDescriptor(8, 64, 4, 0x2100),
        DmaDescriptor(12, 68, 4, 0x2101),
        DmaDescriptor(16, 72, 4, 0x2102),
        DmaDescriptor(20, 76, 4, 0x2103),
    ),
    "dma_completion_fifo_drain": (
        DmaDescriptor(96, 144, 4, 0x2200),
        DmaDescriptor(100, 148, 4, 0x2201),
        DmaDescriptor(104, 152, 4, 0x2202),
    ),
    "dma_irq_masking": (DmaDescriptor(24, 56, 4, 0x1104),),
    "dma_odd_len_reject": (),
    "dma_range_reject": (),
    "dma_timeout_error": (),
    "dma_retry_recover_queue": (
        DmaDescriptor(64, 96, 4, 0x2400),
        DmaDescriptor(80, 112, 4, 0x2401),
    ),
    "dma_power_sleep_resume_queue": (DmaDescriptor(72, 112, 8, 0x2500),),
    "dma_sleep_during_queued_work": (DmaDescriptor(84, 124, 4, 0x2501),),
    "dma_sleep_during_active_transfer": (DmaDescriptor(88, 132, 8, 0x2502),),
    "power_traffic_cross_test": (
        DmaDescriptor(100, 180, 4, 0x2C00),
        DmaDescriptor(104, 184, 4, 0x2C01),
    ),
    "dma_comp_fifo_full_stall": (
        DmaDescriptor(120, 160, 4, 0x2600),
        DmaDescriptor(124, 164, 4, 0x2601),
        DmaDescriptor(128, 168, 4, 0x2602),
        DmaDescriptor(132, 172, 4, 0x2603),
        DmaDescriptor(136, 176, 4, 0x2604),
    ),
    "dma_irq_pending_then_enable": (DmaDescriptor(140, 196, 4, 0x2700),),
    "dma_comp_pop_empty": (),
    "dma_reset_mid_queue": (),
    "dma_tag_reuse": (
        DmaDescriptor(20, 80, 4, 0x2900),
        DmaDescriptor(24, 84, 4, 0x2900),
    ),
    "dma_power_state_retention_matrix": (DmaDescriptor(32, 88, 4, 0x2A00),),
    "dma_crypto_only_submit_blocked": (),
    "mem_bank_parallel_service": (DmaDescriptor(32, 96, 8, 0x3000),),
    "mem_src_bank_conflict": (DmaDescriptor(40, 104, 8, 0x3001),),
    "mem_dst_bank_conflict": (DmaDescriptor(48, 112, 8, 0x3002),),
    "mem_read_while_dma": (DmaDescriptor(56, 120, 8, 0x3003),),
    "mem_write_while_dma_reject": (DmaDescriptor(64, 128, 8, 0x3004),),
    "mem_parity_src_detect": (),
    "mem_parity_dst_maint_detect": (),
    "mem_sleep_retained_bank": (),
    "mem_sleep_nonretained_bank": (),
    "mem_nonretained_readback_poison_clean": (),
    "mem_invalid_clear_on_write": (),
    "mem_deep_sleep_retention_matrix": (),
    "mem_crypto_only_cfg_access": (),
    "mem_bug_parity_skip": (),
    "dma_bug_done_early": (DmaDescriptor(80, 128, 8, 0x110A),),
}


def build_dma_golden_from_descriptors(
    descriptors: tuple[DmaDescriptor, ...],
    key: bytes = AES_KEY,
) -> GoldenResult:
    transactions: list[GoldenTransaction] = []
    destination_image: dict[int, int] = {}
    aes_block_index = 0
    outbound_word_index = 0
    return_word_index = 0

    for desc_index, desc in enumerate(descriptors):
        if desc.len_words % WORDS_PER_AES_BLOCK != 0:
            continue
        dst_index = desc.dst_base
        for offset in range(0, desc.len_words, WORDS_PER_AES_BLOCK):
            src_indices = [desc.src_base + offset, desc.src_base + offset + 1]
            block_words = [dma_source_word(src_indices[0]), dma_source_word(src_indices[1])]
            cipher_words = encrypt_block(key, block_words)
            for block_word_index, cipher_word in enumerate(cipher_words):
                src_index = src_indices[block_word_index]
                destination_image[dst_index] = cipher_word
                transactions.append(
                    GoldenTransaction(
                        desc_index=desc_index,
                        tag=desc.tag,
                        src_index=src_index,
                        dst_index=dst_index,
                        plaintext=block_words[block_word_index],
                        ciphertext=cipher_word,
                        aes_block_index=aes_block_index,
                        block_word_index=block_word_index,
                        outbound_packet=outbound_word_index // WORDS_PER_FLIT_PAYLOAD,
                        return_packet=return_word_index // WORDS_PER_FLIT_PAYLOAD,
                    )
                )
                dst_index += 1
                outbound_word_index += 1
                return_word_index += 1
            aes_block_index += 1

    return GoldenResult(
        descriptors=descriptors,
        transactions=tuple(transactions),
        destination_image=destination_image,
    )


def build_dma_golden(test_name: str, key: bytes = AES_KEY) -> GoldenResult:
    if test_name not in DMA_DESCRIPTOR_PLANS:
        raise KeyError(test_name)
    return build_dma_golden_from_descriptors(DMA_DESCRIPTOR_PLANS[test_name], key)


def write_destination_image(result: GoldenResult, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["index", "word_hex"])
        for idx, word in sorted(result.destination_image.items()):
            writer.writerow([idx, f"{word:016x}"])


def write_debug_traces(result: GoldenResult, output_dir: Path, stem: str) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    with (output_dir / f"{stem}_golden_descriptors.csv").open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["desc_index", "tag_hex", "src_base", "dst_base", "len_words"])
        for idx, desc in enumerate(result.descriptors):
            writer.writerow([idx, f"{desc.tag:04x}", desc.src_base, desc.dst_base, desc.len_words])

    with (output_dir / f"{stem}_golden_plaintext.csv").open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["desc_index", "tag_hex", "src_index", "word_hex", "outbound_packet"])
        for txn in result.transactions:
            writer.writerow([txn.desc_index, f"{txn.tag:04x}", txn.src_index, f"{txn.plaintext:016x}", txn.outbound_packet])

    with (output_dir / f"{stem}_golden_ciphertext.csv").open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["desc_index", "tag_hex", "dst_index", "word_hex", "return_packet"])
        for txn in result.transactions:
            writer.writerow([txn.desc_index, f"{txn.tag:04x}", txn.dst_index, f"{txn.ciphertext:016x}", txn.return_packet])

    with (output_dir / f"{stem}_golden_packets.csv").open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["direction", "packet", "desc_index", "tag_hex", "word_index", "word_hex"])
        for txn in result.transactions:
            writer.writerow(["outbound", txn.outbound_packet, txn.desc_index, f"{txn.tag:04x}", txn.src_index, f"{txn.plaintext:016x}"])
            writer.writerow(["return", txn.return_packet, txn.desc_index, f"{txn.tag:04x}", txn.dst_index, f"{txn.ciphertext:016x}"])


def selftest() -> None:
    known = encrypt_block(AES_KEY, [dma_source_word(8), dma_source_word(9)])
    assert known == [0xBF8BCE88A9DA29B2, 0x9473DE80905242E9], "AES known-answer check failed"

    result = build_dma_golden("dma_queue_back_to_back")
    assert len(result.descriptors) == 2
    assert len(result.destination_image) == 12
    assert result.destination_image[32] == 0xBF8BCE88A9DA29B2
    assert result.destination_image[43] == 0x0EE43EADCE322E9F


if __name__ == "__main__":
    selftest()
