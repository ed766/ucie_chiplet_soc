#!/usr/bin/env python3
"""Aggregate per-run coverage CSVs into a regression coverage summary."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


COVERAGE_METRICS = [
    "link_reset",
    "link_train",
    "link_active",
    "link_retrain",
    "link_degraded",
    "link_recoveries",
    "credit_zero",
    "credit_low",
    "credit_mid",
    "credit_high",
    "backpressure",
    "crc_error",
    "resend_request",
    "lane_fault",
    "retry_backpressure_cross",
    "latency_low",
    "latency_nominal",
    "latency_high",
    "e2e_updates",
    "e2e_mismatch",
    "expected_empty",
    "power_reset_proxy",
    "power_idle_proxy",
]


def metric_category(metric: str) -> str:
    if metric.startswith("link_"):
        return "link_fsm"
    if metric.startswith("credit_"):
        return "credits"
    if metric in {"backpressure", "retry_backpressure_cross"}:
        return "backpressure"
    if metric in {"crc_error", "resend_request", "lane_fault"}:
        return "retry_fault"
    if metric.startswith("latency_"):
        return "latency"
    if metric.startswith("e2e_") or metric == "expected_empty":
        return "end_to_end"
    return "power"


def main() -> int:
    parser = argparse.ArgumentParser(description="Aggregate coverage CSVs referenced by regress_summary.csv.")
    parser.add_argument("--summary", required=True, help="Regression summary CSV.")
    parser.add_argument("--output", required=True, help="Coverage summary CSV.")
    args = parser.parse_args()

    summary_path = Path(args.summary)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    metric_totals: dict[str, dict[str, object]] = {
        metric: {"hit_runs": 0, "sum_value": 0, "max_value": 0, "tests_hit": set()}
        for metric in COVERAGE_METRICS
    }
    total_runs = 0

    with summary_path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            cov_csv = row.get("cov_csv", "").strip()
            if not cov_csv:
                continue
            cov_path = Path(cov_csv)
            if not cov_path.exists():
                continue
            total_runs += 1
            metrics = {}
            with cov_path.open(newline="") as cov_handle:
                cov_reader = csv.DictReader(cov_handle)
                for cov_row in cov_reader:
                    metrics[cov_row["metric"]] = cov_row["value"]
            for metric in COVERAGE_METRICS:
                value = int(metrics.get(metric, "0"))
                bucket = metric_totals[metric]
                bucket["sum_value"] = int(bucket["sum_value"]) + value
                bucket["max_value"] = max(int(bucket["max_value"]), value)
                if value > 0:
                    bucket["hit_runs"] = int(bucket["hit_runs"]) + 1
                    bucket["tests_hit"].add(row["test"])

    covered_bins = sum(1 for metric in COVERAGE_METRICS if int(metric_totals[metric]["hit_runs"]) > 0)
    coverage_pct = (100.0 * covered_bins / len(COVERAGE_METRICS)) if COVERAGE_METRICS else 0.0

    with output_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "metric",
                "category",
                "hit_runs",
                "total_runs",
                "covered",
                "total_bins",
                "sum_value",
                "max_value",
                "tests_hit",
            ],
        )
        writer.writeheader()
        writer.writerow(
            {
                "metric": "__overall__",
                "category": "summary",
                "hit_runs": covered_bins,
                "total_runs": total_runs,
                "covered": covered_bins,
                "total_bins": len(COVERAGE_METRICS),
                "sum_value": f"{coverage_pct:.1f}",
                "max_value": covered_bins,
                "tests_hit": "",
            }
        )
        for metric in COVERAGE_METRICS:
            bucket = metric_totals[metric]
            writer.writerow(
                {
                    "metric": metric,
                    "category": metric_category(metric),
                    "hit_runs": bucket["hit_runs"],
                    "total_runs": total_runs,
                    "covered": 1 if int(bucket["hit_runs"]) > 0 else 0,
                    "total_bins": 1,
                    "sum_value": bucket["sum_value"],
                    "max_value": bucket["max_value"],
                    "tests_hit": ";".join(sorted(bucket["tests_hit"])),
                }
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
