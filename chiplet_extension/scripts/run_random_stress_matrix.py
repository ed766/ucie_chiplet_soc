#!/usr/bin/env python3
"""Execute a bounded subset of generated seeded-random stress manifests."""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPORT_ROOT = ROOT / "reports"
RUN_REGRESSION = ROOT / "scripts" / "run_regression.py"

FAMILY_LIMITS = {
    "random_smoke_25": 25,
    "stress_retry_50": 10,
    "power_dma_cross_25": 5,
}

KNOB_FIELDS = [
    "dma_len",
    "src_bank",
    "dst_bank",
    "queue_pressure",
    "backpressure_cycles",
    "crc_fault_at",
    "lane_fault_type",
    "power_transition_cycle",
    "aes_blocks",
    "parity_injection",
    "timeout_profile",
    "retry_window",
]

DMA_LENGTHS = {1, 2, 4, 8, 12, 16}
QUEUE_PRESSURES = {"single", "pair", "full_queue"}
CRC_POINTS = {"none", "early", "mid", "late"}
LANE_FAULTS = {"none", "single_lane", "burst_lane", "retrain"}
PARITY_INJECTIONS = {"none", "src", "dst_maint"}
TIMEOUT_PROFILES = {"nominal", "low", "high"}


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def bucket_from_row(row: dict[str, str]) -> str:
    if row.get("meets_expectation") == "1":
        return "none"
    detail = row.get("detail", "")
    if "retry" in detail:
        return "retry_identity"
    if "crc" in detail:
        return "crc_integrity"
    if "credit" in detail:
        return "credit_accounting"
    if "dma" in detail:
        return "dma_completion"
    if "memory" in detail or "parity" in detail:
        return "memory_integrity"
    return "uncategorized"


def parse_int(row: dict[str, str], field: str) -> int:
    try:
        return int(row.get(field, ""))
    except ValueError as exc:
        raise ValueError(f"{field} must be an integer") from exc


def base_for_bank(bank: int, base: int) -> int:
    return base + (bank & 1)


def validate_manifest_row(row: dict[str, str]) -> list[str]:
    errors: list[str] = []
    try:
        dma_len = parse_int(row, "dma_len")
        src_bank = parse_int(row, "src_bank")
        dst_bank = parse_int(row, "dst_bank")
        backpressure_cycles = parse_int(row, "backpressure_cycles")
        power_transition_cycle = parse_int(row, "power_transition_cycle")
        aes_blocks = parse_int(row, "aes_blocks")
        retry_window = parse_int(row, "retry_window")
    except ValueError as exc:
        return [str(exc)]

    queue_pressure = row.get("queue_pressure", "")
    crc_fault_at = row.get("crc_fault_at", "")
    lane_fault_type = row.get("lane_fault_type", "")
    parity_injection = row.get("parity_injection", "")
    timeout_profile = row.get("timeout_profile", "")

    if dma_len not in DMA_LENGTHS:
        errors.append("dma_len outside allowed set")
    if src_bank not in (0, 1):
        errors.append("src_bank must be 0 or 1")
    if dst_bank not in (0, 1):
        errors.append("dst_bank must be 0 or 1")
    if queue_pressure not in QUEUE_PRESSURES:
        errors.append("queue_pressure outside allowed set")
    if crc_fault_at not in CRC_POINTS:
        errors.append("crc_fault_at outside allowed set")
    if lane_fault_type not in LANE_FAULTS:
        errors.append("lane_fault_type outside allowed set")
    if parity_injection not in PARITY_INJECTIONS:
        errors.append("parity_injection outside allowed set")
    if timeout_profile not in TIMEOUT_PROFILES:
        errors.append("timeout_profile outside allowed set")
    if backpressure_cycles not in (0, 4, 8, 16, 32):
        errors.append("backpressure_cycles outside allowed set")
    if power_transition_cycle not in (0, 32, 64, 96, 128):
        errors.append("power_transition_cycle outside allowed set")
    if aes_blocks not in (1, 2, 4, 8):
        errors.append("aes_blocks outside allowed set")
    if retry_window not in (0, 4, 8, 16):
        errors.append("retry_window outside allowed set")
    if parity_injection != "none" and queue_pressure != "single":
        errors.append("parity injection rows must use single queue pressure")

    max_words = dma_len * (4 if queue_pressure == "full_queue" else 2)
    if base_for_bank(src_bank, 8) + max_words >= 256:
        errors.append("source descriptor range exceeds scratchpad")
    if base_for_bank(dst_bank, 128) + max_words >= 256:
        errors.append("destination descriptor range exceeds scratchpad")
    return errors


