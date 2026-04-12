#!/usr/bin/env python3
"""Bucket regression failures and emit markdown summaries."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


def bucket_failure(detail: str, log_text: str) -> str:
    text = f"{detail}\n{log_text}"
    if "CREDIT_EXPECTED_MATCH" in text or "credit_assertion" in text:
        return "credit_accounting"
    if "CRC_INTEGRITY_UNEXPECTED" in text or "crc_integrity" in text:
        return "crc_integrity"
    if "Retry payload mismatch" in text or "retry_identity" in text:
        return "retry_identity"
    if "dma_config_violation" in text or "dma_irq_mask_violation" in text:
        return "dma_config"
    if "dma_completion_violation" in text:
        return "dma_completion"
    if "dma_memory_compare_violation" in text:
        return "dma_memory_compare"
    if "memory_integrity_violation" in text:
        return "memory_integrity"
    if "memory_retention_violation" in text or "memory_power_mode_violation" in text:
        return "memory_retention"
    if "memory_bank_conflict_violation" in text or "memory_read_visibility_violation" in text or "memory_write_reject_violation" in text:
        return "memory_banking"
    if "LINK_PROGRESS_BOUNDED" in text or "link_progress" in text:
        return "link_progress"
    if "LINK_TRAINING_BOUNDED" in text or "link_training" in text:
        return "link_training"
    if "scoreboard_violation" in text or "Scoreboard violations" in text:
        return "flit_scoreboard"
    if "Ciphertext mismatches" in text or "e2e_scoreboard" in text:
        return "end_to_end_data"
    if "compile_failure" in text:
        return "compile"
    return "uncategorized"


def read_overall_coverage(path: Path) -> tuple[int, int, float]:
    if not path.exists():
        return 0, 0, 0.0
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            if row["metric"] == "__overall__":
                covered = int(row["covered"])
                total = int(row["total_bins"])
                pct = float(row["sum_value"])
                return covered, total, pct
    return 0, 0, 0.0


def read_power_rows(path: Path) -> tuple[dict[str, str] | None, list[dict[str, str]]]:
    if not path.exists():
        return None, []
    rows = list(csv.DictReader(path.open(newline="")))
    overall = next((row for row in rows if row["test"] == "__overall__"), None)
    tests = [row for row in rows if row["test"] != "__overall__"]
    return overall, tests


def main() -> int:
    parser = argparse.ArgumentParser(description="Bucket failures and write markdown dashboards.")
    parser.add_argument("--summary", required=True, help="Regression summary CSV.")
    parser.add_argument("--coverage", required=True, help="Coverage summary CSV.")
    parser.add_argument("--power-summary", required=True, help="Power-state summary CSV.")
    parser.add_argument("--failure-csv", required=True, help="Failure bucket CSV output.")
    parser.add_argument("--top-failures", required=True, help="Top failures markdown output.")
    parser.add_argument("--dashboard", required=True, help="Verification dashboard markdown output.")
    args = parser.parse_args()

    summary_path = Path(args.summary)
    coverage_path = Path(args.coverage)
    power_summary_path = Path(args.power_summary)
    failure_csv = Path(args.failure_csv)
    top_failures_md = Path(args.top_failures)
    dashboard_md = Path(args.dashboard)

    rows = list(csv.DictReader(summary_path.open(newline="")))
    failure_rows = []
    buckets: dict[str, dict[str, object]] = defaultdict(lambda: {
        "count": 0,
        "unexpected": 0,
        "expected": 0,
        "tests": set(),
        "example_run_id": "",
        "example_detail": "",
        "example_log": "",
    })

    nominal_total = 0
    nominal_pass = 0
    total_runs = len(rows)
    meets_expectation = sum(1 for row in rows if row["meets_expectation"] == "1")
    random_total = 0
    random_pass = 0
    expected_bug_failures = 0

    for row in rows:
        is_random = row["scenario"] == "random"
        if is_random:
            random_total += 1
            if row["meets_expectation"] == "1":
                random_pass += 1
        if row["expected_status"] == "PASS":
            nominal_total += 1
            if row["status"] == "PASS":
                nominal_pass += 1
        elif row["status"] == "FAIL" and row["meets_expectation"] == "1":
            expected_bug_failures += 1

        if row["status"] != "FAIL":
            continue
        log_path = Path(row["log_path"])
        log_text = log_path.read_text() if log_path.exists() else ""
        bucket = bucket_failure(row["detail"], log_text)
        failure_rows.append((row, bucket))
        entry = buckets[bucket]
        entry["count"] = int(entry["count"]) + 1
        if row["expected_status"] == "FAIL":
            entry["expected"] = int(entry["expected"]) + 1
        else:
            entry["unexpected"] = int(entry["unexpected"]) + 1
        entry["tests"].add(row["test"])
        if not entry["example_run_id"]:
            entry["example_run_id"] = row["run_id"]
            entry["example_detail"] = row["detail"]
            entry["example_log"] = row["log_path"]

    failure_csv.parent.mkdir(parents=True, exist_ok=True)
    with failure_csv.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "bucket",
                "count",
                "unexpected_failures",
                "expected_failures",
                "tests",
                "example_run_id",
                "example_detail",
                "example_log",
            ],
        )
        writer.writeheader()
        for bucket, entry in sorted(buckets.items()):
            writer.writerow(
                {
                    "bucket": bucket,
                    "count": entry["count"],
                    "unexpected_failures": entry["unexpected"],
                    "expected_failures": entry["expected"],
                    "tests": ";".join(sorted(entry["tests"])),
                    "example_run_id": entry["example_run_id"],
                    "example_detail": entry["example_detail"],
                    "example_log": entry["example_log"],
                }
            )

    unexpected_failures = sum(1 for row, _ in failure_rows if row["expected_status"] == "PASS")
    top_failures_lines = ["# Top Failures", ""]
    if unexpected_failures == 0:
        top_failures_lines.extend(
            [
                "No unexpected failures were observed in the default regression.",
                "",
                f"Expected bug-validation failures observed: {expected_bug_failures}",
            ]
        )
    else:
        top_failures_lines.append("| Bucket | Count | Tests | Example detail |")
        top_failures_lines.append("| --- | ---: | --- | --- |")
        for bucket, entry in sorted(buckets.items(), key=lambda item: (-int(item[1]["unexpected"]), item[0])):
            if int(entry["unexpected"]) == 0:
                continue
            top_failures_lines.append(
                f"| `{bucket}` | {entry['unexpected']} | {', '.join(sorted(entry['tests']))} | {entry['example_detail']} |"
            )
    top_failures_md.write_text("\n".join(top_failures_lines) + "\n")

    covered_bins, total_bins, coverage_pct = read_overall_coverage(coverage_path)
    power_overall, power_tests = read_power_rows(power_summary_path)
    bug_rows = [row for row in rows if row["expected_status"] == "FAIL"]
    dma_rows = [row for row in rows if row["test"].startswith("dma_")]
    dma_nominal_rows = [row for row in dma_rows if row["expected_status"] == "PASS"]
    dma_bug_rows = [row for row in dma_rows if row["expected_status"] == "FAIL"]
    mem_rows = [row for row in rows if row["test"].startswith("mem_")]
    mem_nominal_rows = [row for row in mem_rows if row["expected_status"] == "PASS"]
    mem_bug_rows = [row for row in mem_rows if row["expected_status"] == "FAIL"]
    bug_table = []
    for row in bug_rows:
        bug_table.append(
            f"| `{row['test']}` | `{row['bug_mode']}` | {row['status']} | {row['meets_expectation']} | {row['detail']} |"
        )

    dashboard_lines = [
        "# Verification Dashboard",
        "",
        "## Regression Snapshot",
        "",
        "| Metric | Value |",
        "| --- | ---: |",
        f"| Total runs | {total_runs} |",
        f"| Runs meeting expectation | {meets_expectation} |",
        f"| Nominal pass rate | {nominal_pass}/{nominal_total} |",
        f"| Randomized runs meeting expectation | {random_pass}/{random_total} |",
        f"| Unexpected failures | {unexpected_failures} |",
        f"| Expected bug-validation failures | {expected_bug_failures} |",
        "",
        "## Coverage Snapshot",
        "",
        "| Metric | Value |",
        "| --- | ---: |",
        f"| Covered functional bins | {covered_bins}/{total_bins} |",
        f"| Functional coverage percent | {coverage_pct:.1f}% |",
            "",
            "## Bug Validation",
            "",
            "| Test | Bug mode | Observed status | Meets expectation | Detail |",
            "| --- | --- | --- | --- | --- |",
    ]
    if bug_table:
        dashboard_lines.extend(bug_table)
    else:
        dashboard_lines.append("| _none_ | _none_ | _none_ | _none_ | _none_ |")

    dashboard_lines.extend(
        [
            "",
            "## DMA Verification",
            "",
            "| Metric | Value |",
            "| --- | ---: |",
            f"| DMA nominal runs meeting expectation | {sum(1 for row in dma_nominal_rows if row['meets_expectation'] == '1')}/{len(dma_nominal_rows)} |",
            f"| DMA bug-validation runs meeting expectation | {sum(1 for row in dma_bug_rows if row['meets_expectation'] == '1')}/{len(dma_bug_rows)} |",
            "",
            "| Test | Status | Detail | DMA desc | DMA irq | DMA err | DMA mem mismatch |",
            "| --- | --- | --- | ---: | ---: | ---: | ---: |",
        ]
    )
    if dma_rows:
        for row in dma_rows:
            dashboard_lines.append(
                f"| `{row['test']}` | {row['status']} | {row['detail']} | "
                f"{row.get('dma_desc_completed', '') or '0'} | "
                f"{row.get('dma_irq_count', '') or '0'} | "
                f"{row.get('dma_error_count', '') or '0'} | "
                f"{row.get('dma_mem_mismatch', '') or '0'} |"
            )
    else:
        dashboard_lines.append("| _none_ | _none_ | _none_ | 0 | 0 | 0 | 0 |")

    dashboard_lines.extend(
        [
            "",
            "## Memory Verification",
            "",
            "| Metric | Value |",
            "| --- | ---: |",
            f"| Memory nominal runs meeting expectation | {sum(1 for row in mem_nominal_rows if row['meets_expectation'] == '1')}/{len(mem_nominal_rows)} |",
            f"| Memory bug-validation runs meeting expectation | {sum(1 for row in mem_bug_rows if row['meets_expectation'] == '1')}/{len(mem_bug_rows)} |",
            "",
            "## Power-State Proxy Verification",
            "",
            "| Metric | Value |",
            "| --- | ---: |",
        ]
    )
    if power_overall is not None:
        dashboard_lines.append(f"| States visited | {power_overall['states_visited']} |")
        dashboard_lines.append(f"| Transitions visited | {power_overall['transitions_visited']} |")
        dashboard_lines.append(f"| Power tests meeting expectation | {power_overall['meets_expectation']}/{len(power_tests)} |")
    else:
        dashboard_lines.append("| States visited | 0/4 |")
        dashboard_lines.append("| Transitions visited | 0/6 |")
        dashboard_lines.append("| Power tests meeting expectation | 0/0 |")

    dashboard_lines.extend(
        [
            "",
            "| Test | Mode | Status | Illegal activity | Resume violations | States |",
            "| --- | --- | --- | ---: | ---: | --- |",
        ]
    )
    if power_tests:
        for row in power_tests:
            dashboard_lines.append(
                f"| `{row['test']}` | `{row['power_mode']}` | {row['status']} | "
                f"{row['illegal_activity_violations']} | {row['resume_violations']} | "
                f"{row['visited_states'].replace(';', ', ')} |"
            )
    else:
        dashboard_lines.append("| _none_ | _none_ | _none_ | 0 | 0 | _none_ |")

    dashboard_lines.extend(
        [
            "",
            "## Failure Buckets",
            "",
            "| Bucket | Count | Unexpected | Expected |",
            "| --- | ---: | ---: | ---: |",
        ]
    )
    if buckets:
        for bucket, entry in sorted(buckets.items()):
            dashboard_lines.append(
                f"| `{bucket}` | {entry['count']} | {entry['unexpected']} | {entry['expected']} |"
            )
    else:
        dashboard_lines.append("| _none_ | 0 | 0 | 0 |")

    dashboard_md.write_text("\n".join(dashboard_lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
