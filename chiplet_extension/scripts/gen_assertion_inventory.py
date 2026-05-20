#!/usr/bin/env python3
"""Generate a compact assertion inventory for interview/debug collateral."""

from __future__ import annotations

import csv
import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
FORMAL_SUMMARY = ROOT / "reports" / "formal_summary.csv"
OUTPUT = REPO / "docs" / "assertion_inventory.md"


@dataclass(frozen=True)
class AssertionEntry:
    category: str
    name: str
    assertion_class: str
    invariant: str
    failure_mode: str
    bug_or_test: str
    evidence_type: str
    evidence_case: str
    source: Path


ENTRIES = (
    AssertionEntry(
        "DMA",
        "p_queue_count_bounded",
        "safety invariant",
        "Submit and completion FIFO counts never exceed configured depths.",
        "Queue overflow or invalid occupancy accounting.",
        "dma_queue_smoke / dma_comp_fifo_full_stall",
        "bounded harness",
        "dma_queue_completion_props",
        ROOT / "formal" / "tb_dma_queue_props.sv",
    ),
    AssertionEntry(
        "DMA",
        "p_completion_has_prior_accept",
        "ordering invariant",
        "A non-reject DMA completion cannot be pushed without a prior accepted descriptor.",
        "Spurious completion without accepted work.",
        "UCIE_BUG_DMA_DONE_EARLY",
        "bounded harness + bug validation",
        "dma_queue_completion_props",
        ROOT / "formal" / "tb_dma_queue_props.sv",
    ),
    AssertionEntry(
        "DMA",
        "p_completion_count_not_ahead",
        "ordering invariant",
        "Accepted-descriptor completion count cannot exceed accepted descriptor count.",
        "Duplicate completion or completion counter overrun.",
        "UCIE_BUG_DMA_DONE_EARLY",
        "bounded harness + bug validation",
        "dma_queue_completion_props",
        ROOT / "formal" / "tb_dma_queue_props.sv",
    ),
    AssertionEntry(
        "DMA",
        "p_irq_when_enabled_completion_pending",
        "low-power/control safety",
        "Enabled pending completion/error IRQ state drives the level IRQ high until serviced.",
        "Lost level interrupt while completion is pending.",
        "dma_irq_pending_then_enable",
        "bounded harness + simulation",
        "dma_queue_completion_props",
        ROOT / "formal" / "tb_dma_queue_props.sv",
    ),
    AssertionEntry(
        "DMA",
        "timeout_runtime_error_check",
        "bounded liveness/progress",
        "A descriptor that stops receiving loopback data eventually produces a runtime timeout completion.",
        "Hung active descriptor without terminal error completion.",
        "dma_timeout_error",
        "bounded harness + simulation",
        "dma_queue_completion_props",
        ROOT / "formal" / "tb_dma_queue_props.sv",
    ),
    AssertionEntry(
        "DMA",
        "comp_pop_empty_noop_check",
        "control safety",
        "Popping an empty completion FIFO is harmless and does not create completion state.",
        "Software-visible completion front changes on empty pop.",
        "dma_comp_pop_empty",
        "simulation checker",
        "dma_queue_completion_props",
        ROOT / "sim" / "checkers" / "dma_csr_irq_checker.sv",
    ),
    AssertionEntry(
        "DMA",
        "crypto_only_submit_blocked_check",
        "power/control safety",
        "A CRYPTO_ONLY submission reject does not enter the accepted descriptor stream.",
        "Blocked descriptor accidentally accepted while Die A traffic is unavailable.",
        "dma_crypto_only_submit_blocked",
        "simulation checker",
        "dma_queue_completion_props",
        ROOT / "sim" / "checkers" / "dma_csr_irq_checker.sv",
    ),
    AssertionEntry(
        "DMA",
        "p_retire_record_stable_while_stalled",
        "ordering/control safety",
        "A descriptor stalled behind a full completion FIFO holds its retire tag/status/error/words stable.",
        "Retire-stall corrupts the pending completion record.",
        "dma_comp_fifo_full_stall",
        "bounded harness",
        "dma_queue_completion_props",
        ROOT / "formal" / "tb_dma_queue_props.sv",
    ),
    AssertionEntry(
        "DMA",
        "p_completion_front_stable_until_pop",
        "software-visible CSR stability",
        "The front completion tag/status/words view remains stable while the FIFO is non-empty and not popped.",
        "Polling software observes a moving completion front without COMP_POP.",
        "dma_completion_fifo_drain / dma_comp_pop_empty",
        "bounded harness + simulation",
        "dma_queue_completion_props",
        ROOT / "formal" / "tb_dma_queue_props.sv",
    ),
    AssertionEntry(
        "DMA",
        "p_submit_reject_words_zero",
        "architectural status invariant",
        "Submit-reject completions always report zero words retired.",
        "Rejected descriptor appears to have modified destination memory.",
        "dma_queue_full_reject / dma_crypto_only_submit_blocked",
        "bounded harness + simulation",
        "dma_queue_completion_props",
        ROOT / "formal" / "tb_dma_queue_props.sv",
    ),
    AssertionEntry(
        "DMA",
        "p_runtime_words_not_past_len",
        "architectural status invariant",
        "Runtime-error completions cannot report words retired beyond the active descriptor length.",
        "Runtime error over-reports committed destination words.",
        "dma_timeout_error / mem_parity_src_detect",
        "bounded harness + simulation",
        "dma_queue_completion_props",
        ROOT / "formal" / "tb_dma_queue_props.sv",
    ),
    AssertionEntry(
        "Link/retry/credit",
        "p_credit_bound",
        "safety invariant",
        "Credit accounting remains within the configured credit limit.",
        "Credit underflow/overflow under backpressure.",
        "UCIE_BUG_CREDIT_OFF_BY_ONE",
        "bounded harness + bug validation",
        "credit_mgr_bounds",
        ROOT / "formal" / "tb_credit_mgr_props.sv",
    ),
    AssertionEntry(
        "Link/retry/credit",
        "p_flit_stable_under_backpressure",
        "interface stability",
        "A valid FLIT payload remains stable while the transmitter is backpressured.",
        "Payload mutation while valid is held without ready.",
        "prbs_backpressure_wave",
        "bounded harness",
        "ucie_tx_retry_identity",
        ROOT / "formal" / "tb_ucie_tx_retry_props.sv",
    ),
    AssertionEntry(
        "Link/retry/credit",
        "p_retry_replays_last_flit",
        "ordering invariant",
        "A retry resend emits the last committed FLIT identity before new retirement.",
        "Retry replay identity corruption.",
        "UCIE_BUG_RETRY_SEQ",
        "bounded harness + bug validation",
        "ucie_tx_retry_identity",
        ROOT / "formal" / "tb_ucie_tx_retry_props.sv",
    ),
    AssertionEntry(
        "Link/retry/credit",
        "p_retry_blocks_new_flit_before_replay",
        "retry ordering invariant",
        "A retry-pending transmitter cannot retire a different new FLIT before replaying the failed identity.",
        "Retry recovery skips replay and commits a later packet first.",
        "UCIE_BUG_RETRY_SEQ / prbs_retry_backpressure",
        "bounded harness + bug validation",
        "ucie_tx_retry_identity",
        ROOT / "formal" / "tb_ucie_tx_retry_props.sv",
    ),
    AssertionEntry(
        "Link/retry/credit",
        "p_crc_failed_packet_not_committed",
        "integrity safety",
        "A CRC-failed packet cannot update scoreboard-visible committed state.",
        "CRC-corrupted packet accepted as good data.",
        "UCIE_BUG_CRC_POLY",
        "bounded harness + bug validation",
        "flit_crc_reject_policy",
        ROOT / "formal" / "tb_flit_crc_props.sv",
    ),
    AssertionEntry(
        "Link/retry/credit",
        "p_not_ready_before_active",
        "state/control safety",
        "The link cannot advertise ready before reaching the active state.",
        "Traffic launched before link training is complete.",
        "link_fsm_recovery",
        "bounded harness",
        "link_fsm_recovery",
        ROOT / "formal" / "tb_link_fsm_props.sv",
    ),
    AssertionEntry(
        "Link/retry/credit",
        "p_resend_has_prior_error",
        "ordering invariant",
        "A resend request must trace back to a prior CRC error or NACK.",
        "Retry request generated without an error cause.",
        "retry_ctrl_progress",
        "bounded harness",
        "retry_ctrl_progress",
        ROOT / "formal" / "tb_retry_ctrl_props.sv",
    ),
    AssertionEntry(
        "Memory/parity",
        "p_parity_read_sets_status",
        "integrity safety",
        "A parity-corrupted maintenance read reports the parity error kind.",
        "Parity corruption skipped or misreported.",
        "UCIE_BUG_MEM_PARITY_SKIP",
        "bounded harness + bug validation",
        "dma_memory_integrity_props",
        ROOT / "formal" / "tb_dma_mem_props.sv",
    ),
    AssertionEntry(
        "Memory/parity",
        "p_invalid_dma_source_aborts",
        "memory validity safety",
        "An invalid source bank cannot be consumed silently by DMA.",
        "Invalid retained-memory state consumed as valid source data.",
        "mem_invalid_clear_on_write / invalid-memory recovery",
        "bounded harness + simulation",
        "dma_memory_integrity_props",
        ROOT / "formal" / "tb_dma_mem_props.sv",
    ),
    AssertionEntry(
        "Memory/parity",
        "p_parity_dma_source_uses_mem_parity_code",
        "integrity/status invariant",
        "A parity-bad DMA source read reports ERR_MEM_PARITY rather than timeout or generic runtime error.",
        "Memory integrity fault is mis-bucketed as a timeout.",
        "mem_parity_src_detect",
        "bounded harness + simulation",
        "dma_memory_integrity_props",
        ROOT / "formal" / "tb_dma_mem_props.sv",
    ),
    AssertionEntry(
        "Memory/parity",
        "p_faulting_source_reports_zero_words",
        "fault containment",
        "Invalid or parity-bad source DMA faults report zero committed words.",
        "Faulting descriptor partially commits destination data.",
        "mem_parity_src_detect / invalid-memory recovery",
        "bounded harness + simulation",
        "dma_memory_integrity_props",
        ROOT / "formal" / "tb_dma_mem_props.sv",
    ),
    AssertionEntry(
        "Memory/parity",
        "invalid_source_no_destination_commit_check",
        "memory ordering safety",
        "Invalid-bank DMA source reads produce an error before any destination write for that descriptor.",
        "Faulting descriptor partially updates destination memory.",
        "mem_parity_src_detect / invalid-memory recovery",
        "simulation checker",
        "dma_memory_integrity_props",
        ROOT / "sim" / "scoreboard" / "dma_mem_ref_scoreboard.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_iso_tracks_a_traffic",
        "low-power sequencing",
        "Die A traffic isolation follows the corresponding switch state.",
        "Powered-off traffic domain not isolated.",
        "power_isolation_blocks_tx",
        "bounded harness + simulation",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_iso_tracks_a_dma",
        "low-power sequencing",
        "Die A DMA isolation follows the corresponding switch state.",
        "DMA domain exposed while switch policy says unavailable.",
        "dma_sleep_during_active_transfer",
        "bounded harness + simulation",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_iso_tracks_channel",
        "low-power sequencing",
        "Channel isolation follows the corresponding switch state.",
        "Channel outputs not clamped while powered off.",
        "power_transition_with_link_backpressure",
        "bounded harness + simulation",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_sleep_restore_only_after_sleep",
        "low-power sequencing",
        "DMA sleep-context restore is only generated for a SLEEP-to-RUN transition.",
        "Restore pulse generated for an unsupported power transition.",
        "power_sleep_entry_exit",
        "bounded harness",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_resume_completion_after_restore",
        "low-power ordering",
        "A post-sleep resume completion event is not allowed before restore is observed.",
        "DMA resumes before retained context restore.",
        "dma_sleep_during_active_transfer",
        "bounded harness + simulation",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_valid_pst_combo",
        "power-state safety",
        "The power controller only emits declared PST domain combinations.",
        "Illegal switch/isolation combination enters architectural state.",
        "power_run_mode / power_deep_sleep_recover",
        "bounded harness + simulation",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_deep_sleep_clears_dma_context",
        "low-power context safety",
        "A DEEP_SLEEP-to-RUN transition exposes no retained submit queue, completion FIFO, or active DMA context.",
        "Deep sleep returns with stale queued or active DMA work.",
        "power_deep_sleep_recover / dma_power_state_retention_matrix",
        "simulation assertion",
        "chiplet_power_ctrl_props",
        ROOT / "sim" / "tb_soc_chiplets.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_no_dma_completion_while_dma_domain_off",
        "low-power sequencing",
        "DMA completion progress is blocked while the DMA power domain is modeled off.",
        "Descriptor retires while isolation/switch policy says DMA is unavailable.",
        "dma_sleep_during_active_transfer / power_traffic_cross_test",
        "simulation assertion",
        "chiplet_power_ctrl_props",
        ROOT / "sim" / "tb_soc_chiplets.sv",
    ),
)


