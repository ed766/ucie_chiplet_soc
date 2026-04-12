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


def main() -> int:
    parser = argparse.ArgumentParser(description="Write a coverage closure matrix markdown file.")
    parser.add_argument("--coverage", required=True, help="Coverage summary CSV.")
    parser.add_argument("--history", required=True, help="Regression history CSV.")
    parser.add_argument("--output", required=True, help="Destination markdown path.")
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
