# Curated Report Policy

This directory contains normalized, reviewer-facing evidence. Raw logs, waveforms, compiled firmware, coverage databases, per-seed traces, and simulator build trees belong under ignored `build/` or `logs/` directories.

## Canonical Evidence Groups

| Group | Representative artifacts |
| --- | --- |
| Stable closure | `regress_summary.csv`, `coverage_summary.csv`, `power_state_summary.csv`, `failure_buckets.csv` |
| Functional interactions | `cross_coverage_summary.csv`, `true_cross_coverage_summary.csv`, `coverage_closure_matrix.md` |
| Firmware/APB | `firmware_soc_summary.csv`, `firmware_coverage_summary.csv`, `firmware_cross_coverage_summary.csv` |
| GCC/ISS | `firmware_c_summary.csv`, directed/seeded summaries, functional/cross coverage, evidence audit, performance, and focused code coverage |
| Privileged RV32 | `privileged_arch_summary.csv`, `privileged_arch_coverage_summary.csv`, `privileged_arch_cross_coverage_summary.csv` |
| External architecture | `rv32_external_tool_status.csv`, Spike, ACT4/Sail, RVFI formal, and external mutation summaries |
| Formal/assertions | `formal_summary.csv`, `formal_proof_summary.csv` |
| UVM/CDC | `uvm_ci_*`, `async_cdc_summary.csv`, `cdc_rdc_summary.csv` |
| Code/implementation | `code_coverage_*`, `frontend_quality_summary.*` |
| Characterization | `perf_characterization.csv`, `dma_mem_characterization.csv` |
| Reviewer snapshot | `project_metrics.csv`, `verification_dashboard.md` |

## Rules

- Reports must use repository-relative paths and deterministic column ordering.
- Functional, cross, power, code, UVM, formal, and mutation evidence remain separate metrics.
- Expected-fail rows are retained only when their intended checker and failure bucket are explicit.
- Focused firmware coverage is not substituted for full-chiplet code coverage.
- Missing optional tools are reported as `SKIP`; release-required external tools fail under `--require`.
- New curated artifacts must be added to `.gitignore` exceptions and, when reviewer-facing, to `REPORT_ARTIFACTS` in the Makefile.

Run the following after regenerating evidence:

```bash
make project-metrics readme-metrics normalize-report-paths docs-check
git diff --check
```

Routine `*_scoreboard.csv`, per-test coverage, seed-specific reports, raw LCOV data, and local tool logs should not be committed unless they support a named debug case study.
