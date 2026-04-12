# Verification Dashboard

## Regression Snapshot

| Metric | Value |
| --- | ---: |
| Total runs | 57 |
| Runs meeting expectation | 57 |
| Nominal pass rate | 52/52 |
| Randomized runs meeting expectation | 1/1 |
| Unexpected failures | 0 |
| Expected bug-validation failures | 5 |

## Coverage Snapshot

| Metric | Value |
| --- | ---: |
| Covered functional bins | 60/60 |
| Functional coverage percent | 100.0% |

## Bug Validation

| Test | Bug mode | Observed status | Meets expectation | Detail |
| --- | --- | --- | --- | --- |
| `bug_credit_off_by_one` | `UCIE_BUG_CREDIT_OFF_BY_ONE` | FAIL | 1 | credit_assertion |
| `bug_crc_poly` | `UCIE_BUG_CRC_POLY` | FAIL | 1 | crc_integrity |
| `bug_retry_seq` | `UCIE_BUG_RETRY_SEQ` | FAIL | 1 | retry_identity |
| `dma_bug_done_early` | `UCIE_BUG_DMA_DONE_EARLY` | FAIL | 1 | dma_completion_violation |
| `mem_bug_parity_skip` | `UCIE_BUG_MEM_PARITY_SKIP` | FAIL | 1 | memory_integrity_violation |

## DMA Verification

| Metric | Value |
| --- | ---: |
| DMA nominal runs meeting expectation | 17/17 |
| DMA bug-validation runs meeting expectation | 1/1 |

| Test | Status | Detail | DMA desc | DMA irq | DMA err | DMA mem mismatch |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `dma_queue_smoke` | PASS | dma_queue_smoke_clean | 1 | 1 | 0 | 0 |
| `dma_queue_back_to_back` | PASS | dma_queue_back_to_back_clean | 2 | 1 | 0 | 0 |
| `dma_queue_full_reject` | PASS | dma_queue_full_reject_clean | 4 | 1 | 4 | 0 |
| `dma_completion_fifo_drain` | PASS | dma_completion_fifo_drain_clean | 3 | 1 | 0 | 0 |
| `dma_irq_masking` | PASS | dma_irq_masking_clean | 1 | 2 | 1 | 0 |
| `dma_odd_len_reject` | PASS | dma_odd_len_reject_clean | 0 | 0 | 1 | 0 |
| `dma_range_reject` | PASS | dma_range_reject_clean | 0 | 0 | 1 | 0 |
| `dma_timeout_error` | PASS | dma_timeout_error_clean | 0 | 0 | 1 | 0 |
| `dma_retry_recover_queue` | PASS | dma_retry_recover_queue_clean | 2 | 1 | 0 | 0 |
| `dma_power_sleep_resume_queue` | PASS | dma_power_sleep_resume_queue_clean | 1 | 1 | 0 | 0 |
| `dma_comp_fifo_full_stall` | PASS | dma_comp_fifo_full_stall_clean | 5 | 0 | 0 | 0 |
| `dma_irq_pending_then_enable` | PASS | dma_irq_pending_then_enable_clean | 1 | 1 | 0 | 0 |
| `dma_comp_pop_empty` | PASS | dma_comp_pop_empty_clean | 0 | 0 | 0 | 0 |
| `dma_reset_mid_queue` | PASS | dma_reset_mid_queue_clean | 0 | 0 | 0 | 0 |
| `dma_tag_reuse` | PASS | dma_tag_reuse_clean | 2 | 0 | 0 | 0 |
| `dma_power_state_retention_matrix` | PASS | dma_power_state_retention_matrix_clean | 1 | 0 | 0 | 0 |
| `dma_crypto_only_submit_blocked` | PASS | dma_crypto_only_submit_blocked_clean | 0 | 0 | 1 | 0 |
| `dma_bug_done_early` | FAIL | dma_completion_violation | 1 | 0 | 0 | 1 |

## Memory Verification

| Metric | Value |
| --- | ---: |
| Memory nominal runs meeting expectation | 13/13 |
| Memory bug-validation runs meeting expectation | 1/1 |

## Power-State Proxy Verification

| Metric | Value |
| --- | ---: |
| States visited | 4/4 |
| Transitions visited | 6/6 |
| Power tests meeting expectation | 6/6 |

| Test | Mode | Status | Illegal activity | Resume violations | States |
| --- | --- | --- | ---: | ---: | --- |
| `power_run_mode` | `run` | PASS | 0 | 0 | run |
| `power_crypto_only` | `crypto_only` | PASS | 0 | 0 | run, crypto_only |
| `power_sleep_entry_exit` | `sleep` | PASS | 0 | 0 | run, sleep |
| `power_deep_sleep_recover` | `deep_sleep` | PASS | 0 | 0 | run, deep_sleep |
| `dma_power_sleep_resume_queue` | `sleep` | PASS | 0 | 1 | run, sleep |
| `dma_power_state_retention_matrix` | `none` | PASS | 0 | 0 | run, sleep, deep_sleep |

## Failure Buckets

| Bucket | Count | Unexpected | Expected |
| --- | ---: | ---: | ---: |
| `crc_integrity` | 1 | 0 | 1 |
| `credit_accounting` | 1 | 0 | 1 |
| `dma_completion` | 1 | 0 | 1 |
| `memory_integrity` | 1 | 0 | 1 |
| `retry_identity` | 1 | 0 | 1 |
