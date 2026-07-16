# Documentation Index

The primary reviewer path is intentionally limited to twelve documents. Generated and specialist collateral remains available under `reference/` without competing with the project narrative.

## Primary Documents

1. [Project metrics](project_metrics.md) - canonical report-backed snapshot.
2. [Verification plan](verification_plan.md) - closure layers, scenarios, and acceptance policy.
3. [Verification traceability](verification_traceability_matrix.md) - requirement-to-stimulus/checker/evidence mapping.
4. [Firmware-driven verification](firmware_soc_verification.md) - RV32/APB MMIO scenarios and coverage.
5. [Power verification](power_verification_plan.md) - proxy behavior, UPF intent, isolation, and retention.
6. [Coverage closure case study](coverage_closure_case_study.md) - functional and interaction closure strategy.
7. [Formal appendix](formal_appendix.md) - bounded and solver-backed property evidence.
8. [Bug diary](bug_diary.md) - implemented mutations and failure triage.
9. [Performance characterization](performance_characterization.md) - measured behavioral tradeoffs.
10. [Open-source flow summary](open_source_flow_summary.md) - simulation, coverage, implementation, and signoff boundaries.
11. [UVM status](uvm_status.md) - supporting real-UVM phase/TLM/RAL lane.
12. This index.

## Reference Collateral

- [Assertion inventory](reference/assertion_inventory.md)
- [AXI-Lite protocol coverage](reference/axi_lite_coverage_summary.md)
- [C reference model](reference/c_reference_model_summary.md)
- [Clock/reset and CDC plan](reference/clock_reset_cdc_plan.md)
- [Code-coverage exclusions](reference/code_coverage_exclusions.md)
- [DMA retry debug case](reference/debug_case_study_dma_retry.md)
- [Firmware DMA waveform case](reference/debug_case_study_firmware_dma.md)
- [Negative-test summary](reference/negative_test_summary.md)
- [Seeded-random stress summary](reference/random_stress_summary.md)
- [True interaction coverage](reference/true_cross_coverage_summary.md)

Canonical machine-readable evidence remains under `chiplet_extension/reports/`. Raw logs, build products, and waveform databases are generated locally and are not reviewer-facing release artifacts.
