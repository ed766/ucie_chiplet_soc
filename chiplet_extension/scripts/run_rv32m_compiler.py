#!/usr/bin/env python3
"""Run the first RV32IM GCC/RTL/ISS compiler matrix."""

from __future__ import annotations

import csv
from pathlib import Path

from build_compiled_firmware import build_one
from run_compiled_firmware import BUILD, REPORTS, Scenario, compile_sim, run_one


def executed_m_ops(trace_path: Path) -> tuple[int, str]:
    names = ("mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu")
    counts = {name: 0 for name in names}
    with trace_path.open(newline="") as handle:
        for event in csv.DictReader(handle):
            insn = int(event["insn"], 16)
            if (insn & 0x7f) == 0x33 and ((insn >> 25) & 0x7f) == 1:
                counts[names[(insn >> 12) & 7]] += 1
    return sum(counts.values()), ";".join(f"{name}={count}" for name, count in counts.items() if count)


def main() -> int:
    images = BUILD / "rv32m_images"
    rows: list[dict[str, str]] = []
    binaries = {
        "rv32i": compile_sim("verilator", False, variant_tag="rv32i_kernel"),
        "rv32im": compile_sim("verilator", False, variant_tag="rv32m_kernel", extra_defines=("RV32M_MODE",)),
    }
    for kernel in range(6):
        for optimization in ("O0", "O2", "Os"):
            for isa, march in (("rv32i", "rv32i_zicsr"), ("rv32im", "rv32im_zicsr")):
                name = f"rv32m_kernel{kernel}_{optimization.lower()}_{isa}"
                artifacts = build_one(name, 58, images, optimization=f"-{optimization}", march=march,
                                      defines={"RV32M_KERNEL_ID": kernel})
                scenario = Scenario(name, "gcc_cpu_only")
                row, _ = run_one(binaries[isa], scenario, artifacts["hex"], metadata={
                    "family": "rv32m_compiler", "isa": isa, "optimizer": optimization,
                    "kernel": str(kernel),
                })
                m_count, m_mix = executed_m_ops(Path(__file__).resolve().parents[2] / row["trace"])
                row["m_instructions"] = str(m_count)
                row["m_opcode_mix"] = m_mix
                if isa == "rv32im" and m_count == 0:
                    row["status"] = "FAIL"
                rows.append(row)
    output = REPORTS / "rv32m_compiler_summary.csv"
    fields = ("test", "status", "rtl_instructions", "iss_instructions", "cpi",
              "m_instructions", "m_opcode_mix", "first_mismatch", "mailbox0", "trace", "log", "applied_knobs")
    with output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"RV32I/RV32IM compiler matrix: {passed} / {len(rows)} PASS")
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
