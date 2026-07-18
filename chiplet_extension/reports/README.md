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
- `formal_proof_summary.csv`
- `async_cdc_summary.csv`
- `uvm_ci_regress_summary.csv`
- `uvm_ci_coverage_summary.csv`
- `code_coverage_summary.txt`
- `code_coverage_summary.md`
- `code_coverage_test_ranking.csv`
- `code_coverage_holes.csv`
- `perf_characterization.csv`
- `dma_mem_characterization.csv`
- `project_metrics.csv`
- `frontend_quality_summary.csv`
- `frontend_quality_summary.md`
- `cdc_rdc_summary.csv`
- `firmware_soc_summary.csv`
- `firmware_coverage_summary.csv`
- `firmware_cross_coverage_summary.csv`
- `firmware_code_coverage_summary.txt`
- `firmware_code_coverage_summary.md`
- `firmware_c_summary.csv`
- `firmware_c_coverage_summary.csv`
- `firmware_c_cross_coverage_summary.csv`
- `firmware_c_evidence_audit.csv`
- `firmware_c_mutation_summary.csv`
  - RTL and normalized-trace mutation sensitivity for the compiled-firmware lane.
- `firmware_c_isa_random_summary.csv`
  - Results and seeds for 25 generated RV32I/Zicsr instruction streams.
- `firmware_c_workload_random_summary.csv`
  - Applied knobs and outcomes for 25 generated firmware/DMA workloads.
- `firmware_c_performance_summary.csv`
  - Behavioral cycle, CPI, APB wait, interrupt, handler, and submit/completion statistics.
- `firmware_c_code_coverage_summary.txt`
- `firmware_c_code_coverage_summary.md`
- `firmware_c_code_coverage_test_ranking.csv`

The firmware flat/cross coverage summaries and focused code-coverage report
are curated exceptions because they are the canonical firmware evidence.
The compiled-C summaries are curated because they record architectural
differential results, detailed ISA/firmware interactions, focused native code
coverage, test contribution, and checker mutation sensitivity without retaining
raw traces or machine-specific build products.
The front-end summaries retain the bounded Yosys control/link proxy and
structural CDC/RDC result while excluding tool logs and build trees.

Do not check in other routine generated files matching `*_coverage.csv`,
`*_scoreboard.csv`, `*_power.csv`, seed-specific summaries, smoke summaries,
or UVM per-test artifacts unless they are being used as a specific debug case
study.
