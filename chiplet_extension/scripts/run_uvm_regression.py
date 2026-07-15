#!/usr/bin/env python3
"""Run the optional full-UVM chiplet lane with a UVM-capable Verilator."""

from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from check_uvm_env import find_uvm_pkg
from run_regression import RTL_DIR, ROOT


SIM_DIR = ROOT / "sim"
UVM_DIR = SIM_DIR / "uvm"
BUILD_ROOT = ROOT / "build" / "uvm_regression"
REPORT_ROOT = ROOT / "reports"
LOG_ROOT = BUILD_ROOT / "logs"
REFERENCE_ROOT = BUILD_ROOT / "reference"
SUMMARY_CSV = REPORT_ROOT / "uvm_regress_summary.csv"
UVM_COVERAGE_SUMMARY = REPORT_ROOT / "uvm_coverage_summary.csv"
UVM_POWER_SUMMARY = REPORT_ROOT / "uvm_power_state_summary.csv"

UVM_TESTS = (
    "uvm_prbs_smoke_test",
    "uvm_soc_smoke_test",
    "uvm_dma_queue_smoke_test",
    "uvm_power_sleep_resume_test",
)

REFERENCE_MAP = {
    "uvm_soc_smoke_test": ("soc_smoke", 512),
    "uvm_dma_queue_smoke_test": ("dma_queue_smoke", 4),
    "uvm_power_sleep_resume_test": ("dma_power_sleep_resume_queue", 8),
}


@dataclass(frozen=True)
class UvmCounts:
    info: int = 0
    warning: int = 0
    error: int = 0
    fatal: int = 0


def uvm_report_paths(prefix: str) -> tuple[Path, Path]:
    clean_prefix = prefix.strip()
    if clean_prefix == "uvm_smoke":
        return REPORT_ROOT / "uvm_smoke_summary.csv", REPORT_ROOT / "uvm_smoke_coverage_summary.csv"
    if clean_prefix and clean_prefix != "uvm":
        return REPORT_ROOT / f"{clean_prefix}_regress_summary.csv", REPORT_ROOT / f"{clean_prefix}_coverage_summary.csv"
    return SUMMARY_CSV, UVM_COVERAGE_SUMMARY


def rtl_sources() -> list[str]:
    return sorted(str(path) for path in RTL_DIR.rglob("*.sv"))


def require_env() -> tuple[str, Path]:
    verilator = os.environ.get("VERILATOR_UVM", "")
    uvm_home = os.environ.get("UVM_HOME", "")
    if not verilator or not uvm_home:
        raise RuntimeError(
            "VERILATOR_UVM and UVM_HOME must be set for the optional full-UVM lane. "
            "Run `make uvm-check-env` for details."
        )
    uvm_pkg = find_uvm_pkg(Path(uvm_home).expanduser().resolve())
    if uvm_pkg is None:
        raise RuntimeError(f"Could not find uvm_pkg.sv under UVM_HOME={uvm_home}")
    return verilator, uvm_pkg


def compile_uvm_binary(verilator: str, uvm_pkg: Path) -> Path:
    BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    LOG_ROOT.mkdir(parents=True, exist_ok=True)
    build_dir = BUILD_ROOT / "tb_chiplet_uvm"
    binary = build_dir / "Vtb_chiplet_uvm"
    compile_log = LOG_ROOT / "tb_chiplet_uvm.compile.log"
    if build_dir.exists():
        shutil.rmtree(build_dir)

    sources = [
        str(UVM_DIR / "chiplet_uvm_if.sv"),
        str(UVM_DIR / "ucie_uvm_pkg.sv"),
        str(UVM_DIR / "dma_uvm_pkg.sv"),
        str(UVM_DIR / "power_uvm_pkg.sv"),
        str(UVM_DIR / "axi_lite_ral_pkg.sv"),
        str(UVM_DIR / "chiplet_uvm_pkg.sv"),
        str(SIM_DIR / "dv" / "ucie_cov_pkg.sv"),
        str(SIM_DIR / "dv" / "stats_pkg.sv"),
        str(SIM_DIR / "dv" / "stats_monitor.sv"),
        str(SIM_DIR / "tb_chiplet_uvm.sv"),
        *rtl_sources(),
    ]
    cmd = [
        verilator,
        "--binary",
        "-j",
        os.environ.get("UVM_BUILD_JOBS", str(os.cpu_count() or 1)),
        "--sv",
        "--timing",
        "-Wall",
        "-Wno-fatal",
        "-Wno-DECLFILENAME",
        "-Wno-PINCONNECTEMPTY",
        "-Wno-WIDTHEXPAND",
        "-Wno-UNUSEDSIGNAL",
        "-Wno-IMPURE",
        "+define+UVM_NO_DPI",
        "+define+CHIPLET_REAL_UVM",
        f"+incdir+{uvm_pkg.parent}",
        f"-I{SIM_DIR}",
        f"-I{UVM_DIR}",
        str(uvm_pkg),
        *sources,
        "--top-module",
        "tb_chiplet_uvm",
        "-Mdir",
        str(build_dir),
    ]
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    compile_log.write_text(
        "## compile_cmd\n"
        + " ".join(cmd)
        + "\n\n## stdout\n"
        + result.stdout
        + "\n## stderr\n"
        + result.stderr
    )
    if result.returncode != 0:
        raise RuntimeError(f"UVM compile failed; see {compile_log}")
    return binary


