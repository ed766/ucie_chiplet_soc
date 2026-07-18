#!/usr/bin/env python3
"""Compile and execute multi-translation-unit firmware across GCC optimizers."""

from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path

from build_compiled_firmware import build_one
from run_compiled_firmware import BUILD, REPORTS, Scenario, compile_sim, run_one

OPTIMIZERS = ("O0", "O1", "O2", "Os")
PROGRAMS = (
    ("c_initialized_data_sections", 26, "gcc_cpu_data", (), True),
    ("c_abi_stack_call_matrix", 27, "gcc_cpu_abi", (), True),
    ("isa_matrix", 10, "isa_matrix", (), True),
    ("operand_corner_matrix", 11, "gcc_cpu_only", (), True),
    ("csr_state_matrix", 12, "gcc_cpu_only", (), False),
    ("rv32_decode_legality_matrix", 28, "gcc_decode_legality", (), True),
    ("apb_reset_phase_matrix", 17, "gcc_apb_reset_phase", ("+APB_WAIT_CYCLES=3",), True),
    ("apb_wait_trap", 8, "apb_wait_error", ("+APB_WAIT_CYCLES=7",), False),
    ("rv32_control_flow_boundary_matrix", 29, "gcc_control_boundary", (), False),
    ("rv32_sram_boundary_fault_matrix", 30, "gcc_sram_boundary", (), False),
    ("interrupt_during_apb_wait", 14, "gcc_interrupt_apb_wait", ("+APB_WAIT_CYCLES=7",), False),
    ("interrupt_mask_pending_enable", 15, "gcc_interrupt_masked", (), False),
    ("irq_trap_priority_matrix", 32, "gcc_irq_trap_priority", (), False),
    ("irq_level_mret_matrix", 33, "gcc_irq_level_mret", (), False),
    ("reset_irq_handler_matrix", 34, "gcc_reset_irq_handler", (), False),
    ("apb_atomicity_wait_error_matrix", 35, "gcc_apb_atomicity", ("+APB_WAIT_CYCLES=4",), False),
)
POINTS = (
    *(f"compiler_{name}" for name in OPTIMIZERS),
    "abi_stack_alignment", "abi_callee_saved", "abi_nested_call", "abi_function_pointer",
    "abi_struct_argument", "abi_struct_return", "abi_switch", "abi_initialized_data",
    "abi_bss_zero", "abi_rodata", "abi_volatile_mmio", "abi_linker_relocation",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verilator", default="verilator")
    args = parser.parse_args()
    images = BUILD / "compiler_matrix"
    jobs = []
    for optimizer in OPTIMIZERS:
        for base_name, scenario_id, testbench_name, plusargs, all_optimizers in PROGRAMS:
            if not all_optimizers and optimizer != "O2": continue
            name = f"{base_name}_{optimizer}"
            artifacts = build_one(name, scenario_id, images, optimization=f"-{optimizer}")
            jobs.append((Scenario(name, testbench_name, plusargs=plusargs), artifacts, optimizer))
    binary = compile_sim(args.verilator, False)
    rows = []
    for scenario, artifacts, optimizer in jobs:
        row, _ = run_one(binary, scenario, artifacts["hex"], metadata={"family": "compiler_matrix", "optimizer": optimizer})
        row["optimizer"] = optimizer
        row["elf_sha256"] = sha256(artifacts["elf"])
        row["source_set"] = "crt0.S;scenario.c;abi_support.c;isa_matrix.S;extended_matrix.S"
        rows.append(row)
    summary = REPORTS / "firmware_c_compiler_matrix_summary.csv"
    with summary.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    passed = [row for row in rows if row["status"] == "PASS"]
    contributors = {point: [] for point in POINTS}
    for row in passed:
        contributors[f"compiler_{row['optimizer']}"] .append(row["test"])
        if "c_abi_stack" in row["test"]:
            for point in POINTS[4:11]: contributors[point].append(row["test"])
        if "c_initialized" in row["test"]:
            for point in POINTS[11:]: contributors[point].append(row["test"])
    coverage = REPORTS / "firmware_c_compiler_abi_coverage.csv"
    with coverage.open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(("coverage_point", "hit", "hit_count", "contributors", "evidence"))
        for point in POINTS:
            tests = contributors[point]
            writer.writerow((point, int(bool(tests)), len(tests), ";".join(tests), "GCC_ELF_RVFI_ISS"))
    print(f"Compiler/ABI matrix: {len(passed)}/{len(rows)} executions; {sum(bool(v) for v in contributors.values())}/{len(POINTS)} points")
    return 0 if len(passed) == len(rows) and all(contributors.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
