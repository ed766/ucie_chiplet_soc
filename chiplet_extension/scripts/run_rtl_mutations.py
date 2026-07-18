#!/usr/bin/env python3
"""Sensitize true RV32 RTL mutations with compiled firmware and ISS/SVA checks."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from build_compiled_firmware import SCENARIOS as IDS, build_one
from run_compiled_firmware import BUILD, REPORTS, SCENARIOS, Scenario, TIMER_WFI_SCENARIOS, compile_sim, run_one

MUTATIONS = (
    ("RV32_BUG_ALU_RESULT", "operand_corner_matrix"),
    ("RV32_BUG_SIGNED_BRANCH", "operand_corner_matrix"),
    ("RV32_BUG_LOAD_SIGN_EXT", "c_initialized_data_sections"),
    ("RV32_BUG_STORE_MASK_SHIFT", "operand_corner_matrix"),
    ("RV32_BUG_CSR_ZERO_SOURCE", "csr_state_matrix"),
    ("RV32_BUG_MSCRATCH_WRITE_DROP", "csr_state_matrix"),
    ("RV32_BUG_TRAP_CAUSE", "isa_matrix"),
    ("RV32_BUG_DUP_APB_COMPLETION", "apb_wait_trap"),
    ("RV32_BUG_IRQ_RESTORE", "interrupt_before_after_retire"),
    ("RV32_BUG_MRET_SKIP", "interrupt_before_after_retire"),
)


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--verilator", default="verilator")
    parser.add_argument("--mutation", choices=[item[0] for item in MUTATIONS])
    parser.add_argument("--report", type=Path, default=REPORTS / "firmware_c_rtl_mutation_summary.csv")
    args = parser.parse_args()
    scenarios = {item.name: item for item in (*SCENARIOS, *TIMER_WFI_SCENARIOS)}
    images = BUILD / "rtl_mutations"; rows = []
    selected = [item for item in MUTATIONS if not args.mutation or item[0] == args.mutation]
    for mutation, scenario_name in selected:
        scenario = scenarios[scenario_name]
        artifacts = build_one(scenario_name, IDS[scenario_name], images)
        binary = compile_sim(args.verilator, False, assertions=True, mutation_define=mutation)
        row, _ = run_one(binary, scenario, artifacts["hex"], artifact_suffix=f"_{mutation.lower()}")
        detected = row["status"] == "FAIL" and (bool(row["first_mismatch"]) or row["checker_failure"] == "1")
        rows.append({"mutation": mutation, "kind": "RTL_MUTATION", "scenario": scenario_name,
                     "status": "PASS" if detected else "FAIL",
                     "iss_detected": int(bool(row["first_mismatch"])),
                     "assertion_detected": row["checker_failure"],
                     "first_mismatch": row["first_mismatch"],
                     "retirement_order": row["first_mismatch"].split(":", 1)[0].removeprefix("order ")
                     if row["first_mismatch"].startswith("order ") else "",
                     "mismatch_pc": row["mismatch_pc"],
                     "function": row["mismatch_function"],
                     "source": row["mismatch_source"],
                     "surrounding_disassembly": row["mismatch_disassembly"],
                     "waveform_timestamp": row["waveform_timestamp"]})
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0], lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"RV32 RTL mutations detected: {passed}/{len(rows)}")
    return 0 if passed == len(rows) else 1


if __name__ == "__main__": raise SystemExit(main())