def crc_plusargs(crc_fault_at: str, retry_window: int) -> list[str]:
    if crc_fault_at == "none":
        return ["ENABLE_CRC_WINDOW=0"]
    start_by_point = {"early": 80, "mid": 140, "late": 200}
    spacing = retry_window if retry_window != 0 else 8
    return [
        "ENABLE_CRC_WINDOW=1",
        f"CRC_START={start_by_point[crc_fault_at]}",
        "CRC_COUNT=1",
        f"CRC_SPACING={spacing}",
    ]


def lane_plusargs(lane_fault_type: str, power_transition_cycle: int) -> list[str]:
    if lane_fault_type == "none":
        return ["ENABLE_LANE_FAULT=0"]
    cycles_by_type = {"single_lane": 1, "burst_lane": 3, "retrain": 2}
    start = power_transition_cycle if power_transition_cycle != 0 else 96
    hold = 0 if lane_fault_type != "retrain" else 32
    return [
        "ENABLE_LANE_FAULT=1",
        "ENABLE_FAULT_ECHO=1",
        f"LANE_FAULT_START={start}",
        f"LANE_FAULT_CYCLES={cycles_by_type[lane_fault_type]}",
        f"TRAINING_HOLD_START={start}",
        f"TRAINING_HOLD_CYCLES={hold}",
    ]


def backpressure_plusargs(backpressure_cycles: int) -> list[str]:
    if backpressure_cycles == 0:
        return ["ENABLE_BACKPRESSURE=0", "BACKPRESSURE_MOD=0", "BACKPRESSURE_HOLD=0"]
    modulus_by_cycles = {4: 16, 8: 8, 16: 4, 32: 2}
    return [
        "ENABLE_BACKPRESSURE=1",
        f"BACKPRESSURE_MOD={modulus_by_cycles[backpressure_cycles]}",
        f"BACKPRESSURE_HOLD={max(1, backpressure_cycles // 8)}",
    ]


def plusargs_for_manifest_row(row: dict[str, str]) -> tuple[list[str], str]:
    errors = validate_manifest_row(row)
    if errors:
        raise ValueError("; ".join(errors))

    dma_len = parse_int(row, "dma_len")
    src_bank = parse_int(row, "src_bank")
    dst_bank = parse_int(row, "dst_bank")
    backpressure_cycles = parse_int(row, "backpressure_cycles")
    power_transition_cycle = parse_int(row, "power_transition_cycle")
    aes_blocks = parse_int(row, "aes_blocks")
    retry_window = parse_int(row, "retry_window")
    queue_pressure = row["queue_pressure"]
    crc_fault_at = row["crc_fault_at"]
    lane_fault_type = row["lane_fault_type"]
    parity_injection = row["parity_injection"]
    timeout_profile = row["timeout_profile"]
    test = row.get("representative_test", "")

    src_base = base_for_bank(src_bank, 8)
    dst_base = base_for_bank(dst_bank, 128)
    second_src = src_base + 32
    second_dst = dst_base + 32
    power_start = power_transition_cycle if power_transition_cycle != 0 else 96

    dma_plusargs = [
        f"DMA_LEN_WORDS={dma_len}",
        f"DMA_SRC_BASE={src_base}",
        f"DMA_DST_BASE={dst_base}",
        f"DMA2_LEN_WORDS={dma_len}",
        f"DMA2_SRC_BASE={second_src}",
        f"DMA2_DST_BASE={second_dst}",
        f"QUEUE_PRESSURE={queue_pressure}",
        f"PARITY_INJECTION={parity_injection}",
        f"TIMEOUT_PROFILE={timeout_profile}",
        "MAX_CYCLES=32000",
    ]
    link_plusargs = [
        *backpressure_plusargs(backpressure_cycles),
        *crc_plusargs(crc_fault_at, retry_window),
        *lane_plusargs(lane_fault_type, power_transition_cycle),
    ]
    power_plusargs = [
        f"POWER_EVENT_START={power_start}",
        "POWER_EVENT_CYCLES=12",
        "POWER_RECOVERY_CYCLES=48",
    ]

    if test == "random_manifest_scenario":
        plusargs = dma_plusargs
    elif test == "prbs_retry_backpressure":
        plusargs = [
            *backpressure_plusargs(backpressure_cycles),
            *crc_plusargs(crc_fault_at, retry_window),
            "ENABLE_LANE_FAULT=0",
        ]
    elif test == "power_traffic_cross_test":
        # Preserve the named power-cross link/retry recipe; only sweep DMA
        # descriptor placement/length and event timing knobs.
        plusargs = [
            *dma_plusargs,
            *power_plusargs,
        ]
    else:
        plusargs = [
            *dma_plusargs,
            *power_plusargs,
            *link_plusargs,
        ]

    if test not in ("prbs_retry_backpressure",):
        plusargs.extend([
        f"TARGET_CIPHER_UPDATES={aes_blocks}",
        f"TARGET_TX_COUNT={max(32, aes_blocks * 32)}",
        ])
    return plusargs, ";".join(plusargs)


