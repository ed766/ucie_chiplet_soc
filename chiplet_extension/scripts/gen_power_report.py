#!/usr/bin/env python3
"""Aggregate power-intent proxy results into a compact CSV summary."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


STATE_METRICS = {
    "run": "run_cycles",
    "crypto_only": "crypto_only_cycles",
    "sleep": "sleep_cycles",
    "deep_sleep": "deep_sleep_cycles",
}

TRANSITION_METRICS = {
    "run_to_crypto_only": "trans_run_to_crypto_only",
    "crypto_only_to_run": "trans_crypto_only_to_run",
    "run_to_sleep": "trans_run_to_sleep",
    "sleep_to_run": "trans_sleep_to_run",
    "run_to_deep_sleep": "trans_run_to_deep_sleep",
    "deep_sleep_to_run": "trans_deep_sleep_to_run",
}


def read_metric_map(path: Path) -> dict[str, str]:
    if not str(path) or str(path) == "." or not path.exists() or path.is_dir():
        return {}
    with path.open(newline="") as handle:
        return {row["metric"]: row["value"] for row in csv.DictReader(handle)}


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize power proxy verification results.")
    parser.add_argument("--summary", required=True, help="Regression summary CSV.")
    parser.add_argument("--output", required=True, help="Destination CSV.")
    args = parser.parse_args()

    summary_path = Path(args.summary)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    rows = list(csv.DictReader(summary_path.open(newline="")))
    power_rows = [
        row for row in rows
        if row["test"].startswith("power_") or row["test"].startswith("dma_power_")
    ]

    state_hits = {name: 0 for name in STATE_METRICS}
    transition_hits = {name: 0 for name in TRANSITION_METRICS}
    passing_tests = 0
    output_rows: list[dict[str, str]] = []

    for row in power_rows:
        metric_map = read_metric_map(Path(row.get("power_csv", "")))
        visited_states = [name for name, metric in STATE_METRICS.items() if int(metric_map.get(metric, "0")) > 0]
        visited_transitions = [
            name for name, metric in TRANSITION_METRICS.items() if int(metric_map.get(metric, "0")) > 0
        ]
        for state_name in visited_states:
            state_hits[state_name] = 1
        for transition_name in visited_transitions:
            transition_hits[transition_name] = 1
        if row["meets_expectation"] == "1":
            passing_tests += 1

        output_rows.append(
            {
                "test": row["test"],
                "power_mode": metric_map.get("power_mode", "none"),
                "status": row["status"],
                "meets_expectation": row["meets_expectation"],
                "illegal_activity_violations": metric_map.get("illegal_activity_violations", "0"),
                "resume_events": metric_map.get("resume_events", "0"),
                "resume_violations": metric_map.get("resume_violations", "0"),
                "states_visited": str(len(visited_states)),
                "transitions_visited": str(len(visited_transitions)),
                "visited_states": ";".join(visited_states),
                "visited_transitions": ";".join(visited_transitions),
                "power_csv": row.get("power_csv", ""),
            }
        )

    overall_row = {
        "test": "__overall__",
        "power_mode": "summary",
        "status": "",
        "meets_expectation": str(passing_tests),
        "illegal_activity_violations": "0",
        "resume_events": "",
        "resume_violations": "0",
        "states_visited": f"{sum(state_hits.values())}/{len(STATE_METRICS)}",
        "transitions_visited": f"{sum(transition_hits.values())}/{len(TRANSITION_METRICS)}",
        "visited_states": ";".join(name for name, hit in state_hits.items() if hit),
        "visited_transitions": ";".join(name for name, hit in transition_hits.items() if hit),
        "power_csv": "",
    }

    with output_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "test",
                "power_mode",
                "status",
                "meets_expectation",
                "illegal_activity_violations",
                "resume_events",
                "resume_violations",
                "states_visited",
                "transitions_visited",
                "visited_states",
                "visited_transitions",
                "power_csv",
            ],
        )
        writer.writeheader()
        writer.writerow(overall_row)
        writer.writerows(output_rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
