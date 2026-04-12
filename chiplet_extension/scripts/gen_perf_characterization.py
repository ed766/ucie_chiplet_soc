#!/usr/bin/env python3
"""Run compact protocol/performance sweeps on the PRBS bench."""

from __future__ import annotations

import argparse
import csv
import subprocess
from dataclasses import dataclass
from pathlib import Path

from run_regression import LOG_ROOT, REPORT_ROOT, compile_binary


ROOT = Path(__file__).resolve().parent.parent
BUILD_ROOT = ROOT / "build" / "characterization"
DOC_ROOT = ROOT.parent / "docs"


@dataclass(frozen=True)
class SweepCase:
    sweep: str
    label: str
    test: str
    knob_name: str
    knob_value: str
    max_cycles: int
    plusargs: tuple[str, ...] = ()
    notes: str = ""


CASES = (
    SweepCase(
        sweep="latency_vs_channel_delay",
        label="delay_0",
        test="prbs_latency_low",
        knob_name="channel_delay_cycles",
        knob_value="0",
        max_cycles=10000,
        plusargs=("CHANNEL_DELAY=0",),
        notes="Baseline receive path without added channel-delay shim.",
    ),
    SweepCase(
        sweep="latency_vs_channel_delay",
        label="delay_10",
        test="prbs_latency_nominal",
        knob_name="channel_delay_cycles",
        knob_value="10",
        max_cycles=12000,
        plusargs=("CHANNEL_DELAY=10",),
        notes="Nominal delay point used for the mid-latency bucket.",
    ),
    SweepCase(
        sweep="latency_vs_channel_delay",
        label="delay_20",
        test="prbs_latency_high",
        knob_name="channel_delay_cycles",
        knob_value="20",
        max_cycles=14000,
        plusargs=("CHANNEL_DELAY=20",),
        notes="High-delay stress point that still meets the scoreboard latency window.",
    ),
    SweepCase(
        sweep="throughput_vs_backpressure",
        label="bp_mod_16",
        test="prbs_backpressure_wave",
        knob_name="backpressure_modulus",
        knob_value="16",
        max_cycles=10000,
        plusargs=("BACKPRESSURE_MOD=16", "BACKPRESSURE_HOLD=1"),
        notes="Light backpressure.",
    ),
    SweepCase(
        sweep="throughput_vs_backpressure",
        label="bp_mod_8",
        test="prbs_backpressure_wave",
        knob_name="backpressure_modulus",
        knob_value="8",
        max_cycles=10000,
        plusargs=("BACKPRESSURE_MOD=8", "BACKPRESSURE_HOLD=1"),
        notes="Nominal backpressure wave.",
    ),
    SweepCase(
        sweep="throughput_vs_backpressure",
        label="bp_mod_4",
        test="prbs_backpressure_wave",
        knob_name="backpressure_modulus",
        knob_value="4",
        max_cycles=10000,
        plusargs=("BACKPRESSURE_MOD=4", "BACKPRESSURE_HOLD=1"),
        notes="Heavy backpressure.",
    ),
    SweepCase(
        sweep="throughput_vs_backpressure",
        label="bp_mod_2",
        test="prbs_backpressure_wave",
        knob_name="backpressure_modulus",
        knob_value="2",
        max_cycles=12000,
        plusargs=("BACKPRESSURE_MOD=2", "BACKPRESSURE_HOLD=1"),
        notes="Near-saturation backpressure.",
    ),
    SweepCase(
        sweep="retry_rate_vs_fault_density",
        label="crc_spacing_24",
        test="prbs_crc_burst_recover",
        knob_name="crc_spacing",
        knob_value="24",
        max_cycles=16000,
        plusargs=(
            "TARGET_TX_COUNT=80",
            "CRC_COUNT=2",
            "CRC_SPACING=24",
            "BACKPRESSURE_MOD=5",
            "BACKPRESSURE_HOLD=1",
        ),
        notes="Sparse CRC error windowing.",
    ),
    SweepCase(
        sweep="retry_rate_vs_fault_density",
        label="crc_spacing_16",
        test="prbs_crc_burst_recover",
        knob_name="crc_spacing",
        knob_value="16",
        max_cycles=16000,
        plusargs=(
            "TARGET_TX_COUNT=80",
            "CRC_COUNT=2",
            "CRC_SPACING=16",
            "BACKPRESSURE_MOD=5",
            "BACKPRESSURE_HOLD=1",
        ),
        notes="Medium CRC error density.",
    ),
    SweepCase(
        sweep="retry_rate_vs_fault_density",
        label="crc_spacing_8",
        test="prbs_crc_burst_recover",
        knob_name="crc_spacing",
        knob_value="8",
        max_cycles=16000,
        plusargs=(
            "TARGET_TX_COUNT=80",
            "CRC_COUNT=2",
            "CRC_SPACING=8",
            "BACKPRESSURE_MOD=5",
            "BACKPRESSURE_HOLD=1",
        ),
        notes="Dense CRC error burst spacing.",
    ),
)


