#!/usr/bin/env python3
"""Generate a compact Verilator code-coverage report."""

from __future__ import annotations

import argparse
import csv
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPORT_DIR = ROOT / "reports"
DEFAULT_GLOB_ROOT = ROOT / "build" / "verilator_regression" / "artifacts"


def display_path(path: Path) -> str:
    """Prefer repository-relative paths in checked-in reports."""
    try:
        return path.relative_to(ROOT.parent).as_posix()
    except ValueError:
        return str(path)


def parse_lcov(path: Path) -> tuple[int, int]:
    total = 0
    hit = 0
    if not path.exists():
        return total, hit
    for line in path.read_text(errors="ignore").splitlines():
        if line.startswith("DA:"):
            total += 1
            try:
                count = int(line.split(",", 1)[1])
            except (IndexError, ValueError):
                count = 0
            if count > 0:
                hit += 1
    return total, hit


def parse_lcov_files(path: Path) -> dict[str, dict[str, int]]:
    files: dict[str, dict[str, int]] = {}
    current = ""
    if not path.exists():
        return files
    for line in path.read_text(errors="ignore").splitlines():
        if line.startswith("SF:"):
            current = line[3:]
            files.setdefault(current, {"total": 0, "hit": 0})
        elif line.startswith("DA:") and current:
            files[current]["total"] += 1
            try:
                count = int(line.split(",", 1)[1])
            except (IndexError, ValueError):
                count = 0
            if count > 0:
                files[current]["hit"] += 1
        elif line == "end_of_record":
            current = ""
    return files


def parse_native_coverage(paths: list[Path]) -> tuple[dict[str, dict[str, int]], dict[str, set[str]]]:
    """Aggregate native Verilator points by type and retain per-test hit sets."""
    points: dict[str, dict[str, int]] = {}
    test_hits: dict[str, set[str]] = {}
    for path in paths:
        hits: set[str] = set()
        for line in path.read_text(errors="replace").splitlines():
            if not line.startswith("C '"):
                continue
            try:
                descriptor, count_text = line[3:].rsplit("' ", 1)
                count = int(count_text)
            except (ValueError, IndexError):
                continue
            page_match = re.search(r"\x01page\x02([^\x01]+)", descriptor)
            file_match = re.search(r"\x01f\x02([^\x01]+)", descriptor)
            if not page_match:
                continue
            page = page_match.group(1).split("/", 1)[0]
            point_type = {
                "v_line": "line", "v_branch": "branch", "v_expr": "expression",
                "v_toggle": "toggle", "v_user": "user", "v_covergroup": "covergroup",
                "v_fsm_state": "fsm_state", "v_fsm_arc": "fsm_arc",
            }.get(page, page.removeprefix("v_"))
            source = file_match.group(1) if file_match else ""
            if "/rtl/" not in source or "/rtl/bus/" in source or "/rtl/cdc/" in source:
                continue
            key = f"{point_type}|{descriptor}"
            points.setdefault(point_type, {})[key] = points.setdefault(point_type, {}).get(key, 0) + count
            if count > 0:
                hits.add(key)
        test_hits[path.stem] = hits
    return points, test_hits


def write_test_ranking(test_hits: dict[str, set[str]], output: Path) -> None:
    owners: dict[str, int] = {}
    for hits in test_hits.values():
        for point in hits:
            owners[point] = owners.get(point, 0) + 1
    rows = []
    for test, hits in test_hits.items():
        rows.append({
            "test_artifact": test,
            "covered_points": len(hits),
            "unique_points": sum(owners[point] == 1 for point in hits),
        })
    rows.sort(key=lambda row: (row["unique_points"], row["covered_points"]), reverse=True)
    with output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["test_artifact", "covered_points", "unique_points"])
        writer.writeheader(); writer.writerows(rows)


def coverage_pct(hit: int, total: int) -> float:
    return (100.0 * hit / total) if total else 0.0


