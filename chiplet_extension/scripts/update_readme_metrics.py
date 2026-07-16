#!/usr/bin/env python3
"""Refresh the generated verification snapshot in the top-level README."""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
README = ROOT / "README.md"
METRICS = ROOT / "chiplet_extension" / "reports" / "project_metrics.csv"
START = "<!-- BEGIN GENERATED METRICS -->"
END = "<!-- END GENERATED METRICS -->"

SELECTED = (
    ("stable_runs", "Stable regression"),
    ("functional_coverage", "Functional coverage"),
    ("low_power_proxy_targets", "Low-power proxy targets"),
    ("firmware_soc_scenarios", "RV32 firmware scenarios"),
    ("real_uvm_ci", "Supporting real-UVM lane"),
    ("solver_formal_proofs", "Solver-backed proofs"),
    ("integrated_async_cdc", "Integrated async CDC ratios"),
    ("design_line_coverage", "Raw design line coverage"),
)


def main() -> int:
    values = {row["metric"]: row["value"] for row in csv.DictReader(METRICS.open())}
    missing = [key for key, _ in SELECTED if key not in values]
    if missing:
        raise SystemExit(f"Missing canonical metrics: {', '.join(missing)}")
    lines = [START, "| Evidence | Current result |", "| --- | ---: |"]
    lines.extend(f"| {label} | `{values[key]}` |" for key, label in SELECTED)
    code_values: dict[str, str] = {}
    summary = ROOT / "chiplet_extension" / "reports" / "code_coverage_summary.txt"
    for line in summary.read_text().splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            code_values[key] = value
    if "design_toggle_points_hit" not in code_values or "design_toggle_points_total" not in code_values:
        report = (ROOT / "chiplet_extension" / "reports" / "code_coverage_summary.md").read_text()
        match = re.search(r"\| `toggle` \| (\d+) \| (\d+) \|", report)
        if not match:
            raise SystemExit("Canonical toggle hit/total values are unavailable")
        code_values["design_toggle_points_hit"], code_values["design_toggle_points_total"] = match.groups()
    raw_hit = code_values["design_toggle_points_hit"]
    raw_total = code_values["design_toggle_points_total"]
    reviewed_hit = code_values["design_toggle_reviewed_points_hit"]
    reviewed_total = code_values["design_toggle_reviewed_points_total"]
    reviewed_pct = code_values["design_toggle_reviewed_coverage_pct"]
    excluded = int(raw_total) - int(reviewed_total)
    raw_pct = code_values["design_toggle_coverage_pct"]
    lines.append(f"| Raw design toggle coverage | `{raw_hit} / {raw_total} ({raw_pct}%)` |")
    lines.append(f"| Reviewed design toggle coverage | `{reviewed_hit} / {reviewed_total} ({reviewed_pct}%); {excluded} excluded` |")
    lines.extend([
        END,
    ])
    text = README.read_text()
    if START not in text or END not in text:
        raise SystemExit("README generated-metrics markers are missing")
    prefix, remainder = text.split(START, 1)
    _, suffix = remainder.split(END, 1)
    README.write_text(prefix + "\n".join(lines) + suffix)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
