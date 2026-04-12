#!/usr/bin/env python3
"""Run lightweight bounded property harnesses with Verilator."""

from __future__ import annotations

import argparse
import csv
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FORMAL_DIR = ROOT / "formal"
RTL_DIR = ROOT / "rtl"
BUILD_DIR = ROOT / "build" / "formal_checks"
REPORT_PATH = ROOT / "reports" / "formal_summary.csv"

VERILATOR_WARNINGS = [
    "-Wno-fatal",
    "-Wno-DECLFILENAME",
    "-Wno-UNUSEDSIGNAL",
    "-Wno-UNUSEDPARAM",
]


@dataclass(frozen=True)
class PropertyCase:
    name: str
    top: str
    harness: str
    rtl_sources: tuple[str, ...]
    defines: tuple[str, ...] = ()
    expected_status: str = "PASS"


CASES = (
    PropertyCase(
        name="credit_mgr_bounds",
        top="tb_credit_mgr_props",
        harness="tb_credit_mgr_props.sv",
        rtl_sources=("d2d_adapter/credit_mgr.sv",),
    ),
    PropertyCase(
        name="link_fsm_recovery",
        top="tb_link_fsm_props",
        harness="tb_link_fsm_props.sv",
        rtl_sources=("d2d_adapter/link_fsm.sv",),
    ),
    PropertyCase(
        name="retry_ctrl_progress",
        top="tb_retry_ctrl_props",
        harness="tb_retry_ctrl_props.sv",
        rtl_sources=("d2d_adapter/retry_ctrl.sv",),
    ),
    PropertyCase(
        name="ucie_tx_retry_identity",
        top="tb_ucie_tx_retry_props",
        harness="tb_ucie_tx_retry_props.sv",
        rtl_sources=("d2d_adapter/ucie_tx.sv",),
    ),
    PropertyCase(
        name="ucie_tx_retry_identity_bug_demo",
        top="tb_ucie_tx_retry_props",
        harness="tb_ucie_tx_retry_props.sv",
        rtl_sources=("d2d_adapter/ucie_tx.sv",),
        defines=("UCIE_BUG_RETRY_SEQ",),
        expected_status="FAIL",
    ),
)


def compile_case(verilator: str, case: PropertyCase) -> tuple[Path, Path]:
    build_dir = BUILD_DIR / case.name
    build_dir.mkdir(parents=True, exist_ok=True)
    log_path = build_dir / "compile.log"
    binary = build_dir / f"V{case.top}"

    cmd = [
        verilator,
        "--binary",
        "--sv",
        "--timing",
        "--assert",
        "-Wall",
        *VERILATOR_WARNINGS,
        *[f"-D{define}" for define in case.defines],
        "--top-module",
        case.top,
        str(FORMAL_DIR / case.harness),
        *[str(RTL_DIR / relpath) for relpath in case.rtl_sources],
        "-Mdir",
        str(build_dir),
    ]
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    log_path.write_text(
        "## compile_cmd\n"
        + " ".join(cmd)
        + "\n\n## stdout\n"
        + result.stdout
        + "\n## stderr\n"
        + result.stderr
    )
    if result.returncode != 0:
        raise RuntimeError(f"compile failed for {case.name}")
    return binary, log_path


def parse_prop_result(log_text: str) -> dict[str, str]:
    for line in reversed(log_text.splitlines()):
        if line.startswith("PROP_RESULT|"):
            fields: dict[str, str] = {}
            for part in line.split("|")[1:]:
                if "=" in part:
                    key, value = part.split("=", 1)
                    fields[key] = value
            return fields
    return {}


def run_case(binary: Path, case: PropertyCase) -> tuple[str, str, int, Path]:
    log_path = binary.parent / "run.log"
    result = subprocess.run([str(binary)], cwd=ROOT, capture_output=True, text=True)
    log_text = "## stdout\n" + result.stdout + "\n## stderr\n" + result.stderr
    log_path.write_text(log_text)
    fields = parse_prop_result(log_text)
    observed = fields.get("status", "FAIL" if result.returncode != 0 else "PASS")
    detail = fields.get("detail", "assertion_failure" if result.returncode != 0 else "completed")
    return observed, detail, result.returncode, log_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Run bounded assertion harnesses for chiplet DV collateral.")
    parser.add_argument("--verilator", default="verilator", help="Verilator executable.")
    args = parser.parse_args()

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, str]] = []
    for case in CASES:
        binary, compile_log = compile_case(args.verilator, case)
        observed, detail, returncode, run_log = run_case(binary, case)
        rows.append(
            {
                "name": case.name,
                "top": case.top,
                "expected_status": case.expected_status,
                "observed_status": observed,
                "meets_expectation": "1" if observed == case.expected_status else "0",
                "detail": detail,
                "defines": " ".join(case.defines),
                "returncode": str(returncode),
                "compile_log": str(compile_log),
                "run_log": str(run_log),
            }
        )

    with REPORT_PATH.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "name",
                "top",
                "expected_status",
                "observed_status",
                "meets_expectation",
                "detail",
                "defines",
                "returncode",
                "compile_log",
                "run_log",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    unexpected = [row for row in rows if row["meets_expectation"] != "1"]
    return 1 if unexpected else 0


if __name__ == "__main__":
    raise SystemExit(main())