def parse_uvm_counts(text: str) -> UvmCounts:
    summary = {kind: int(count) for kind, count in re.findall(r"UVM_(INFO|WARNING|ERROR|FATAL)\s*:\s*(\d+)", text)}
    if summary:
        return UvmCounts(
            info=summary.get("INFO", 0),
            warning=summary.get("WARNING", 0),
            error=summary.get("ERROR", 0),
            fatal=summary.get("FATAL", 0),
        )
    return UvmCounts(
        info=len(re.findall(r"^UVM_INFO", text, flags=re.MULTILINE)),
        warning=len(re.findall(r"^UVM_WARNING", text, flags=re.MULTILINE)),
        error=len(re.findall(r"^UVM_ERROR", text, flags=re.MULTILINE)),
        fatal=len(re.findall(r"^UVM_FATAL", text, flags=re.MULTILINE)),
    )


def gen_reference(test: str) -> str:
    if test not in REFERENCE_MAP:
        return ""
    REFERENCE_ROOT.mkdir(parents=True, exist_ok=True)
    source_test, words = REFERENCE_MAP[test]
    ref_path = REFERENCE_ROOT / f"{test}_expected.csv"
    cmd = [
        sys.executable,
        str(ROOT / "scripts" / "gen_reference_vectors.py"),
        "--test",
        source_test,
        "--output",
        str(ref_path),
        "--words",
        str(words),
    ]
    subprocess.run(cmd, cwd=ROOT, check=True)
    return str(ref_path)


def run_test(binary: Path, test: str, artifact_prefix: str = "") -> dict[str, str]:
    log_path = LOG_ROOT / f"{test}.log"
    ref_path = gen_reference(test)
    cov_stem = f"{artifact_prefix}_{test}" if artifact_prefix else test
    cov_path = REPORT_ROOT / f"{cov_stem}_uvm_coverage.csv"
    cmd = [str(binary), f"+UVM_TESTNAME={test}", "+UVM_VERBOSITY=UVM_LOW"]
    if test == "uvm_axi_lite_ral_smoke_test":
        cmd.append("+UVM_RAL_MODE")
    if ref_path:
        cmd.append(f"+REF_CSV={ref_path}")
    cmd.append(f"+UVM_COV_OUT={cov_path}")
    timeout_s = int(os.environ.get("UVM_TEST_TIMEOUT_S", "120"))
    timed_out = False
    try:
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout_s)
        combined = result.stdout + "\n" + result.stderr
        returncode = result.returncode
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        stdout = exc.stdout if isinstance(exc.stdout, str) else (exc.stdout or b"").decode(errors="replace")
        stderr = exc.stderr if isinstance(exc.stderr, str) else (exc.stderr or b"").decode(errors="replace")
        combined = stdout + "\n" + stderr + f"\nUVM test timed out after {timeout_s} seconds\n"
        returncode = 124
    log_path.write_text("## run_cmd\n" + " ".join(cmd) + "\n\n## output\n" + combined)
    counts = parse_uvm_counts(combined)
    status = "PASS" if not timed_out and returncode == 0 and counts.error == 0 and counts.fatal == 0 else "FAIL"
    return {
        "test": test,
        "status": status,
        "returncode": str(returncode),
        "uvm_info": str(counts.info),
        "uvm_warning": str(counts.warning),
        "uvm_error": str(counts.error),
        "uvm_fatal": str(counts.fatal),
        "ref_csv": ref_path,
        "cov_csv": str(cov_path),
        "log": str(log_path),
    }


