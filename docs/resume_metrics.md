# Resume Metrics - UCIe Chiplet DV

## Resume-Ready Bullets

- Built a coverage-driven SystemVerilog verification environment for a
  dual-die RISC-V SoC with a behavioral UCIe-style link, using named tests,
  passive monitors, scoreboards, assertions, proxy low-power scenarios, a
  CSR-programmable queued DMA offload path, and Verilator-based regression
  automation.
- Expanded the project to 49 named tests and 43 checked-in stable-report runs, then added machine-readable
  `DV_RESULT` reporting, Python golden-model reference generation, automated
  failure bucketing, coverage closure reporting, and CSV/Markdown dashboards
  for regression status and functional coverage.
- Validated four injected bug modes
  (`UCIE_BUG_CREDIT_OFF_BY_ONE`, `UCIE_BUG_CRC_POLY`,
  `UCIE_BUG_RETRY_SEQ`, `UCIE_BUG_DMA_DONE_EARLY`) and automatically bucketed
  them as `credit_accounting`, `crc_integrity`, `retry_identity`, and
  `dma_completion`.
- Added UPF-aligned power-intent proxy verification, CSR-programmed DMA
  completion checks, and a bounded Verilator property appendix for protocol
  invariants.

## Supporting Numbers

These values come from the current checked-in regression artifacts:

- Stable regression runs meeting expectation: `43 / 43`
- Nominal stable-report pass rate: `39 / 39`
- Stable functional coverage: `51 / 51` bins (`100.0%`)
- Randomized stable runs meeting expectation: `1 / 1`
- Power-proxy tests meeting expectation: `6 / 6`
- DMA nominal runs meeting expectation: `17 / 17`
- DMA bug-validation runs meeting expectation: `1 / 1`
- Expected bug-validation failures observed: `4 / 4`

Source files:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/verification_dashboard.md`
- `chiplet_extension/reports/power_state_summary.csv`
- `chiplet_extension/reports/formal_summary.csv`

## Interview Talking Points

- The environment is intentionally lightweight rather than full UVM, but it
  still demonstrates the core DV ideas: stimulus control, monitor-driven
  checking, functional coverage, regression automation, and bug-injection
  validation.
- The SoC bench uses a Python-generated reference CSV rather than reusing the
  same in-bench datapath for expected results.
- The DMA offload path adds a software-visible subsystem with source and
  destination scratchpads, a queued submit/completion model, IRQ completion,
  timeout handling, reject logging, and golden-image comparison.
- Power behavior is verified with explicit proxy scenarios, which is honest
  and practical for this project stage.
- The property appendix is bounded and Verilator-based, so it is proof-style
  collateral without pretending to be full theorem-proving formal.

## Honest Limitations To Mention

- The power-state work is proxy-based rather than UPF-aware simulation.
- The property harnesses are bounded assertion checks, not a complete formal
  signoff flow.
- The stress suite still exists as explicit characterization and closure work
  for anyone who wants to dig deeper.
