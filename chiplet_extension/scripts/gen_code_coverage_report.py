#!/usr/bin/env python3
"""Generate a compact Verilator code-coverage report."""

from __future__ import annotations

import argparse
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


def coverage_pct(hit: int, total: int) -> float:
    return (100.0 * hit / total) if total else 0.0


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
        "## Coverage By Source Group",
        "",
        "| Source group | Hit | Total | Coverage |",
        "| --- | ---: | ---: | ---: |",
    ]
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
