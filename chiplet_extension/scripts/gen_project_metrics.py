#!/usr/bin/env python3
"""Generate one resume-facing project metrics snapshot from canonical reports."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = ROOT.parent
REPORTS = ROOT / "reports"
DOCS = REPO_ROOT / "docs"


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def yes(value: str) -> bool:
    return value in {"1", "yes", "true", "PASS", "pass"}


def count_total(rows: list[dict[str, str]], predicate) -> tuple[int, int]:
    return sum(1 for row in rows if predicate(row)), len(rows)


def metric_pair(numer: int, denom: int) -> str:
    return f"{numer} / {denom}" if denom else "NA"


def assertion_count(path: Path) -> str:
    if not path.exists():
        return "NA"
    text = path.read_text()
    match = re.search(r"Total inventoried assertions/invariants:\s*(\d+)", text)
    return match.group(1) if match else "NA"


def overall_coverage(rows: list[dict[str, str]]) -> tuple[str, str]:
    row = next((item for item in rows if item.get("metric") == "__overall__"), None)
    if not row:
        return "NA", "NA"
    return metric_pair(int(row.get("covered", "0")), int(row.get("total_bins", "0"))), row.get("sum_value", "NA")


def power_summary(rows: list[dict[str, str]]) -> tuple[str, str]:
    detail_rows = [row for row in rows if row.get("test") != "__overall__"]
    passed = sum(1 for row in detail_rows if yes(row.get("meets_expectation", "")))
    overall = next((row for row in rows if row.get("test") == "__overall__"), {})
    targets = ", ".join(
        value
        for value in [
            overall.get("states_visited", ""),
            overall.get("transitions_visited", ""),
            overall.get("domain_combos_visited", ""),
            overall.get("isolation_bins_visited", ""),
            overall.get("retention_bins_visited", ""),
            overall.get("activity_cross_bins_visited", ""),
            overall.get("switch_domain_bins_visited", ""),
            overall.get("isolation_domain_bins_visited", ""),
            overall.get("sequence_bins_visited", ""),
        ]
        if value
    )
    return metric_pair(passed, len(detail_rows)), targets or "NA"


def cross_summary(rows: list[dict[str, str]]) -> str:
    if not rows:
        return "NA"
    observed = sum(1 for row in rows if row.get("status") == "observed")
    return metric_pair(observed, len(rows))


def random_stress_summary(rows: list[dict[str, str]]) -> str:
    if not rows:
        return "NA"
    valid_rows = [row for row in rows if row.get("constraint_status", "valid") == "valid"]
    invalid_rows = [row for row in rows if row.get("constraint_status") == "invalid"]
    passed = sum(1 for row in valid_rows if yes(row.get("meets_expectation", "")))
    valid_pair = metric_pair(passed, len(valid_rows))
    if invalid_rows:
        return f"{valid_pair} valid; {len(invalid_rows)} schema-rejected"
    return valid_pair


def key_value_file(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    values: dict[str, str] = {}
    for line in path.read_text(errors="ignore").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def axi_lite_summary(rows: list[dict[str, str]]) -> str:
    if not rows:
        return "NA"
    hit = sum(1 for row in rows if row.get("hit") == "1")
    return metric_pair(hit, len(rows))


def optional_bench_summary(rows: list[dict[str, str]], bench: str) -> str:
    row = next((item for item in rows if item.get("bench") == bench), None)
    if not row:
        return "NA"
    return row.get("status", "NA")


def generate(csv_out: Path, md_out: Path) -> None:
    regress = read_csv(REPORTS / "regress_summary.csv")
    coverage = read_csv(REPORTS / "coverage_summary.csv")
    power = read_csv(REPORTS / "power_state_summary.csv")
    cross = read_csv(REPORTS / "cross_coverage_summary.csv")
    true_cross = read_csv(REPORTS / "true_cross_coverage_summary.csv")
    random_stress = read_csv(REPORTS / "random_stress_regress_summary.csv")
    formal = read_csv(REPORTS / "formal_summary.csv")
    negative = read_csv(REPORTS / "negative_test_summary.csv")
    optional_benches = read_csv(REPORTS / "optional_bench_summary.csv")
    axi_lite = read_csv(REPORTS / "axi_lite_coverage_summary.csv")
    firmware = read_csv(REPORTS / "firmware_soc_summary.csv")
    firmware_coverage = read_csv(REPORTS / "firmware_coverage_summary.csv")
    firmware_cross = read_csv(REPORTS / "firmware_cross_coverage_summary.csv")
    firmware_code_cov = key_value_file(REPORTS / "firmware_code_coverage_summary.txt")
    firmware_c = read_csv(REPORTS / "firmware_c_summary.csv")
    firmware_c_directed = read_csv(REPORTS / "firmware_c_directed_summary.csv")
    firmware_c_coverage = read_csv(REPORTS / "firmware_c_coverage_summary.csv")
    firmware_c_cross = read_csv(REPORTS / "firmware_c_cross_coverage_summary.csv")
    firmware_c_code_cov = key_value_file(REPORTS / "firmware_c_code_coverage_summary.txt")
    firmware_c_mutations = read_csv(REPORTS / "firmware_c_mutation_summary.csv")
    firmware_c_isa_random = read_csv(REPORTS / "firmware_c_isa_random_summary.csv")
    firmware_c_workload_random = read_csv(REPORTS / "firmware_c_workload_random_summary.csv")
    code_cov = key_value_file(REPORTS / "code_coverage_summary.txt")
    solver_formal = read_csv(REPORTS / "formal_proof_summary.csv")
    async_cdc = read_csv(REPORTS / "async_cdc_summary.csv")
    uvm_ci = read_csv(REPORTS / "uvm_ci_regress_summary.csv")

    stable_pass = sum(1 for row in regress if yes(row.get("meets_expectation", "")))
    nominal_rows = [row for row in regress if row.get("expected_status") == "PASS"]
    nominal_pass = sum(1 for row in nominal_rows if row.get("status") == "PASS")
    randomized_rows = [row for row in regress if row.get("scenario") == "random"]
    randomized_pass = sum(1 for row in randomized_rows if yes(row.get("meets_expectation", "")))
    bug_rows = [row for row in regress if row.get("expected_status") == "FAIL"]
    bug_pass = sum(1 for row in bug_rows if yes(row.get("meets_expectation", "")))
    dma_rows = [row for row in regress if row.get("test", "").startswith("dma_") and row.get("expected_status") == "PASS"]
    dma_pass = sum(1 for row in dma_rows if row.get("status") == "PASS")
    mem_rows = [row for row in regress if row.get("test", "").startswith("mem_") and row.get("expected_status") == "PASS"]
    mem_pass = sum(1 for row in mem_rows if row.get("status") == "PASS")
    formal_pass = sum(1 for row in formal if yes(row.get("meets_expectation", "")))
    negative_pass = sum(1 for row in negative if yes(row.get("meets_expectation", "")))

    coverage_pair, coverage_pct = overall_coverage(coverage)
    power_pair, power_targets = power_summary(power)
    cross_pair = cross_summary(cross)
    true_cross_pair = cross_summary(true_cross)
    random_pair = random_stress_summary(random_stress)
    assertions = assertion_count(DOCS / "reference" / "assertion_inventory.md")
    axi_pair = axi_lite_summary(axi_lite)
    axi_status = optional_bench_summary(optional_benches, "axi_lite")
    optional_cov = code_cov.get("optional_collateral_rtl_line_coverage_pct", "NA")
    firmware_pass = sum(1 for row in firmware if row.get("status") == "PASS")
    firmware_cov_hit = sum(1 for row in firmware_coverage if row.get("hit") == "1")
    firmware_cross_hit = sum(1 for row in firmware_cross if row.get("hit") == "1")
    firmware_code_pct = firmware_code_cov.get("focus_line_coverage_pct", "NA")
    firmware_c_all = firmware_c if any(row.get("family") != "directed" for row in firmware_c) else firmware_c + firmware_c_isa_random + firmware_c_workload_random
    firmware_c_pass = sum(1 for row in firmware_c_all if row.get("status") == "PASS")
    firmware_c_directed_rows = firmware_c_directed or [row for row in firmware_c if row.get("family") == "directed"]
    firmware_c_cov_hit = sum(1 for row in firmware_c_coverage if row.get("hit") == "1")
    firmware_c_code_pct = firmware_c_code_cov.get("focus_line_coverage_pct", "NA")
    firmware_c_branch_pct = firmware_c_code_cov.get("focus_branch_expression_coverage_pct", "NA")
    firmware_c_cross_hit = sum(1 for row in firmware_c_cross if row.get("hit") == "1")
    solver_proves = [row for row in solver_formal if row.get("task") == "prove"]
    solver_covers = [row for row in solver_formal if row.get("task") == "cover"]
    solver_mutations = [row for row in solver_formal if row.get("task") == "mutation"]
    async_pass = sum(row.get("status") == "PASS" for row in async_cdc)
    uvm_pass = sum(row.get("status") == "PASS" for row in uvm_ci)

    metrics = [
        ("stable_runs", metric_pair(stable_pass, len(regress)), "Default stable/closure regression rows meeting expectation."),
        ("nominal_pass_rate", metric_pair(nominal_pass, len(nominal_rows)), "Expected-pass rows with PASS status."),
        ("randomized_stable_runs", metric_pair(randomized_pass, len(randomized_rows)), "Randomized rows inside the stable gate."),
        ("expected_bug_failures", metric_pair(bug_pass, len(bug_rows)), "Expected-fail bug-validation rows that failed as intended."),
        ("dma_nominal_runs", metric_pair(dma_pass, len(dma_rows)), "Expected-pass DMA rows."),
        ("memory_nominal_runs", metric_pair(mem_pass, len(mem_rows)), "Expected-pass memory rows."),
        ("functional_coverage", coverage_pair, f"Flat closure bins, {coverage_pct}% covered."),
        ("low_power_proxy_targets", power_pair, f"Low-power proxy rows; aggregate targets: {power_targets}."),
        ("cross_coverage_groups", cross_pair, "Grouped cross-evidence derived from flat coverage metrics."),
        ("true_cross_groups", true_cross_pair, "Interaction-level cross evidence when generated."),
        ("bounded_property_checks", metric_pair(formal_pass, len(formal)), "Nominal and expected-fail bounded assertion harnesses."),
        ("solver_formal_proofs", metric_pair(sum(row.get("status") == "PASS" for row in solver_proves), len(solver_proves)), "SymbiYosys unbounded safety proof tasks when the pinned toolchain is available."),
        ("solver_formal_covers", metric_pair(sum(row.get("status") == "PASS" for row in solver_covers), len(solver_covers)), "Reachability tasks paired with solver proofs."),
        ("formal_mutation_sensitivity", metric_pair(sum(row.get("status") == "PASS" for row in solver_mutations), len(solver_mutations)), "Expected counterexamples under property-specific mutations."),
        ("negative_tests", metric_pair(negative_pass, len(negative)), "Illegal-operation tests with explicit expected response."),
        ("optional_random_stress_subset", random_pair, "Optional seeded-random execution subset; not part of default closure."),
        ("assertion_inventory", assertions, "Inventoried protocol/control invariants."),
        ("axi_lite_protocol_coverage", axi_pair, "Optional AXI-Lite CSR wrapper directed protocol coverage."),
        ("axi_lite_optional_bench", axi_status, "AXI-Lite optional bench status."),
        ("firmware_soc_scenarios", metric_pair(firmware_pass, len(firmware)), "ROM-backed RV32 programs controlling DMA through APB MMIO."),
        ("firmware_mmio_coverage", metric_pair(firmware_cov_hit, len(firmware_coverage)), "Firmware/MMIO protocol and scenario coverage points."),
        ("firmware_outcome_crosses", metric_pair(firmware_cross_hit, len(firmware_cross)), "Firmware outcome, power-state, and wait-state interaction crosses."),
        ("firmware_focused_code_coverage", f"{firmware_code_pct}%" if firmware_code_pct != "NA" else "NA", "Focused Verilator line coverage for RV32/APB/ROM integration RTL."),
        ("compiled_firmware_scenarios", metric_pair(firmware_c_pass, len(firmware_c_all)), "GCC-built directed and seeded executions checked against the repository-local independent RV32 ISS."),
        ("compiled_firmware_directed", metric_pair(sum(1 for row in firmware_c_directed_rows if row.get("status") == "PASS"), len(firmware_c_directed_rows)), "Named GCC-built firmware scenarios."),
        ("compiled_firmware_isa_random", metric_pair(sum(1 for row in firmware_c_isa_random if row.get("status") == "PASS"), len(firmware_c_isa_random)), "Deterministic generated CPU instruction streams."),
        ("compiled_firmware_workload_random", metric_pair(sum(1 for row in firmware_c_workload_random if row.get("status") == "PASS"), len(firmware_c_workload_random)), "Deterministic firmware/DMA workload seeds."),
        ("compiled_firmware_coverage", metric_pair(firmware_c_cov_hit, len(firmware_c_coverage)), "RV32I/Zicsr, APB, interrupt, trap, and firmware outcome points."),
        ("compiled_firmware_crosses", metric_pair(firmware_c_cross_hit, len(firmware_c_cross)), "Compiled firmware, DMA outcome, power, reset, and interrupt interactions."),
        ("compiled_firmware_focused_code_coverage", f"{firmware_c_code_pct}%" if firmware_c_code_pct != "NA" else "NA", "Focused Verilator line coverage for the GCC-driven RV32/APB/ROM integration RTL."),
        ("compiled_firmware_focused_branch_coverage", f"{firmware_c_branch_pct}%" if firmware_c_branch_pct != "NA" else "NA", "Focused RV32/APB/ROM branch/expression coverage."),
        ("compiled_firmware_mutation_detection", metric_pair(sum(1 for row in firmware_c_mutations if row.get("status") == "PASS"), len(firmware_c_mutations)), "RTL and architectural-trace mutations detected by SVA/ISS checking."),
        ("optional_collateral_code_coverage", f"{optional_cov}%" if optional_cov != "NA" else "NA", "Verilator line coverage for optional AXI/CDC collateral RTL."),
        ("integrated_async_cdc", metric_pair(async_pass, len(async_cdc)), "Optional two-clock chiplet matrix across clock ratios and reset skew."),
        ("real_uvm_ci", metric_pair(uvm_pass, len(uvm_ci)), "Pinned Verilator/UVM phase, TLM, coverage, and RAL smoke lane when executed."),
        ("design_line_coverage", f"{code_cov.get('design_line_coverage_pct', 'NA')}%" if code_cov.get("design_line_coverage_pct") else "NA", "Native Verilator design-RTL line coverage."),
        ("design_branch_expression_coverage", f"{code_cov.get('design_branch_expression_coverage_pct', 'NA')}%" if code_cov.get('design_branch_expression_coverage_pct') else "NA", "Verilator design-RTL branch/expression outcome coverage."),
        ("design_toggle_coverage", f"{code_cov.get('design_toggle_coverage_pct', 'NA')}%" if code_cov.get('design_toggle_coverage_pct') else "NA", "Raw toggle coverage with signals wider than 32 bits excluded by instrumentation policy."),
        ("design_toggle_reviewed", f"{code_cov.get('design_toggle_reviewed_coverage_pct', 'NA')}%" if code_cov.get('design_toggle_reviewed_coverage_pct') else "NA", "Reviewed toggle coverage after documented structural, fixed-credit-bit, and diagnostic-counter exclusions."),
    ]

    csv_out.parent.mkdir(parents=True, exist_ok=True)
    with csv_out.open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["metric", "value", "note"])
        writer.writerows(metrics)

    lines = [
        "# Project Metrics",
        "",
        "This is the single resume-facing metrics snapshot for the chiplet project. It is generated from the canonical CSV reports by `make -C chiplet_extension project-metrics`.",
        "",
        "| Metric | Value | Note |",
        "| --- | --- | --- |",
    ]
    for metric, value, note in metrics:
        lines.append(f"| `{metric}` | `{value}` | {note} |")
    lines.extend(
        [
            "",
            "## Claim Boundary",
            "",
            "- `stable_runs`, `functional_coverage`, `low_power_proxy_targets`, `bounded_property_checks`, `firmware_soc_scenarios`, and `expected_bug_failures` are the core evidence set.",
            "- `optional_random_stress_subset`, UVM artifacts, and characterization reports are useful supporting evidence, but they are not the default closure gate.",
            "- Raw per-test CSVs are generated artifacts; the checked-in project should keep summaries and curated documentation instead.",
            "",
        ]
    )
    md_out.parent.mkdir(parents=True, exist_ok=True)
    md_out.write_text("\n".join(lines))

    compiled_doc = DOCS / "reference" / "compiled_firmware_verification.md"
    if compiled_doc.exists() and firmware_c_code_pct != "NA":
        text = compiled_doc.read_text()
        replacement = (
            f"- Focused RV32/APB/ROM line coverage: **{firmware_c_code_pct}%** "
            f"(`rv32_core`: **{firmware_c_code_cov.get('rv32_core_line_coverage_pct', 'NA')}%**); "
            f"branch/expression: **{firmware_c_branch_pct}%**"
        )
        text = re.sub(r"- Focused RV32/APB/ROM line coverage:.*", replacement, text)
        compiled_doc.write_text(text)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate project metrics from canonical report artifacts.")
    parser.add_argument("--csv-out", default=str(REPORTS / "project_metrics.csv"))
    parser.add_argument("--md-out", default=str(DOCS / "project_metrics.md"))
    args = parser.parse_args()
    generate(Path(args.csv_out), Path(args.md_out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
