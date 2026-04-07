#!/usr/bin/env python3
"""Run the lightweight coverage-driven regression on Verilator."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import random
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parent.parent
SIM_DIR = ROOT / "sim"
RTL_DIR = ROOT / "rtl"
BUILD_ROOT = ROOT / "build" / "verilator_regression"
REPORT_ROOT = ROOT / "reports"
LOG_ROOT = BUILD_ROOT / "logs"
MANIFEST_PATH = BUILD_ROOT / "run_manifest.csv"
REGRESS_SUMMARY = REPORT_ROOT / "regress_summary.csv"
COVERAGE_SUMMARY = REPORT_ROOT / "coverage_summary.csv"
FAILURE_BUCKETS = REPORT_ROOT / "failure_buckets.csv"
TOP_FAILURES = REPORT_ROOT / "top_failures.md"
VERIFICATION_DASHBOARD = REPORT_ROOT / "verification_dashboard.md"

VERILATOR_WARNINGS = [
    "-Wno-fatal",
    "-Wno-DECLFILENAME",
    "-Wno-PINCONNECTEMPTY",
    "-Wno-WIDTHEXPAND",
    "-Wno-UNUSEDSIGNAL",
]


@dataclass(frozen=True)
class TestSpec:
    name: str
    bench: str
    default_enabled: bool = True
    randomized: bool = False
    expected_status: str = "PASS"
    bug_mode: str = "none"
    defines: tuple[str, ...] = ()
    max_cycles: int = 9000
    suites: tuple[str, ...] = ("stable",)
    plusargs: tuple[str, ...] = ()


@dataclass
class RunSpec:
    run_id: str
    test: str
    bench: str
    seed: int
    randomized: bool
    expected_status: str
    bug_mode: str
    defines: tuple[str, ...]
    max_cycles: int
    plusargs: tuple[str, ...] = field(default_factory=tuple)


TEST_SPECS: tuple[TestSpec, ...] = (
    TestSpec("prbs_smoke", "tb_ucie_prbs"),
    TestSpec("prbs_credit_starve", "tb_ucie_prbs"),
    TestSpec("prbs_reset_midflight", "tb_ucie_prbs"),
    TestSpec("prbs_backpressure_wave", "tb_ucie_prbs"),
    TestSpec("prbs_rand_stress", "tb_ucie_prbs", randomized=True),
    TestSpec("prbs_retry_burst", "tb_ucie_prbs", default_enabled=False, suites=("stress",)),
    TestSpec("prbs_crc_storm", "tb_ucie_prbs", default_enabled=False, suites=("stress",)),
    TestSpec("prbs_fault_retrain", "tb_ucie_prbs", default_enabled=False, suites=("stress",)),
    TestSpec("soc_smoke", "tb_soc_chiplets"),
    TestSpec("soc_wrong_key", "tb_soc_chiplets"),
    TestSpec("soc_misalign", "tb_soc_chiplets"),
    TestSpec("soc_backpressure", "tb_soc_chiplets"),
    TestSpec("soc_fault_echo", "tb_soc_chiplets"),
    TestSpec("soc_rand_mix", "tb_soc_chiplets", randomized=True),
    TestSpec(
        "bug_credit_off_by_one",
        "tb_ucie_prbs",
        expected_status="FAIL",
        bug_mode="UCIE_BUG_CREDIT_OFF_BY_ONE",
        defines=("UCIE_BUG_CREDIT_OFF_BY_ONE",),
        suites=("stable", "bug"),
    ),
)


def rtl_sources() -> list[str]:
    return sorted(str(path) for path in RTL_DIR.rglob("*.sv"))


def sim_sources() -> list[str]:
    return sorted(str(path) for path in SIM_DIR.rglob("*.sv")) + \
        sorted(str(path) for path in SIM_DIR.rglob("*.svh"))


def bench_tb_file(bench: str) -> Path:
    return SIM_DIR / f"{bench}.sv"


def bench_binary_name(bench: str) -> str:
    return f"V{bench}"


def compile_key(bench: str, defines: tuple[str, ...]) -> str:
    fingerprint = hashlib.sha1()
    fingerprint.update("|".join((bench, *defines)).encode("utf-8"))
    for source in [*rtl_sources(), *sim_sources()]:
        path = Path(source)
        stat = path.stat()
        fingerprint.update(str(path).encode("utf-8"))
        fingerprint.update(str(stat.st_mtime_ns).encode("utf-8"))
        fingerprint.update(str(stat.st_size).encode("utf-8"))
    digest = fingerprint.hexdigest()[:10]
    return f"{bench}_{digest}"


def compile_binary(verilator: str, bench: str, defines: tuple[str, ...]) -> tuple[Path, Path]:
    BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    LOG_ROOT.mkdir(parents=True, exist_ok=True)

    key = compile_key(bench, defines)
    build_dir = BUILD_ROOT / key
    build_dir.mkdir(parents=True, exist_ok=True)
    binary = build_dir / bench_binary_name(bench)
    compile_log = LOG_ROOT / f"{key}.compile.log"

    cmd = [
        verilator,
        "--binary",
        "--sv",
        "--timing",
        "-Wall",
        *VERILATOR_WARNINGS,
        *[f"-D{define}" for define in defines],
        "--top-module",
        bench,
        f"-I{SIM_DIR}",
        str(bench_tb_file(bench)),
        *rtl_sources(),
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
        raise RuntimeError(f"Verilator compile failed for {bench} ({', '.join(defines) or 'nominal'})")
    return binary, compile_log


def pick_specs(args: argparse.Namespace) -> list[TestSpec]:
    explicit = {name.strip() for name in args.tests.split(",")} if args.tests else None
    selected: list[TestSpec] = []
    for spec in TEST_SPECS:
        if explicit is not None:
            if spec.name in explicit:
                selected.append(spec)
            continue
        if args.suite and args.suite not in spec.suites:
            continue
        if spec.default_enabled:
            selected.append(spec)
    return selected


def expand_runs(specs: Iterable[TestSpec], base_seed: int, random_seed_count: int) -> list[RunSpec]:
    rng = random.Random(base_seed)
    runs: list[RunSpec] = []
    for spec in specs:
        seed_iterations = random_seed_count if spec.randomized else 1
        for idx in range(seed_iterations):
            seed = rng.randrange(1, 2**31 - 1)
            suffix = f"_seed{seed:08x}" if seed_iterations > 1 or spec.expected_status == "FAIL" else ""
            runs.append(
                RunSpec(
                    run_id=f"{spec.name}{suffix}",
                    test=spec.name,
                    bench=spec.bench,
                    seed=seed,
                    randomized=spec.randomized,
                    expected_status=spec.expected_status,
                    bug_mode=spec.bug_mode,
                    defines=spec.defines,
                    max_cycles=spec.max_cycles,
                    plusargs=spec.plusargs,
                )
            )
    return runs


def write_manifest(rows: list[dict[str, str]]) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    with MANIFEST_PATH.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "run_id",
                "test",
                "bench",
                "seed",
                "randomized",
                "expected_status",
                "bug_mode",
                "defines",
                "max_cycles",
                "log_path",
                "compile_log_path",
                "cov_csv",
                "score_csv",
                "elapsed_s",
                "returncode",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)


def run_suite(args: argparse.Namespace) -> int:
    specs = pick_specs(args)
    if not specs:
        print("No tests selected.", file=sys.stderr)
        return 2

    REPORT_ROOT.mkdir(parents=True, exist_ok=True)
    LOG_ROOT.mkdir(parents=True, exist_ok=True)
    (BUILD_ROOT / "artifacts").mkdir(parents=True, exist_ok=True)

    binaries: dict[tuple[str, tuple[str, ...]], tuple[Path, Path]] = {}
    manifest_rows: list[dict[str, str]] = []

    for run in expand_runs(specs, args.seed, args.random_seeds):
        key = (run.bench, run.defines)
        if key not in binaries:
            binaries[key] = compile_binary(args.verilator, run.bench, run.defines)
        binary, compile_log = binaries[key]

        cov_csv = REPORT_ROOT / f"{run.run_id}_coverage.csv"
        score_csv = REPORT_ROOT / f"{run.run_id}_scoreboard.csv"
        log_path = LOG_ROOT / f"{run.run_id}.log"
        plusargs = [
            f"+TEST={run.test}",
            f"+SEED={run.seed}",
            f"+MAX_CYCLES={run.max_cycles}",
            f"+COV_OUT={cov_csv}",
            f"+SCORE_OUT={score_csv}",
        ]
        if run.bug_mode != "none":
            plusargs.append(f"+BUG_MODE={run.bug_mode}")
        plusargs.extend(f"+{arg}" for arg in run.plusargs)

        cmd = [str(binary), *plusargs]
        start = time.time()
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        elapsed = time.time() - start
        log_path.write_text(
            "## run_cmd\n"
            + " ".join(cmd)
            + "\n\n## stdout\n"
            + result.stdout
            + "\n## stderr\n"
            + result.stderr
        )

        manifest_rows.append(
            {
                "run_id": run.run_id,
                "test": run.test,
                "bench": run.bench,
                "seed": str(run.seed),
                "randomized": "1" if run.randomized else "0",
                "expected_status": run.expected_status,
                "bug_mode": run.bug_mode,
                "defines": " ".join(run.defines),
                "max_cycles": str(run.max_cycles),
                "log_path": str(log_path),
                "compile_log_path": str(compile_log),
                "cov_csv": str(cov_csv),
                "score_csv": str(score_csv),
                "elapsed_s": f"{elapsed:.3f}",
                "returncode": str(result.returncode),
            }
        )

    write_manifest(manifest_rows)

    parser_cmd = [
        sys.executable,
        str(ROOT / "scripts" / "parse_regression_results.py"),
        "--manifest",
        str(MANIFEST_PATH),
        "--output",
        str(REGRESS_SUMMARY),
    ]
    coverage_cmd = [
        sys.executable,
        str(ROOT / "scripts" / "gen_coverage_report.py"),
        "--summary",
        str(REGRESS_SUMMARY),
        "--output",
        str(COVERAGE_SUMMARY),
    ]
    failure_cmd = [
        sys.executable,
        str(ROOT / "scripts" / "gen_failure_summary.py"),
        "--summary",
        str(REGRESS_SUMMARY),
        "--coverage",
        str(COVERAGE_SUMMARY),
        "--failure-csv",
        str(FAILURE_BUCKETS),
        "--top-failures",
        str(TOP_FAILURES),
        "--dashboard",
        str(VERIFICATION_DASHBOARD),
    ]
    for cmd in (parser_cmd, coverage_cmd, failure_cmd):
        subprocess.run(cmd, cwd=ROOT, check=True)

    print(f"Regression summary: {REGRESS_SUMMARY}")
    print(f"Coverage summary:   {COVERAGE_SUMMARY}")
    print(f"Failure buckets:    {FAILURE_BUCKETS}")
    print(f"Dashboard:          {VERIFICATION_DASHBOARD}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the Verilator DV regression for the UCIe chiplet benches.")
    parser.add_argument("--suite", default="stable", choices=["stable", "stress", "bug"], help="Named regression suite.")
    parser.add_argument("--tests", default="", help="Comma-separated explicit test list. Overrides --suite.")
    parser.add_argument("--random-seeds", type=int, default=2, help="Seeds to sweep for randomized named tests.")
    parser.add_argument("--seed", type=int, default=20260329, help="Master regression seed.")
    parser.add_argument("--verilator", default=os.environ.get("VERILATOR", "verilator"), help="Verilator executable.")
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(run_suite(parse_args()))
