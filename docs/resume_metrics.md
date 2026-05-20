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

## Supporting Numbers

Use [`project_metrics.md`](/home/esgha/ucie_chiplet_soc/docs/project_metrics.md) as the
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
- `chiplet_extension/reports/project_metrics.csv`
- `chiplet_extension/reports/random_stress_regress_summary.csv`
- `docs/project_metrics.md`
- `docs/assertion_inventory.md`
- `docs/random_stress_summary.md`
- `docs/uvm_status.md`
- `docs/performance_characterization.md`
- `docs/bug_diary.md`
- `docs/debug_case_study_dma_retry.md`

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

## Honest Limitations To Mention

- The power-state work is proxy-based rather than UPF-aware simulation.
- The property harnesses are bounded assertion checks, not a complete formal
  signoff flow.
- The stress suite still exists as explicit characterization and closure work
  for anyone who wants to dig deeper.
