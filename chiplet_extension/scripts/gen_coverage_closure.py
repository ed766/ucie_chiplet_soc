#!/usr/bin/env python3
"""Generate a compact coverage-closure markdown report."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def write_cross_summary(path: Path, coverage_rows: list[dict[str, str]]) -> None:
    covered_by_metric = {
        row["metric"]: int(row["covered"])
        for row in coverage_rows
        if row["metric"] != "__overall__"
    }
    tests_by_metric = {
        row["metric"]: row.get("tests_hit", "")
        for row in coverage_rows
        if row["metric"] != "__overall__"
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "cross_group",
                "required_metrics",
                "observed_metrics",
                "missing_metrics",
                "status",
                "source_tests",
            ],
        )
        writer.writeheader()
        for cross_name, metrics in CROSS_GROUPS.items():
            observed_metrics = [metric for metric in metrics if covered_by_metric.get(metric, 0)]
            missing_metrics = [metric for metric in metrics if not covered_by_metric.get(metric, 0)]
            source_tests: set[str] = set()
            for metric in observed_metrics:
                source_tests.update(test for test in tests_by_metric.get(metric, "").split(";") if test)
            writer.writerow(
                {
                    "cross_group": cross_name,
                    "required_metrics": ";".join(metrics),
                    "observed_metrics": ";".join(observed_metrics),
                    "missing_metrics": ";".join(missing_metrics),
                    "status": "observed" if not missing_metrics else "missing",
                    "source_tests": ";".join(sorted(source_tests)),
                }
            )


def coverage_area(metric: str) -> str:
    if metric.startswith("dma_"):
        return "DMA"
    if metric.startswith("mem_"):
        return "Memory"
    if metric.startswith("power_"):
        return "Power"
    if metric.startswith("e2e_") or metric == "expected_empty":
        return "AES/service"
    return "Link"


AREA_EXAMPLES = {
    "DMA": "queue occupancy, completion FIFO, timeout, reject, retire stall",
    "Link": "training, retry, CRC fault, lane fault, latency, backpressure",
    "Memory": "bank conflict, wait, parity, invalid bank, retention wake",
    "Power": "reset and idle proxy bins; PST/isolation/retention closure is summarized in power_state_summary.csv",
    "AES/service": "end-to-end updates, mismatch detection, expected-empty, return ordering",
}


CROSS_GROUPS = {
    "DMA length x queue occupancy": (
        "dma_submit_occ_0",
        "dma_submit_occ_1",
        "dma_submit_occ_23",
        "dma_submit_occ_4",
        "dma_multi_queued",
    ),
    "DMA active x power transition": (
        "dma_active_present",
        "dma_completion_after_sleep_resume",
        "power_reset_proxy",
        "power_idle_proxy",
    ),
    "retry event x backpressure level": (
        "resend_request",
        "backpressure",
        "retry_backpressure_cross",
    ),
    "CRC fault x retry recovery": (
        "crc_error",
        "resend_request",
        "link_recoveries",
    ),
    "memory bank x retained/invalid state": (
        "mem_src_conflict",
        "mem_dst_conflict",
        "mem_invalid_bank_present",
        "mem_wake_apply",
    ),
    "parity error x completion status": (
        "mem_parity_maint",
        "mem_parity_dma",
        "dma_comp_runtime_error",
    ),
    "power state x isolation state": (
        "power_reset_proxy",
        "power_idle_proxy",
    ),
    "AES block count x return ordering": (
        "e2e_updates",
        "e2e_mismatch",
        "expected_empty",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Write a coverage closure matrix markdown file.")
    parser.add_argument("--coverage", required=True, help="Coverage summary CSV.")
    parser.add_argument("--history", required=True, help="Regression history CSV.")
    parser.add_argument("--output", required=True, help="Destination markdown path.")
    parser.add_argument("--cross-output", default="", help="Optional destination CSV for cross-coverage summary.")
    args = parser.parse_args()

    coverage_rows = read_rows(Path(args.coverage))
    history_rows = read_rows(Path(args.history))
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    overall_cov = next((row for row in coverage_rows if row["metric"] == "__overall__"), None)
    prev_row = history_rows[-2] if len(history_rows) >= 2 else None
    curr_row = history_rows[-1] if history_rows else None

    lines = [
        "# Coverage Closure Matrix",
        "",
        "## Trend",
        "",
        "| Snapshot | Covered bins | Coverage percent |",
        "| --- | ---: | ---: |",
    ]

    if prev_row is not None:
        lines.append(
            f"| Previous stable | {prev_row['covered_bins']}/{prev_row['total_bins']} | {float(prev_row['coverage_pct']):.1f}% |"
        )
    if curr_row is not None:
        lines.append(
            f"| Current stable | {curr_row['covered_bins']}/{curr_row['total_bins']} | {float(curr_row['coverage_pct']):.1f}% |"
        )
    if curr_row is None and overall_cov is not None:
        lines.append(
            f"| Current stable | {overall_cov['covered']}/{overall_cov['total_bins']} | {float(overall_cov['sum_value']):.1f}% |"
        )

    lines.extend(
        [
            "",
            "## Feature-Grouped Coverage",
            "",
            "| Area | Covered bins | Example bins |",
            "| --- | ---: | --- |",
        ]
    )

    area_totals: dict[str, dict[str, int]] = {
        area: {"covered": 0, "total": 0} for area in AREA_EXAMPLES
    }
    for row in coverage_rows:
        if row["metric"] == "__overall__":
            continue
        area = coverage_area(row["metric"])
        area_totals[area]["total"] += 1
        area_totals[area]["covered"] += int(row["covered"])
    for area in ("DMA", "Link", "Memory", "Power", "AES/service"):
        totals = area_totals[area]
        lines.append(f"| {area} | {totals['covered']}/{totals['total']} | {AREA_EXAMPLES[area]} |")

    covered_by_metric = {
        row["metric"]: int(row["covered"])
        for row in coverage_rows
        if row["metric"] != "__overall__"
    }
    lines.extend(
        [
            "",
            "## Cross-Coverage Evidence",
            "",
            "These cross groups are quality evidence layered on top of the canonical flat closure vector. They do not replace the `60 / 60` closure target.",
            "",
            "Optional seeded-random stress evidence is summarized separately in `docs/random_stress_summary.md`; it is useful for stress confidence but is not a gating closure target.",
            "",
            "| Cross group | Evidence metrics | Status |",
            "| --- | --- | --- |",
        ]
    )
    for cross_name, metrics in CROSS_GROUPS.items():
        observed = all(covered_by_metric.get(metric, 0) for metric in metrics)
        metric_text = ", ".join(f"`{metric}`" for metric in metrics)
        status = "observed" if observed else "missing evidence"
        lines.append(f"| {cross_name} | {metric_text} | {status} |")

    if args.cross_output:
        write_cross_summary(Path(args.cross_output), coverage_rows)

    lines.extend(
        [
            "",
            "## Coverage-to-Test Mapping",
            "",
            "| Metric | Category | Covered | Tests hitting bin |",
            "| --- | --- | ---: | --- |",
        ]
    )

    for row in coverage_rows:
        if row["metric"] == "__overall__":
            continue
        tests_hit = row["tests_hit"] if row["tests_hit"] else "_none_"
        lines.append(
            f"| `{row['metric']}` | `{row['category']}` | {row['covered']} | {tests_hit.replace(';', ', ')} |"
        )

    output_path.write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