def parse_result_line(log_text: str) -> dict[str, str]:
    for line in reversed(log_text.splitlines()):
        if line.startswith("DV_RESULT|"):
            fields: dict[str, str] = {}
            for part in line.split("|")[1:]:
                if "=" in part:
                    key, value = part.split("=", 1)
                    fields[key] = value
            return fields
    return {}


def read_metric_map(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    with path.open(newline="") as handle:
        return {row["metric"]: row["value"] for row in csv.DictReader(handle)}


def fmt_ratio(numer: int, denom: int) -> str:
    if denom == 0:
        return "0.0000"
    return f"{numer / denom:.4f}"


def render_markdown(rows: list[dict[str, str]], output_path: Path) -> None:
    by_sweep: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        by_sweep.setdefault(row["sweep"], []).append(row)

    lines = [
        "# Protocol Characterization",
        "",
        "These measurements come from the behavioral Verilator PRBS bench, so they are",
        "verification-oriented characterizations rather than silicon sign-off numbers.",
        "",
        "## Latency vs Channel Delay",
        "",
        "| Label | Delay cycles | Avg latency | Min | Max | Status |",
        "| --- | ---: | ---: | ---: | ---: | --- |",
    ]

    for row in by_sweep.get("latency_vs_channel_delay", []):
        lines.append(
            f"| `{row['label']}` | {row['knob_value']} | {row['latency_avg_cycles']} | "
            f"{row['latency_min_cycles']} | {row['latency_max_cycles']} | {row['status']} |"
        )

    lines.extend(
        [
            "",
            "## Throughput vs Backpressure",
            "",
            "| Label | Backpressure modulus | Backpressure hits | Throughput (rx/sample_cycles) | Avg latency | Status |",
            "| --- | ---: | ---: | ---: | ---: | --- |",
        ]
    )

    for row in by_sweep.get("throughput_vs_backpressure", []):
        lines.append(
            f"| `{row['label']}` | {row['knob_value']} | {row['backpressure_hits']} | {row['throughput_flits_per_cycle']} | "
            f"{row['latency_avg_cycles']} | {row['status']} |"
        )

    lines.extend(
        [
            "",
            "## Retry Rate vs Fault Density Proxy",
            "",
            "| Label | CRC spacing | Retries | Retry rate (retry/tx) | CRC hits | Resend hits | Status |",
            "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
        ]
    )

    for row in by_sweep.get("retry_rate_vs_fault_density", []):
        lines.append(
            f"| `{row['label']}` | {row['knob_value']} | {row['retry_count']} | "
            f"{row['retry_rate']} | {row['crc_error_hits']} | {row['resend_hits']} | {row['status']} |"
        )

    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- The latency sweep uses the receive-path channel-delay shim in `tb_ucie_prbs.sv`.",
            "- The retry-density sweep uses CRC spacing as a deterministic fault-density proxy.",
            "- In this behavioral model, the backpressure sweep is more visible in backpressure-hit counts and latency buckets than in raw throughput.",
            "- These runs intentionally reuse the named tests and scoreboards already used by the regression flow.",
        ]
    )

    output_path.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate lightweight protocol/performance characterization tables.")
    parser.add_argument("--verilator", default="verilator", help="Verilator executable.")
    parser.add_argument("--seed", type=int, default=20260408, help="Master seed for sweep reproducibility.")
    parser.add_argument(
        "--csv-out",
        default=str(REPORT_ROOT / "perf_characterization.csv"),
        help="Destination CSV for characterization data.",
    )
    parser.add_argument(
        "--markdown-out",
        default=str(DOC_ROOT / "protocol_characterization.md"),
        help="Destination markdown summary.",
    )
    args = parser.parse_args()

    BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    REPORT_ROOT.mkdir(parents=True, exist_ok=True)
    Path(args.markdown_out).parent.mkdir(parents=True, exist_ok=True)

    binary, compile_log = compile_binary(args.verilator, "tb_ucie_prbs", ())

    rows: list[dict[str, str]] = []
    for idx, case in enumerate(CASES):
        run_name = f"char_{case.sweep}_{case.label}"
        cov_csv = REPORT_ROOT / f"{run_name}_coverage.csv"
        score_csv = REPORT_ROOT / f"{run_name}_scoreboard.csv"
        log_path = BUILD_ROOT / f"{run_name}.log"
        cmd = [
            str(binary),
            f"+TEST={case.test}",
            f"+SEED={args.seed + idx}",
            f"+MAX_CYCLES={case.max_cycles}",
            f"+COV_OUT={cov_csv}",
            f"+SCORE_OUT={score_csv}",
            *[f"+{plusarg}" for plusarg in case.plusargs],
        ]
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        log_text = "## run_cmd\n" + " ".join(cmd) + "\n\n## stdout\n" + result.stdout + "\n## stderr\n" + result.stderr
        log_path.write_text(log_text)

        result_fields = parse_result_line(log_text)
        status = result_fields.get("status", "FAIL" if result.returncode else "PASS")
        score_metrics = read_metric_map(score_csv)
        cov_metrics = read_metric_map(cov_csv)

        tx_count = int(score_metrics.get("tx_count", "0"))
        rx_count = int(score_metrics.get("rx_count", "0"))
        retry_count = int(score_metrics.get("retry_count", "0"))
        sample_cycles = int(cov_metrics.get("sample_cycles", "0"))
        crc_hits = int(cov_metrics.get("crc_error", "0"))
        resend_hits = int(cov_metrics.get("resend_request", "0"))
        lane_fault_hits = int(cov_metrics.get("lane_fault", "0"))
        backpressure_hits = int(cov_metrics.get("backpressure", "0"))

        rows.append(
            {
                "sweep": case.sweep,
                "label": case.label,
                "test": case.test,
                "status": status,
                "detail": result_fields.get("detail", "missing_result_line"),
                "seed": str(args.seed + idx),
                "knob_name": case.knob_name,
                "knob_value": case.knob_value,
                "tx_count": str(tx_count),
                "rx_count": str(rx_count),
                "retry_count": str(retry_count),
                "latency_min_cycles": score_metrics.get("latency_min_cycles", "0"),
                "latency_max_cycles": score_metrics.get("latency_max_cycles", "0"),
                "latency_avg_cycles": score_metrics.get("latency_avg_cycles", "0"),
                "sample_cycles": str(sample_cycles),
                "throughput_flits_per_cycle": fmt_ratio(rx_count, sample_cycles),
                "retry_rate": fmt_ratio(retry_count, tx_count),
                "backpressure_hits": str(backpressure_hits),
                "crc_error_hits": str(crc_hits),
                "resend_hits": str(resend_hits),
                "lane_fault_hits": str(lane_fault_hits),
                "compile_log": str(compile_log),
                "log_path": str(log_path),
                "score_csv": str(score_csv),
                "cov_csv": str(cov_csv),
                "notes": case.notes,
            }
        )

    csv_path = Path(args.csv_out)
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "sweep",
                "label",
                "test",
                "status",
                "detail",
                "seed",
                "knob_name",
                "knob_value",
                "tx_count",
                "rx_count",
                "retry_count",
                "latency_min_cycles",
                "latency_max_cycles",
                "latency_avg_cycles",
                "sample_cycles",
                "throughput_flits_per_cycle",
                "retry_rate",
                "backpressure_hits",
                "crc_error_hits",
                "resend_hits",
                "lane_fault_hits",
                "compile_log",
                "log_path",
                "score_csv",
                "cov_csv",
                "notes",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    render_markdown(rows, Path(args.markdown_out))

    return 0 if all(row["status"] == "PASS" for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
