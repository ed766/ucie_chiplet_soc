#!/usr/bin/env python3
"""Demonstrate independent external-oracle sensitivity to true RTL defects."""

from __future__ import annotations

import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"
REPORTS = ROOT / "reports"
REPORT = REPORTS / "rv32_external_mutation_matrix.csv"


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT.parent, check=True)


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def main() -> int:
    local_report = REPORTS / "rv32_external_mutation_local_iss.csv"
    spike_report = REPORTS / "rv32_external_mutation_spike.csv"
    act_report = REPORTS / "rv32_external_mutation_act4.csv"
    formal_report = REPORTS / "rv32_external_mutation_formal.csv"

    run([sys.executable, str(SCRIPTS / "run_rtl_mutations.py"),
         "--mutation", "RV32_BUG_MSCRATCH_WRITE_DROP", "--report", str(local_report)])
    run([sys.executable, str(SCRIPTS / "run_external_iss.py"), "--require",
         "--program", "operand_corner_matrix_Os", "--mutation", "RV32_BUG_ALU_RESULT",
         "--expect-detection", "--report", str(spike_report)])
    run([sys.executable, str(SCRIPTS / "run_act4.py"), "--require", "--suite-prefix", "Zicsr",
         "--mutation", "RV32_BUG_MSCRATCH_WRITE_DROP", "--expect-detection",
         "--report", str(act_report)])
    run([sys.executable, str(SCRIPTS / "run_rv32_formal.py"), "--require", "--custom-only",
         "--custom-mutation", "RV32_BUG_MSCRATCH_WRITE_DROP", "--expect-detection",
         "--report", str(formal_report)])

    local = read_rows(local_report)
    spike = read_rows(spike_report)
    act = read_rows(act_report)
    formal = read_rows(formal_report)
    rows = [
        {
            "oracle": "repository_local_iss_and_sva",
            "mutation": "RV32_BUG_MSCRATCH_WRITE_DROP",
            "expected_detection": "architectural_state_or_assertion_mismatch",
            "observed_detection": "ISS/SVA" if local and local[0]["status"] == "PASS" else "none",
            "status": "PASS" if local and local[0]["status"] == "PASS" else "FAIL",
            "evidence": str(local_report.relative_to(ROOT.parent)),
        },
        {
            "oracle": "Spike",
            "mutation": "RV32_BUG_ALU_RESULT",
            "expected_detection": "PC/instruction_stream_divergence",
            "observed_detection": spike[0].get("first_mismatch", "") if spike else "none",
            "status": "PASS" if spike and spike[0]["status"] == "PASS" and spike[0]["detected"] == "1" else "FAIL",
            "evidence": str(spike_report.relative_to(ROOT.parent)),
        },
        {
            "oracle": "ACT4/Sail",
            "mutation": "RV32_BUG_MSCRATCH_WRITE_DROP",
            "expected_detection": "self_checking_Zicsr_mailbox_failure",
            "observed_detection": f"{sum(item['status'] == 'FAIL' for item in act)} failing Zicsr tests",
            "status": "PASS" if any(item["status"] == "FAIL" for item in act) else "FAIL",
            "evidence": str(act_report.relative_to(ROOT.parent)),
        },
        {
            "oracle": "SymbiYosys_custom_RVFI",
            "mutation": "RV32_BUG_MSCRATCH_WRITE_DROP",
            "expected_detection": "bounded_counterexample",
            "observed_detection": formal[0].get("detail", "") if formal else "none",
            "status": "PASS" if formal and formal[0]["status"] == "PASS" else "FAIL",
            "evidence": str(formal_report.relative_to(ROOT.parent)),
        },
    ]
    REPORT.parent.mkdir(exist_ok=True)
    with REPORT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    passed = sum(item["status"] == "PASS" for item in rows)
    print(f"External-oracle mutation matrix: {passed}/{len(rows)}")
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
