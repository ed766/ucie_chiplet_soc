#!/usr/bin/env python3
"""Summarize directed negative tests separately from bug-injection modes."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPORT_ROOT = ROOT / "reports"
DOC_OUT = ROOT.parent / "docs" / "negative_test_summary.md"


@dataclass(frozen=True)
class NegativeCase:
    test: str
    illegal_action: str
    expected_response: str
    checker: str
    coverage_bin: str


NEGATIVE_CASES: tuple[NegativeCase, ...] = (
    NegativeCase("dma_comp_pop_empty", "Pop an empty completion FIFO.", "No-op; no synthetic completion appears.", "dma_csr_irq_checker", "dma_comp_occ_0"),
    NegativeCase("dma_queue_full_reject", "Submit while the internal submit queue is full.", "Submit-reject completion with ERR_QUEUE_FULL or reject-overflow accounting.", "dma_csr_irq_checker + completion scoreboard", "dma_reject_qfull"),
    NegativeCase("dma_crypto_only_submit_blocked", "Submit a descriptor in CRYPTO_ONLY.", "Submit-reject completion with ERR_SUBMIT_BLOCKED and no accepted descriptor.", "dma_csr_irq_checker", "dma_reject_blocked"),
    NegativeCase("mem_write_while_dma_reject", "Attempt maintenance write while DMA has active context.", "Maintenance write reject; source memory remains unchanged.", "memory scoreboard", "mem_write_reject"),
    NegativeCase("mem_op_start_busy_reject", "Start a maintenance op while another maintenance op is busy.", "MEM_OP_STATUS.op_reject_busy is set and active op is undisturbed.", "MEM_OP status checker", "mem_wait"),
    NegativeCase("mem_inject_start_busy_reject", "Start parity injection while maintenance op is busy.", "MEM_INJECT_STATUS.reject_busy is set and active op is undisturbed.", "MEM_INJECT status checker", "mem_wait"),
    NegativeCase("mem_parity_src_detect", "Consume a parity-bad source word through DMA.", "Runtime-error completion with ERR_MEM_PARITY and zero retired words.", "DMA/memory scoreboard", "mem_parity_dma"),
    NegativeCase("power_illegal_access_error_response", "Attempt unavailable-domain DMA submission in CRYPTO_ONLY.", "Blocked-submission reject path; descriptor not accepted.", "power proxy + DMA checker", "dma_reject_blocked"),
    NegativeCase("power_transition_with_link_backpressure", "Cross a power transition while link backpressure is active.", "No isolation/resume violation and traffic recovers cleanly.", "power_state_monitor", "retry_backpressure_cross"),
)


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def write_outputs(rows: list[dict[str, str]], csv_out: Path, md_out: Path) -> None:
    csv_out.parent.mkdir(parents=True, exist_ok=True)
    with csv_out.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "test",
                "illegal_action",
                "expected_response",
                "checker",
                "coverage_bin",
                "status",
                "meets_expectation",
                "detail",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    met = sum(1 for row in rows if row["meets_expectation"] == "1")
    lines = [
        "# Negative Test Summary",
        "",
        "This lane covers illegal software/protocol actions separately from compile-time bug-injection modes. Each case must fail if the illegal action silently succeeds.",
        "",
        f"- Negative cases meeting expectation: {met} / {len(rows)}",
        "",
        "| Test | Illegal action | Expected response | Checker | Coverage bin | Status |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| `{row['test']}` | {row['illegal_action']} | {row['expected_response']} | {row['checker']} | `{row['coverage_bin']}` | {row['status']} |"
        )
    md_out.parent.mkdir(parents=True, exist_ok=True)
    md_out.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Write negative-test summary artifacts.")
    parser.add_argument("--summary", default=str(REPORT_ROOT / "negative_regress_summary.csv"))
    parser.add_argument("--csv-out", default=str(REPORT_ROOT / "negative_test_summary.csv"))
    parser.add_argument("--md-out", default=str(DOC_OUT))
    args = parser.parse_args()

    by_test = {row.get("test", ""): row for row in read_rows(Path(args.summary))}
    out_rows: list[dict[str, str]] = []
    for case in NEGATIVE_CASES:
        row = by_test.get(case.test, {})
        meets = row.get("meets_expectation", "0")
        status = "PASS" if meets == "1" else ("NOT_RUN" if not row else "FAIL")
        out_rows.append(
            {
                "test": case.test,
                "illegal_action": case.illegal_action,
                "expected_response": case.expected_response,
                "checker": case.checker,
                "coverage_bin": case.coverage_bin,
                "status": status,
                "meets_expectation": meets,
                "detail": row.get("detail", "missing_negative_run"),
            }
        )

    write_outputs(out_rows, Path(args.csv_out), Path(args.md_out))
    missing = [row for row in out_rows if row["meets_expectation"] != "1"]
    print(f"Negative test summary: {len(out_rows) - len(missing)}/{len(out_rows)} cases met expectation")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
