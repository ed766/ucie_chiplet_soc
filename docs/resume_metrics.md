# Resume Metrics - UCIe Chiplet DV

## Resume-Ready Bullets

- Built a coverage-driven SystemVerilog verification environment for a
  dual-die RISC-V SoC with a behavioral UCIe-style link, using named tests,
  passive monitors, scoreboards, assertions, proxy low-power scenarios, a
  CSR-programmable queued DMA offload path, and Verilator-based regression
  automation.
- Expanded the project to 70 named tests with machine-readable
  `DV_RESULT` reporting, Python golden-model reference generation, automated
  failure bucketing, coverage closure reporting, and CSV/Markdown dashboards
  for regression status and functional coverage.
- Validated five injected bug modes
  (`UCIE_BUG_CREDIT_OFF_BY_ONE`, `UCIE_BUG_CRC_POLY`,
  `UCIE_BUG_RETRY_SEQ`, `UCIE_BUG_DMA_DONE_EARLY`,
  `UCIE_BUG_MEM_PARITY_SKIP`) and automatically bucketed them as
  `credit_accounting`, `crc_integrity`, `retry_identity`, `dma_completion`,
  and `memory_integrity`.
- Added UPF-aligned power-intent proxy verification, CSR-programmed DMA
  completion checks, and a bounded Verilator property appendix for protocol
  invariants.
- Added reusable protocol and low-power assertions for DMA queue integrity,
  credit underflow prevention, retry recovery, isolation timing, retention
  restore, and invalid-memory access protection.
- Built bounded seeded-random scenario manifests for DMA, link retry,
  backpressure, parity injection, and power-transition timing, with
  reproducible seed/knob metadata for stress triage.
- Documented injected RTL bug modes and waveform-driven debug evidence for
  credit accounting, retry identity, DMA completion, parity, and low-power
  sequencing failure classes.
- Characterized DMA offload latency, retry overhead, backpressure sensitivity,
  and sleep/resume recovery behavior across named traffic scenarios.
- Added open-source front-end quality collateral with Verilator lint, optional
  Yosys/OpenSTA probes, Verilator code coverage, structural CDC/RDC checks,
  an AXI-Lite CSR wrapper test, and a standalone C CRC reference model.
- Integrated the lightweight RV32 core as a software-visible bus master and
  executed twelve ROM-backed programs that configure DMA through APB MMIO,
  poll IRQ/completion state, handle wait states and bus errors, and resume
  after sleep; the focused lane runs `12 / 12` programs, closes `30 / 30`
  MMIO/outcome points and `7 / 7` crosses, and reaches `86.62%` focused
  Verilator line coverage for RV32/APB/ROM integration RTL.

## Supporting Numbers

Use [`project_metrics.md`](project_metrics.md) as the
single source of truth for current counts. It is regenerated from canonical CSV
reports by running:

```bash
make -C chiplet_extension project-metrics
```

The resume-safe core claim is the default closure evidence: stable regression,
flat functional coverage, low-power proxy coverage, bounded assertion checks,
and expected bug-validation failures. Optional seeded-random stress and UVM
artifacts are useful supporting evidence, but they are not the default closure
gate.

Source files:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/verification_dashboard.md`
- `chiplet_extension/reports/power_state_summary.csv`
- `chiplet_extension/reports/formal_summary.csv`
- `chiplet_extension/reports/coverage_closure_matrix.md`
- `chiplet_extension/reports/cross_coverage_summary.csv`
- `chiplet_extension/reports/true_cross_coverage_summary.csv`
- `chiplet_extension/reports/project_metrics.csv`
- `chiplet_extension/reports/random_stress_regress_summary.csv`
- `chiplet_extension/reports/frontend_quality_summary.md`
- `chiplet_extension/reports/code_coverage_summary.md`
- `chiplet_extension/reports/c_reference_summary.csv`
- `chiplet_extension/reports/cdc_rdc_summary.csv`
- `chiplet_extension/reports/firmware_soc_summary.csv`
- `chiplet_extension/reports/firmware_coverage_summary.csv`
- `chiplet_extension/reports/firmware_cross_coverage_summary.csv`
- `chiplet_extension/reports/firmware_code_coverage_summary.md`
- `docs/project_metrics.md`
- `docs/assertion_inventory.md`
- `docs/random_stress_summary.md`
- `docs/true_cross_coverage_summary.md`
- `docs/verification_traceability_matrix.md`
- `docs/uvm_status.md`
- `docs/performance_characterization.md`
- `docs/bug_diary.md`
- `docs/debug_case_study_dma_retry.md`
- `docs/open_source_flow_summary.md`
- `docs/clock_reset_cdc_plan.md`
- `docs/c_reference_model_summary.md`
- `docs/firmware_soc_verification.md`
- `docs/debug_case_study_firmware_dma.md`

## Interview Talking Points

- The environment is intentionally lightweight rather than full UVM, but it
  still demonstrates the core DV ideas: stimulus control, monitor-driven
  checking, functional coverage, regression automation, and bug-injection
  validation.
- The SoC bench uses a Python-generated reference CSV rather than reusing the
  same in-bench datapath for expected results.
- The DMA path now has an independent transaction-level Python golden model
  for descriptor, plaintext, packet-order, ciphertext, and destination-image
  traces.
- The DMA offload path adds a software-visible subsystem with source and
  destination scratchpads, a queued submit/completion model, IRQ completion,
  timeout handling, reject logging, and golden-image comparison.
- Power behavior is verified with explicit proxy scenarios, which is honest
  and practical for this project stage.
- The property appendix is bounded and Verilator-based, so it is proof-style
  collateral without pretending to be full theorem-proving formal.
- The coverage closure matrix now includes non-gating cross-coverage evidence
  for queue occupancy, retry/backpressure, CRC recovery, memory validity,
  parity/error status, power/isolation, and AES return ordering.
- The verification traceability matrix maps each major feature to stimulus,
  checkers, assertions, coverage, and report artifacts for faster review.
- The AXI-Lite wrapper keeps the internal DMA CSR map unchanged while showing a
  standard SoC-style register integration path.
- The flagship integration uses ROM-backed RV32 firmware over APB MMIO to
  stage descriptors, ring the DMA doorbell, poll completion/IRQ state, and
  exercise low-power resume without testbench CSR writes.
- The C CRC model is intentionally standalone rather than DPI-based, making it
  portable and easy to run in open-source regression environments.

## Honest Limitations To Mention

- The power-state work is proxy-based rather than UPF-aware simulation.
- The property harnesses are bounded assertion checks, not a complete formal
  signoff flow.
- The seeded-random stress suite is optional supporting evidence; generated
  rows are schema-checked, and invalid generated combinations are reported
  separately from valid executed rows.
- Yosys/OpenSTA/code-coverage/CDC results are open-source quality proxies and
  should not be described as commercial signoff closure.
