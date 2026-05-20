#!/usr/bin/env python3
"""Generate Phase A DMA/memory architecture characterization tables."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from run_regression import LOG_ROOT, REPORT_ROOT, ROOT, compile_binary


BUILD_ROOT = ROOT / "build" / "characterization_dma_mem"
DOC_ROOT = ROOT.parent / "docs"

NA = "NA"
DMA_CHAR_RESULT_PREFIX = "CHAR_RESULT|"
DV_RESULT_PREFIX = "DV_RESULT|"


CSV_FIELDS = [
    "study_family",
    "phase",
    "workload",
    "seed_policy",
    "queue_depth",
    "comp_depth",
    "bank_mode",
    "parity_enable",
    "timeout_profile",
    "status",
    "detail",
    "descriptor_throughput",
    "average_completion_latency_cycles",
    "max_completion_latency_cycles",
    "submit_reject_count",
    "completion_occupancy_mean",
    "completion_occupancy_max",
    "completion_full_cycle_fraction",
    "source_conflict_count",
    "destination_conflict_count",
    "maintenance_wait_cycles",
    "maintenance_starvation_incidence",
    "maint_wait_mean",
    "maint_wait_p95",
    "maint_wait_max",
    "invalid_abort_count",
    "recovery_writes",
    "recovery_cycles",
    "throughput_penalty_vs_baseline",
    "synth_cell_count",
    "synth_area_estimate",
    "synth_worst_path_delay",
    "synth_cell_count_delta",
    "synth_area_delta",
    "synth_worst_path_delay_delta",
    "notes",
    "compile_log",
    "run_log",
]


@dataclass(frozen=True)
class PhaseACase:
    study_family: str
    workload: str
    test: str
    params: dict[str, int]
    seed: int
    max_cycles: int
    notes: str
    phase: str = "A"
    seed_policy: str = "1x_deterministic"


def parse_result_line(log_text: str, prefix: str) -> dict[str, str]:
    for line in reversed(log_text.splitlines()):
        if line.startswith(prefix):
            fields: dict[str, str] = {}
            for part in line.split("|")[1:]:
                if "=" in part:
                    key, value = part.split("=", 1)
                    fields[key] = value
            return fields
    return {}


def format_ratio(numer: int, denom: int) -> str:
    if denom == 0:
        return "0.0000"
    return f"{numer / denom:.4f}"


def na_row() -> dict[str, str]:
    return {field: NA for field in CSV_FIELDS}


def populate_common(
    row: dict[str, str],
    case: PhaseACase,
    dv_fields: dict[str, str],
    char_fields: dict[str, str],
    compile_log: Path,
    run_log: Path,
) -> dict[str, str]:
    samples = int(char_fields.get("completion_occupancy_samples", "0"))
    desc_completed = int(char_fields.get("desc_completed", "0"))
    maint_wait_count = int(char_fields.get("maint_wait_count", "0"))
    src_wait = int(char_fields.get("src_wait_cycles", "0"))
    dst_wait = int(char_fields.get("dst_wait_cycles", "0"))
    status = dv_fields.get("status", char_fields.get("status", "FAIL"))
    detail = char_fields.get("detail", dv_fields.get("detail", "missing_result"))
    if case.study_family == "invalid_memory_recovery_sweep":
        recovered = int(char_fields.get("recovery_writes", "0")) > 0 and int(char_fields.get("recovery_cycles", "0")) > 0
        if recovered:
            status = "PASS"
            detail = "invalid_memory_recovery_observed"
    row.update(
        {
            "study_family": case.study_family,
            "phase": case.phase,
            "workload": case.workload,
            "seed_policy": case.seed_policy,
            "queue_depth": str(case.params["DMA_SUBMIT_QUEUE_DEPTH"]),
            "comp_depth": str(case.params["DMA_COMP_QUEUE_DEPTH"]),
            "bank_mode": str(case.params["DMA_BANKS"]),
            "parity_enable": str(case.params["DMA_PARITY_ENABLE"]),
            "timeout_profile": "nominal",
            "status": status,
            "detail": detail,
            "descriptor_throughput": format_ratio(desc_completed, int(char_fields.get("sample_cycles", "0"))),
            "average_completion_latency_cycles": char_fields.get("latency_avg_cycles", "0"),
            "max_completion_latency_cycles": char_fields.get("latency_max_cycles", "0"),
            "submit_reject_count": char_fields.get("submit_reject_count", "0"),
            "completion_occupancy_mean": format_ratio(int(char_fields.get("completion_occupancy_sum", "0")), samples),
            "completion_occupancy_max": char_fields.get("completion_occupancy_max", "0"),
            "completion_full_cycle_fraction": format_ratio(int(char_fields.get("completion_full_cycles", "0")), samples),
            "source_conflict_count": char_fields.get("src_conflicts", "0"),
            "destination_conflict_count": char_fields.get("dst_conflicts", "0"),
            "maintenance_wait_cycles": str(src_wait + dst_wait),
            "maintenance_starvation_incidence": format_ratio(int(char_fields.get("maint_wait_above32", "0")), maint_wait_count),
            "maint_wait_mean": format_ratio(int(char_fields.get("maint_wait_sum", "0")), maint_wait_count),
            "maint_wait_p95": char_fields.get("maint_wait_p95", "0"),
            "maint_wait_max": char_fields.get("maint_wait_max", "0"),
            "invalid_abort_count": char_fields.get("invalid_abort_count", "0"),
            "recovery_writes": char_fields.get("recovery_writes", NA),
            "recovery_cycles": char_fields.get("recovery_cycles", NA),
            "throughput_penalty_vs_baseline": NA,
            "synth_cell_count": NA,
            "synth_area_estimate": NA,
            "synth_worst_path_delay": NA,
            "synth_cell_count_delta": NA,
            "synth_area_delta": NA,
            "synth_worst_path_delay_delta": NA,
            "notes": case.notes,
            "compile_log": str(compile_log),
            "run_log": str(run_log),
        }
    )
    return row


def run_soc_case(verilator: str, case: PhaseACase) -> dict[str, str]:
    BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    REPORT_ROOT.mkdir(parents=True, exist_ok=True)
    ref_root = BUILD_ROOT / "reference"
    ref_root.mkdir(parents=True, exist_ok=True)

    binary, compile_log = compile_binary(verilator, "tb_soc_chiplets", (), params=case.params)
    run_name = f"{case.study_family}_{case.workload}_q{case.params['DMA_SUBMIT_QUEUE_DEPTH']}_c{case.params['DMA_COMP_QUEUE_DEPTH']}_b{case.params['DMA_BANKS']}_p{case.params['DMA_PARITY_ENABLE']}"
    cov_csv = REPORT_ROOT / f"{run_name}_coverage.csv"
    score_csv = REPORT_ROOT / f"{run_name}_scoreboard.csv"
    power_csv = REPORT_ROOT / f"{run_name}_power.csv"
    ref_csv = ref_root / f"{run_name}_expected.csv"
    run_log = BUILD_ROOT / f"{run_name}.log"

    ref_cmd = [
        sys.executable,
        str(ROOT / "scripts" / "gen_reference_vectors.py"),
        "--test",
        case.test,
        "--output",
        str(ref_csv),
        "--words",
        "0",
    ]
    subprocess.run(ref_cmd, cwd=ROOT, check=True)

    cmd = [
        str(binary),
        f"+TEST={case.test}",
        f"+SEED={case.seed}",
        f"+MAX_CYCLES={case.max_cycles}",
        f"+COV_OUT={cov_csv}",
        f"+SCORE_OUT={score_csv}",
        f"+POWER_OUT={power_csv}",
        f"+REF_CSV={ref_csv}",
    ]
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    log_text = "## run_cmd\n" + " ".join(cmd) + "\n\n## stdout\n" + result.stdout + "\n## stderr\n" + result.stderr
    run_log.write_text(log_text)

    dv_fields = parse_result_line(log_text, DV_RESULT_PREFIX)
    char_fields = parse_result_line(log_text, DMA_CHAR_RESULT_PREFIX)
    if not char_fields:
        raise RuntimeError(f"Missing {DMA_CHAR_RESULT_PREFIX} line for {case.test}")

    row = na_row()
    row = populate_common(row, case, dv_fields, char_fields, compile_log, run_log)
    return row


def find_yosys() -> str:
    cmd = subprocess.run(["bash", "-lc", "command -v yosys || true"], capture_output=True, text=True, check=True)
    candidate = cmd.stdout.strip()
    if candidate:
        return candidate
    for path in sorted(Path("/nix/store").glob("*/bin/yosys")):
        if path.is_file():
            return str(path)
    raise RuntimeError("yosys not found")


def run_parity_synth_proxy(
    yosys_bin: str,
    parity_enable: int,
    work_dir: Path,
) -> dict[str, str]:
    work_dir.mkdir(parents=True, exist_ok=True)
    script_path = work_dir / f"parity_{parity_enable}.ys"
    log_path = work_dir / f"parity_{parity_enable}.log"
    top_file = ROOT / "rtl" / "die_a" / "dma_offload_ctrl.sv"
    script_path.write_text(
        "\n".join(
            [
                f"read_verilog -sv {top_file}",
                "hierarchy -check -top dma_offload_ctrl",
                f"chparam -set DATA_WIDTH 64 dma_offload_ctrl",
                f"chparam -set SRAM_DEPTH 256 dma_offload_ctrl",
                f"chparam -set DMA_TIMEOUT_CYCLES 1024 dma_offload_ctrl",
                f"chparam -set SUBMIT_QUEUE_DEPTH 4 dma_offload_ctrl",
                f"chparam -set COMP_QUEUE_DEPTH 4 dma_offload_ctrl",
                f"chparam -set BANKS 2 dma_offload_ctrl",
                f"chparam -set PARITY_ENABLE {parity_enable} dma_offload_ctrl",
                "proc; opt; memory; opt",
                "fsm; opt",
                "techmap; opt",
                "abc -g simple",
                "opt",
                "stat",
                "ltp",
            ]
        )
        + "\n"
    )
    result = subprocess.run([yosys_bin, "-s", str(script_path)], cwd=ROOT, capture_output=True, text=True)
    log_path.write_text(
        "## yosys_cmd\n"
        + " ".join([yosys_bin, "-s", str(script_path)])
        + "\n\n## stdout\n"
        + result.stdout
        + "\n## stderr\n"
        + result.stderr
    )
    if result.returncode != 0:
        return {
            "cell_count": NA,
            "area_estimate": NA,
            "worst_path_delay": NA,
            "log_path": str(log_path),
        }

    cell_count = 0
    cell_hist: dict[str, int] = {}
    area_units = 0.0
    delay_proxy = 0.0
    weights = {
        "$_NOT_": 1.0,
        "$_AND_": 1.0,
        "$_NAND_": 1.0,
        "$_OR_": 1.0,
        "$_NOR_": 1.0,
        "$_XOR_": 1.5,
        "$_XNOR_": 1.5,
        "$_MUX_": 2.0,
        "$_AOI3_": 1.5,
        "$_OAI3_": 1.5,
        "$_AOI4_": 2.0,
        "$_OAI4_": 2.0,
        "$_DFF_P_": 4.0,
        "$_DFF_N_": 4.0,
        "$_DFFE_PP_": 5.0,
        "$_DFFE_PN_": 5.0,
    }
    for line in result.stdout.splitlines():
        match = re.search(r"^\s+([$_A-Za-z0-9]+)\s+(\d+)$", line)
        if match and match.group(1).startswith("$_"):
            cell_hist[match.group(1)] = int(match.group(2))
        if "Number of cells:" in line:
            cell_count = int(line.rsplit(":", 1)[1].strip())
        depth_match = re.search(r"Longest topological path.*?([0-9]+(?:\.[0-9]+)?)", line)
        if depth_match:
            delay_proxy = float(depth_match.group(1))

    for cell_name, count in cell_hist.items():
        area_units += weights.get(cell_name, 1.0) * count

    return {
        "cell_count": str(cell_count),
        "area_estimate": f"{area_units:.1f}",
        "worst_path_delay": f"{delay_proxy:.1f}",
        "log_path": str(log_path),
    }


def load_perf_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def render_protocol_markdown(perf_rows: list[dict[str, str]], dma_rows: list[dict[str, str]], output_path: Path) -> None:
    lines = [
        "# Protocol Characterization",
        "",
        "These measurements come from the behavioral Verilator benches and a lightweight synthesis-based parity proxy.",
        "They are architecture and verification characterizations, not silicon signoff numbers.",
        "",
        "## Behavioral Performance Characterization",
        "",
    ]

    if perf_rows:
        latency_rows = [row for row in perf_rows if row["sweep"] == "latency_vs_channel_delay"]
        lines.extend(
            [
                "### Link / PRBS Sweeps",
                "",
                "| Label | Sweep | Knob | Avg latency | Throughput | Status |",
                "| --- | --- | ---: | ---: | ---: | --- |",
            ]
        )
        for row in perf_rows:
            lines.append(
                f"| `{row['label']}` | `{row['sweep']}` | {row['knob_value']} | "
                f"{row['latency_avg_cycles']} | {row['throughput_flits_per_cycle']} | {row['status']} |"
            )
        if latency_rows:
            lines.extend(
                [
                    "",
                    "- Link characterization stays in `perf_characterization.csv`; the DMA/memory tradeoff data is kept separate in `dma_mem_characterization.csv`.",
                    "- The existing PRBS sweeps remain the behavioral baseline for latency, backpressure, and retry-density trends.",
                    "",
                ]
            )
    else:
        lines.extend(
            [
                "Link characterization CSV was not available when this document was rendered.",
                "",
            ]
        )

    lines.extend(
        [
            "## DMA/Memory Architectural Tradeoff Characterization",
            "",
            "### Phase A Visual Summary",
            "",
            "| Study | Best point | Why it wins |",
            "| --- | --- | --- |",
        ]
    )

    def best_row(study: str, key: str, reverse: bool = True) -> dict[str, str] | None:
        study_rows = [row for row in dma_rows if row["study_family"] == study and row["status"] == "PASS"]
        numeric_rows: list[tuple[float, dict[str, str]]] = []
        for row in study_rows:
            try:
                numeric_rows.append((float(row[key]), row))
            except (KeyError, TypeError, ValueError):
                continue
        if not numeric_rows:
            return None
        return sorted(numeric_rows, key=lambda item: item[0], reverse=reverse)[0][1]

    queue_depth_rows = [
        row
        for row in dma_rows
        if row["study_family"] == "queue_depth_sweep"
        and row["workload"] == "dma_back_to_back"
        and row["status"] == "PASS"
    ]
    queue_best = (
        sorted(queue_depth_rows, key=lambda row: float(row["average_completion_latency_cycles"]))[0]
        if queue_depth_rows
        else None
    )
    bank_best = best_row("bank_mode_sweep", "maintenance_wait_cycles", reverse=False)
    parity_best = best_row("parity_cost_sweep", "synth_area_delta", reverse=False)
    invalid_best = best_row("invalid_memory_recovery_sweep", "throughput_penalty_vs_baseline", reverse=False)
    summary_rows = [
        ("Queue depth", queue_best, "With one active descriptor, shallower queues minimize average completion latency under fixed immediate-drain traffic."),
        ("Bank mode", bank_best, "Two-bank mode reduces maintenance conflict and wait pressure without changing the software-visible memory model."),
        ("Parity cost", parity_best, "Parity-enabled vs disabled cost is captured when the local synthesis proxy can elaborate the DMA slice."),
        ("Invalid recovery", invalid_best, "Recovery cost is reported in explicit writes and cycles until required banks become valid."),
    ]
    for label, row, note in summary_rows:
        if row is None:
            lines.append(f"| {label} | `n/a` | {note} |")
        else:
            lines.append(
                f"| {label} | `{row['workload']} q{row['queue_depth']} b{row['bank_mode']} p{row['parity_enable']}` | {note} |"
            )

    study_tables = [
        ("queue_depth_sweep", "Queue Depth Sweep", ["queue_depth", "descriptor_throughput", "average_completion_latency_cycles", "max_completion_latency_cycles", "submit_reject_count", "completion_occupancy_mean"]),
        ("bank_mode_sweep", "Bank Mode Sweep", ["bank_mode", "workload", "source_conflict_count", "destination_conflict_count", "maint_wait_mean", "maint_wait_p95", "maintenance_starvation_incidence"]),
        ("maintenance_starvation_sweep", "Maintenance Starvation Sweep", ["bank_mode", "maint_wait_mean", "maint_wait_p95", "maint_wait_max", "maintenance_starvation_incidence"]),
        ("invalid_memory_recovery_sweep", "Invalid-Memory Recovery Sweep", ["invalid_abort_count", "recovery_writes", "recovery_cycles", "throughput_penalty_vs_baseline"]),
    ]
    for family, title, columns in study_tables:
        family_rows = [row for row in dma_rows if row["study_family"] == family]
        if not family_rows:
            continue
        lines.extend([f"", f"### {title}", "", "| " + " | ".join(col.replace("_", " ") for col in columns) + " |", "| " + " | ".join(["---"] * len(columns)) + " |"])
        for row in family_rows:
            lines.append("| " + " | ".join(row.get(col, NA) for col in columns) + " |")
        if family == "queue_depth_sweep":
            lines.extend(
                [
                    "",
                    "- Queue depth is measured under fixed 32-descriptor back-to-back submission pressure.",
                    "- The queue study uses immediate completion draining so the sensitivity reflects submit-side elasticity, not delayed software service.",
                ]
            )
        elif family == "bank_mode_sweep":
            lines.extend(
                [
                    "",
                    "- The 1-bank vs 2-bank comparison is a structural compile-time sweep, not a runtime mode bit.",
                    "- Conflict-light and conflict-heavy workloads alternate source and destination maintenance reads 50/50.",
                ]
            )
        elif family == "maintenance_starvation_sweep":
            lines.extend(
                [
                    "",
                    "- Starvation incidence is the fraction of maintenance reads with wait time greater than 32 cycles.",
                    "- The starvation view reuses the conflict-heavy measurements instead of inventing a second traffic generator.",
                ]
            )
        elif family == "invalid_memory_recovery_sweep":
            lines.extend(
                [
                    "",
                    "- Recovery rewrites one required word per invalid bank in ascending bank/address order.",
                    "- The reported recovery cost is behavioral and directly tied to the architectural invalid-bit clearing rule.",
                ]
            )

    parity_rows = [row for row in dma_rows if row["study_family"] == "parity_cost_sweep"]
    if parity_rows:
        synth_available = any(row["synth_cell_count"] != NA for row in parity_rows)
        lines.extend(
            [
                "",
                "## Synthesis-Proxy Cost Estimation",
                "",
                "| Parity | Throughput | Cell count | Area estimate | Worst-path delay | Cell delta | Area delta | Delay delta |",
                "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
            ]
        )
        for row in parity_rows:
            lines.append(
                f"| `{row['parity_enable']}` | {row['descriptor_throughput']} | {row['synth_cell_count']} | {row['synth_area_estimate']} | "
                f"{row['synth_worst_path_delay']} | {row['synth_cell_count_delta']} | {row['synth_area_delta']} | {row['synth_worst_path_delay_delta']} |"
            )
        lines.extend(
            [
                "",
                "- The parity proxy attempts to synthesize the `dma_offload_ctrl` slice with identical settings and only toggles `PARITY_ENABLE`.",
                (
                    "- The local Yosys proxy produced cost numbers for this run."
                    if synth_available
                    else "- The local Yosys proxy could not elaborate the current SystemVerilog slice, so cost fields are marked `NA`; behavioral parity-on/off results are still reported."
                ),
                "- Worst-path delay is a lightweight synthesis proxy when available and should not be read as signoff timing.",
                "",
                "## Notes",
                "",
                "- Phase A is intentionally limited to queue depth, bank mode, parity cost, maintenance starvation, and invalid-memory recovery.",
                "- Completion-depth, timeout-threshold, retention-policy, and retry/fault sensitivity sweeps remain deferred to Phase B.",
            ]
        )

    output_path.write_text("\n".join(lines) + "\n")


def make_phase_a_cases(base_seed: int) -> list[PhaseACase]:
    queue_base = {"DMA_SUBMIT_QUEUE_DEPTH": 4, "DMA_COMP_QUEUE_DEPTH": 4, "DMA_BANKS": 2, "DMA_PARITY_ENABLE": 1, "DMA_TIMEOUT_CYCLES": 1024}
    cases: list[PhaseACase] = [
        PhaseACase(
            study_family="queue_depth_sweep",
            workload="dma_back_to_back",
            test="char_dma_back_to_back",
            params={**queue_base, "DMA_SUBMIT_QUEUE_DEPTH": depth},
            seed=base_seed + idx,
            max_cycles=30000,
            notes="Back-to-back enqueue attempts every cycle across a fixed 32-descriptor workload.",
        )
        for idx, depth in enumerate((1, 2, 4))
    ]
    cases.append(
        PhaseACase(
            study_family="queue_depth_sweep",
            workload="dma_nominal_stream",
            test="char_dma_nominal_stream",
            params=queue_base,
            seed=base_seed + 20,
            max_cycles=20000,
            notes="Optional nominal-stream baseline row for queue-depth interpretation.",
        )
    )
    bank_seed = base_seed + 40
    for idx, bank_mode in enumerate((1, 2)):
        for offset, workload in enumerate(("char_mem_conflict_light", "char_mem_conflict_heavy")):
            cases.append(
                PhaseACase(
                    study_family="bank_mode_sweep",
                    workload=workload.replace("char_", ""),
                    test=workload,
                    params={**queue_base, "DMA_BANKS": bank_mode},
                    seed=bank_seed + (idx * 8) + offset,
                    max_cycles=28000,
                    notes="Maintenance reads are issued every 16 cycles with fixed 50/50 source/destination alternation.",
                )
            )
    for idx, parity_enable in enumerate((0, 1)):
        cases.append(
            PhaseACase(
                study_family="parity_cost_sweep",
                workload="dma_nominal_stream",
                test="char_dma_nominal_stream",
                params={**queue_base, "DMA_PARITY_ENABLE": parity_enable},
                seed=base_seed + 80 + idx,
                max_cycles=20000,
                notes="Parity on/off preserves interfaces and control flow while removing parity storage/checking internally.",
            )
        )
    cases.append(
        PhaseACase(
            study_family="invalid_memory_recovery_sweep",
            workload="invalid_memory_recovery",
            test="char_invalid_memory_recovery",
            params=queue_base,
            seed=base_seed + 100,
            max_cycles=24000,
            notes="Deterministic recovery rewrites one required word per invalid bank in ascending bank/address order.",
        )
    )
    return cases


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Phase A DMA/memory characterization tables.")
    parser.add_argument("--verilator", default="verilator", help="Verilator executable.")
    parser.add_argument("--seed", type=int, default=20260412, help="Base seed for deterministic characterization runs.")
    parser.add_argument(
        "--csv-out",
        default=str(REPORT_ROOT / "dma_mem_characterization.csv"),
        help="Destination CSV for DMA/memory characterization data.",
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

    rows: list[dict[str, str]] = []
    measured_bank_heavy: list[dict[str, str]] = []
    for case in make_phase_a_cases(args.seed):
        row = run_soc_case(args.verilator, case)
        rows.append(row)
        if case.study_family == "bank_mode_sweep" and case.workload == "char_mem_conflict_heavy".replace("char_", ""):
            measured_bank_heavy.append(row)

    for source_row in measured_bank_heavy:
        starvation_row = dict(source_row)
        starvation_row["study_family"] = "maintenance_starvation_sweep"
        starvation_row["notes"] = "Derived from the same conflict-heavy DMA-backed measurement point."
        rows.append(starvation_row)

    parity_proxy_rows = [row for row in rows if row["study_family"] == "parity_cost_sweep"]
    if parity_proxy_rows:
        yosys_bin = find_yosys()
        synth_root = BUILD_ROOT / "synth_proxy"
        proxy_by_parity: dict[str, dict[str, str]] = {}
        for parity_row in parity_proxy_rows:
            parity_key = parity_row["parity_enable"]
            if parity_key not in proxy_by_parity:
                proxy_by_parity[parity_key] = run_parity_synth_proxy(yosys_bin, int(parity_key), synth_root)
            proxy = proxy_by_parity[parity_key]
            parity_row["synth_cell_count"] = proxy["cell_count"]
            parity_row["synth_area_estimate"] = proxy["area_estimate"]
            parity_row["synth_worst_path_delay"] = proxy["worst_path_delay"]
            parity_row["run_log"] = proxy["log_path"]
        parity_off = next((row for row in parity_proxy_rows if row["parity_enable"] == "0"), None)
        if parity_off is not None:
            for row in parity_proxy_rows:
                if NA in {
                    row["synth_cell_count"],
                    row["synth_area_estimate"],
                    row["synth_worst_path_delay"],
                    parity_off["synth_cell_count"],
                    parity_off["synth_area_estimate"],
                    parity_off["synth_worst_path_delay"],
                }:
                    row["synth_cell_count_delta"] = NA
                    row["synth_area_delta"] = NA
                    row["synth_worst_path_delay_delta"] = NA
                    row["notes"] += " Synthesis proxy unavailable in this local Yosys flow; see run log."
                else:
                    row["synth_cell_count_delta"] = str(int(row["synth_cell_count"]) - int(parity_off["synth_cell_count"]))
                    row["synth_area_delta"] = f"{float(row['synth_area_estimate']) - float(parity_off['synth_area_estimate']):.1f}"
                    row["synth_worst_path_delay_delta"] = f"{float(row['synth_worst_path_delay']) - float(parity_off['synth_worst_path_delay']):.1f}"

    baseline_row = next(
        (
            row
            for row in rows
            if row["study_family"] == "parity_cost_sweep"
            and row["parity_enable"] == "1"
            and row["bank_mode"] == "2"
            and row["queue_depth"] == "4"
        ),
        None,
    )
    if baseline_row is not None:
        baseline_throughput = float(baseline_row["descriptor_throughput"])
        for row in rows:
            if row["study_family"] == "invalid_memory_recovery_sweep":
                penalty = 0.0 if baseline_throughput == 0.0 else (baseline_throughput - float(row["descriptor_throughput"])) / baseline_throughput
                row["throughput_penalty_vs_baseline"] = f"{penalty:.4f}"

    csv_path = Path(args.csv_out)
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    perf_rows = load_perf_rows(REPORT_ROOT / "perf_characterization.csv")
    render_protocol_markdown(perf_rows, rows, Path(args.markdown_out))

    unexpected = [row for row in rows if row["status"] != "PASS"]
    return 1 if unexpected else 0


if __name__ == "__main__":
    raise SystemExit(main())
