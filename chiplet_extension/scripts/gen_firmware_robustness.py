#!/usr/bin/env python3
"""Require independent contributors for architectural points and high-risk crosses."""

from __future__ import annotations

import csv
import re
from collections import defaultdict
from pathlib import Path

from run_compiled_firmware import REPO, REPORTS, decode_points, enrich_points, observed_crosses

FLAT_AREAS = {"isa_operand", "csr_trap_interrupt", "apb_mmio"}
CROSS_GROUPS = {"instruction_operand", "memory_width_offset", "csr_form_source", "trap_side_effect",
                "control_fault", "apb_wait_response", "interrupt_state"}


def read(path: Path) -> list[dict[str, str]]:
    if not path.exists(): return []
    with path.open(newline="") as handle: return list(csv.DictReader(handle))


def main() -> int:
    flat_rows = [row for row in read(REPORTS / "firmware_c_coverage_summary.csv") if row["coverage_area"] in FLAT_AREAS]
    cross_rows = [row for row in read(REPORTS / "firmware_c_cross_coverage_summary.csv") if row["cross_group"] in CROSS_GROUPS]
    flat = {row["coverage_point"]: set(filter(None, row["contributing_tests"].split(";"))) for row in flat_rows}
    crosses = {row["cross_bin"]: set(filter(None, row["source_tests"].split(";"))) for row in cross_rows}
    extras = read(REPORTS / "firmware_c_compiler_matrix_summary.csv") + read(REPORTS / "timer_wfi_summary.csv") + read(REPORTS / "firmware_c_generated_c_summary.csv")
    for row in extras:
        if row.get("status") != "PASS" or not row.get("trace"): continue
        trace = REPO / row["trace"]
        if not trace.exists(): continue
        name = row["test"]
        base_name = re.sub(r"_O(?:0|1|2|s)$", "", name)
        normalized = dict(row); normalized["test"] = base_name
        for point in enrich_points(base_name, decode_points(trace), normalized):
            if point in flat: flat[point].add(name)
        for cross in observed_crosses(normalized):
            cross_bin = cross.split("__", 1)[-1]
            if cross_bin in crosses: crosses[cross_bin].add(name)
    output = REPORTS / "firmware_c_coverage_robustness.csv"
    rows = []
    for name, contributors in flat.items():
        rows.append({"kind":"architectural_point", "item":name, "required_contributors":2,
                     "contributor_count":len(contributors), "status":"PASS" if len(contributors)>=2 else "FAIL",
                     "contributors":";".join(sorted(contributors))})
    for name, contributors in crosses.items():
        rows.append({"kind":"high_risk_cross", "item":name, "required_contributors":2,
                     "contributor_count":len(contributors), "status":"PASS" if len(contributors)>=2 else "FAIL",
                     "contributors":";".join(sorted(contributors))})
    with output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0], lineterminator="\n"); writer.writeheader(); writer.writerows(rows)
    flat_pass = sum(row["status"]=="PASS" for row in rows if row["kind"]=="architectural_point")
    cross_pass = sum(row["status"]=="PASS" for row in rows if row["kind"]=="high_risk_cross")
    print(f"Coverage robustness: architectural {flat_pass}/{len(flat)}; high-risk crosses {cross_pass}/{len(crosses)}")
    return 0 if flat_pass == len(flat) and cross_pass == len(crosses) else 1


if __name__ == "__main__": raise SystemExit(main())
