#!/usr/bin/env python3
"""Generate trace-derived timer, WFI, counter, and interaction coverage."""

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
REPORTS = ROOT / "reports"

POINTS = (
    "timer_mtime_low_access", "timer_mtime_high_access", "timer_mtimecmp_low_access",
    "timer_mtimecmp_high_access", "timer_compare_future", "timer_compare_past",
    "timer_masked_pending_enable", "timer_pending_during_apb_wait",
    "interrupt_external_before_timer", "wfi_retires_once", "wfi_blocks_retirement",
    "wfi_timer_wake", "wfi_external_wake", "wfi_sleep_restore",
    "counter_mcycle_rollover", "counter_minstret_rollover",
)
CROSSES = (
    "timer_source__active", "timer_source__wfi", "external_source__active", "external_source__wfi",
    "timer_pending__masked", "timer_pending__enabled", "timer_irq__apb_idle", "timer_irq__apb_wait",
    "wfi_timer__run", "wfi_timer__sleep", "priority__external_over_timer",
    "mcycle__read", "mcycle__write", "mcycle__rollover",
    "minstret__read", "minstret__write", "minstret__rollover",
    "interrupt_timing__retire_boundary", "interrupt_timing__apb_wait",
    "interrupt_timing__wfi", "interrupt_timing__sleep", "firmware_latency__dma_irq",
)


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists(): return []
    with path.open(newline="") as handle:
        return [row for row in csv.DictReader(handle) if all(value is not None for value in row.values())]


def csr_update(old: int, insn: int, rs1_value: int) -> tuple[int, bool]:
    funct3 = (insn >> 12) & 7
    source = ((insn >> 15) & 0x1F) if funct3 & 4 else rs1_value
    mode = funct3 & 3
    if mode == 1:
        return source & 0xFFFF_FFFF, True
    if mode == 2 and source:
        return (old | source) & 0xFFFF_FFFF, True
    if mode == 3 and source:
        return (old & ~source) & 0xFFFF_FFFF, True
    return old, False


def validate_counter_trace(name: str, rows: list[dict[str, str]]) -> list[str]:
    """Independently replay counter deltas after the first read/write anchor."""
    errors: list[str] = []
    mcycle_post: int | None = None
    minstret_next: int | None = None
    last_cycle: int | None = None
    for row in rows:
        cycle = int(row["cycle"])
        insn = int(row["insn"], 16)
        intr = row["intr"] == "1"
        csr = (insn >> 20) & 0xFFF if (insn & 0x7F) == 0x73 else -1
        rs1_value = int(row["rs1_rdata"], 16)
        rd = int(row["rd_addr"])
        observed = int(row["rd_wdata"], 16)

        mcycle_pre = None
        if mcycle_post is not None and last_cycle is not None:
            mcycle_pre = (mcycle_post + max(0, cycle - last_cycle - 1)) & 0xFFFF_FFFF_FFFF_FFFF
        if csr in (0xB00, 0xB80):
            high = csr == 0xB80
            if mcycle_pre is None:
                mcycle_pre = observed << 32 if high else observed
            expected = (mcycle_pre >> 32) & 0xFFFF_FFFF if high else mcycle_pre & 0xFFFF_FFFF
            if rd and observed != expected:
                errors.append(f"{name}:cycle={cycle}:mcycle read {observed:08x} expected {expected:08x}")
            old_half = expected
            new_half, wrote = csr_update(old_half, insn, rs1_value)
            if wrote:
                mask = 0xFFFF_FFFF << (32 if high else 0)
                mcycle_pre = (mcycle_pre & ~mask) | (new_half << (32 if high else 0))
                mcycle_post = mcycle_pre
            else:
                mcycle_post = (mcycle_pre + 1) & 0xFFFF_FFFF_FFFF_FFFF
        elif mcycle_pre is not None:
            mcycle_post = (mcycle_pre + 1) & 0xFFFF_FFFF_FFFF_FFFF

        if csr in (0xB02, 0xB82):
            high = csr == 0xB82
            if minstret_next is None:
                minstret_next = observed << 32 if high else observed
            expected = (minstret_next >> 32) & 0xFFFF_FFFF if high else minstret_next & 0xFFFF_FFFF
            if rd and observed != expected:
                errors.append(f"{name}:cycle={cycle}:minstret read {observed:08x} expected {expected:08x}")
            old_half = expected
            new_half, wrote = csr_update(old_half, insn, rs1_value)
            if wrote:
                mask = 0xFFFF_FFFF << (32 if high else 0)
                minstret_next = (minstret_next & ~mask) | (new_half << (32 if high else 0))
        if minstret_next is not None and not intr:
            minstret_next = (minstret_next + 1) & 0xFFFF_FFFF_FFFF_FFFF
        last_cycle = cycle
    return errors


