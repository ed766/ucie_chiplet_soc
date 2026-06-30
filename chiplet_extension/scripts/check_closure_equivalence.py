#!/usr/bin/env python3
"""Check functional/power closure and UVM-vs-non-UVM equivalence."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from gen_coverage_report import COVERAGE_METRICS


ROOT = Path(__file__).resolve().parent.parent
REPORT_ROOT = ROOT / "reports"

POWER_FRACTION_FIELDS = [
    "states_visited",
    "transitions_visited",
    "domain_combos_visited",
    "isolation_bins_visited",
    "retention_bins_visited",
    "activity_cross_bins_visited",
]


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def coverage_map(path: Path) -> dict[str, int]:
    rows = read_rows(path)
    return {
        row["metric"]: int(row.get("covered", "0") or "0")
        for row in rows
        if row.get("metric") and row["metric"] != "__overall__"
    }


def coverage_overall(path: Path) -> tuple[int, int]:
    for row in read_rows(path):
        if row.get("metric") == "__overall__":
            return int(row.get("covered", "0") or "0"), int(row.get("total_bins", "0") or "0")
    return 0, len(COVERAGE_METRICS)


def missing_coverage(path: Path) -> list[str]:
    cov = coverage_map(path)
    return [metric for metric in COVERAGE_METRICS if cov.get(metric, 0) == 0]


def power_overall(path: Path) -> dict[str, str]:
    for row in read_rows(path):
        if row.get("test") == "__overall__":
            return row
    return {}


def parse_fraction(value: str) -> tuple[int, int]:
    if "/" not in value:
        return 0, 0
    hit, total = value.split("/", 1)
    try:
        return int(hit), int(total)
    except ValueError:
        return 0, 0


def missing_power(path: Path) -> list[str]:
    overall = power_overall(path)
    missing = []
    for field in POWER_FRACTION_FIELDS:
        hit, total = parse_fraction(overall.get(field, "0/0"))
        if total == 0 or hit < total:
            missing.append(field)
    return missing


def bug_status(path: Path) -> tuple[int, list[str]]:
    rows = read_rows(path)
    bug_rows = [row for row in rows if row.get("expected_status") == "FAIL"]
    misses = [
        row.get("test", row.get("run_id", "unknown"))
        for row in bug_rows
        if row.get("meets_expectation") != "1"
    ]
    return len(bug_rows), misses


def add_row(rows: list[dict[str, str]], check: str, non_uvm: str, uvm: str, passed: bool, detail: str) -> None:
    rows.append(
        {
            "check": check,
            "non_uvm": non_uvm,
            "uvm": uvm,
            "status": "PASS" if passed else "FAIL",
            "detail": detail,
        }
    )


def write_outputs(rows: list[dict[str, str]], csv_out: Path, md_out: Path) -> None:
    csv_out.parent.mkdir(parents=True, exist_ok=True)
    with csv_out.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["check", "non_uvm", "uvm", "status", "detail"],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)

    md_lines = [
        "# Closure Equivalence",
        "",
        "| Check | Non-UVM | UVM | Status | Detail |",
        "| --- | ---: | ---: | --- | --- |",
    ]
    for row in rows:
        md_lines.append(
            f"| `{row['check']}` | {row['non_uvm']} | {row['uvm']} | {row['status']} | {row['detail']} |"
        )
    md_out.write_text("\n".join(md_lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Check closure and UVM/non-UVM equivalence.")
    parser.add_argument("--mode", choices=["nonuvm", "uvm", "equivalence"], default="equivalence")
    parser.add_argument("--non-uvm-summary", default=str(REPORT_ROOT / "regress_summary.csv"))
    parser.add_argument("--non-uvm-coverage", default=str(REPORT_ROOT / "coverage_summary.csv"))
    parser.add_argument("--non-uvm-power", default=str(REPORT_ROOT / "power_state_summary.csv"))
    parser.add_argument("--uvm-summary", default=str(REPORT_ROOT / "uvm_regress_summary.csv"))
    parser.add_argument("--uvm-coverage", default=str(REPORT_ROOT / "uvm_coverage_summary.csv"))
    parser.add_argument("--uvm-power", default=str(REPORT_ROOT / "uvm_power_state_summary.csv"))
    parser.add_argument("--csv-out", default=str(REPORT_ROOT / "closure_equivalence.csv"))
    parser.add_argument("--md-out", default=str(REPORT_ROOT / "closure_equivalence.md"))
    args = parser.parse_args()

    non_summary = Path(args.non_uvm_summary)
    non_cov = Path(args.non_uvm_coverage)
    non_power = Path(args.non_uvm_power)
    uvm_summary = Path(args.uvm_summary)
    uvm_cov = Path(args.uvm_coverage)
    uvm_power = Path(args.uvm_power)

    rows: list[dict[str, str]] = []

    if args.mode in {"nonuvm", "equivalence"}:
        non_missing_cov = missing_coverage(non_cov)
        non_cov_hit, non_cov_total = coverage_overall(non_cov)
        add_row(
            rows,
            "non_uvm_functional_coverage",
            f"{non_cov_hit}/{non_cov_total}",
            "",
            not non_missing_cov and non_cov_total == len(COVERAGE_METRICS),
            "missing=" + ";".join(non_missing_cov) if non_missing_cov else "all required bins covered",
        )
        non_missing_power = missing_power(non_power)
        add_row(
            rows,
            "non_uvm_power_coverage",
            "closed" if not non_missing_power else "open",
            "",
            not non_missing_power,
            "missing=" + ";".join(non_missing_power) if non_missing_power else "all power bins covered",
        )
        non_bug_count, non_bug_misses = bug_status(non_summary)
        add_row(
            rows,
            "non_uvm_expected_bug_results",
            str(non_bug_count),
            "",
            non_bug_count > 0 and not non_bug_misses,
            "misses=" + ";".join(non_bug_misses) if non_bug_misses else "expected failures met",
        )

    if args.mode in {"uvm", "equivalence"}:
        uvm_missing_cov = missing_coverage(uvm_cov)
        uvm_cov_hit, uvm_cov_total = coverage_overall(uvm_cov)
        add_row(
            rows,
            "uvm_functional_coverage",
            "",
            f"{uvm_cov_hit}/{uvm_cov_total}",
            not uvm_missing_cov and uvm_cov_total == len(COVERAGE_METRICS),
            "missing=" + ";".join(uvm_missing_cov) if uvm_missing_cov else "all required bins covered",
        )
        uvm_missing_power = missing_power(uvm_power)
        add_row(
            rows,
            "uvm_power_coverage",
            "",
            "closed" if not uvm_missing_power else "open",
            not uvm_missing_power,
            "missing=" + ";".join(uvm_missing_power) if uvm_missing_power else "all power bins covered",
        )
        uvm_bug_count, uvm_bug_misses = bug_status(uvm_summary)
        add_row(
            rows,
            "uvm_expected_bug_results",
            "",
            str(uvm_bug_count),
            uvm_bug_count > 0 and not uvm_bug_misses,
            "misses=" + ";".join(uvm_bug_misses) if uvm_bug_misses else "expected failures met",
        )

    if args.mode == "equivalence":
        non_cov_map = coverage_map(non_cov)
        uvm_cov_map = coverage_map(uvm_cov)
        missing_equiv = [
            metric for metric in COVERAGE_METRICS
            if non_cov_map.get(metric, 0) > 0 and uvm_cov_map.get(metric, 0) == 0
        ]
        add_row(
            rows,
            "coverage_vector_equivalence",
            "closed",
            "closed" if not missing_equiv else "open",
            not missing_equiv,
            "missing_uvm=" + ";".join(missing_equiv) if missing_equiv else "UVM covers all non-UVM-covered bins",
        )

        non_bug_count, non_bug_misses = bug_status(non_summary)
        uvm_bug_count, uvm_bug_misses = bug_status(uvm_summary)
        add_row(
            rows,
            "bug_result_equivalence",
            str(non_bug_count),
            str(uvm_bug_count),
            non_bug_count == uvm_bug_count and not non_bug_misses and not uvm_bug_misses,
            "expected bug counts/results match",
        )

    write_outputs(rows, Path(args.csv_out), Path(args.md_out))
    failures = [row for row in rows if row["status"] != "PASS"]
    if failures:
        for row in failures:
            print(f"{row['check']}: {row['detail']}")
        return 1
    print(f"Closure equivalence: {args.md_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
