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

DOMAIN_COMBO_METRICS = {
    "run": "domain_combo_run",
    "crypto_only": "domain_combo_crypto_only",
    "sleep": "domain_combo_sleep",
    "deep_sleep": "domain_combo_deep_sleep",
}

ISOLATION_METRICS = {
    "asserted": "isolation_assert_cycles",
    "deasserted": "isolation_deassert_cycles",
    "blocked": "isolation_blocked_cycles",
    "release_traffic": "isolation_release_traffic_seen",
}

RETENTION_METRICS = {
    "dma_sleep_save": "dma_sleep_save_seen",
    "dma_sleep_restore": "dma_sleep_restore_seen",
    "dma_mem_save": "dma_mem_save_seen",
    "dma_mem_restore": "dma_mem_restore_seen",
}

ACTIVITY_CROSS_METRICS = {
    "no_traffic": "activity_cross_no_traffic",
    "link_traffic": "activity_cross_link_traffic",
    "dma_queued": "activity_cross_dma_queued",
    "dma_active": "activity_cross_dma_active",
    "completion_pending": "activity_cross_completion_pending",
}


def read_metric_map(path: Path) -> dict[str, str]:
    if not str(path) or str(path) == "." or not path.exists() or path.is_dir():
        return {}
    with path.open(newline="") as handle:
        return {row["metric"]: row["value"] for row in csv.DictReader(handle)}


def hit_names(metric_map: dict[str, str], metrics: dict[str, str]) -> list[str]:
    return [name for name, metric in metrics.items() if int(metric_map.get(metric, "0")) > 0]


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize power proxy verification results.")
    parser.add_argument("--summary", required=True, help="Regression summary CSV.")
    parser.add_argument("--output", required=True, help="Destination CSV.")
    args = parser.parse_args()

    summary_path = Path(args.summary)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    rows = list(csv.DictReader(summary_path.open(newline="")))
    power_rows = []
    for row in rows:
        power_csv = row.get("power_csv", "")
        scenario = row.get("scenario", "")
        test = row.get("test", "")
        if power_csv and ("power" in scenario or test.startswith("power_") or test.startswith("dma_power_")):
            power_rows.append(row)

    state_hits = {name: 0 for name in STATE_METRICS}
    transition_hits = {name: 0 for name in TRANSITION_METRICS}
    domain_combo_hits = {name: 0 for name in DOMAIN_COMBO_METRICS}
    isolation_hits = {name: 0 for name in ISOLATION_METRICS}
    retention_hits = {name: 0 for name in RETENTION_METRICS}
    activity_cross_hits = {name: 0 for name in ACTIVITY_CROSS_METRICS}
    passing_tests = 0
    output_rows: list[dict[str, str]] = []

    for row in power_rows:
        metric_map = read_metric_map(Path(row.get("power_csv", "")))
        visited_states = hit_names(metric_map, STATE_METRICS)
        visited_transitions = hit_names(metric_map, TRANSITION_METRICS)
        visited_domain_combos = hit_names(metric_map, DOMAIN_COMBO_METRICS)
        visited_isolation = hit_names(metric_map, ISOLATION_METRICS)
        visited_retention = hit_names(metric_map, RETENTION_METRICS)
        visited_activity_cross = hit_names(metric_map, ACTIVITY_CROSS_METRICS)
        for state_name in visited_states:
            state_hits[state_name] = 1
        for transition_name in visited_transitions:
            transition_hits[transition_name] = 1
        for name in visited_domain_combos:
            domain_combo_hits[name] = 1
        for name in visited_isolation:
            isolation_hits[name] = 1
        for name in visited_retention:
            retention_hits[name] = 1
        for name in visited_activity_cross:
            activity_cross_hits[name] = 1
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
                "domain_combos_visited": str(len(visited_domain_combos)),
                "isolation_bins_visited": str(len(visited_isolation)),
                "retention_bins_visited": str(len(visited_retention)),
                "activity_cross_bins_visited": str(len(visited_activity_cross)),
                "visited_states": ";".join(visited_states),
                "visited_transitions": ";".join(visited_transitions),
                "visited_domain_combos": ";".join(visited_domain_combos),
                "visited_isolation": ";".join(visited_isolation),
                "visited_retention": ";".join(visited_retention),
                "visited_activity_cross": ";".join(visited_activity_cross),
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
        "domain_combos_visited": f"{sum(domain_combo_hits.values())}/{len(DOMAIN_COMBO_METRICS)}",
        "isolation_bins_visited": f"{sum(isolation_hits.values())}/{len(ISOLATION_METRICS)}",
        "retention_bins_visited": f"{sum(retention_hits.values())}/{len(RETENTION_METRICS)}",
        "activity_cross_bins_visited": f"{sum(activity_cross_hits.values())}/{len(ACTIVITY_CROSS_METRICS)}",
        "visited_states": ";".join(name for name, hit in state_hits.items() if hit),
        "visited_transitions": ";".join(name for name, hit in transition_hits.items() if hit),
        "visited_domain_combos": ";".join(name for name, hit in domain_combo_hits.items() if hit),
        "visited_isolation": ";".join(name for name, hit in isolation_hits.items() if hit),
        "visited_retention": ";".join(name for name, hit in retention_hits.items() if hit),
        "visited_activity_cross": ";".join(name for name, hit in activity_cross_hits.items() if hit),
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
                "domain_combos_visited",
                "isolation_bins_visited",
                "retention_bins_visited",
                "activity_cross_bins_visited",
                "visited_states",
                "visited_transitions",
                "visited_domain_combos",
                "visited_isolation",
                "visited_retention",
                "visited_activity_cross",
                "power_csv",
            ],
        )
        writer.writeheader()
        writer.writerow(overall_row)
        writer.writerows(output_rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