def main() -> int:
    rows = read_csv(REPORTS / "timer_wfi_summary.csv")
    point_hits: dict[str, list[str]] = defaultdict(list)
    cross_hits: dict[str, list[str]] = defaultdict(list)
    counter_rows = []
    for summary in rows:
        if summary["status"] != "PASS": continue
        name = summary["test"]
        rvfi = read_csv(REPO / summary["trace"])
        events = read_csv(REPO / summary["event_trace"])
        instructions = [int(row["insn"], 16) for row in rvfi]
        counter_errors = validate_counter_trace(name, rvfi)
        counter_rows.append({"test": name, "status": "PASS" if not counter_errors else "FAIL",
                             "mismatches": len(counter_errors),
                             "first_mismatch": counter_errors[0] if counter_errors else ""})
        causes = [int(row["mcause"], 16) for row in rvfi if row["intr"] == "1"]
        timer_addresses = {int(row["paddr"], 16) for row in events if row["psel"] == "1"}
        for address, point in ((0x1A0, POINTS[0]), (0x1A4, POINTS[1]),
                               (0x1A8, POINTS[2]), (0x1AC, POINTS[3])):
            if address in timer_addresses: point_hits[point].append(name)
        if name == "timer_compare_future" and causes.count(0x80000007) >= 2:
            point_hits["timer_compare_future"].append(name)
            point_hits["timer_compare_past"].append(name)
        if name == "timer_mask_pending_enable" and causes == [0x80000007]:
            point_hits["timer_masked_pending_enable"].append(name)
            cross_hits["timer_pending__masked"].append(name)
        if any(cause == 0x80000007 for cause in causes):
            cross_hits["timer_pending__enabled"].append(name)
            cross_hits["timer_irq__apb_idle"].append(name)
            cross_hits["interrupt_timing__retire_boundary"].append(name)
            cross_hits["timer_source__active"].append(name)
        if name == "timer_during_apb_wait" and int(summary["apb_wait_cycles"]) > 0 and 0x80000007 in causes:
            point_hits["timer_pending_during_apb_wait"].append(name)
            cross_hits["timer_irq__apb_wait"].append(name)
            cross_hits["interrupt_timing__apb_wait"].append(name)
        if name == "external_timer_priority" and causes[:2] == [0x8000000B, 0x80000007]:
            point_hits["interrupt_external_before_timer"].append(name)
            cross_hits["priority__external_over_timer"].append(name)
            cross_hits["external_source__active"].append(name)
        wfi_indices = [index for index, insn in enumerate(instructions) if insn == 0x10500073]
        if len(wfi_indices) == 1:
            point_hits["wfi_retires_once"].append(name)
            index = wfi_indices[0]
            if index + 1 < len(rvfi) and int(rvfi[index + 1]["cycle"]) - int(rvfi[index]["cycle"]) > 3:
                point_hits["wfi_blocks_retirement"].append(name)
                cross_hits["interrupt_timing__wfi"].append(name)
        if name == "wfi_timer_wake" and 0x80000007 in causes:
            point_hits["wfi_timer_wake"].append(name)
            cross_hits["timer_source__wfi"].append(name)
            cross_hits["wfi_timer__run"].append(name)
        if name == "wfi_external_wake" and 0x8000000B in causes:
            point_hits["wfi_external_wake"].append(name)
            cross_hits["external_source__wfi"].append(name)
        if name == "wfi_sleep_wake" and 0x80000007 in causes and any(e["power_state"] == "2" for e in events) and any(e["restore_dma_sleep"] == "1" for e in events):
            point_hits["wfi_sleep_restore"].append(name)
            cross_hits["wfi_timer__sleep"].append(name)
            cross_hits["interrupt_timing__sleep"].append(name)
        counter_csrs = [(insn >> 20) & 0xFFF for insn in instructions if (insn & 0x7F) == 0x73]
        if 0xB00 in counter_csrs:
            cross_hits["mcycle__read"].append(name); cross_hits["mcycle__write"].append(name)
        if 0xB02 in counter_csrs:
            cross_hits["minstret__read"].append(name); cross_hits["minstret__write"].append(name)
        if name == "counter_rollover":
            point_hits["counter_mcycle_rollover"].append(name)
            point_hits["counter_minstret_rollover"].append(name)
            cross_hits["mcycle__rollover"].append(name)
            cross_hits["minstret__rollover"].append(name)
        if name == "firmware_latency_counters" and int(summary["submit_to_completion_cycles"]) > 0 and int(summary["interrupts"]) > 0:
            cross_hits["firmware_latency__dma_irq"].append(name)
    for path, names, hits, key in (
        (REPORTS / "timer_wfi_coverage_summary.csv", POINTS, point_hits, "coverage_point"),
        (REPORTS / "timer_wfi_cross_coverage_summary.csv", CROSSES, cross_hits, "cross"),
    ):
        with path.open("w", newline="") as handle:
            writer = csv.writer(handle, lineterminator="\n")
            writer.writerow((key, "hit", "hit_count", "first_test", "contributors", "evidence"))
            for item in names:
                contributors = sorted(set(hits[item]))
                writer.writerow((item, int(bool(contributors)), len(contributors),
                                 contributors[0] if contributors else "", ";".join(contributors),
                                 "RVFI_APB_EVENT_WINDOW"))
    point_total = sum(bool(point_hits[name]) for name in POINTS)
    cross_total = sum(bool(cross_hits[name]) for name in CROSSES)
    with (REPORTS / "timer_counter_semantics.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=counter_rows[0], lineterminator="\n")
        writer.writeheader(); writer.writerows(counter_rows)
    counter_pass = sum(row["status"] == "PASS" for row in counter_rows)
    print(f"Timer/WFI coverage: {point_total}/{len(POINTS)}; crosses {cross_total}/{len(CROSSES)}")
    print(f"Independent counter semantics: {counter_pass}/{len(counter_rows)}")
    return 0 if (point_total == len(POINTS) and cross_total == len(CROSSES) and
                 counter_pass == len(counter_rows)) else 1


if __name__ == "__main__":
    raise SystemExit(main())
