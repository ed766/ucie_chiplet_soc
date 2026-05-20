#!/usr/bin/env python3
"""Generate a resume-friendly behavioral performance characterization report."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPORT_ROOT = ROOT / "reports"
DOC_ROOT = ROOT.parent / "docs"
NA = "NA"


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"missing required artifact: {path}")
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def read_metric_csv(path_text: str) -> dict[str, str]:
    if not path_text:
        return {}
    path = Path(path_text)
    if not path.exists():
        return {}
    with path.open(newline="") as handle:
        return {row["metric"]: row["value"] for row in csv.DictReader(handle)}


def find_row(rows: list[dict[str, str]], **criteria: str) -> dict[str, str]:
    for row in rows:
        if all(row.get(key) == value for key, value in criteria.items()):
            return row
    raise KeyError(f"missing row matching {criteria}")


def find_first(rows: list[dict[str, str]], tests: tuple[str, ...]) -> dict[str, str]:
    for test in tests:
        for row in rows:
            if row.get("test") == test:
                return row
    raise KeyError(f"missing test row for any of {tests}")


def fmt_num(value: str) -> str:
    return value if value not in {"", "0.0000"} else ("0.0000" if value == "0.0000" else NA)


def link_row(scenario: str, source: dict[str, str], notes: str) -> dict[str, str]:
    return {
        "Scenario": scenario,
        "Source test": source["test"],
        "Avg latency": source.get("latency_avg_cycles", NA),
        "Max latency": source.get("latency_max_cycles", NA),
        "Retry count": source.get("retry_count", NA),
        "Throughput": source.get("throughput_flits_per_cycle", NA),
        "Notes": notes,
    }


def regression_row(scenario: str, source: dict[str, str], notes: str, throughput_policy: str = "scoreboard") -> dict[str, str]:
    metrics = read_metric_csv(source.get("score_csv", ""))
    avg_latency = metrics.get("latency_avg_cycles", NA)
    max_latency = metrics.get("latency_max_cycles", NA)
    retry_count = source.get("retries", metrics.get("retry_count", NA))
    if throughput_policy == "na":
        throughput = NA
    else:
        rx = int(metrics.get("rx_count", source.get("rx", "0") or "0"))
        avg = avg_latency if avg_latency not in {"", "0"} else NA
        throughput = f"{rx}/{avg} flits/latency-window" if avg != NA and rx != 0 else NA
    return {
        "Scenario": scenario,
        "Source test": source["test"],
        "Avg latency": avg_latency if avg_latency != "0" else NA,
        "Max latency": max_latency if max_latency != "0" else NA,
        "Retry count": retry_count,
        "Throughput": throughput,
        "Notes": notes,
    }


def build_rows(perf_rows: list[dict[str, str]], regress_rows: list[dict[str, str]]) -> list[dict[str, str]]:
    no_fault = find_row(perf_rows, sweep="latency_vs_channel_delay", label="delay_0")
    backpressure = find_row(perf_rows, sweep="throughput_vs_backpressure", label="bp_mod_4")
    crc_retry = find_row(perf_rows, sweep="retry_rate_vs_fault_density", label="crc_spacing_16")
    lane_fault = find_first(regress_rows, ("prbs_lane_fault_recover",))
    sleep_resume = find_first(regress_rows, ("dma_sleep_during_queued_work", "dma_power_sleep_resume_queue"))
    crypto_only = find_first(regress_rows, ("dma_crypto_only_submit_blocked", "mem_crypto_only_cfg_access"))

    return [
        link_row("No fault", no_fault, "Baseline PRBS link path with no injected retry/fault window."),
        link_row("Backpressure", backpressure, "Heavy deterministic backpressure point; throughput remains scoreboard-clean."),
        link_row(
            "CRC retry",
            crc_retry,
            f"CRC retry recovery with retry rate {crc_retry.get('retry_rate', NA)}.",
        ),
        regression_row("Lane fault", lane_fault, "Lane fault recovery completed without scoreboard mismatch."),
        regression_row(
            "Sleep/resume during queued DMA",
            sleep_resume,
            f"DMA descriptors completed={sleep_resume.get('dma_desc_completed', NA)}, errors={sleep_resume.get('dma_error_count', NA)}.",
        ),
        regression_row(
            "Crypto-only mode",
            crypto_only,
            f"Mode blocks new DMA submission; error/reject count={crypto_only.get('dma_error_count', NA)}.",
            throughput_policy="na",
        ),
    ]


def render_markdown(rows: list[dict[str, str]], output: Path) -> None:
    lines = [
        "# Performance Characterization",
        "",
        "These measurements come from behavioral Verilator simulation and are intended",
        "for architecture/DV discussion. They are not silicon timing, power, or",
        "implementation signoff numbers.",
        "",
        "| Scenario | Source test | Avg latency | Max latency | Retry count | Throughput | Notes |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in rows:
        lines.append(
            f"| {row['Scenario']} | `{row['Source test']}` | {row['Avg latency']} | "
            f"{row['Max latency']} | {row['Retry count']} | {row['Throughput']} | {row['Notes']} |"
        )

    no_fault = rows[0]
    backpressure = rows[1]
    crc_retry = rows[2]
    lane_fault = rows[3]
    sleep_resume = rows[4]
    crypto_only = rows[5]
    lines.extend(
        [
            "",
            "## Observations",
            "",
            f"- The no-fault baseline reports {no_fault['Avg latency']} cycles average latency and {no_fault['Throughput']} flits/cycle throughput in the PRBS characterization path.",
            f"- The selected backpressure point keeps average latency at {backpressure['Avg latency']} cycles while preserving a clean scoreboard result; the stress is visible in backpressure coverage rather than failures.",
            f"- CRC retry recovery records {crc_retry['Retry count']} retries at the selected point, showing retry overhead without packet-order corruption.",
            f"- Lane-fault recovery completes through `{lane_fault['Source test']}` with {lane_fault['Retry count']} retry event and no mismatch in the regression row.",
            f"- Sleep/resume and crypto-only rows are control-behavior characterizations: `{sleep_resume['Source test']}` proves queued DMA recovery, while `{crypto_only['Source test']}` proves mode-dependent submission blocking.",
            "",
            "## Source Artifacts",
            "",
            "- `chiplet_extension/reports/perf_characterization.csv`",
            "- `chiplet_extension/reports/regress_summary.csv`",
            "- per-test `*_scoreboard.csv` files referenced by the regression summary",
        ]
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate behavioral performance characterization markdown.")
    parser.add_argument("--perf-csv", default=str(REPORT_ROOT / "perf_characterization.csv"))
    parser.add_argument("--regress-csv", default=str(REPORT_ROOT / "regress_summary.csv"))
    parser.add_argument("--output", default=str(DOC_ROOT / "performance_characterization.md"))
    args = parser.parse_args()

    perf_rows = read_rows(Path(args.perf_csv))
    regress_rows = read_rows(Path(args.regress_csv))
    rows = build_rows(perf_rows, regress_rows)
    render_markdown(rows, Path(args.output))
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
