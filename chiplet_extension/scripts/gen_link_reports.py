#!/usr/bin/env python3
"""Aggregate chiplet link metrics into summary CSV files.

This script consumes raw CSV entries located in ../reports and produces
an updated comparison table while preserving headers for downstream tools.
"""

from __future__ import annotations

import argparse
import csv
import pathlib
from typing import Dict, List


def load_csv(path: pathlib.Path) -> List[Dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader)


def write_csv(path: pathlib.Path, fieldnames: List[str], rows: List[Dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def generate_summary(reports_dir: pathlib.Path) -> None:
    bw_latency = load_csv(reports_dir / "link_bw_latency.csv")
    energy = load_csv(reports_dir / "energy_bit.csv")

    if not bw_latency:
        return

    summary_rows: List[Dict[str, str]] = []
    for entry in bw_latency:
        summary = dict(entry)
        for energy_entry in energy:
            if energy_entry.get("run_id") == entry.get("run_id"):
                summary["energy_pj_per_bit"] = energy_entry.get("energy_pj_per_bit", "")
                break
        summary_rows.append(summary)

    write_csv(reports_dir / "link_summary.csv", list(summary_rows[0].keys()), summary_rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate chiplet link summary reports")
    parser.add_argument("--reports", default="../reports", help="Path to reports directory")
    args = parser.parse_args()

    reports_dir = pathlib.Path(args.reports).resolve()
    generate_summary(reports_dir)


if __name__ == "__main__":
    main()
