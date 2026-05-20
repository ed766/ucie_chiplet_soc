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
REFERENCE_ROOT = BUILD_ROOT / "reference"
MANIFEST_PATH = BUILD_ROOT / "run_manifest.csv"
REGRESS_SUMMARY = REPORT_ROOT / "regress_summary.csv"
COVERAGE_SUMMARY = REPORT_ROOT / "coverage_summary.csv"
FAILURE_BUCKETS = REPORT_ROOT / "failure_buckets.csv"
TOP_FAILURES = REPORT_ROOT / "top_failures.md"
VERIFICATION_DASHBOARD = REPORT_ROOT / "verification_dashboard.md"
REGRESSION_HISTORY = REPORT_ROOT / "regression_history.csv"
CLOSURE_TARGETS = REPORT_ROOT / "closure_targets.md"
POWER_SUMMARY = REPORT_ROOT / "power_state_summary.csv"
COVERAGE_CLOSURE_MATRIX = REPORT_ROOT / "coverage_closure_matrix.md"
CROSS_COVERAGE_SUMMARY = REPORT_ROOT / "cross_coverage_summary.csv"

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
    ref_words: int = 512
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
    ref_words: int
    plusargs: tuple[str, ...] = field(default_factory=tuple)


TEST_SPECS: tuple[TestSpec, ...] = (
    TestSpec("prbs_smoke", "tb_ucie_prbs"),
    TestSpec("prbs_credit_starve", "tb_ucie_prbs"),
    TestSpec("prbs_credit_low", "tb_ucie_prbs"),
    TestSpec("prbs_retry_single", "tb_ucie_prbs", max_cycles=12000),
    TestSpec("prbs_retry_backpressure", "tb_ucie_prbs", max_cycles=14000),
    TestSpec("prbs_crc_burst_recover", "tb_ucie_prbs", max_cycles=14000),
    TestSpec("prbs_lane_fault_recover", "tb_ucie_prbs", max_cycles=15000),
    TestSpec("prbs_reset_midflight", "tb_ucie_prbs"),
    TestSpec("prbs_backpressure_wave", "tb_ucie_prbs"),
    TestSpec("prbs_latency_low", "tb_ucie_prbs"),
    TestSpec("prbs_latency_nominal", "tb_ucie_prbs"),
    TestSpec("prbs_latency_high", "tb_ucie_prbs", max_cycles=14000),
    TestSpec("prbs_rand_stress", "tb_ucie_prbs", randomized=True, max_cycles=30000),
    TestSpec("prbs_retry_burst", "tb_ucie_prbs", default_enabled=False, suites=("stress",)),
    TestSpec("prbs_crc_storm", "tb_ucie_prbs", default_enabled=False, suites=("stress",)),
    TestSpec("prbs_fault_retrain", "tb_ucie_prbs", default_enabled=False, suites=("stress",)),
    TestSpec("soc_smoke", "tb_soc_chiplets"),
    TestSpec("soc_wrong_key", "tb_soc_chiplets"),
    TestSpec("soc_misalign", "tb_soc_chiplets"),
    TestSpec("soc_backpressure", "tb_soc_chiplets"),
    TestSpec("soc_expected_empty", "tb_soc_chiplets", ref_words=4),
    TestSpec("soc_fault_echo", "tb_soc_chiplets", default_enabled=False, suites=("stress",)),
    TestSpec("soc_retry_e2e", "tb_soc_chiplets", default_enabled=False, suites=("stress",)),
    TestSpec("soc_rand_mix", "tb_soc_chiplets", default_enabled=False, randomized=True, suites=("stress",)),
    TestSpec("random_manifest_scenario", "tb_soc_chiplets", default_enabled=False, max_cycles=32000, ref_words=0, suites=("stress",)),
    TestSpec("power_run_mode", "tb_soc_chiplets", suites=("stable", "power")),
    TestSpec("power_crypto_only", "tb_soc_chiplets", max_cycles=7000, suites=("stable", "power")),
    TestSpec("power_sleep_entry_exit", "tb_soc_chiplets", max_cycles=8000, suites=("stable", "power")),
    TestSpec("power_deep_sleep_recover", "tb_soc_chiplets", max_cycles=9000, suites=("stable", "power")),
    TestSpec("power_isolation_blocks_tx", "tb_soc_chiplets", max_cycles=9000, suites=("power",)),
    TestSpec("power_wakeup_releases_isolation_cleanly", "tb_soc_chiplets", max_cycles=10000, suites=("power",)),
    TestSpec("power_transition_with_link_backpressure", "tb_soc_chiplets", max_cycles=12000, suites=("power", "negative")),
    TestSpec("power_illegal_access_error_response", "tb_soc_chiplets", max_cycles=10000, ref_words=0, suites=("power", "negative")),
    TestSpec("power_traffic_cross_test", "tb_soc_chiplets", max_cycles=24000, ref_words=8, suites=("power",)),
    TestSpec("dma_queue_smoke", "tb_soc_chiplets", max_cycles=12000, ref_words=4),
    TestSpec("dma_queue_back_to_back", "tb_soc_chiplets", max_cycles=14000, ref_words=12),
    TestSpec("dma_queue_full_reject", "tb_soc_chiplets", max_cycles=18000, ref_words=16, suites=("stable", "negative")),
    TestSpec("dma_completion_fifo_drain", "tb_soc_chiplets", max_cycles=18000, ref_words=12),
    TestSpec("dma_irq_masking", "tb_soc_chiplets", max_cycles=14000, ref_words=4),
    TestSpec("dma_odd_len_reject", "tb_soc_chiplets", max_cycles=8000, ref_words=0),
    TestSpec("dma_range_reject", "tb_soc_chiplets", max_cycles=8000, ref_words=0),
    TestSpec("dma_timeout_error", "tb_soc_chiplets", max_cycles=12000, ref_words=0),
    TestSpec("dma_retry_recover_queue", "tb_soc_chiplets", max_cycles=22000, ref_words=8),
    TestSpec("dma_power_sleep_resume_queue", "tb_soc_chiplets", max_cycles=18000, ref_words=8, suites=("stable", "power")),
    TestSpec("dma_sleep_during_queued_work", "tb_soc_chiplets", max_cycles=18000, ref_words=4, suites=("power",)),
    TestSpec("dma_sleep_during_active_transfer", "tb_soc_chiplets", max_cycles=20000, ref_words=8, suites=("power",)),
    TestSpec("dma_comp_fifo_full_stall", "tb_soc_chiplets", max_cycles=22000, ref_words=20),
    TestSpec("dma_irq_pending_then_enable", "tb_soc_chiplets", max_cycles=14000, ref_words=4),
    TestSpec("dma_comp_pop_empty", "tb_soc_chiplets", max_cycles=6000, ref_words=0, suites=("stable", "negative")),
    TestSpec("dma_reset_mid_queue", "tb_soc_chiplets", max_cycles=12000, ref_words=0),
    TestSpec("dma_tag_reuse", "tb_soc_chiplets", max_cycles=16000, ref_words=8),
    TestSpec("dma_power_state_retention_matrix", "tb_soc_chiplets", max_cycles=18000, ref_words=4, suites=("stable", "power")),
    TestSpec("dma_crypto_only_submit_blocked", "tb_soc_chiplets", max_cycles=10000, ref_words=0, suites=("stable", "power", "negative")),
    TestSpec("mem_bank_parallel_service", "tb_soc_chiplets", max_cycles=16000, ref_words=8, suites=("stable", "memory")),
    TestSpec("mem_src_bank_conflict", "tb_soc_chiplets", max_cycles=16000, ref_words=8, suites=("stable", "memory")),
    TestSpec("mem_dst_bank_conflict", "tb_soc_chiplets", max_cycles=18000, ref_words=8, suites=("stable", "memory")),
    TestSpec("mem_read_while_dma", "tb_soc_chiplets", max_cycles=16000, ref_words=8, suites=("stable", "memory")),
    TestSpec("mem_write_while_dma_reject", "tb_soc_chiplets", max_cycles=16000, ref_words=8, suites=("stable", "memory", "negative")),
    TestSpec("mem_op_start_busy_reject", "tb_soc_chiplets", default_enabled=False, max_cycles=12000, ref_words=0, suites=("negative",)),
    TestSpec("mem_inject_start_busy_reject", "tb_soc_chiplets", default_enabled=False, max_cycles=12000, ref_words=0, suites=("negative",)),
    TestSpec("mem_parity_src_detect", "tb_soc_chiplets", max_cycles=12000, ref_words=0, suites=("stable", "memory", "negative")),
    TestSpec("mem_parity_dst_maint_detect", "tb_soc_chiplets", max_cycles=10000, ref_words=0, suites=("stable", "memory")),
    TestSpec("mem_sleep_retained_bank", "tb_soc_chiplets", max_cycles=12000, ref_words=0, suites=("stable", "power", "memory")),
    TestSpec("mem_sleep_nonretained_bank", "tb_soc_chiplets", max_cycles=12000, ref_words=0, suites=("stable", "power", "memory")),
    TestSpec("mem_nonretained_readback_poison_clean", "tb_soc_chiplets", max_cycles=12000, ref_words=0, suites=("stable", "power", "memory")),
    TestSpec("mem_invalid_clear_on_write", "tb_soc_chiplets", max_cycles=12000, ref_words=0, suites=("stable", "power", "memory")),
    TestSpec("mem_deep_sleep_retention_matrix", "tb_soc_chiplets", max_cycles=14000, ref_words=0, suites=("stable", "power", "memory")),
    TestSpec("mem_crypto_only_cfg_access", "tb_soc_chiplets", max_cycles=12000, ref_words=0, suites=("stable", "power", "memory")),
    TestSpec(
        "bug_credit_off_by_one",
        "tb_ucie_prbs",
        expected_status="FAIL",
        bug_mode="UCIE_BUG_CREDIT_OFF_BY_ONE",
        defines=("UCIE_BUG_CREDIT_OFF_BY_ONE",),
        suites=("stable", "bug"),
    ),
    TestSpec(
        "bug_crc_poly",
        "tb_ucie_prbs",
        expected_status="FAIL",
        bug_mode="UCIE_BUG_CRC_POLY",
        defines=("UCIE_BUG_CRC_POLY",),
        suites=("stable", "bug"),
    ),
    TestSpec(
        "bug_retry_seq",
        "tb_ucie_prbs",
        expected_status="FAIL",
        bug_mode="UCIE_BUG_RETRY_SEQ",
        defines=("UCIE_BUG_RETRY_SEQ",),
        max_cycles=12000,
        suites=("stable", "bug"),
    ),
    TestSpec(
        "dma_bug_done_early",
        "tb_soc_chiplets",
        expected_status="FAIL",
        bug_mode="UCIE_BUG_DMA_DONE_EARLY",
        defines=("UCIE_BUG_DMA_DONE_EARLY",),
        max_cycles=14000,
        ref_words=8,
        suites=("stable", "bug"),
    ),
    TestSpec(
        "mem_bug_parity_skip",
        "tb_soc_chiplets",
        expected_status="FAIL",
        bug_mode="UCIE_BUG_MEM_PARITY_SKIP",
        defines=("UCIE_BUG_MEM_PARITY_SKIP",),
        max_cycles=12000,
        ref_words=0,
        suites=("stable", "bug", "memory"),
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


def normalize_params(params: dict[str, int | str] | tuple[tuple[str, int | str], ...] | None) -> tuple[tuple[str, str], ...]:
    if params is None:
        return ()
    if isinstance(params, dict):
        items = params.items()
    else:
        items = params
    return tuple(sorted((str(key), str(value)) for key, value in items))


def compile_key(bench: str, defines: tuple[str, ...], params: tuple[tuple[str, str], ...] = ()) -> str:
    fingerprint = hashlib.sha1()
    fingerprint.update("|".join((bench, *defines)).encode("utf-8"))
    if params:
        fingerprint.update("|".join(f"{key}={value}" for key, value in params).encode("utf-8"))
    for source in [*rtl_sources(), *sim_sources()]:
        path = Path(source)
        stat = path.stat()
        fingerprint.update(str(path).encode("utf-8"))
        fingerprint.update(str(stat.st_mtime_ns).encode("utf-8"))
        fingerprint.update(str(stat.st_size).encode("utf-8"))
    digest = fingerprint.hexdigest()[:10]
    return f"{bench}_{digest}"


def compile_binary(
    verilator: str,
    bench: str,
    defines: tuple[str, ...],
    params: dict[str, int | str] | tuple[tuple[str, int | str], ...] | None = None,
) -> tuple[Path, Path]:
    BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    LOG_ROOT.mkdir(parents=True, exist_ok=True)

    normalized_params = normalize_params(params)
    key = compile_key(bench, defines, normalized_params)
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
        *[f"-G{param}={value}" for param, value in normalized_params],
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
        if args.suite == "stable":
            if spec.default_enabled and args.suite in spec.suites:
                selected.append(spec)
            continue
        if args.suite == "closure":
            if (spec.default_enabled and "stable" in spec.suites) or ("power" in spec.suites):
                selected.append(spec)
            continue
        if args.suite in spec.suites:
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
                    ref_words=spec.ref_words,
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
                "power_csv",
                "ref_csv",
                "elapsed_s",
                "returncode",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)


@dataclass(frozen=True)
class ReportPaths:
    summary: Path
    coverage: Path
    failure_buckets: Path
    top_failures: Path
    dashboard: Path
    history: Path
    closure_targets: Path
    power: Path
    closure_matrix: Path


def report_paths(prefix: str) -> ReportPaths:
    stem = f"{prefix.strip()}_" if prefix.strip() else ""
    return ReportPaths(
        summary=REPORT_ROOT / f"{stem}regress_summary.csv",
        coverage=REPORT_ROOT / f"{stem}coverage_summary.csv",
        failure_buckets=REPORT_ROOT / f"{stem}failure_buckets.csv",
        top_failures=REPORT_ROOT / f"{stem}top_failures.md",
        dashboard=REPORT_ROOT / f"{stem}verification_dashboard.md",
        history=REPORT_ROOT / f"{stem}regression_history.csv",
        closure_targets=REPORT_ROOT / f"{stem}closure_targets.md",
        power=REPORT_ROOT / f"{stem}power_state_summary.csv",
        closure_matrix=REPORT_ROOT / f"{stem}coverage_closure_matrix.md",
    )


def load_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def plusarg_map(plusargs: Iterable[str]) -> dict[str, str]:
    values: dict[str, str] = {}
    for item in plusargs:
        if "=" not in item:
            continue
        key, value = item.split("=", 1)
        values[key] = value
    return values


def write_regression_history(summary_path: Path, coverage_path: Path, output_path: Path) -> None:
    summary_rows = load_csv_rows(summary_path)
    coverage_rows = load_csv_rows(coverage_path)
    if not summary_rows:
        return

    overall_cov = next((row for row in coverage_rows if row["metric"] == "__overall__"), None)
    total_runs = len(summary_rows)
    meets_expectation = sum(1 for row in summary_rows if row["meets_expectation"] == "1")
    nominal_total = sum(1 for row in summary_rows if row["expected_status"] == "PASS")
    nominal_pass = sum(1 for row in summary_rows if row["expected_status"] == "PASS" and row["status"] == "PASS")
    randomized_total = sum(1 for row in summary_rows if row["scenario"] == "random")
    randomized_pass = sum(1 for row in summary_rows if row["scenario"] == "random" and row["meets_expectation"] == "1")
    bug_expected_failures = sum(1 for row in summary_rows if row["expected_status"] == "FAIL" and row["meets_expectation"] == "1")

    fieldnames = [
        "timestamp_utc",
        "total_runs",
        "meets_expectation",
        "nominal_pass",
        "nominal_total",
        "randomized_pass",
        "randomized_total",
        "bug_expected_failures",
        "covered_bins",
        "total_bins",
        "coverage_pct",
    ]
    existing_rows = load_csv_rows(output_path)
    existing_rows.append(
        {
            "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "total_runs": str(total_runs),
            "meets_expectation": str(meets_expectation),
            "nominal_pass": str(nominal_pass),
            "nominal_total": str(nominal_total),
            "randomized_pass": str(randomized_pass),
            "randomized_total": str(randomized_total),
            "bug_expected_failures": str(bug_expected_failures),
            "covered_bins": overall_cov["covered"] if overall_cov else "0",
            "total_bins": overall_cov["total_bins"] if overall_cov else "0",
            "coverage_pct": overall_cov["sum_value"] if overall_cov else "0.0",
        }
    )

    with output_path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(existing_rows[-12:])


def write_closure_targets(summary_path: Path, coverage_path: Path, output_path: Path) -> None:
    summary_rows = load_csv_rows(summary_path)
    coverage_rows = load_csv_rows(coverage_path)
    uncovered = [row for row in coverage_rows if row["metric"] != "__overall__" and row["covered"] == "0"]
    expected_bug_failures = [row for row in summary_rows if row["expected_status"] == "FAIL" and row["meets_expectation"] == "1"]

    lines = [
        "# Verification Closure Targets",
        "",
        "## Current Snapshot",
        "",
        f"- Stable runs recorded: {len(summary_rows)}",
        f"- Expected bug-validation failures observed: {len(expected_bug_failures)}",
        "",
        "## Closure Wins",
        "",
        "- Deterministic retry / CRC / lane-fault tests are part of the named-test flow.",
        "- Bug validation now covers credit accounting, CRC integrity, and retry identity.",
        "- End-to-end SoC checking uses a file-backed Python golden-model reference path.",
        "",
        "## Remaining Uncovered Bins",
        "",
    ]

    if uncovered:
        for row in uncovered:
            lines.append(f"- `{row['metric']}` ({row['category']})")
    else:
        lines.append("- None in the current checked-in summary.")

    output_path.write_text("\n".join(lines) + "\n")


def run_suite(args: argparse.Namespace) -> int:
    specs = pick_specs(args)
    if not specs:
        print("No tests selected.", file=sys.stderr)
        return 2

    REPORT_ROOT.mkdir(parents=True, exist_ok=True)
    LOG_ROOT.mkdir(parents=True, exist_ok=True)
    REFERENCE_ROOT.mkdir(parents=True, exist_ok=True)
    (BUILD_ROOT / "artifacts").mkdir(parents=True, exist_ok=True)
    paths = report_paths(args.report_prefix)
    run_id_prefix = args.run_id_prefix.strip()

    binaries: dict[tuple[str, tuple[str, ...]], tuple[Path, Path]] = {}
    manifest_rows: list[dict[str, str]] = []

    for run in expand_runs(specs, args.seed, args.random_seeds):
        output_run_id = f"{run_id_prefix}_{run.run_id}" if run_id_prefix else run.run_id
        run_plusargs = [*run.plusargs, *args.plusarg]
        runtime_arg_map = plusarg_map(run_plusargs)
        key = (run.bench, run.defines)
        if key not in binaries:
            binaries[key] = compile_binary(args.verilator, run.bench, run.defines)
        binary, compile_log = binaries[key]

        cov_csv = REPORT_ROOT / f"{output_run_id}_coverage.csv"
        score_csv = REPORT_ROOT / f"{output_run_id}_scoreboard.csv"
        power_csv = REPORT_ROOT / f"{output_run_id}_power.csv"
        ref_csv = REFERENCE_ROOT / f"{output_run_id}_expected.csv"
        ref_csv_str = ""
        power_csv_str = ""
        log_path = LOG_ROOT / f"{output_run_id}.log"
        plusargs = [
            f"+TEST={run.test}",
            f"+SEED={run.seed}",
            f"+MAX_CYCLES={run.max_cycles}",
            f"+COV_OUT={cov_csv}",
            f"+SCORE_OUT={score_csv}",
        ]
        if run.bench == "tb_soc_chiplets":
            ref_cmd = [
                sys.executable,
                str(ROOT / "scripts" / "gen_reference_vectors.py"),
                "--test",
                run.test,
                "--output",
                str(ref_csv),
                "--words",
                str(run.ref_words),
            ]
            dynamic_ref_options = {
                "DMA_SRC_BASE": "--dma-src-base",
                "DMA_DST_BASE": "--dma-dst-base",
                "DMA_LEN_WORDS": "--dma-len-words",
                "DMA_TAG": "--dma-tag",
                "DMA2_SRC_BASE": "--dma2-src-base",
                "DMA2_DST_BASE": "--dma2-dst-base",
                "DMA2_LEN_WORDS": "--dma2-len-words",
                "DMA2_TAG": "--dma2-tag",
                "QUEUE_PRESSURE": "--queue-pressure",
            }
            for plusarg_name, option_name in dynamic_ref_options.items():
                if plusarg_name in runtime_arg_map:
                    ref_cmd.extend([option_name, runtime_arg_map[plusarg_name]])
            subprocess.run(ref_cmd, cwd=ROOT, check=True)
            plusargs.append(f"+REF_CSV={ref_csv}")
            plusargs.append(f"+POWER_OUT={power_csv}")
            ref_csv_str = str(ref_csv)
            power_csv_str = str(power_csv)
        if run.bug_mode != "none":
            plusargs.append(f"+BUG_MODE={run.bug_mode}")
        plusargs.extend(f"+{arg}" for arg in run_plusargs)

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
                "run_id": output_run_id,
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
                "cov_csv": str(cov_csv) if cov_csv.exists() else "",
                "score_csv": str(score_csv) if score_csv.exists() else "",
                "power_csv": power_csv_str if power_csv_str and power_csv.exists() else "",
                "ref_csv": ref_csv_str if ref_csv_str and ref_csv.exists() else "",
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
        str(paths.summary),
    ]
    coverage_cmd = [
        sys.executable,
        str(ROOT / "scripts" / "gen_coverage_report.py"),
        "--summary",
        str(paths.summary),
        "--output",
        str(paths.coverage),
    ]
    power_cmd = [
        sys.executable,
        str(ROOT / "scripts" / "gen_power_report.py"),
        "--summary",
        str(paths.summary),
        "--output",
        str(paths.power),
    ]
    failure_cmd = [
        sys.executable,
        str(ROOT / "scripts" / "gen_failure_summary.py"),
        "--summary",
        str(paths.summary),
        "--coverage",
        str(paths.coverage),
        "--power-summary",
        str(paths.power),
        "--failure-csv",
        str(paths.failure_buckets),
        "--top-failures",
        str(paths.top_failures),
        "--dashboard",
        str(paths.dashboard),
    ]
    for cmd in (parser_cmd, coverage_cmd, power_cmd, failure_cmd):
        subprocess.run(cmd, cwd=ROOT, check=True)

    if not args.tests and args.suite in {"stable", "closure"} and not args.report_prefix:
        write_regression_history(paths.summary, paths.coverage, paths.history)
        write_closure_targets(paths.summary, paths.coverage, paths.closure_targets)
        subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts" / "gen_coverage_closure.py"),
                "--coverage",
                str(paths.coverage),
                "--history",
                str(paths.history),
                "--output",
                str(paths.closure_matrix),
                "--cross-output",
                str(REPORT_ROOT / (f"{args.report_prefix.strip()}_cross_coverage_summary.csv" if args.report_prefix.strip() else "cross_coverage_summary.csv")),
            ],
            cwd=ROOT,
            check=True,
        )

    print(f"Regression summary: {paths.summary}")
    print(f"Coverage summary:   {paths.coverage}")
    print(f"Failure buckets:    {paths.failure_buckets}")
    print(f"Dashboard:          {paths.dashboard}")
    print(f"Power summary:      {paths.power}")
    print(f"Trend history:      {paths.history}")
    print(f"Closure targets:    {paths.closure_targets}")
    print(f"Closure matrix:     {paths.closure_matrix}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the Verilator DV regression for the UCIe chiplet benches.")
    parser.add_argument("--suite", default="stable", choices=["stable", "stress", "bug", "power", "closure", "negative"], help="Named regression suite.")
    parser.add_argument("--tests", default="", help="Comma-separated explicit test list. Overrides --suite.")
    parser.add_argument("--random-seeds", type=int, default=3, help="Seeds to sweep for randomized named tests.")
    parser.add_argument("--seed", type=int, default=20260329, help="Master regression seed.")
    parser.add_argument("--verilator", default=os.environ.get("VERILATOR", "verilator"), help="Verilator executable.")
    parser.add_argument("--report-prefix", default="", help="Prefix aggregate report filenames, e.g. smoke or uvm.")
    parser.add_argument("--run-id-prefix", default="", help="Prefix per-run artifact IDs to avoid clobbering closure artifacts.")
    parser.add_argument(
        "--plusarg",
        action="append",
        default=[],
        help="Additional runtime plusarg without leading '+'. May be repeated.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(run_suite(parse_args()))
