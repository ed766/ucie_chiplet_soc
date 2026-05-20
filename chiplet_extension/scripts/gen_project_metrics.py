#!/usr/bin/env python3
"""Generate one resume-facing project metrics snapshot from canonical reports."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = ROOT.parent
REPORTS = ROOT / "reports"
DOCS = REPO_ROOT / "docs"


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def yes(value: str) -> bool:
    return value in {"1", "yes", "true", "PASS", "pass"}


def count_total(rows: list[dict[str, str]], predicate) -> tuple[int, int]:
    return sum(1 for row in rows if predicate(row)), len(rows)


def metric_pair(numer: int, denom: int) -> str:
    return f"{numer} / {denom}" if denom else "NA"


def assertion_count(path: Path) -> str:
    if not path.exists():
        return "NA"
    text = path.read_text()
    match = re.search(r"Total inventoried assertions/invariants:\s*(\d+)", text)
    return match.group(1) if match else "NA"


def overall_coverage(rows: list[dict[str, str]]) -> tuple[str, str]:
    row = next((item for item in rows if item.get("metric") == "__overall__"), None)
    if not row:
        return "NA", "NA"
    return metric_pair(int(row.get("covered", "0")), int(row.get("total_bins", "0"))), row.get("sum_value", "NA")


def power_summary(rows: list[dict[str, str]]) -> tuple[str, str]:
    detail_rows = [row for row in rows if row.get("test") != "__overall__"]
    passed = sum(1 for row in detail_rows if yes(row.get("meets_expectation", "")))
    overall = next((row for row in rows if row.get("test") == "__overall__"), {})
    targets = ", ".join(
        value
        for value in [
            overall.get("states_visited", ""),
            overall.get("transitions_visited", ""),
            overall.get("domain_combos_visited", ""),
            overall.get("isolation_bins_visited", ""),
            overall.get("retention_bins_visited", ""),
            overall.get("activity_cross_bins_visited", ""),
        ]
        if value
    )
    return metric_pair(passed, len(detail_rows)), targets or "NA"


def cross_summary(rows: list[dict[str, str]]) -> str:
    if not rows:
        return "NA"
    observed = sum(1 for row in rows if row.get("status") == "observed")
    return metric_pair(observed, len(rows))


def random_stress_summary(rows: list[dict[str, str]]) -> str:
    if not rows:
        return "NA"
    passed = sum(1 for row in rows if yes(row.get("meets_expectation", "")))
    return metric_pair(passed, len(rows))


def generate(csv_out: Path, md_out: Path) -> None:
    regress = read_csv(REPORTS / "regress_summary.csv")
    coverage = read_csv(REPORTS / "coverage_summary.csv")
    power = read_csv(REPORTS / "power_state_summary.csv")
    cross = read_csv(REPORTS / "cross_coverage_summary.csv")
    true_cross = read_csv(REPORTS / "true_cross_coverage_summary.csv")
    random_stress = read_csv(REPORTS / "random_stress_regress_summary.csv")
    formal = read_csv(REPORTS / "formal_summary.csv")
    negative = read_csv(REPORTS / "negative_test_summary.csv")

    stable_pass = sum(1 for row in regress if yes(row.get("meets_expectation", "")))
    nominal_rows = [row for row in regress if row.get("expected_status") == "PASS"]
    nominal_pass = sum(1 for row in nominal_rows if row.get("status") == "PASS")
    randomized_rows = [row for row in regress if row.get("scenario") == "random"]
    randomized_pass = sum(1 for row in randomized_rows if yes(row.get("meets_expectation", "")))
    bug_rows = [row for row in regress if row.get("expected_status") == "FAIL"]
    bug_pass = sum(1 for row in bug_rows if yes(row.get("meets_expectation", "")))
    dma_rows = [row for row in regress if row.get("test", "").startswith("dma_") and row.get("expected_status") == "PASS"]
    dma_pass = sum(1 for row in dma_rows if row.get("status") == "PASS")
    mem_rows = [row for row in regress if row.get("test", "").startswith("mem_") and row.get("expected_status") == "PASS"]
    mem_pass = sum(1 for row in mem_rows if row.get("status") == "PASS")
    formal_pass = sum(1 for row in formal if yes(row.get("meets_expectation", "")))
    negative_pass = sum(1 for row in negative if yes(row.get("meets_expectation", "")))

    coverage_pair, coverage_pct = overall_coverage(coverage)
    power_pair, power_targets = power_summary(power)
    cross_pair = cross_summary(cross)
    true_cross_pair = cross_summary(true_cross)
    random_pair = random_stress_summary(random_stress)
    assertions = assertion_count(DOCS / "assertion_inventory.md")

    metrics = [
        ("stable_runs", metric_pair(stable_pass, len(regress)), "Default stable/closure regression rows meeting expectation."),
        ("nominal_pass_rate", metric_pair(nominal_pass, len(nominal_rows)), "Expected-pass rows with PASS status."),
        ("randomized_stable_runs", metric_pair(randomized_pass, len(randomized_rows)), "Randomized rows inside the stable gate."),
        ("expected_bug_failures", metric_pair(bug_pass, len(bug_rows)), "Expected-fail bug-validation rows that failed as intended."),
        ("dma_nominal_runs", metric_pair(dma_pass, len(dma_rows)), "Expected-pass DMA rows."),
        ("memory_nominal_runs", metric_pair(mem_pass, len(mem_rows)), "Expected-pass memory rows."),
        ("functional_coverage", coverage_pair, f"Flat closure bins, {coverage_pct}% covered."),
        ("low_power_proxy_targets", power_pair, f"Low-power proxy rows; aggregate targets: {power_targets}."),
        ("cross_coverage_groups", cross_pair, "Grouped cross-evidence derived from flat coverage metrics."),
        ("true_cross_groups", true_cross_pair, "Interaction-level cross evidence when generated."),
        ("bounded_property_checks", metric_pair(formal_pass, len(formal)), "Nominal and expected-fail bounded assertion harnesses."),
        ("negative_tests", metric_pair(negative_pass, len(negative)), "Illegal-operation tests with explicit expected response."),
        ("optional_random_stress_subset", random_pair, "Optional seeded-random execution subset; not part of default closure."),
        ("assertion_inventory", assertions, "Inventoried protocol/control invariants."),
    ]

    csv_out.parent.mkdir(parents=True, exist_ok=True)
    with csv_out.open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["metric", "value", "note"])
        writer.writerows(metrics)

    lines = [
        "# Project Metrics",
        "",
        "This is the single resume-facing metrics snapshot for the chiplet project. It is generated from the canonical CSV reports by `make -C chiplet_extension project-metrics`.",
        "",
        "| Metric | Value | Note |",
        "| --- | --- | --- |",
    ]
    for metric, value, note in metrics:
        lines.append(f"| `{metric}` | `{value}` | {note} |")
    lines.extend(
        [
            "",
            "## Claim Boundary",
            "",
            "- `stable_runs`, `functional_coverage`, `low_power_proxy_targets`, `bounded_property_checks`, and `expected_bug_failures` are the core evidence set.",
            "- `optional_random_stress_subset`, UVM artifacts, and characterization reports are useful supporting evidence, but they are not the default closure gate.",
            "- Raw per-test CSVs are generated artifacts; the checked-in project should keep summaries and curated documentation instead.",
            "",
        ]
    )
    md_out.parent.mkdir(parents=True, exist_ok=True)
    md_out.write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate project metrics from canonical report artifacts.")
    parser.add_argument("--csv-out", default=str(REPORTS / "project_metrics.csv"))
    parser.add_argument("--md-out", default=str(DOCS / "project_metrics.md"))
    args = parser.parse_args()
    generate(Path(args.csv_out), Path(args.md_out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
