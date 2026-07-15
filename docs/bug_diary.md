# Bug Diary

This diary is the interview-facing view of the injected bug-validation flow.
It maps each implemented compile-time bug mode to the symptom, checker, and
regression evidence that proves the verification environment catches it. It is
not a list of hypothetical bugs.

## Summary

| Bug class | Injected mode | Regression | Checker / evidence |
| --- | --- | --- | --- |
| Credit underflow/backpressure accounting | `UCIE_BUG_CREDIT_OFF_BY_ONE` | `bug_credit_off_by_one` | credit checker and failure bucket |
| CRC integrity fault | `UCIE_BUG_CRC_POLY` | `bug_crc_poly` | CRC monitor, retry path, failure bucket |
| Retry replay identity corruption | `UCIE_BUG_RETRY_SEQ` | `bug_retry_seq` | retry checker, scoreboard, bounded bug demo |
| DMA completion generated too early | `UCIE_BUG_DMA_DONE_EARLY` | `dma_bug_done_early` | DMA memory scoreboard and completion monitor |
| Memory parity reporting skipped | `UCIE_BUG_MEM_PARITY_SKIP` | `mem_bug_parity_skip` | maintenance status check and memory-integrity bucket |

## Credit Underflow On Backpressure And Retry

| Field | Detail |
| --- | --- |
| Symptom | Credit accounting leaves the legal range under directed backpressure/retry pressure. |
| Root cause model | The bug mode perturbs credit update behavior so debit/return accounting can become inconsistent. |
| Injected fault | `UCIE_BUG_CREDIT_OFF_BY_ONE` |
| Checker / assertion | `credit_checker.sv`, credit bounded property harness, and regression failure bucketing. |
| Regression | `bug_credit_off_by_one` |
| Debug artifact | `chiplet_extension/reports/regress_summary.csv` and `failure_buckets.csv` identify the failing bucket. |
| Validation result | Expected failure is observed in the credit-accounting bucket; a silent pass would fail bug validation. |

## CRC Integrity Fault

| Field | Detail |
| --- | --- |
| Symptom | Receive-side integrity logic observes a packet that does not match the expected CRC behavior. |
| Root cause model | Packet CRC generation/checking is intentionally mismatched under the bug define. |
| Injected fault | `UCIE_BUG_CRC_POLY` |
| Checker / assertion | CRC monitor path, retry/error handling, and CRC integrity failure bucket. |
| Regression | `bug_crc_poly` |
| Debug artifact | Run log and scoreboard artifacts linked from the regression summary. |
| Validation result | Corrupted packet integrity is not silently accepted. |

## Retry Replay Identity Corruption

| Field | Detail |
| --- | --- |
| Symptom | Retry resend data no longer matches the previously transmitted FLIT identity. |
| Root cause model | The replay path mutates or reuses stale FLIT data during retry recovery. |
| Injected fault | `UCIE_BUG_RETRY_SEQ` |
| Checker / assertion | `retry_checker.sv`, `ucie_scoreboard.sv`, and `tb_ucie_tx_retry_props.sv`. |
| Regression | `bug_retry_seq` |
| Debug artifact | See `docs/debug_case_study_dma_retry.md` and `docs/images/dma_retry_waveform.png` for the retry timeline style used in debug. |
| Validation result | Expected failure proves retry identity is checked directly rather than inferred from handshakes. |

## DMA Completion Generated Too Early

| Field | Detail |
| --- | --- |
| Symptom | DMA completion is reported before all destination words match the expected ciphertext image. |
| Root cause model | Completion valid is allowed to escape before the descriptor has fully retired. |
| Injected fault | `UCIE_BUG_DMA_DONE_EARLY` |
| Checker / assertion | `dma_mem_ref_scoreboard.sv`, DMA completion monitor, and DMA queue/completion property harness. |
| Regression | `dma_bug_done_early` |
| Debug artifact | Per-run scoreboard CSV linked from `regress_summary.csv`. |
| Validation result | Expected failure proves the flow checks final memory state, not only a done bit. |

## Memory Parity Reporting Skipped

| Field | Detail |
| --- | --- |
| Symptom | A corrupted scratchpad word is read without the expected parity-error status. |
| Root cause model | Parity reporting is suppressed even though stored parity does not match data. |
| Injected fault | `UCIE_BUG_MEM_PARITY_SKIP` |
| Checker / assertion | Maintenance status checks, parity counters, memory-integrity bucket, and memory property harness. |
| Regression | `mem_bug_parity_skip` |
| Debug artifact | Run log, coverage CSV, and scoreboard artifacts linked from `regress_summary.csv`. |
| Validation result | Expected failure proves local-memory integrity errors are software-visible. |

## Validation Policy

- Each entry maps to an implemented compile-time bug mode, expected-fail regression, checker, and failure bucket.
- A bug test meets expectation only when it fails in its assigned bucket; a silent pass fails bug validation.
- New entries require matching injected RTL behavior and machine-readable regression evidence.
- The diary supports debug discussion but does not replace `regress_summary.csv` or `failure_buckets.csv`.