def run_manifest_row(row: dict[str, str], verilator: str) -> dict[str, str]:
    family = row["family"]
    index = int(row["index"])
    seed = int(row["seed"])
    test = row["representative_test"]
    prefix = f"random_stress_{family}_{index:03d}"
    try:
        extra_plusargs, applied_plusargs = plusargs_for_manifest_row(row)
        constraint_status = "valid"
        constraint_detail = "constraints_applied"
    except ValueError as exc:
        extra_plusargs = []
        applied_plusargs = ""
        constraint_status = "invalid"
        constraint_detail = str(exc)

    if constraint_status != "valid":
        merged = {
            "family": family,
            "index": str(index),
            "manifest_seed": str(seed),
            "representative_test": test,
            "status": "FAIL",
            "expected_status": "PASS",
            "meets_expectation": "0",
            "failure_bucket": "constraint_validation",
            "detail": constraint_detail,
            "log_path": "",
            "summary_csv": "",
            "runner_returncode": "2",
            "constraint_status": constraint_status,
            "applied_plusargs": applied_plusargs,
        }
        for field in KNOB_FIELDS:
            merged[field] = row.get(field, "")
        return merged

    cmd = [
        sys.executable,
        str(RUN_REGRESSION),
        "--tests",
        test,
        "--random-seeds",
        "1",
        "--seed",
        str(seed),
        "--verilator",
        verilator,
        "--report-prefix",
        prefix,
        "--run-id-prefix",
        prefix,
    ]
    for plusarg in extra_plusargs:
        cmd.extend(["--plusarg", plusarg])
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    summary_path = REPORT_ROOT / f"{prefix}_regress_summary.csv"
    child_rows = read_rows(summary_path)
    child = child_rows[0] if child_rows else {}
    merged = {
        "family": family,
        "index": str(index),
        "manifest_seed": str(seed),
        "representative_test": test,
        "status": child.get("status", "FAIL"),
        "expected_status": child.get("expected_status", "PASS"),
        "meets_expectation": child.get("meets_expectation", "0"),
        "failure_bucket": bucket_from_row(child) if child else "runner_error",
        "detail": child.get("detail", "missing_child_summary"),
        "log_path": child.get("log_path", ""),
        "summary_csv": str(summary_path),
        "runner_returncode": str(result.returncode),
        "constraint_status": constraint_status,
        "applied_plusargs": applied_plusargs,
    }
    for field in KNOB_FIELDS:
        merged[field] = row.get(field, "")
    return merged


def selected_manifest_rows(family: str) -> list[dict[str, str]]:
    path = REPORT_ROOT / f"{family}_manifest.csv"
    rows = read_rows(path)
    return rows[: FAMILY_LIMITS[family]]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a bounded matrix from seeded-random stress manifests.")
    parser.add_argument("--verilator", default="verilator")
    parser.add_argument(
        "--output",
        default=str(REPORT_ROOT / "random_stress_regress_summary.csv"),
        help="Combined stress execution summary CSV.",
    )
    args = parser.parse_args()

    REPORT_ROOT.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, str]] = []
    for family in FAMILY_LIMITS:
        for manifest_row in selected_manifest_rows(family):
            rows.append(run_manifest_row(manifest_row, args.verilator))

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "family",
        "index",
        "manifest_seed",
        "representative_test",
        *KNOB_FIELDS,
        "status",
        "expected_status",
        "meets_expectation",
        "failure_bucket",
        "detail",
        "log_path",
        "summary_csv",
        "runner_returncode",
        "constraint_status",
        "applied_plusargs",
    ]
    with output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    unexpected = [row for row in rows if row["meets_expectation"] != "1"]
    print(f"Random stress matrix: {len(rows) - len(unexpected)}/{len(rows)} rows met expectation")
    print(f"Summary: {output}")
    return 1 if unexpected else 0


if __name__ == "__main__":
    raise SystemExit(main())
