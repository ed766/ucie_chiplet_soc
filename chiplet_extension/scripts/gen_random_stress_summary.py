#!/usr/bin/env python3
"""Summarize optional seeded-random stress manifests and representative probes."""

from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
REPORTS = ROOT / "reports"
OUTPUT = REPO / "docs" / "random_stress_summary.md"
EXEC_SUMMARY = REPORTS / "random_stress_regress_summary.csv"

FAMILIES = (
    ("random_smoke_25", "Random smoke", 25),
    ("stress_retry_50", "Retry/backpressure stress", 50),
    ("power_dma_cross_25", "Power/DMA cross stress", 25),
)

KNOBS = (
    "DMA length",
    "source/destination banks",
    "queue pressure",
    "backpressure duration",
    "CRC fault insertion point",
    "lane fault type",
    "power transition timing",
    "AES block count",
    "parity injection",
    "timeout profile",
    "retry window",
)


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def representative_status(family: str) -> str:
    summary = REPORTS / f"{family}_probe_regress_summary.csv"
    rows = read_rows(summary)
    if not rows:
        return "manifest generated; representative probe not run"
    meets = [row.get("meets_expectation", "0") == "1" for row in rows]
    passed = sum(1 for item in meets if item)
    total = len(meets)
    return f"{passed}/{total} representative probe rows met expectation"


def executed_status(family: str) -> str:
    rows = [row for row in read_rows(EXEC_SUMMARY) if row.get("family") == family]
    if not rows:
        return "not run"
    valid_rows = [row for row in rows if row.get("constraint_status", "valid") == "valid"]
    invalid_rows = [row for row in rows if row.get("constraint_status") == "invalid"]
    passed = sum(1 for row in valid_rows if row.get("meets_expectation") == "1")
    applied = sum(1 for row in valid_rows if row.get("applied_plusargs"))
    if valid_rows and invalid_rows:
        return (
            f"{passed}/{len(valid_rows)} valid executed rows met expectation; "
            f"{len(invalid_rows)} schema-rejected rows; {applied}/{len(valid_rows)} valid rows applied manifest plusargs"
        )
    if invalid_rows:
        return f"0/0 valid executed rows; {len(invalid_rows)} schema-rejected rows; representative probe covers runnability"
    return f"{passed}/{len(valid_rows)} valid executed rows met expectation; {applied}/{len(valid_rows)} valid rows applied manifest plusargs"


def seed_preview(rows: list[dict[str, str]]) -> str:
    seeds = [row.get("seed", "") for row in rows[:5]]
    seeds = [seed for seed in seeds if seed]
    return ", ".join(f"`{seed}`" for seed in seeds) if seeds else "NA"


def main() -> int:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    family_rows: list[tuple[str, str, int, int, str, str, str]] = []
    total = 0
    for family, label, expected in FAMILIES:
        rows = read_rows(REPORTS / f"{family}_manifest.csv")
        count = len(rows)
        total += count
        family_rows.append(
            (family, label, expected, count, seed_preview(rows), representative_status(family), executed_status(family))
        )

    lines = [
        "# Seeded-Random Stress Summary",
        "",
        "This report summarizes optional bounded seeded-random collateral. These generated scenarios are not part of the default stable regression or the canonical `60 / 60` closure gate.",
        "",
        f"- Total generated scenarios: {total}",
        "- Reproduction model: every scenario row records a deterministic seed plus the randomized knob values.",
        "- Constraint model: generated rows are schema-checked before execution; valid rows are translated into concrete runtime plusargs.",
        "- Representative probes validate that each family is runnable without promoting all generated scenarios into default closure.",
        "- The optional execution matrix runs a bounded 25/10/5 subset and writes `chiplet_extension/reports/random_stress_regress_summary.csv`.",
        "",
        "## Randomized Knobs",
        "",
    ]
    lines.extend(f"- {knob}" for knob in KNOBS)
    lines.extend(
        [
            "",
            "## Families",
            "",
            "| Family | Expected scenarios | Generated scenarios | Seed preview | Representative validation | Executed subset |",
            "| --- | ---: | ---: | --- | --- | --- |",
        ]
    )

    for family, label, expected, count, seeds, status, executed in family_rows:
        lines.append(f"| `{family}` ({label}) | {expected} | {count} | {seeds} | {status} | {executed} |")

    lines.extend(
        [
            "",
            "## Reproduce By Seed",
            "",
            "1. Regenerate a family manifest with `make -C chiplet_extension random-smoke-25`, `make -C chiplet_extension stress-retry-50`, or `make -C chiplet_extension power-dma-cross-25`.",
            "2. Select the desired `seed` and knob row from the corresponding manifest in `chiplet_extension/reports/`.",
            "3. Run the representative test listed in the manifest, preserving the seed and knob metadata in the log or bug report.",
            "4. To regenerate the bounded executed subset, run `make -C chiplet_extension random-stress-run` followed by `make -C chiplet_extension random-stress-summary`.",
            "",
            "## Claim Boundary",
            "",
            "- Safe claim: directed and seeded-random testing are both used.",
            "- Stronger claim supported by this collateral: bounded seeded-random stress generation creates 100 reproducible scenarios across DMA, retry/backpressure, parity, and power-transition timing.",
            "- This is optional stress evidence; the closure source of truth remains `coverage_summary.csv` and `coverage_closure_matrix.md`.",
        ]
    )

    OUTPUT.write_text("\n".join(lines) + "\n")
    print(f"Wrote {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
