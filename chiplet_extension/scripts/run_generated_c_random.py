#!/usr/bin/env python3
"""Generate, compile, and differentially execute reproducible C instruction streams."""

from __future__ import annotations

import argparse
import csv
import hashlib
import random
from pathlib import Path

from build_compiled_firmware import build_one
from run_compiled_firmware import BUILD, REPORTS, Scenario, compile_sim, run_one


def u32(value: int) -> int: return value & 0xFFFF_FFFF


def generate(seed: int, path: Path, operations: int = 120) -> tuple[int, dict[str, int]]:
    rng = random.Random(seed); value = seed; lines = ["#include <stdint.h>", "uint32_t generated_cpu_stream(void) {", f"  uint32_t value = 0x{seed:08x}u;"]
    counts = {name: 0 for name in ("add", "xor", "rotate", "branch")}
    for _ in range(operations):
        kind = rng.choice(tuple(counts)); operand = rng.getrandbits(32); counts[kind] += 1
        if kind == "add": value = u32(value + operand); lines.append(f"  value += 0x{operand:08x}u;")
        elif kind == "xor": value ^= operand; lines.append(f"  value ^= 0x{operand:08x}u;")
        elif kind == "rotate":
            shift = rng.randint(1, 31); value = u32((value << shift) | (value >> (32-shift)))
            lines.append(f"  value = (value << {shift}) | (value >> {32-shift});")
        else:
            mask = 1 << rng.randint(0, 31)
            if value & mask: value = u32(value + operand); lines.append(f"  if (value & 0x{mask:08x}u) value += 0x{operand:08x}u; else value -= 0x{operand:08x}u;")
            else: value = u32(value - operand); lines.append(f"  if (value & 0x{mask:08x}u) value += 0x{operand:08x}u; else value -= 0x{operand:08x}u;")
    lines.extend(["  return value;", "}"])
    path.write_text("\n".join(lines) + "\n")
    return value, counts


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--verilator", default="verilator"); parser.add_argument("--count", type=int, default=25); args = parser.parse_args()
    source_dir = BUILD / "generated_c" / "sources"; image_dir = BUILD / "generated_c" / "images"
    source_dir.mkdir(parents=True, exist_ok=True); rows = []; jobs = []
    optimizers = ("O0", "O1", "O2", "Os")
    for index in range(args.count):
        seed = 0xC000 + index; name = f"generated_c_{seed:08x}"; source = source_dir / f"{name}.c"
        expected, counts = generate(seed, source); optimizer = optimizers[index % len(optimizers)]
        artifacts = build_one(name, 24, image_dir, extra_sources=[source], optimization=f"-{optimizer}")
        jobs.append((Scenario(name, "gcc_cpu_only"), artifacts, seed, expected, optimizer, counts, source))
    binary = compile_sim(args.verilator, False)
    for scenario, artifacts, seed, expected, optimizer, counts, source in jobs:
        row, _ = run_one(binary, scenario, artifacts["hex"], seed=seed, metadata={"family":"generated_c", "optimizer":optimizer})
        signature_match = row["mailbox0"].lower() == f"{expected:08x}"
        row.update({"expected_signature": f"{expected:08x}", "signature_match": int(signature_match),
                    "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                    "elf_sha256": hashlib.sha256(artifacts["elf"].read_bytes()).hexdigest(),
                    "instruction_knobs": ";".join(f"{key}={value}" for key,value in counts.items())})
        if not signature_match: row["status"] = "FAIL"
        rows.append(row)
    report = REPORTS / "firmware_c_generated_c_summary.csv"
    with report.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0], lineterminator="\n"); writer.writeheader(); writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"Generated C differential: {passed}/{len(rows)}")
    return 0 if passed == len(rows) else 1


if __name__ == "__main__": raise SystemExit(main())