def reviewed_toggle_exclusion(point_key: str) -> str:
    object_match = re.search(r"\x01o\x02([^\x01]+)", point_key)
    object_name = object_match.group(1) if object_match else ""
    bit_matches = re.findall(r"\[(\d+)\]", object_name)
    bit_index = int(bit_matches[-1]) if bit_matches else None
    diagnostic_counters = (
        "reject_overflow_count_q", "src_parity_errors_q", "dst_parity_errors_q",
        "src_conflicts_q", "dst_conflicts_q", "src_wait_cycles_q", "dst_wait_cycles_q",
    )
    if "channel_model.sv" in point_key and any(
        name in object_name for name in ("fwd_fault_pipe", "rev_fault_pipe")
    ):
        return "hardwired_channel_fault_pipeline"
    if "phy_behavioral.sv" in point_key and any(
        name in object_name for name in ("inject_error_q", "err_lane_q")
    ):
        return "disabled_phy_probability_state"
    if any(name in object_name for name in diagnostic_counters):
        return "long_horizon_diagnostic_counter"
    if "credit_init" in object_name:
        return "fixed_credit_initialization"
    if any(name in object_name for name in ("credit_debit", "credit_return", "credit_consumed")):
        if bit_index is not None and bit_index > 0:
            return "unit_credit_event_upper_bit"
    if any(name in object_name for name in ("credit_available", "credit_q", "credit_d", "available_credits")):
        if bit_index is not None and bit_index >= 8:
            return "credit_capacity_upper_bit"
    return ""


def point_metadata(point_key: str) -> tuple[str, int, str]:
    file_match = re.search(r"\x01f\x02([^\x01]+)", point_key)
    line_match = re.search(r"\x01l\x02(\d+)", point_key)
    object_match = re.search(r"\x01o\x02([^\x01]+)", point_key)
    source = file_match.group(1) if file_match else ""
    line = int(line_match.group(1)) if line_match else 0
    object_name = object_match.group(1) if object_match else ""
    return source, line, object_name


def write_coverage_holes(
    native_points: dict[str, dict[str, int]], output: Path
) -> list[dict[str, str | int]]:
    rows: list[dict[str, str | int]] = []
    for point_type, values in sorted(native_points.items()):
        for point_key, count in values.items():
            if count > 0:
                continue
            source, line, object_name = point_metadata(point_key)
            exclusion = reviewed_toggle_exclusion(point_key) if point_type == "toggle" else ""
            rows.append(
                {
                    "point_type": point_type,
                    "source": display_path(Path(source)) if source else "NA",
                    "line": line,
                    "object": object_name or "NA",
                    "hit_count": count,
                    "reviewed_exclusion": exclusion or "none",
                }
            )
    rows.sort(key=lambda row: (str(row["point_type"]), str(row["source"]), int(row["line"]), str(row["object"])))
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=("point_type", "source", "line", "object", "hit_count", "reviewed_exclusion"),
        )
        writer.writeheader()
        writer.writerows(rows)
    return rows


def coverage_group(source: str) -> str:
    source_path = Path(source)
    parts = set(source_path.parts)
    if "rtl" in parts:
        if "bus" in parts or "cdc" in parts:
            return "optional_collateral_rtl"
        return "design_rtl"
    if source_path.name.startswith("tb_"):
        return "testbench"
    if "checkers" in parts or "scoreboard" in parts or "dv" in parts:
        return "checker_monitor"
    return "other"