def decorate_uvm_closure_summary(summary_path: Path) -> None:
    rows = []
    with summary_path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        fieldnames = list(reader.fieldnames or [])
        for row in reader:
            row["uvm_info"] = row.get("uvm_info", "0")
            row["uvm_warning"] = row.get("uvm_warning", "0")
            row["uvm_error"] = row.get("uvm_error", "1" if row.get("status") == "FAIL" else "0")
            row["uvm_fatal"] = row.get("uvm_fatal", "0")
            rows.append(row)
    for field in ("uvm_info", "uvm_warning", "uvm_error", "uvm_fatal"):
        if field not in fieldnames:
            fieldnames.append(field)
    with summary_path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def run_uvm_closure(args: argparse.Namespace) -> int:
    require_env()
    cmd = [
        sys.executable,
        str(ROOT / "scripts" / "run_regression.py"),
        "--suite",
        "closure",
        "--random-seeds",
        str(args.random_seeds),
        "--seed",
        str(args.seed),
        "--verilator",
        args.verilator,
        "--report-prefix",
        "uvm",
        "--run-id-prefix",
        "uvm",
    ]
    result = subprocess.run(cmd, cwd=ROOT)
    if result.returncode != 0:
        return result.returncode
    decorate_uvm_closure_summary(SUMMARY_CSV)
    print(f"UVM closure summary: {SUMMARY_CSV}")
    print(f"UVM closure coverage: {UVM_COVERAGE_SUMMARY}")
    print(f"UVM closure power: {UVM_POWER_SUMMARY}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run optional full-UVM chiplet tests.")
    parser.add_argument("--suite", default="smoke", choices=["smoke", "closure"], help="UVM lane suite to run.")
    parser.add_argument("--tests", default="", help="Comma-separated UVM test names for smoke mode.")
    parser.add_argument("--report-prefix", default="uvm", help="Prefix aggregate smoke report filenames.")
    parser.add_argument("--random-seeds", type=int, default=1, help="Seeds for randomized closure tests.")
    parser.add_argument("--seed", type=int, default=20260329, help="Master regression seed for closure mode.")
    parser.add_argument("--verilator", default=os.environ.get("VERILATOR", "verilator"), help="Verilator executable for closure compatibility runs.")
    args = parser.parse_args()

    try:
        if args.suite == "closure":
            return run_uvm_closure(args)
        verilator, uvm_pkg = require_env()
        binary = compile_uvm_binary(verilator, uvm_pkg)
        tests_arg = args.tests or ",".join(UVM_TESTS)
        tests = [name.strip() for name in tests_arg.split(",") if name.strip()]
        summary_csv, coverage_summary = uvm_report_paths(args.report_prefix)
        artifact_prefix = args.report_prefix.strip()
        REPORT_ROOT.mkdir(parents=True, exist_ok=True)
        rows = [run_test(binary, test, artifact_prefix) for test in tests]
        with summary_csv.open("w", newline="") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=[
                    "test",
                    "status",
                    "returncode",
                    "uvm_info",
                    "uvm_warning",
                    "uvm_error",
                    "uvm_fatal",
                    "ref_csv",
                    "cov_csv",
                    "log",
                ],
            )
            writer.writeheader()
            writer.writerows(rows)
        subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts" / "gen_coverage_report.py"),
                "--summary",
                str(summary_csv),
                "--output",
                str(coverage_summary),
            ],
            cwd=ROOT,
            check=True,
        )
        failures = [row for row in rows if row["status"] != "PASS"]
        print(f"UVM summary: {summary_csv}")
        print(f"UVM coverage: {coverage_summary}")
        return 1 if failures else 0
    except RuntimeError as exc:
        print(f"UVM regression failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
