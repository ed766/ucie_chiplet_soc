#!/usr/bin/env python3
"""Generate non-gating true cross-coverage evidence from per-run artifacts."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parent.parent
REPORT_ROOT = ROOT / "reports"
DOC_OUT = ROOT.parent / "docs" / "true_cross_coverage_summary.md"


def read_rows(path: Path | str) -> list[dict[str, str]]:
    path = Path(path)
    if not path.exists() or not str(path):
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def metric_map(path: str) -> dict[str, int]:
    values: dict[str, int] = {}
    for row in read_rows(path):
        try:
            values[row["metric"]] = int(row["value"])
        except (KeyError, ValueError):
            continue
    return values


def int_field(row: dict[str, str], field: str) -> int:
    try:
        return int(row.get(field, "0"))
    except ValueError:
        return 0


@dataclass(frozen=True)
class RunEvidence:
    row: dict[str, str]
    cov: dict[str, int]
    power: dict[str, int]
    score: dict[str, int]

    @property
    def test(self) -> str:
        return self.row.get("test", "")

    @property
    def scenario(self) -> str:
        return self.row.get("scenario", "")


@dataclass(frozen=True)
class CrossBin:
    group: str
    name: str
    criteria: str
    predicate: Callable[[RunEvidence], bool]


def any_metric(ev: RunEvidence, *names: str) -> bool:
    return any(ev.cov.get(name, 0) > 0 for name in names)


def all_metrics(ev: RunEvidence, *names: str) -> bool:
    return all(ev.cov.get(name, 0) > 0 for name in names)


CROSS_BINS: tuple[CrossBin, ...] = (
    CrossBin(
        "DMA length x submit occupancy",
        "dma_short_len_with_single_or_empty_queue",
        "DMA scenario has a short descriptor and observes submit occupancy 0/1.",
        lambda ev: ev.test in {"dma_queue_smoke", "random_manifest_scenario"}
        and any_metric(ev, "dma_submit_occ_0", "dma_submit_occ_1"),
    ),
    CrossBin(
        "DMA length x submit occupancy",
        "dma_multi_descriptor_with_queue_pressure",
        "Back-to-back/full-queue DMA scenario observes queue pressure with multiple accepted descriptors.",
        lambda ev: ev.test in {"dma_queue_back_to_back", "dma_queue_full_reject", "random_manifest_scenario"}
        and ev.cov.get("dma_submit_accept", 0) >= 2,
    ),
    CrossBin(
        "DMA activity x power transition",
        "dma_active_crosses_sleep_transition",
        "Same run observes active DMA and RUN<->SLEEP transition activity.",
        lambda ev: ev.power.get("activity_cross_dma_active", 0) > 0
        and ev.power.get("trans_run_to_sleep", 0) > 0
        and ev.power.get("trans_sleep_to_run", 0) > 0,
    ),
    CrossBin(
        "DMA activity x power transition",
        "completion_pending_or_queued_crosses_power_transition",
        "Same run observes queued/completion-pending DMA activity during a power transition.",
        lambda ev: (
            ev.power.get("activity_cross_dma_queued", 0) > 0
            or ev.power.get("activity_cross_completion_pending", 0) > 0
        )
        and (
            ev.power.get("trans_run_to_sleep", 0) > 0
            or ev.power.get("trans_run_to_crypto_only", 0) > 0
        ),
    ),
    CrossBin(
        "CRC/retry x backpressure",
        "crc_retry_under_backpressure",
        "Same run observes CRC error, resend/retry, and backpressure interaction.",
        lambda ev: all_metrics(ev, "crc_error", "resend_request", "retry_backpressure_cross"),
    ),
    CrossBin(
        "Lane fault x recovery",
        "lane_fault_retrains_and_recovers",
        "Same run observes lane fault, degraded/retrain state, and recovery.",
        lambda ev: all_metrics(ev, "lane_fault", "link_degraded", "link_recoveries"),
    ),
    CrossBin(
        "Memory bank x conflict/wait",
        "source_bank_conflict_with_wait",
        "Same run observes a source-bank conflict and maintenance wait.",
        lambda ev: all_metrics(ev, "mem_src_conflict", "mem_wait"),
    ),
    CrossBin(
        "Memory bank x conflict/wait",
        "destination_bank_conflict_with_wait",
        "Same run observes a destination-bank conflict and maintenance wait.",
        lambda ev: all_metrics(ev, "mem_dst_conflict", "mem_wait"),
    ),
    CrossBin(
        "Invalid memory x DMA error",
        "invalid_source_read_errors_without_success",
        "Same run observes invalid memory state and a DMA runtime error.",
        lambda ev: any_metric(ev, "mem_invalid_read", "mem_invalid_bank_present")
        and ev.cov.get("dma_comp_runtime_error", 0) > 0,
    ),
    CrossBin(
        "Parity x completion status",
        "source_parity_error_runtime_completion",
        "Same run observes source parity fault and runtime-error completion.",
        lambda ev: all_metrics(ev, "mem_parity_dma", "dma_comp_runtime_error"),
    ),
    CrossBin(
        "Parity x completion status",
        "maintenance_parity_error_reported",
        "Same run observes maintenance parity detection.",
        lambda ev: ev.cov.get("mem_parity_maint", 0) > 0,
    ),
    CrossBin(
        "Retention x post-wake validity",
        "retention_wake_produces_invalid_bank_state",
        "Same run observes wake application and invalid bank state.",
        lambda ev: all_metrics(ev, "mem_wake_apply", "mem_invalid_bank_present"),
    ),
    CrossBin(
        "Power state x isolation",
        "sleep_or_deep_sleep_isolation_asserted",
        "Same run observes powered-off state and asserted isolation.",
        lambda ev: (
            ev.power.get("sleep_cycles", 0) > 0
            or ev.power.get("deep_sleep_cycles", 0) > 0
        )
        and ev.power.get("isolation_assert_cycles", 0) > 0,
    ),
    CrossBin(
        "AES/service x return ordering",
        "aes_return_ordering_without_mismatch",
        "Same run observes end-to-end updates with no mismatch/drop.",
        lambda ev: ev.cov.get("e2e_updates", 0) > 0
        and int_field(ev.row, "mismatch") == 0
        and int_field(ev.row, "drop") == 0
        and int_field(ev.row, "e2e_mismatch") == 0,
    ),
)


def load_evidence(summary: Path) -> list[RunEvidence]:
    evidence: list[RunEvidence] = []
    for row in read_rows(summary):
        evidence.append(
            RunEvidence(
                row=row,
                cov=metric_map(row.get("cov_csv", "")),
                power=metric_map(row.get("power_csv", "")),
                score=metric_map(row.get("score_csv", "")),
            )
        )
    return evidence


def write_outputs(rows: list[dict[str, str]], csv_out: Path, md_out: Path) -> None:
    csv_out.parent.mkdir(parents=True, exist_ok=True)
    with csv_out.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["cross_group", "cross_bin", "status", "source_tests", "criteria"],
        )
        writer.writeheader()
        writer.writerows(rows)

    observed = sum(1 for row in rows if row["status"] == "observed")
    lines = [
        "# True Cross-Coverage Summary",
        "",
        "This report is non-gating quality evidence. It checks whether selected interactions occurred in the same run/window, while `coverage_summary.csv` remains the canonical `60 / 60` closure source.",
        "",
        f"- Observed true-cross bins: {observed} / {len(rows)}",
        "",
        "| Cross group | Cross bin | Status | Source tests |",
        "| --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| {row['cross_group']} | `{row['cross_bin']}` | {row['status']} | {row['source_tests'] or 'NA'} |"
        )
    md_out.parent.mkdir(parents=True, exist_ok=True)
    md_out.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate true cross-coverage evidence.")
    parser.add_argument("--summary", default=str(REPORT_ROOT / "regress_summary.csv"))
    parser.add_argument("--csv-out", default=str(REPORT_ROOT / "true_cross_coverage_summary.csv"))
    parser.add_argument("--md-out", default=str(DOC_OUT))
    args = parser.parse_args()

    evidence = load_evidence(Path(args.summary))
    rows: list[dict[str, str]] = []
    for cross in CROSS_BINS:
        sources = sorted({ev.test for ev in evidence if cross.predicate(ev)})
        rows.append(
            {
                "cross_group": cross.group,
                "cross_bin": cross.name,
                "status": "observed" if sources else "missing",
                "source_tests": ";".join(sources),
                "criteria": cross.criteria,
            }
        )

    write_outputs(rows, Path(args.csv_out), Path(args.md_out))
    missing = [row for row in rows if row["status"] != "observed"]
    print(f"True cross coverage: {len(rows) - len(missing)}/{len(rows)} bins observed")
    print(f"CSV: {args.csv_out}")
    print(f"Markdown: {args.md_out}")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
