# Resume Metrics — UCIe Chiplet DV

## Resume-Ready Bullets

- Built a lightweight coverage-driven SystemVerilog DV environment for a
  dual-die RISC-V SoC with a behavioral UCIe-style link, using named tests,
  passive monitors, scoreboards, assertions, and Verilator-based regression
  automation.
- Added 15 named directed and randomized tests plus machine-readable
  `DV_RESULT` reporting, enabling automated CSV / Markdown dashboards for
  regression status, functional coverage, and failure bucketing.
- Validated bug-checker sensitivity with an injected
  `UCIE_BUG_CREDIT_OFF_BY_ONE` mode that deterministically fails the credit
  checker and is automatically classified into a `credit_accounting` bucket.

## Supporting Numbers

These values come from the current checked-in stable regression artifacts:

- Stable regression runs: 14
- Runs meeting expectation: 14
- Nominal pass rate: 13 / 13
- Randomized runs meeting expectation: 4 / 4
- Named tests implemented: 15
- Functional coverage in the default stable suite: 11 / 23 bins (47.8%)
- Expected bug-validation failures observed: 1

Source files:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/verification_dashboard.md`

## Interview Talking Points

- The environment is intentionally lightweight rather than full UVM, but it
  still shows the core DV ideas: stimulus control, monitor-driven checking,
  functional coverage, regression automation, and bug-injection validation.
- Directed tests prove corner cases and negative behavior; randomized tests add
  seed-swept evidence without requiring manual bench edits.
- Coverage and failure summaries are generated automatically, which makes the
  project stronger than a one-off simulation demo.

## Honest Limitations To Mention

- Retry / CRC / lane-fault coverage is not yet closed in the default stable
  suite.
- Heavy retry stress remains exploratory and currently buckets as
  `link_progress`.
- Power-state scenarios are represented with reset / idle proxies rather than
  true UPF-aware simulation.
