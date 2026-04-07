#!/usr/bin/env python3
"""Parse machine-readable DV result lines into a regression summary CSV."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def parse_result_line(line: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for part in line.strip().split("|")[1:]:
        if "=" in part:
            key, value = part.split("=", 1)
            fields[key] = value
    return fields


def infer_detail(log_text: str, returncode: str) -> str:
    patterns = [
        ("CREDIT_EXPECTED_MATCH", "credit_assertion"),
        ("LINK_PROGRESS_BOUNDED", "link_progress"),
        ("LINK_TRAINING_BOUNDED", "link_training"),
        ("Scoreboard violations", "scoreboard_violation"),
        ("Ciphertext mismatches", "e2e_scoreboard"),
        ("Compile failed", "compile_failure"),
    ]
    for needle, label in patterns:
        if needle in log_text:
            return label
    if returncode and returncode != "0":
        return f"process_rc_{returncode}"
    return "missing_result_line"


def normalize_status(raw_status: str) -> str:
    status = (raw_status or "").upper()
    return status if status in {"PASS", "FAIL"} else "FAIL"


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse Verilator regression logs into regress_summary.csv.")
    parser.add_argument("--manifest", required=True, help="CSV manifest emitted by run_regression.py.")
    parser.add_argument("--output", required=True, help="Destination CSV.")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, str]] = []
    with manifest_path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        for entry in reader:
            log_text = Path(entry["log_path"]).read_text() if Path(entry["log_path"]).exists() else ""
            result_fields: dict[str, str] = {}
            for line in reversed(log_text.splitlines()):
                if line.startswith("DV_RESULT|"):
                    result_fields = parse_result_line(line)
                    break

            status = normalize_status(result_fields.get("status", ""))
            detail = result_fields.get("detail", infer_detail(log_text, entry.get("returncode", "")))
            expected = normalize_status(entry.get("expected_status", "PASS"))
            meets_expectation = status == expected

            cov_hits = result_fields.get("cov_hits", "0")
            cov_total = result_fields.get("cov_total", "0")
            cov_pct = ""
            try:
                cov_total_int = int(cov_total)
                cov_hits_int = int(cov_hits)
                if cov_total_int > 0:
                    cov_pct = f"{(100.0 * cov_hits_int / cov_total_int):.1f}"
            except ValueError:
                cov_pct = ""

            row = {
                "run_id": entry["run_id"],
                "bench": result_fields.get("bench", entry["bench"]),
                "test": result_fields.get("test", entry["test"]),
                "scenario": result_fields.get("scenario", "random" if entry["randomized"] == "1" else "directed"),
                "seed": result_fields.get("seed", entry["seed"]),
                "bug_mode": result_fields.get("bug_mode", entry.get("bug_mode", "none")),
                "status": status,
                "expected_status": expected,
                "meets_expectation": "1" if meets_expectation else "0",
                "detail": detail,
                "tx": result_fields.get("tx", ""),
                "rx": result_fields.get("rx", ""),
                "retries": result_fields.get("retries", ""),
                "mismatch": result_fields.get("mismatch", ""),
                "drop": result_fields.get("drop", ""),
                "latency_violations": result_fields.get("latency_violations", ""),
                "e2e_mismatch": result_fields.get("e2e_mismatch", ""),
                "expected_empty": result_fields.get("expected_empty", ""),
                "cov_hits": cov_hits,
                "cov_total": cov_total,
                "cov_pct": cov_pct,
                "defines": entry.get("defines", ""),
                "returncode": entry.get("returncode", ""),
                "elapsed_s": entry.get("elapsed_s", ""),
                "log_path": entry["log_path"],
                "compile_log_path": entry["compile_log_path"],
                "score_csv": result_fields.get("score_csv", entry.get("score_csv", "")),
                "cov_csv": result_fields.get("cov_csv", entry.get("cov_csv", "")),
            }
            rows.append(row)

    with output_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "run_id",
                "bench",
                "test",
                "scenario",
                "seed",
                "bug_mode",
                "status",
                "expected_status",
                "meets_expectation",
                "detail",
                "tx",
                "rx",
                "retries",
                "mismatch",
                "drop",
                "latency_violations",
                "e2e_mismatch",
                "expected_empty",
                "cov_hits",
                "cov_total",
                "cov_pct",
                "defines",
                "returncode",
                "elapsed_s",
                "log_path",
                "compile_log_path",
                "score_csv",
                "cov_csv",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
