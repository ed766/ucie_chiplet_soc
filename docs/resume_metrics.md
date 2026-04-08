# Resume Metrics — UCIe Chiplet DV

## Resume-Ready Bullets

- Built a coverage-driven SystemVerilog verification environment for a dual-die
  RISC-V SoC with a behavioral UCIe-style link, using named tests, passive
  monitors, scoreboards, assertions, and Verilator-based regression automation.
- Added 22 named tests plus machine-readable `DV_RESULT` reporting, Python
  golden-model reference generation, automated failure bucketing, and
  CSV/Markdown dashboards for regression status and functional coverage.
- Validated three injected bug modes
  (`UCIE_BUG_CREDIT_OFF_BY_ONE`, `UCIE_BUG_CRC_POLY`,
  `UCIE_BUG_RETRY_SEQ`) and automatically bucketed them as
  `credit_accounting`, `crc_integrity`, and `retry_identity`.

## Supporting Numbers

These values come from the current checked-in stable regression artifacts:

- Stable regression runs meeting expectation: `16 / 16`
- Nominal pass rate: `13 / 13`
- Randomized runs meeting expectation: `3 / 3`
- Named tests implemented: `22`
- Stable functional coverage: `18 / 23` bins (`78.3%`)
- Expected bug-validation failures observed: `3 / 3`

Source files:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/verification_dashboard.md`

## Interview Talking Points

- The environment is intentionally lightweight rather than full UVM, but it
  still demonstrates the core DV ideas: stimulus control, monitor-driven
  checking, functional coverage, regression automation, and bug-injection
  validation.
- The SoC bench uses a Python-generated reference CSV rather than reusing the
  same in-bench datapath for expected results.
- The stable suite is green, while the heavier retry/fault mixes remain named
  stress tests for explicit closure work rather than hidden failures.

## Honest Limitations To Mention

- The stable suite still leaves `credit_low`, `retry_backpressure_cross`,
  `latency_low`, `latency_high`, and `expected_empty` uncovered.
- Heavier retry/backpressure and SoC recovery scenarios remain in the stress
  suite rather than the default gate.
- Power-state scenarios are represented with reset/idle proxies instead of
  true UPF-aware simulation.
