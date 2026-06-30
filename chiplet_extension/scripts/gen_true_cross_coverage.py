#!/usr/bin/env python3
"""Generate non-gating true interaction cross-coverage evidence.

The canonical closure model is still the flat 60-bin coverage summary. This
script asks a stricter question for a small set of high-value interactions:
did the relevant conditions occur in the same test row/window?
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPORT_ROOT = ROOT / "reports"
DOC_OUT = ROOT.parent / "docs" / "true_cross_coverage_summary.md"
MIN_OBSERVED = 8


def read_rows(path: Path | str) -> list[dict[str, str]]:
    path = Path(path)
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def split_tests(value: str) -> set[str]:
    return {item for item in value.split(";") if item}


def load_metric_tests(path: Path) -> dict[str, set[str]]:
    tests: dict[str, set[str]] = {}
    for row in read_rows(path):
        metric = row.get("metric", "")
        if metric and metric != "__overall__":
            tests[metric] = split_tests(row.get("tests_hit", ""))
    return tests


def intersect(metric_tests: dict[str, set[str]], *metrics: str) -> set[str]:
    if not metrics:
        return set()
    present = [metric_tests.get(metric, set()) for metric in metrics]
    if not present:
        return set()
    result = set(present[0])
    for tests in present[1:]:
        result &= tests
    return result


def union(metric_tests: dict[str, set[str]], *metrics: str) -> set[str]:
    result: set[str] = set()
    for metric in metrics:
        result |= metric_tests.get(metric, set())
    return result


def regress_clean_tests(rows: list[dict[str, str]]) -> set[str]:
    clean: set[str] = set()
    for row in rows:
        if row.get("status") != "PASS":
            continue
        if row.get("mismatch") != "0" or row.get("drop") != "0" or row.get("e2e_mismatch") != "0":
            continue
        clean.add(row.get("test", ""))
    return clean


def power_tests_with(rows: list[dict[str, str]], activity: set[str], transitions: set[str]) -> set[str]:
    hits: set[str] = set()
    for row in rows:
        test = row.get("test", "")
        if test == "__overall__":
            continue
        visited_activity = split_tests(row.get("visited_activity_cross", ""))
        visited_transitions = split_tests(row.get("visited_transitions", ""))
        if visited_activity & activity and visited_transitions & transitions:
            hits.add(test)
    return hits


def power_isolation_tests(rows: list[dict[str, str]]) -> set[str]:
    hits: set[str] = set()
    for row in rows:
        if row.get("test") == "__overall__":
            continue
        states = split_tests(row.get("visited_states", ""))
        isolation = split_tests(row.get("visited_isolation", ""))
        if states & {"sleep", "deep_sleep", "crypto_only"} and {"asserted", "deasserted"} <= isolation:
            hits.add(row.get("test", ""))
    return hits


def make_row(group: str, criteria: str, sources: set[str], defer_note: str = "") -> dict[str, str]:
    status = "observed" if sources else "deferred"
    return {
        "cross_group": group,
        "status": status,
        "source_tests": ";".join(sorted(sources)),
        "criteria": criteria,
        "defer_note": "" if sources else defer_note,
    }


def build_rows(
    metric_tests: dict[str, set[str]],
    regress_rows: list[dict[str, str]],
    power_rows: list[dict[str, str]],
) -> list[dict[str, str]]:
    clean = regress_clean_tests(regress_rows)
    queue_pressure = intersect(metric_tests, "dma_submit_accept") & union(
        metric_tests,
        "dma_submit_occ_23",
        "dma_submit_occ_4",
    )
    dma_power = power_tests_with(
        power_rows,
        {"dma_active", "dma_queued", "completion_pending"},
        {"run_to_sleep", "sleep_to_run", "run_to_crypto_only", "crypto_only_to_run"},
    )
    crc_retry_bp = intersect(metric_tests, "crc_error", "resend_request", "retry_backpressure_cross")
    lane_recovery = intersect(metric_tests, "lane_fault", "link_degraded", "link_recoveries")
    bank_conflict = union(
        metric_tests,
        "mem_src_conflict",
        "mem_dst_conflict",
    ) & metric_tests.get("mem_wait", set())
    invalid_dma = union(metric_tests, "mem_invalid_read", "mem_invalid_bank_present") & metric_tests.get(
        "dma_comp_runtime_error", set()
    )
    parity_error = intersect(metric_tests, "mem_parity_dma", "dma_comp_runtime_error") | metric_tests.get(
        "mem_parity_maint", set()
    )
    retention_validity = intersect(metric_tests, "mem_wake_apply", "mem_invalid_bank_present")
    power_isolation = power_isolation_tests(power_rows)
    aes_order = metric_tests.get("e2e_updates", set()) & clean

    return [
        make_row(
            "DMA length bucket x submit queue occupancy bucket",
            "DMA accepted descriptors coincide with non-trivial submit queue occupancy.",
            queue_pressure,
        ),
        make_row(
            "DMA active/queued/completion-pending x power transition type",
            "DMA active, queued, or completion-pending state occurs in the same power run as RUN/SLEEP or RUN/CRYPTO_ONLY transition.",
            dma_power,
        ),
        make_row(
            "CRC fault x retry recovery x backpressure active",
            "CRC fault, resend/retry, and retry-under-backpressure evidence occur in the same test.",
            crc_retry_bp,
        ),
        make_row(
            "Lane fault x retrain x successful post-recovery packet",
            "Lane fault, degraded/retrain state, and link recovery occur in the same test.",
            lane_recovery,
        ),
        make_row(
            "Source/destination bank x conflict/wait event",
            "Source or destination bank conflict coincides with maintenance wait evidence.",
            bank_conflict,
        ),
        make_row(
            "Invalid bank x DMA source read x error completion",
            "Invalid bank state coincides with DMA runtime-error completion.",
            invalid_dma,
            "Current closure covers invalid-bank maintenance reads and DMA parity runtime errors separately; a direct invalid-source DMA error cross remains a targeted future case.",
        ),
        make_row(
            "Parity error source/destination x completion/error status",
            "Source parity DMA runtime error or destination maintenance parity report occurs.",
            parity_error,
        ),
        make_row(
            "Retention policy x post-wake valid/invalid bank state",
            "Wake application and invalid-bank state occur in the same test.",
            retention_validity,
        ),
        make_row(
            "Power state x isolation asserted/deasserted",
            "Powered-off/protected state coincides with asserted and released isolation behavior.",
            power_isolation,
        ),
        make_row(
            "AES block count x return ordering",
            "End-to-end AES/service updates complete without mismatch/drop.",
            aes_order,
        ),
    ]


def write_outputs(rows: list[dict[str, str]], csv_out: Path, md_out: Path) -> None:
    csv_out.parent.mkdir(parents=True, exist_ok=True)
    with csv_out.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["cross_group", "status", "source_tests", "criteria", "defer_note"],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)

    observed = sum(1 for row in rows if row["status"] == "observed")
    lines = [
        "# True Cross-Coverage Summary",
        "",
        "This report is non-gating quality evidence. It checks whether selected interactions occurred in the same test/window, while `coverage_summary.csv` remains the canonical `60 / 60` closure source.",
        "",
        f"- Observed true-cross groups: {observed} / {len(rows)}",
        f"- Acceptance threshold for this optional evidence: at least {MIN_OBSERVED} / {len(rows)} groups observed.",
        "",
        "| Cross group | Status | Source tests | Notes |",
        "| --- | --- | --- | --- |",
    ]
    for row in rows:
        notes = row["criteria"] if row["status"] == "observed" else row["defer_note"]
        lines.append(
            f"| {row['cross_group']} | {row['status']} | {row['source_tests'] or 'NA'} | {notes} |"
        )
    md_out.parent.mkdir(parents=True, exist_ok=True)
    md_out.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate true cross-coverage evidence.")
    parser.add_argument("--coverage", default=str(REPORT_ROOT / "coverage_summary.csv"))
    parser.add_argument("--regress", default=str(REPORT_ROOT / "regress_summary.csv"))
    parser.add_argument("--summary", dest="regress", help="Compatibility alias for --regress.")
    parser.add_argument("--power", default=str(REPORT_ROOT / "power_state_summary.csv"))
    parser.add_argument("--csv-out", default=str(REPORT_ROOT / "true_cross_coverage_summary.csv"))
    parser.add_argument("--md-out", default=str(DOC_OUT))
    args = parser.parse_args()

    rows = build_rows(
        load_metric_tests(Path(args.coverage)),
        read_rows(Path(args.regress)),
        read_rows(Path(args.power)),
    )
    write_outputs(rows, Path(args.csv_out), Path(args.md_out))
    observed = sum(1 for row in rows if row["status"] == "observed")
    print(f"True cross coverage: {observed}/{len(rows)} groups observed")
    print(f"CSV: {args.csv_out}")
    print(f"Markdown: {args.md_out}")
    return 0 if observed >= MIN_OBSERVED else 1


if __name__ == "__main__":
    raise SystemExit(main())
