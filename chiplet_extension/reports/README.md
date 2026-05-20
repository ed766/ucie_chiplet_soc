# Report Policy

This directory keeps only curated evidence summaries under version control.
Raw per-test and per-seed artifacts are generated locally by the Make targets
and are ignored by default.

Keep checked in:

- `regress_summary.csv`
- `coverage_summary.csv`
- `failure_buckets.csv`
- `verification_dashboard.md`
- `power_state_summary.csv`
- `coverage_closure_matrix.md`
- `cross_coverage_summary.csv`
- `formal_summary.csv`
- `perf_characterization.csv`
- `dma_mem_characterization.csv`
- `project_metrics.csv`

Do not check in routine generated files matching `*_coverage.csv`,
`*_scoreboard.csv`, `*_power.csv`, seed-specific summaries, smoke summaries,
or UVM per-test artifacts unless they are being used as a specific debug case
study.
