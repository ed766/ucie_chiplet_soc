# Bug Validation Cases

This diary records the injected bug modes that are actually compiled and
validated by the chiplet regression. Each case is expected to fail in a known
bucket; a silent pass is treated as a verification failure. The more
interview-oriented narrative view is in `docs/bug_diary.md`.

## Summary Table

| Bug mode | Regression test | Expected bucket | Debug class |
| --- | --- | --- | --- |
| `UCIE_BUG_CREDIT_OFF_BY_ONE` | `bug_credit_off_by_one` | `credit_accounting` | credit underflow/backpressure accounting |
| `UCIE_BUG_CRC_POLY` | `bug_crc_poly` | `crc_integrity` | CRC error packet accepted or misclassified |
| `UCIE_BUG_RETRY_SEQ` | `bug_retry_seq` | `retry_identity` | retry identity/reordered replay |
| `UCIE_BUG_DMA_DONE_EARLY` | `dma_bug_done_early` | `dma_completion` | DMA completion generated early or twice |
| `UCIE_BUG_MEM_PARITY_SKIP` | `mem_bug_parity_skip` | `memory_integrity` | memory parity skip / retained-memory integrity |

## `UCIE_BUG_CREDIT_OFF_BY_ONE`

| Field | Detail |
| --- | --- |
| Bug name | Credit off-by-one under backpressure |
| Injected fault | Credit accounting is intentionally perturbed in the UCIe credit path. |
| Expected symptom | Credit bounds or accounting invariant fails under the directed bug test. |
| Checker that caught it | `credit_checker.sv` plus regression failure bucketing. |
| Waveform/debug evidence | Compile log and run log are linked from `chiplet_extension/reports/regress_summary.csv`; the failing bucket is summarized in `failure_buckets.csv`. |
| Fix or validation result | Expected-fail validation confirms the checker is sensitive to credit-accounting corruption. |
| Regression test | `bug_credit_off_by_one` |

## `UCIE_BUG_CRC_POLY`

| Field | Detail |
| --- | --- |
| Bug name | CRC polynomial mismatch |
| Injected fault | The packetizer uses the wrong CRC polynomial under the bug define. |
| Expected symptom | Receive-side CRC checking detects corrupted FLIT integrity. |
| Checker that caught it | CRC monitor path, retry/error handling, and regression bucket parser. |
| Waveform/debug evidence | The failing run log shows CRC-integrity failure signatures and is linked from the regression summary. |
| Fix or validation result | Expected-fail validation confirms CRC corruption is not silently accepted. |
| Regression test | `bug_crc_poly` |

## `UCIE_BUG_RETRY_SEQ`

| Field | Detail |
| --- | --- |
| Bug name | Retry replay identity corruption |
| Injected fault | The retry resend path mutates the replayed FLIT payload. |
| Expected symptom | Retry checker observes resend data that does not match the previously committed transmit FLIT. |
| Checker that caught it | `retry_checker.sv`, `ucie_scoreboard.sv`, and the bounded retry bug-demo harness. |
| Waveform/debug evidence | Retry resend and debug FLIT traces are captured in the run log linked from `regress_summary.csv` and `formal_summary.csv`. |
| Fix or validation result | Expected-fail validation confirms replay identity is checked directly rather than inferred from handshakes. |
| Regression test | `bug_retry_seq` |

## `UCIE_BUG_DMA_DONE_EARLY`

| Field | Detail |
| --- | --- |
| Bug name | DMA done generated before destination image is complete |
| Injected fault | DMA completion is reported before all expected destination words are retired. |
| Expected symptom | Destination scratchpad compare finds stale or missing ciphertext even though completion was reported. |
| Checker that caught it | `dma_mem_ref_scoreboard.sv`, DMA completion monitor, and DMA CSR/IRQ checker. |
| Waveform/debug evidence | The failing run log and scoreboard CSV are linked from `regress_summary.csv`. |
| Fix or validation result | Expected-fail validation proves completion is checked against final memory state, not just a done bit. |
| Regression test | `dma_bug_done_early` |

## `UCIE_BUG_MEM_PARITY_SKIP`

| Field | Detail |
| --- | --- |
| Bug name | Memory parity error skipped |
| Injected fault | Parity detection/reporting is suppressed for a corrupted scratchpad maintenance read. |
| Expected symptom | Memory integrity checker expects a parity error and fails when it is not reported. |
| Checker that caught it | Memory maintenance status checks, parity counters, and memory-integrity failure bucket. |
| Waveform/debug evidence | The failing run log, coverage CSV, and scoreboard artifacts are linked from `regress_summary.csv`. |
| Fix or validation result | Expected-fail validation confirms local-memory integrity faults are observable. |
| Regression test | `mem_bug_parity_skip` |

## Notes

- These are the implemented bug-validation cases. Do not add unimplemented bugs to this diary without a matching compile-time bug mode and regression row.
- The more narrative version of these cases is in `docs/bug_case_studies.md`.
