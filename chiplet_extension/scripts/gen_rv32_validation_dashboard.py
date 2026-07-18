#!/usr/bin/env python3
"""Generate the reviewer-facing RV32 architectural validation dashboard."""

from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
REPORTS = ROOT / "reports"
OUTPUT = REPO / "docs" / "reference" / "rv32_external_validation.md"


def read(name: str) -> list[dict[str, str]]:
    path = REPORTS / name
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def tally(rows: list[dict[str, str]]) -> str:
    passed = sum(row.get("status") == "PASS" for row in rows)
    skipped = sum(row.get("status") == "SKIP" for row in rows)
    failed = sum(row.get("status") == "FAIL" for row in rows)
    return f"{passed} PASS / {skipped} SKIP / {failed} FAIL"


def main() -> int:
    tools = read("rv32_external_tool_status.csv")
    spike = read("rv32_external_iss_summary.csv")
    act = read("rv32_act_summary.csv")
    formal = read("rv32_formal_summary.csv")
    mutations = read("rv32_external_mutation_matrix.csv")

    lines = [
        "# RV32 Architectural Validation Dashboard",
        "",
        "This dashboard separates independent architectural oracles instead of treating one",
        "repository-local checker as proof of correctness. Results apply to the documented",
        "RV32I/Zicsr machine-mode subset; they are not RISC-V certification.",
        "",
        "## Release Evidence",
        "",
        "| Evidence lane | Current result | What it independently checks | Canonical report |",
        "| --- | ---: | --- | --- |",
        f"| Pinned dependency integrity | `{tally(tools)}` | Git revisions and archive SHA-256 values | `chiplet_extension/reports/rv32_external_tool_status.csv` |",
        f"| Spike CPU differential | `{tally(spike)}` | PC/instruction retirement prefix across ALU, ABI, data, CSR, control-flow, and optimizer variants | `chiplet_extension/reports/rv32_external_iss_summary.csv` |",
        f"| ACT4/Sail RTL execution | `{tally(act)}` | Self-checking generated RV32I/Zicsr architectural ELFs executed on RTL | `chiplet_extension/reports/rv32_act_summary.csv` |",
        f"| Standard/custom RVFI formal | `{tally(formal)}` | Instruction/register/PC ordering plus bounded CSR, trap, APB, interrupt, and `mscratch` properties | `chiplet_extension/reports/rv32_formal_summary.csv` |",
        f"| External-oracle mutation sensitivity | `{tally(mutations)}` | A real injected RTL defect is detected by each oracle family | `chiplet_extension/reports/rv32_external_mutation_matrix.csv` |",
        "",
        "## Behavior-to-Oracle Matrix",
        "",
        "| Architectural behavior | Local ISS | Spike | ACT4/Sail | SVA / formal |",
        "| --- | :---: | :---: | :---: | :---: |",
        "| RV32I ALU, branches, loads/stores | Full retirement replay | CPU-only differential | Generated architectural tests | Standard RVFI checks |",
        "| Compiler ABI and optimizer behavior | GPR/SRAM/signature replay | 12-program optimizer/ABI matrix | Not an ABI suite | Retirement/order invariants |",
        "| Zicsr including `mscratch` | CSR state transition model | CPU-only CSR program | Six Zicsr form suites | Directed SVA plus bounded next-state property |",
        "| Traps, `MRET`, external/timer IRQs | Precise machine-state model | CPU-only subset | Applicable architectural tests | Custom bounded properties |",
        "| APB, DMA, power, timer MMIO | Device-input and side-effect checks | Out of scope | Out of scope | APB/retirement and power-order assertions |",
        "",
        "## Mutation Sensitivity",
        "",
        "| Oracle | RTL mutation | Expected symptom | Result |",
        "| --- | --- | --- | ---: |",
    ]
    for row in mutations:
        lines.append(f"| `{row['oracle']}` | `{row['mutation']}` | {row['expected_detection']} | `{row['status']}` |")
    lines.extend([
        "",
        "The ACT4 report distinguishes dependency/generation failure, host timeout, RTL mailbox",
        "timeout, and self-checking mailbox failure. Failure rows include the last retired PC,",
        "mailbox value, expected result, observed result, and RVFI trace path; register-specific",
        "fields are explicitly `NA` when ACT's generated mailbox does not expose them.",
        "",
        "## Reproduce",
        "",
        "```bash",
        "make -C chiplet_extension rv32-external-tools-install",
        "make -C chiplet_extension rv32-external-iss-check",
        "make -C chiplet_extension rv32-act-check",
        "make -C chiplet_extension rv32-formal-check",
        "make -C chiplet_extension rv32-external-mutation-check",
        "```",
        "",
        "Release validation uses `--require`; missing, skipped, revision-mismatched, or",
        "checksum-mismatched external dependencies fail the release rather than producing a",
        "nominal success.",
    ])
    OUTPUT.write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
