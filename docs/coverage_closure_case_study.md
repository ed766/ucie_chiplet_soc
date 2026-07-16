# Coverage Closure Case Study

This case study explains how the chiplet verification flow reached the
canonical `60 / 60` functional coverage target. It is intended as the
interview-facing explanation behind the headline metric, not a replacement for
the machine-readable reports.

## Closure Target

The gating functional target is the flat 60-bin model generated from
`chiplet_extension/reports/coverage_summary.csv` and summarized in
`chiplet_extension/reports/coverage_closure_matrix.md`.

| Coverage area | Example bins |
| --- | --- |
| DMA | submit acceptance/reject, queue occupancy, completion FIFO occupancy, timeout, IRQ, retire stall |
| Link | normal transfer, credit pressure, retry request, CRC fault, lane fault, latency low/nominal/high |
| Memory | bank conflict, wait accounting, parity error, invalid-bank read, retained/non-retained wake behavior |
| Power | RUN, CRYPTO_ONLY, SLEEP, DEEP_SLEEP, legal transitions, isolation, retention, transition/activity crosses |
| AES/service | end-to-end updates, expected-empty path, mismatch detection, return ordering |

## Closure Strategy

Coverage was closed with a mix of directed tests and bounded stress:

- Directed DMA tests closed queueing, completion, IRQ, timeout, reject, and FIFO edge behavior.
- Link tests closed retry, CRC, backpressure, lane-fault, credit, and latency bins.
- Memory tests closed bank conflicts, maintenance access, parity, invalid-bank, and retention semantics.
- Power-proxy tests closed PST states, transitions, switch/isolation behavior, retention pulses, and active-traffic transitions.
- Negative tests proved illegal operations return explicit errors instead of silently mutating state.
- Expected-fail bug-validation tests proved the checkers are sensitive to injected design faults.
- Optional seeded-random stress adds confidence but is not the default closure gate.

## Hard-To-Close Examples

| Case | Why it mattered | Closure evidence |
| --- | --- | --- |
| Invalid source bank consumed by DMA | A non-retained bank is readable and parity-clean, so DMA must still reject it as architecturally invalid. | `mem_invalid_src_dma_error`, true cross `invalid bank x DMA source read x error completion` |
| Retry under backpressure | Handshakes can look legal while replay identity is wrong. | `prbs_retry_backpressure`, `bug_retry_seq`, retry identity property |
| Power transition with active traffic | UPF-like intent is only useful if isolation/retention behavior is exercised during activity, not only idle states. | `power_traffic_cross_test`, `power_transition_with_link_backpressure`, low-power proxy targets |
| Completion FIFO full/empty edges | Completion ordering and interrupt behavior can fail when software drains slowly or pops empty. | `dma_comp_fifo_full_stall`, `dma_comp_pop_empty`, completion FIFO bins |

## Final Evidence

- Functional coverage: `60 / 60` bins in `chiplet_extension/reports/coverage_summary.csv`.
- Grouped closure matrix: `chiplet_extension/reports/coverage_closure_matrix.md`.
- Interaction evidence: `chiplet_extension/reports/true_cross_coverage_summary.csv` and `docs/reference/true_cross_coverage_summary.md`.
- Regression evidence: `chiplet_extension/reports/regress_summary.csv`.
- Bug sensitivity: `docs/bug_diary.md` and `chiplet_extension/reports/failure_buckets.csv`.

## Boundary

The `60 / 60` model is the canonical closure target. True-cross coverage,
seeded-random stress, code coverage, UVM collateral, CDC/RDC checks, and UPF
static validation are additional quality evidence, not replacements for the
flat functional closure vector.
