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
OPTIONAL_BENCH_SUMMARY = ROOT / "reports" / "optional_bench_summary.csv"
FIRMWARE_SUMMARY = ROOT / "reports" / "firmware_soc_summary.csv"
FIRMWARE_C_SUMMARY = ROOT / "reports" / "firmware_c_summary.csv"
OUTPUT = REPO / "docs" / "reference" / "assertion_inventory.md"


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


RV32_EXTRA_ASSERTIONS = (
    ("a_rv32_load_mask_matches_width", "data-integrity invariant", "A retired load exposes the exact byte mask implied by its width and address offset.", "A load uses the wrong byte lanes.", "operand_corner_matrix / CPU seeds"),
    ("a_rv32_store_mask_matches_width", "data-integrity invariant", "A retired store exposes the exact byte mask implied by its width and address offset.", "A store corrupts adjacent byte lanes.", "operand_corner_matrix / CPU seeds"),
    ("a_rv32_trap_suppresses_register_write", "precise-exception invariant", "A trapping instruction cannot update its destination register.", "A faulting operation leaves a partial register side effect.", "decode/access legality matrices"),
    ("a_rv32_interrupt_suppresses_instruction_effect", "interrupt sequencing invariant", "An interrupt-boundary record has no register or memory side effect.", "The interrupted instruction partially retires.", "interrupt timing matrices"),
    ("a_rv32_apb_wait_blocks_architectural_event", "interface ordering invariant", "Neither retirement nor interrupt entry occurs during an unresolved APB transfer.", "An MMIO instruction or interrupt crosses an incomplete bus operation.", "interrupt_during_apb_wait / APB wait matrix"),
    ("a_rv32_zero_destination_has_zero_data", "architectural safety invariant", "RVFI reports zero write data when the destination is x0.", "A discarded x0 write appears architecturally visible.", "CPU seeds / operand matrix"),
    ("a_rv32_csr_state_is_implemented_subset", "CSR-state invariant", "Machine status and interrupt-enable snapshots contain only implemented bits.", "Unsupported CSR bits become observable.", "csr_state_matrix / illegal CSR matrix"),
    ("a_rv32_mmio_completion_cannot_repeat", "control-bus transaction invariant", "A completed MMIO transfer cannot repeat on the following cycle.", "One instruction causes duplicate peripheral side effects.", "APB atomicity matrix"),
    ("a_rv32_mmio_error_retires_precise_trap", "fault-containment invariant", "An APB error retires as a precise trap without destination writeback.", "A failed MMIO operation appears successful.", "APB legality and atomicity matrices"),
    ("a_rv32_mret_has_saved_interrupt_state", "trap-return invariant", "MRET observes a saved machine interrupt-enable state before returning.", "Interrupt enable state is lost across a handler.", "IRQ level/MRET matrix"),
    ("a_rv32_reset_clears_architectural_event", "reset safety invariant", "Reset suppresses retirement, writeback, and RVFI events.", "A reset-aborted instruction creates a ghost architectural event.", "APB/reset and handler-reset matrices"),
)


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
        "p_iso_safe_a_traffic",
        "low-power sequencing",
        "Die A traffic isolation may deassert only when the traffic switch is on.",
        "Powered-off traffic domain not isolated.",
        "power_isolation_blocks_tx",
        "bounded harness + simulation",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_iso_safe_a_dma",
        "low-power sequencing",
        "Die A DMA isolation may deassert only when the DMA switch is on.",
        "DMA domain exposed while switch policy says unavailable.",
        "dma_sleep_during_active_transfer",
        "bounded harness + simulation",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_iso_safe_channel",
        "low-power sequencing",
        "Channel isolation may deassert only when the channel switch is on.",
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
        "p_no_deisolated_off_domain",
        "power-state safety",
        "No switchable domain is de-isolated while its switch policy says the domain is off.",
        "Illegal switch/isolation combination enters architectural state.",
        "power_run_mode / power_deep_sleep_recover",
        "bounded harness + simulation",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_iso_before_switch_off",
        "low-power sequencing",
        "Isolation is asserted before any switchable chiplet domain is observed switching off.",
        "A powered-down domain could expose unclamped outputs for one cycle.",
        "power_isolation_blocks_tx / upf-check",
        "bounded harness",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_switch_on_before_restore",
        "low-power sequencing",
        "DMA restore pulses are only allowed after the DMA switch domain is powered on.",
        "Retained DMA context restore occurs while the DMA domain is still off.",
        "dma_sleep_during_active_transfer",
        "bounded harness",
        "chiplet_power_ctrl_props",
        ROOT / "formal" / "tb_power_ctrl_props.sv",
    ),
    AssertionEntry(
        "Power/retention",
        "p_restore_before_deiso",
        "low-power sequencing",
        "DMA de-isolation after low-power wake requires a prior DMA sleep or memory restore observation.",
        "DMA domain becomes visible before retained state is restored.",
        "dma_sleep_during_active_transfer / dma_power_state_retention_matrix",
        "bounded harness",
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
    AssertionEntry(
        "AXI-Lite",
        "awaddr_stable_while_backpressured",
        "control-bus safety",
        "AXI-Lite write address remains stable while AWVALID is held without AWREADY.",
        "CSR bridge samples a drifting write address under backpressure.",
        "axi-lite-check",
        "simulation bench",
        "axi_lite_protocol_edges",
        ROOT / "sim" / "tb_axi_lite_csr_wrapper.sv",
    ),
    AssertionEntry(
        "AXI-Lite",
        "wdata_wstrb_stable_while_backpressured",
        "control-bus safety",
        "AXI-Lite write data and byte enables remain stable while WVALID is held without WREADY.",
        "CSR bridge writes corrupted data or accepts partial-strobe drift.",
        "axi-lite-check",
        "simulation bench",
        "axi_lite_protocol_edges",
        ROOT / "sim" / "tb_axi_lite_csr_wrapper.sv",
    ),
    AssertionEntry(
        "AXI-Lite",
        "araddr_stable_while_backpressured",
        "control-bus safety",
        "AXI-Lite read address remains stable while ARVALID is held without ARREADY.",
        "CSR bridge returns data for an unintended address.",
        "axi-lite-check",
        "simulation bench",
        "axi_lite_protocol_edges",
        ROOT / "sim" / "tb_axi_lite_csr_wrapper.sv",
    ),
    AssertionEntry(
        "AXI-Lite",
        "bresp_stable_while_bready_low",
        "control-bus response safety",
        "AXI-Lite write response remains stable while BVALID is held and BREADY is low.",
        "Software observes an unstable write response under response backpressure.",
        "axi-lite-check",
        "simulation bench",
        "axi_lite_protocol_edges",
        ROOT / "sim" / "tb_axi_lite_csr_wrapper.sv",
    ),
    AssertionEntry(
        "AXI-Lite",
        "rdata_rresp_stable_while_rready_low",
        "control-bus response safety",
        "AXI-Lite read data and response remain stable while RVALID is held and RREADY is low.",
        "Software observes unstable read data under response backpressure.",
        "axi-lite-check",
        "simulation bench",
        "axi_lite_protocol_edges",
        ROOT / "sim" / "tb_axi_lite_csr_wrapper.sv",
    ),
    AssertionEntry(
        "AXI-Lite",
        "partial_wstrb_slverr",
        "control-bus negative safety",
        "Partial-strobe AXI-Lite writes return SLVERR and do not generate a CSR write pulse.",
        "Unsupported byte write mutates a CSR.",
        "axi-lite-check",
        "simulation bench",
        "axi_lite_protocol_edges",
        ROOT / "sim" / "tb_axi_lite_csr_wrapper.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "apb_enable_requires_select",
        "control-bus safety",
        "An APB access phase cannot occur without an active peripheral select.",
        "Malformed APB transfer reaches the DMA CSR bridge.",
        "firmware-soc-check",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "apb_access_requires_setup",
        "control-bus ordering invariant",
        "Every APB access phase is preceded by a setup phase for the same transfer.",
        "The CSR bridge accepts an access without APB setup sequencing.",
        "firmware-soc-check",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "apb_one_csr_operation_per_transfer",
        "control-bus transaction invariant",
        "A successful APB transfer generates one CSR operation pulse and error transfers generate none.",
        "A wait-stated transfer duplicates a CSR operation or an error access mutates state.",
        "apb_wait_error / dma_smoke",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "apb_control_stable_during_wait",
        "interface-stability invariant",
        "APB address, direction, and write data remain stable while PREADY is low.",
        "A wait-stated transfer changes identity before completion.",
        "apb_wait_error",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "rv32_mmio_retire_requires_pready",
        "ordering invariant",
        "An RV32 MMIO load or store cannot retire before its APB transfer completes.",
        "Firmware advances past a wait-stated or incomplete CSR operation.",
        "apb_wait_error",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "doorbell_precedes_descriptor_accept",
        "end-to-end ordering invariant",
        "A firmware doorbell write precedes every descriptor acceptance event.",
        "DMA accepts work that software did not submit.",
        "dma_smoke / dma_back_to_back",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "software_completion_has_accepted_descriptor",
        "end-to-end ordering invariant",
        "A completion observed by firmware corresponds to previously accepted DMA work.",
        "Firmware consumes a spurious or uncorrelated completion.",
        "dma_smoke / dma_back_to_back",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "mmio_error_cannot_mutate_dma",
        "fault-containment invariant",
        "An APB error response cannot generate a valid DMA CSR operation.",
        "Invalid firmware address silently changes DMA state.",
        "apb_wait_error",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "restore_precedes_software_completion",
        "low-power sequencing invariant",
        "DMA sleep restore is observed before firmware can observe a post-wake completion.",
        "Software consumes retained completion state before restore sequencing finishes.",
        "sleep_resume",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "firmware_completion_order_matches_acceptance",
        "end-to-end ordering invariant",
        "Accepted descriptors produce non-reject completion records in accepted-tag order.",
        "Firmware observes reordered or duplicate accepted-work completion identity.",
        "dma_back_to_back / completion_fifo_stall",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "firmware_accept_matches_submitted_tag",
        "end-to-end submission invariant",
        "Every accepted descriptor tag matches the independent APB-observed firmware submission queue.",
        "DMA accepts a descriptor identity different from the tag staged before the software doorbell.",
        "dma_smoke / dma_back_to_back / queue_full_reject",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "firmware_completion_front_stable_while_stalled",
        "software-visible stability invariant",
        "The completion front entry remains stable while retire is stalled behind a full FIFO.",
        "Firmware reads a changing completion record before issuing COMP_POP.",
        "completion_fifo_stall",
        "simulation bench",
        "firmware_soc_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "APB/firmware",
        "firmware_reject_matches_submitted_tag",
        "end-to-end rejection invariant",
        "A rejected software doorbell consumes the matching submitted tag without entering the accepted stream.",
        "A queue-full or blocked rejection corrupts later submission-to-accept correlation.",
        "queue_full_reject / queue_full_recovery / crypto_only_reject",
        "simulation monitor + compiled firmware",
        "compiled_firmware_integration",
        ROOT / "sim" / "tb_firmware_soc.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_x0_constant",
        "architectural safety invariant",
        "Architectural register x0 remains hardwired to zero.",
        "An instruction or trap path corrupts the architectural zero register.",
        "all compiled-C scenarios",
        "simulation SVA + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_retire_pc_aligned",
        "architectural safety invariant",
        "Retired source and destination PCs remain instruction aligned.",
        "A branch, jump, or trap retires an unaligned architectural PC.",
        "branch/load-store differential programs",
        "simulation SVA + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_trap_target_aligned",
        "trap sequencing invariant",
        "Trap entry transfers control to an aligned machine-mode vector.",
        "An exception or interrupt enters an invalid trap address.",
        "misalignment / illegal access / interrupt scenarios",
        "simulation SVA + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_no_retire_while_apb_wait",
        "interface ordering invariant",
        "An MMIO instruction cannot retire while its APB transfer is wait-stated.",
        "Firmware advances before the device-side operation completes.",
        "apb_wait_error / reset_mid_wait",
        "simulation SVA + APB monitor",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_mmio_error_no_writeback",
        "fault-containment invariant",
        "An APB error response cannot silently update an architectural destination register.",
        "A failed MMIO load appears successful to firmware.",
        "apb_wait_error",
        "simulation SVA + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_interrupt_at_boundary",
        "interrupt sequencing invariant",
        "External interrupts are represented only on architectural retirement boundaries.",
        "An asynchronous interrupt creates a partial or duplicate instruction retirement.",
        "interrupt_dma",
        "simulation SVA + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_order_increments",
        "retirement ordering invariant",
        "Consecutive retirement records have strictly increasing architectural order.",
        "An instruction retires twice or a retirement record is dropped.",
        "all compiled-C scenarios",
        "simulation SVA + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_mret_returns_mepc",
        "trap-return ordering invariant",
        "MRET resumes exactly at the saved machine exception PC.",
        "Trap return skips or replays an interrupted instruction.",
        "interrupt_dma / RV32_BUG_MRET_SKIP",
        "simulation SVA + mutation + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_apb_completion_is_single_pulse",
        "control-bus transaction invariant",
        "A completed APB transfer exits the access phase before another operation can complete.",
        "One MMIO instruction generates duplicate device operations.",
        "apb_wait_error / polling_dma",
        "simulation SVA + APB monitor",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_interrupt_cause_external",
        "interrupt-state invariant",
        "A retired external interrupt records the machine-external interrupt cause.",
        "Interrupt entry records a stale or incorrect machine cause.",
        "interrupt_dma",
        "simulation SVA + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_sync_trap_cause_supported",
        "precise-exception invariant",
        "Synchronous traps report the supported illegal, misalignment, access-fault, or ECALL cause.",
        "Firmware enters a handler with an incorrect or stale cause code.",
        "apb_wait_trap / isa_matrix",
        "simulation SVA + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
    AssertionEntry(
        "RV32/compiled firmware",
        "a_rv32_trap_records_fault_pc",
        "precise-exception invariant",
        "Synchronous trap state records the exact faulting instruction PC in mepc.",
        "Trap recovery skips or replays the wrong architectural instruction.",
        "apb_wait_trap / isa_matrix / RV32_BUG_MRET_SKIP",
        "simulation SVA + mutation + differential ISS",
        "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    ),
) + tuple(
    AssertionEntry(
        "RV32/compiled firmware", name, assertion_class, invariant, failure_mode,
        test, "simulation SVA + differential ISS", "compiled_firmware_integration",
        ROOT / "sim" / "assertions" / "rv32_firmware_assertions.sv",
    )
    for name, assertion_class, invariant, failure_mode, test in RV32_EXTRA_ASSERTIONS
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


def read_optional_bench_status() -> dict[str, str]:
    if not OPTIONAL_BENCH_SUMMARY.exists():
        return {}
    with OPTIONAL_BENCH_SUMMARY.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    status = {}
    for row in rows:
        if row.get("bench") == "axi_lite":
            status["axi_lite_protocol_edges"] = (
                "meets expectation"
                if row.get("status") == "PASS"
                else f"unexpected {row.get('status', 'UNKNOWN')}"
            )
    return status


def read_firmware_status() -> dict[str, str]:
    if not FIRMWARE_SUMMARY.exists():
        return {}
    with FIRMWARE_SUMMARY.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        return {"firmware_soc_integration": "not run"}
    passed = all(row.get("status") == "PASS" for row in rows)
    return {
        "firmware_soc_integration": (
            "meets expectation" if passed else "unexpected scenario failure"
        )
    }


def read_compiled_firmware_status() -> dict[str, str]:
    if not FIRMWARE_C_SUMMARY.exists():
        return {}
    with FIRMWARE_C_SUMMARY.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        return {"compiled_firmware_integration": "not run"}
    passed = all(
        row.get("status") == "PASS"
        and row.get("assertion_failures") == "0"
        and not row.get("first_mismatch")
        for row in rows
    )
    return {
        "compiled_firmware_integration": (
            "meets expectation" if passed else "unexpected scenario or architectural mismatch"
        )
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
    status_by_case.update(read_optional_bench_status())
    status_by_case.update(read_firmware_status())
    status_by_case.update(read_compiled_firmware_status())
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
            "- Assertion categories: DMA, link/retry/credit, memory/parity, power/retention, AXI-Lite, APB/firmware, and RV32/compiled firmware.",
            "- Assertion classes include safety, ordering, interface-stability, bounded-progress, integrity, and low-power sequencing checks.",
            "- Simulation scoreboards remain the end-to-end data-integrity oracle; these assertions protect local protocol/control invariants.",
            "- Expected-fail bug demonstrations are consolidated in `docs/bug_diary.md`.",
        ]
    )

    OUTPUT.write_text("\n".join(lines) + "\n")
    print(f"Wrote {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
