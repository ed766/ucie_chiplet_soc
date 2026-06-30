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

SWITCH_DOMAIN_METRICS = {
    "pd_a_traffic_on": "switch_pd_a_traffic_on_seen",
    "pd_a_traffic_off": "switch_pd_a_traffic_off_seen",
    "pd_a_dma_on": "switch_pd_a_dma_on_seen",
    "pd_a_dma_off": "switch_pd_a_dma_off_seen",
    "pd_a_link_on": "switch_pd_a_link_on_seen",
    "pd_a_link_off": "switch_pd_a_link_off_seen",
    "pd_b_crypto_on": "switch_pd_b_crypto_on_seen",
    "pd_b_crypto_off": "switch_pd_b_crypto_off_seen",
    "pd_b_link_on": "switch_pd_b_link_on_seen",
    "pd_b_link_off": "switch_pd_b_link_off_seen",
    "pd_channel_on": "switch_pd_channel_on_seen",
    "pd_channel_off": "switch_pd_channel_off_seen",
}

ISOLATION_DOMAIN_METRICS = {
    "pd_a_traffic_assert": "iso_pd_a_traffic_assert_seen",
    "pd_a_traffic_deassert": "iso_pd_a_traffic_deassert_seen",
    "pd_a_dma_assert": "iso_pd_a_dma_assert_seen",
    "pd_a_dma_deassert": "iso_pd_a_dma_deassert_seen",
    "pd_a_link_assert": "iso_pd_a_link_assert_seen",
    "pd_a_link_deassert": "iso_pd_a_link_deassert_seen",
    "pd_b_crypto_assert": "iso_pd_b_crypto_assert_seen",
    "pd_b_crypto_deassert": "iso_pd_b_crypto_deassert_seen",
    "pd_b_link_assert": "iso_pd_b_link_assert_seen",
    "pd_b_link_deassert": "iso_pd_b_link_deassert_seen",
    "pd_channel_assert": "iso_pd_channel_assert_seen",
    "pd_channel_deassert": "iso_pd_channel_deassert_seen",
}

SEQUENCE_METRICS = {
    "iso_before_switch_off": "seq_iso_before_switch_off_seen",
    "switch_on_before_restore": "seq_switch_on_before_restore_seen",
    "restore_before_deiso": "seq_restore_before_deiso_seen",
    "retention_pulse_width_ok": "retention_pulse_width_ok_seen",
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
    switch_domain_hits = {name: 0 for name in SWITCH_DOMAIN_METRICS}
    isolation_domain_hits = {name: 0 for name in ISOLATION_DOMAIN_METRICS}
    sequence_hits = {name: 0 for name in SEQUENCE_METRICS}
    passing_tests = 0
    total_sequence_violations = 0
    total_unsupported_transitions = 0
    output_rows: list[dict[str, str]] = []

    for row in power_rows:
        metric_map = read_metric_map(Path(row.get("power_csv", "")))
        visited_states = hit_names(metric_map, STATE_METRICS)
        visited_transitions = hit_names(metric_map, TRANSITION_METRICS)
        visited_domain_combos = hit_names(metric_map, DOMAIN_COMBO_METRICS)
        visited_isolation = hit_names(metric_map, ISOLATION_METRICS)
        visited_retention = hit_names(metric_map, RETENTION_METRICS)
        visited_activity_cross = hit_names(metric_map, ACTIVITY_CROSS_METRICS)
        visited_switch_domains = hit_names(metric_map, SWITCH_DOMAIN_METRICS)
        visited_isolation_domains = hit_names(metric_map, ISOLATION_DOMAIN_METRICS)
        visited_sequences = hit_names(metric_map, SEQUENCE_METRICS)
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
        for name in visited_switch_domains:
            switch_domain_hits[name] = 1
        for name in visited_isolation_domains:
            isolation_domain_hits[name] = 1
        for name in visited_sequences:
            sequence_hits[name] = 1
        sequence_violations = sum(
            int(metric_map.get(metric, "0"))
            for metric in [
                "seq_iso_before_switch_off_violations",
                "seq_switch_on_before_restore_violations",
                "seq_restore_before_deiso_violations",
                "retention_pulse_width_violations",
            ]
        )
        total_sequence_violations += sequence_violations
        total_unsupported_transitions += int(metric_map.get("unsupported_transition_seen", "0"))
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
                "switch_domain_bins_visited": str(len(visited_switch_domains)),
                "isolation_domain_bins_visited": str(len(visited_isolation_domains)),
                "sequence_bins_visited": str(len(visited_sequences)),
                "sequence_violations": str(sequence_violations),
                "unsupported_transitions": metric_map.get("unsupported_transition_seen", "0"),
                "visited_states": ";".join(visited_states),
                "visited_transitions": ";".join(visited_transitions),
                "visited_domain_combos": ";".join(visited_domain_combos),
                "visited_isolation": ";".join(visited_isolation),
                "visited_retention": ";".join(visited_retention),
                "visited_activity_cross": ";".join(visited_activity_cross),
                "visited_switch_domains": ";".join(visited_switch_domains),
                "visited_isolation_domains": ";".join(visited_isolation_domains),
                "visited_sequences": ";".join(visited_sequences),
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
        "switch_domain_bins_visited": f"{sum(switch_domain_hits.values())}/{len(SWITCH_DOMAIN_METRICS)}",
        "isolation_domain_bins_visited": f"{sum(isolation_domain_hits.values())}/{len(ISOLATION_DOMAIN_METRICS)}",
        "sequence_bins_visited": f"{sum(sequence_hits.values())}/{len(SEQUENCE_METRICS)}",
        "sequence_violations": str(total_sequence_violations),
        "unsupported_transitions": str(total_unsupported_transitions),
        "visited_states": ";".join(name for name, hit in state_hits.items() if hit),
        "visited_transitions": ";".join(name for name, hit in transition_hits.items() if hit),
        "visited_domain_combos": ";".join(name for name, hit in domain_combo_hits.items() if hit),
        "visited_isolation": ";".join(name for name, hit in isolation_hits.items() if hit),
        "visited_retention": ";".join(name for name, hit in retention_hits.items() if hit),
        "visited_activity_cross": ";".join(name for name, hit in activity_cross_hits.items() if hit),
        "visited_switch_domains": ";".join(name for name, hit in switch_domain_hits.items() if hit),
        "visited_isolation_domains": ";".join(name for name, hit in isolation_domain_hits.items() if hit),
        "visited_sequences": ";".join(name for name, hit in sequence_hits.items() if hit),
        "power_csv": "",
    }

    with output_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            lineterminator="\n",
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
                "switch_domain_bins_visited",
                "isolation_domain_bins_visited",
                "sequence_bins_visited",
                "sequence_violations",
                "unsupported_transitions",
                "visited_states",
                "visited_transitions",
                "visited_domain_combos",
                "visited_isolation",
                "visited_retention",
                "visited_activity_cross",
                "visited_switch_domains",
                "visited_isolation_domains",
                "visited_sequences",
                "power_csv",
            ],
        )
        writer.writeheader()
        writer.writerow(overall_row)
        writer.writerows(output_rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