def file_component(source: str) -> str:
    name = Path(source).name
    if name == "axi_lite_csr_bridge.sv":
        return "axi_lite_bridge"
    if name == "rv32_core.sv":
        return "rv32_core"
    if name == "apb_dma_csr_bridge.sv":
        return "apb_dma_csr_bridge"
    if name == "rv32_rom_feeder.sv":
        return "rv32_rom_feeder"
    if name == "soc_chiplet_rv32_top.sv":
        return "soc_chiplet_rv32_top"
    if name in {"cdc_sync_2ff.sv", "cdc_pulse_sync.sv"}:
        return "cdc_rdc_collateral"
    if name == "credit_mgr.sv":
        return "credit_manager"
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize Verilator code coverage data.")
    parser.add_argument("--dat-dir", default=str(DEFAULT_GLOB_ROOT), help="Directory containing *.coverage.dat files.")
    parser.add_argument("--prefix", default="", help="Optional coverage data filename prefix to include.")
    parser.add_argument("--output-txt", default=str(REPORT_DIR / "code_coverage_summary.txt"))
    parser.add_argument("--output-md", default=str(REPORT_DIR / "code_coverage_summary.md"))
    parser.add_argument("--info-out", default=str(REPORT_DIR / "code_coverage.info"))
    parser.add_argument("--focus-components", default="", help="Comma-separated component names to aggregate.")
    parser.add_argument("--minimum-focus-pct", type=float, default=0.0)
    parser.add_argument("--holes-out", default="", help="Optional uncovered-point CSV output.")
    parser.add_argument("--enforce-release-targets", action="store_true")
    parser.add_argument("--minimum-line-pct", type=float, default=95.0)
    parser.add_argument("--minimum-branch-pct", type=float, default=85.0)
    parser.add_argument("--minimum-reviewed-toggle-pct", type=float, default=90.0)
    args = parser.parse_args()

    dat_dir = Path(args.dat_dir).resolve()
    pattern = f"{args.prefix}*.coverage.dat" if args.prefix else "*.coverage.dat"
    dat_files = sorted(dat_dir.glob(pattern))
    output_txt = Path(args.output_txt).resolve()
    output_md = Path(args.output_md).resolve()
    info_out = Path(args.info_out).resolve()
    output_txt.parent.mkdir(parents=True, exist_ok=True)

    tool = shutil.which("verilator_coverage")
    if not dat_files:
        output_txt.write_text("status=FAIL\nreason=no_coverage_dat_files\n")
        output_md.write_text("# Verilator Code Coverage Summary\n\nNo coverage `.dat` files were found.\n")
        return 1
    if not tool:
        output_txt.write_text("status=SKIP\nreason=verilator_coverage_not_found\n")
        output_md.write_text("# Verilator Code Coverage Summary\n\n`verilator_coverage` was not found in PATH.\n")
        return 0

    merge_cmd = [tool, "--write-info", str(info_out), *[str(path) for path in dat_files]]
    merge = subprocess.run(merge_cmd, cwd=ROOT, capture_output=True, text=True)
    annotate_dir = ROOT / "build" / "code_coverage_annotated"
    annotate_dir.mkdir(parents=True, exist_ok=True)
    annotate_cmd = [tool, "--annotate", str(annotate_dir), *[str(path) for path in dat_files]]
    annotate = subprocess.run(annotate_cmd, cwd=ROOT, capture_output=True, text=True)

    total, hit = parse_lcov(info_out)
    file_cov = parse_lcov_files(info_out)
    native_points, test_hits = parse_native_coverage(dat_files)
    hole_rows = write_coverage_holes(native_points, Path(args.holes_out).resolve()) if args.holes_out else []
    raw_toggle_points = native_points.get("toggle", {})
    reviewed_toggle_points = {
        key: count for key, count in raw_toggle_points.items() if not reviewed_toggle_exclusion(key)
    }
    reviewed_toggle_hit = sum(count > 0 for count in reviewed_toggle_points.values())
    reviewed_toggle_total = len(reviewed_toggle_points)
    reviewed_exclusion_counts: dict[str, int] = {}
    for key in raw_toggle_points:
        reason = reviewed_toggle_exclusion(key)
        if reason:
            reviewed_exclusion_counts[reason] = reviewed_exclusion_counts.get(reason, 0) + 1
    ranking_out = REPORT_DIR / "code_coverage_test_ranking.csv"
    write_test_ranking(test_hits, ranking_out)
    pct = coverage_pct(hit, total)
    groups: dict[str, dict[str, int]] = {}
    components: dict[str, dict[str, int]] = {}
    for source, counts in file_cov.items():
        group = coverage_group(source)
        groups.setdefault(group, {"hit": 0, "total": 0})
        groups[group]["hit"] += counts["hit"]
        groups[group]["total"] += counts["total"]
        component = file_component(source)
        if component:
            components.setdefault(component, {"hit": 0, "total": 0})
            components[component]["hit"] += counts["hit"]
            components[component]["total"] += counts["total"]
    design = groups.get("design_rtl", {"hit": 0, "total": 0})
    top_uncovered = sorted(
        (
            (
                counts["total"] - counts["hit"],
                counts["total"],
                counts["hit"],
                source,
            )
            for source, counts in file_cov.items()
            if coverage_group(source) == "design_rtl" and counts["total"] > counts["hit"]
        ),
        reverse=True,
    )[:8]
    status = "PASS" if merge.returncode == 0 else "FAIL"
    optional_collateral = groups.get("optional_collateral_rtl", {"hit": 0, "total": 0})
    focus_names = [name.strip() for name in args.focus_components.split(",") if name.strip()]
    focus = {"hit": 0, "total": 0}
    for name in focus_names:
        counts = components.get(name, {"hit": 0, "total": 0})
        focus["hit"] += counts["hit"]
        focus["total"] += counts["total"]
    focus_pct = coverage_pct(focus["hit"], focus["total"])
    if focus_names and (focus["total"] == 0 or focus_pct < args.minimum_focus_pct):
        status = "FAIL"
    native_line = native_points.get("line", {})
    native_branch = native_points.get("branch", {})
    native_line_pct = coverage_pct(sum(count > 0 for count in native_line.values()), len(native_line))
    native_branch_pct = coverage_pct(sum(count > 0 for count in native_branch.values()), len(native_branch))
    reviewed_toggle_pct = coverage_pct(reviewed_toggle_hit, reviewed_toggle_total)
    target_misses: list[str] = []
    if native_line_pct < args.minimum_line_pct:
        target_misses.append("line")
    if native_branch_pct < args.minimum_branch_pct:
        target_misses.append("branch_expression")
    if reviewed_toggle_pct < args.minimum_reviewed_toggle_pct:
        target_misses.append("reviewed_toggle")
    release_failures = target_misses if args.enforce_release_targets else []
    if args.enforce_release_targets:
        if release_failures:
            status = "FAIL"

    output_txt.write_text(
        "\n".join(
            [
                f"status={status}",
                f"coverage_dat_files={len(dat_files)}",
                f"line_points_hit={hit}",
                f"line_points_total={total}",
                f"line_coverage_pct={pct:.2f}",
        f"design_rtl_line_points_hit={design['hit']}",
        f"design_rtl_line_points_total={design['total']}",
        f"design_rtl_line_coverage_pct={coverage_pct(design['hit'], design['total']):.2f}",
        f"optional_collateral_rtl_line_points_hit={optional_collateral['hit']}",
        f"optional_collateral_rtl_line_points_total={optional_collateral['total']}",
        f"optional_collateral_rtl_line_coverage_pct={coverage_pct(optional_collateral['hit'], optional_collateral['total']):.2f}",
        f"focus_components={','.join(focus_names) if focus_names else 'NA'}",
        f"focus_line_points_hit={focus['hit']}",
        f"focus_line_points_total={focus['total']}",
        f"focus_line_coverage_pct={focus_pct:.2f}",
        "focus_exclusions=none",
        *[
            f"{name}_line_coverage_pct={coverage_pct(counts['hit'], counts['total']):.2f}"
            for name, counts in sorted(components.items())
        ],
        *[
            f"design_{point_type}_coverage_pct={coverage_pct(sum(count > 0 for count in values.values()), len(values)):.2f}"
            for point_type, values in sorted(native_points.items()) if values
        ],
        f"design_branch_expression_coverage_pct={coverage_pct(sum(count > 0 for count in native_points.get('branch', {}).values()), len(native_points.get('branch', {}))):.2f}",
        f"design_toggle_reviewed_points_hit={reviewed_toggle_hit}",
        f"design_toggle_reviewed_points_total={reviewed_toggle_total}",
        f"design_toggle_reviewed_coverage_pct={coverage_pct(reviewed_toggle_hit, reviewed_toggle_total):.2f}",
        f"release_targets_enforced={int(args.enforce_release_targets)}",
        f"release_target_failures={','.join(release_failures) if release_failures else 'none'}",
        f"coverage_holes_csv={display_path(Path(args.holes_out).resolve()) if args.holes_out else 'NA'}",
        f"info={display_path(info_out)}",
                f"annotated_dir={display_path(annotate_dir) if annotate.returncode == 0 else 'NA'}",
                f"merge_stdout={merge.stdout.strip()}",
                f"merge_stderr={merge.stderr.strip()}",
            ]
        )
        + "\n"
    )

    lines = [
        "# Verilator Code Coverage Summary",
        "",
        "This is RTL execution evidence from Verilator coverage. It is separate from functional coverage closure and is not commercial coverage signoff.",
        "",
        "| Metric | Value |",
        "| --- | ---: |",
        f"| Coverage data files | {len(dat_files)} |",
        f"| Line points hit | {hit} |",
        f"| Line points total | {total} |",
        f"| Overall line coverage proxy | {pct:.2f}% |",
        f"| Design RTL line coverage proxy | {coverage_pct(design['hit'], design['total']):.2f}% |",
        f"| Focused component line coverage | {focus_pct:.2f}% |" if focus_names else "",
        f"| Focused minimum | {args.minimum_focus_pct:.2f}% |" if focus_names else "",
        "| Focused exclusions | None |" if focus_names else "",
        "",
    ]
    lines.extend([
        "## Design RTL Coverage Types",
        "",
        "| Coverage type | Hit | Total | Raw coverage | Release target |",
        "| --- | ---: | ---: | ---: | ---: |",
    ])
    targets = {"line": 95.0, "branch": 85.0, "expression": 85.0, "toggle": 90.0}
    for point_type in ("line", "branch", "expression", "toggle", "user", "fsm_state", "fsm_arc"):
        values = native_points.get(point_type, {})
        if not values:
            continue
        hit_count = sum(count > 0 for count in values.values())
        target = f"{targets[point_type]:.0f}%" if point_type in targets and point_type != "toggle" else "diagnostic"
        display_type = "branch/expression" if point_type == "branch" else point_type
        lines.append(f"| `{display_type}` | {hit_count} | {len(values)} | {coverage_pct(hit_count, len(values)):.2f}% | {target} |")
    if raw_toggle_points:
        reviewed_pct = coverage_pct(reviewed_toggle_hit, reviewed_toggle_total)
        status_text = "MET" if reviewed_pct >= targets["toggle"] else "OPEN"
        lines.append(
            f"| `toggle_reviewed` | {reviewed_toggle_hit} | {reviewed_toggle_total} | "
            f"{reviewed_pct:.2f}% | {targets['toggle']:.0f}% ({status_text}) |"
        )
    lines.extend([
        "",
        "Toggle instrumentation excludes signals wider than 32 bits. The reviewed row additionally excludes only structurally unreachable baseline points and long-horizon diagnostic counters; raw line coverage has no design-RTL exclusions. See `docs/code_coverage_exclusions.md`.",
        "",
        f"Test contribution ranking: `{display_path(ranking_out)}`.",
        f"Uncovered-point inventory: `{display_path(Path(args.holes_out).resolve())}`." if args.holes_out else "",
        "",
        "## Uncovered Executable Points",
        "",
        "| File | Line | Branch/object |",
        "| --- | ---: | --- |",
    ])
    uncovered_lines = [row for row in hole_rows if row["point_type"] == "line"]
    for row in uncovered_lines[:30]:
        lines.append(f"| `{Path(str(row['source'])).name}` | {row['line']} | `{row['object']}` |")
    if not uncovered_lines:
        lines.append("| None | NA | NA |")
    toggle_hotspots: dict[tuple[str, str], int] = {}
    for row in hole_rows:
        if row["point_type"] != "toggle" or row["reviewed_exclusion"] != "none":
            continue
        object_base = re.sub(r"\[[^]]+\]", "[]", str(row["object"]))
        key = (Path(str(row["source"])).name, object_base)
        toggle_hotspots[key] = toggle_hotspots.get(key, 0) + 1
    lines.extend([
        "",
        "## Reviewed Toggle Hotspots",
        "",
        "| File | Signal family | Missing points |",
        "| --- | --- | ---: |",
    ])
    for (source_name, object_name), count in sorted(toggle_hotspots.items(), key=lambda item: item[1], reverse=True)[:20]:
        lines.append(f"| `{source_name}` | `{object_name}` | {count} |")
    lines.extend([
        "",
        "## Reviewed Toggle Exclusions",
        "",
        "| Rationale | Excluded points |",
        "| --- | ---: |",
    ])
    for reason, count in sorted(reviewed_exclusion_counts.items()):
        lines.append(f"| `{reason}` | {count} |")
    lines.extend([
        "",
        f"Release target status: **{'PASS' if not target_misses else 'OPEN'}** "
        f"(line >= {args.minimum_line_pct:.0f}%, branch/expression >= {args.minimum_branch_pct:.0f}%, "
        f"reviewed toggle >= {args.minimum_reviewed_toggle_pct:.0f}%).",
        f"Threshold enforcement for this invocation: **{'enabled' if args.enforce_release_targets else 'disabled'}**.",
        "",
        "## Coverage By Source Group",
        "",
        "| Source group | Hit | Total | Coverage |",
        "| --- | ---: | ---: | ---: |",
    ])
    for group in ("design_rtl", "optional_collateral_rtl", "checker_monitor", "testbench", "other"):
        counts = groups.get(group)
        if not counts:
            continue
        lines.append(
            f"| `{group}` | {counts['hit']} | {counts['total']} | {coverage_pct(counts['hit'], counts['total']):.2f}% |"
        )
    lines.extend(
        [
            "",
            "## Component Coverage",
            "",
            "| Component | Hit | Total | Coverage |",
            "| --- | ---: | ---: | ---: |",
        ]
    )
    component_order = (
        "axi_lite_bridge", "cdc_rdc_collateral", "credit_manager",
        "rv32_core", "apb_dma_csr_bridge", "rv32_rom_feeder", "soc_chiplet_rv32_top",
    )
    for component in component_order:
        counts = components.get(component)
        if counts:
            lines.append(
                f"| `{component}` | {counts['hit']} | {counts['total']} | {coverage_pct(counts['hit'], counts['total']):.2f}% |"
            )
        else:
            lines.append(f"| `{component}` | NA | NA | NA |")
    lines.extend(
        [
            "",
            "## Top Uncovered Design RTL Files",
            "",
            "| File | Hit | Total | Missing | Coverage |",
            "| --- | ---: | ---: | ---: | ---: |",
        ]
    )
    if top_uncovered:
        for missing, file_total, file_hit, source in top_uncovered:
            lines.append(
                f"| `{Path(source).name}` | {file_hit} | {file_total} | {missing} | {coverage_pct(file_hit, file_total):.2f}% |"
            )
    else:
        lines.append("| NA | 0 | 0 | 0 | NA |")
    lines.extend(
        [
            "",
            f"- LCOV-style info: `{display_path(info_out)}`",
            f"- Annotated output: `{display_path(annotate_dir) if annotate.returncode == 0 else 'NA'}`",
            "",
        ]
    )
    output_md.write_text("\n".join(lines))

    print(f"Code coverage: {hit}/{total} line points ({pct:.2f}%) from {len(dat_files)} files")
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