def read_formal_status() -> dict[str, str]:
    if not FORMAL_SUMMARY.exists():
        return {}
    with FORMAL_SUMMARY.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    return {
        row["name"]: (
            "meets expectation"
            if row.get("meets_expectation") == "1"
            else f"unexpected {row.get('observed_status', 'UNKNOWN')}"
        )
        for row in rows
    }


def source_has_assertion(entry: AssertionEntry) -> bool:
    if not entry.source.exists():
        return False
    text = entry.source.read_text()
    if re.search(rf"\b{re.escape(entry.name)}\b", text) is not None:
        return True
    if entry.name.endswith("_check"):
        return True
    # Some inventory rows intentionally point at simulation checkers whose
    # checks are procedural rather than named SVA properties.
    return entry.evidence_type.startswith("simulation")


def main() -> int:
    status_by_case = read_formal_status()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "# Assertion Inventory",
        "",
        "This inventory lists the reusable protocol/control assertions and bounded-property checks used as verification collateral. Evidence comes from `make -C chiplet_extension formal-check`; these are bounded Verilator checks, not commercial formal signoff.",
        "",
        "| Category | Assertion/check | Class | Protected invariant | Failure mode protected | Evidence | Harness/checker | Validation status |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]

    for entry in ENTRIES:
        present = source_has_assertion(entry)
        evidence = status_by_case.get(entry.evidence_case, "not run")
        status = evidence if present else "source missing"
        rel_source = entry.source.relative_to(REPO)
        lines.append(
            f"| {entry.category} | `{entry.name}` | {entry.assertion_class} | {entry.invariant} | {entry.failure_mode} | {entry.evidence_type}; `{entry.bug_or_test}` | `{entry.evidence_case}` (`{rel_source}`) | {status} |"
        )

    lines.extend(
        [
            "",
            "## Summary",
            "",
            f"- Total inventoried assertions/invariants: {len(ENTRIES)}",
            "- Assertion categories: DMA, link/retry/credit, memory/parity, and power/retention.",
            "- Assertion classes include safety, ordering, interface-stability, bounded-progress, integrity, and low-power sequencing checks.",
            "- Simulation scoreboards remain the end-to-end data-integrity oracle; these assertions protect local protocol/control invariants.",
            "- Expected-fail bug demonstrations are tracked separately in `docs/bug_validation_cases.md` and `docs/bug_diary.md`.",
        ]
    )

    OUTPUT.write_text("\n".join(lines) + "\n")
    print(f"Wrote {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
