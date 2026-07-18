#!/usr/bin/env python3
"""Generate deterministic CPU-stream assembly and firmware workload manifests."""

from __future__ import annotations

import argparse
import csv
import random
from pathlib import Path


def cpu_stream(seed: int, output: Path) -> None:
    rng = random.Random(seed)
    lines = [
        ".section .text", ".align 2", ".globl generated_cpu_stream",
        "generated_cpu_stream:", "addi sp, sp, -32", "sw ra, 28(sp)",
        f"li t0, 0x{rng.getrandbits(32):08x}", "li t1, 1", "li t2, 31",
    ]
    operations = ("add", "sub", "xor", "or", "and", "sll", "srl", "sra", "slt", "sltu")
    loads = (("lb", 3), ("lbu", 1), ("lh", 0), ("lhu", 2), ("lw", 0))
    stores = (("sb", 1), ("sb", 3), ("sh", 0), ("sh", 2), ("sw", 0))
    for index in range(50):
        imm = rng.randrange(-1024, 1024)
        op = operations[(index + rng.randrange(len(operations))) % len(operations)]
        store, store_offset = stores[index % len(stores)]
        load, load_offset = loads[index % len(loads)]
        lines.extend([
            f"addi t3, t0, {imm}", f"xori t4, t3, {rng.randrange(0, 2048)}",
            f"{op} t0, t3, t4", f"{store} t0, {store_offset}(sp)",
            f"{load} t5, {load_offset}(sp)", "xor t0, t0, t5",
        ])
        if index % 5 == 0:
            lines.extend(["lw t5, 0(sp)", "beq t5, t0, 1f", "addi t0, t0, 1", "1:"])
        if index % 7 == 0:
            lines.extend([
                "csrrs t5, mcause, zero", "csrrw zero, mcause, t5",
                "csrrc zero, mcause, t1", "csrrsi zero, mcause, 0",
            ])
        if index % 11 == 0:
            lines.extend(["jal t6, 2f", "addi t0, t0, 7", "2:"])
        if index == 25:
            lines.extend(["fence", "ecall"])
    lines.extend(["xor a0, t0, t1", "lw ra, 28(sp)", "addi sp, sp, 32", "ret", ""])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines))


def workload_rows(count: int) -> list[dict[str, str]]:
    rows = []
    for index in range(count):
        seed = 0xC001_0000 + index
        rng = random.Random(seed)
        length = (2, 4, 8, 16)[index % 4]
        descriptors = (1, 4, 3, 2)[index % 4]
        error_profile = ("none", "none", "none", "timeout", "parity", "invalid")[index % 6]
        power_event = "deep_sleep" if error_profile == "invalid" else rng.choice(("run", "sleep"))
        completion_mode = "irq" if index % 2 or error_profile in ("timeout", "parity", "invalid") else "poll"
        rows.append({
            "family": "firmware_workload", "index": str(index), "seed": str(seed),
            "descriptors": str(descriptors), "dma_length": str(length),
            "source_bank": str((index >> 1) & 1), "destination_bank": str(index & 1),
            "queue_pressure": str(descriptors), "completion_mode": completion_mode,
            "apb_wait_cycles": str(rng.choice((0, 1, 2, 3, 4, 7))),
            "backpressure_cycles": str(rng.choice((0, 4, 8))),
            "error_profile": error_profile, "power_event": power_event,
        })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cpu-seed", type=int)
    parser.add_argument("--cpu-output", type=Path)
    parser.add_argument("--workload-manifest", type=Path)
    parser.add_argument("--count", type=int, default=25)
    args = parser.parse_args()
    if args.cpu_seed is not None:
        if not args.cpu_output:
            parser.error("--cpu-output is required with --cpu-seed")
        cpu_stream(args.cpu_seed, args.cpu_output)
    if args.workload_manifest:
        rows = workload_rows(args.count)
        args.workload_manifest.parent.mkdir(parents=True, exist_ok=True)
        with args.workload_manifest.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
            writer.writeheader(); writer.writerows(rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
