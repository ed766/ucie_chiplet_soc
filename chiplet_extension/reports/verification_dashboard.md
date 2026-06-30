# Verification Dashboard

## Regression Snapshot

| Metric | Value |
| --- | ---: |
| Total runs | 70 |
| Runs meeting expectation | 70 |
| Nominal pass rate | 65/65 |
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
| DMA nominal runs meeting expectation | 19/19 |
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
| `dma_sleep_during_queued_work` | PASS | dma_sleep_during_queued_work_clean | 1 | 0 | 0 | 0 |
| `dma_sleep_during_active_transfer` | PASS | dma_sleep_during_active_transfer_clean | 1 | 0 | 0 | 0 |
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
| Memory nominal runs meeting expectation | 15/15 |
| Memory bug-validation runs meeting expectation | 1/1 |

## Power-State Proxy Verification

| Metric | Value |
| --- | ---: |
| States visited | 4/4 |
| Transitions visited | 6/6 |
| PST domain combos visited | 4/4 |
| Isolation bins visited | 4/4 |
| Retention bins visited | 4/4 |
| Transition/activity bins visited | 5/5 |
| Power tests meeting expectation | 26/26 |

| Test | Mode | Status | Illegal activity | Resume violations | States |
| --- | --- | --- | ---: | ---: | --- |
| `power_run_mode` | `run` | PASS | 0 | 0 | run |
| `power_crypto_only` | `crypto_only` | PASS | 0 | 0 | run, crypto_only |
| `power_sleep_entry_exit` | `sleep` | PASS | 0 | 0 | run, sleep |
| `power_deep_sleep_recover` | `deep_sleep` | PASS | 0 | 0 | run, deep_sleep |
| `power_isolation_blocks_tx` | `sleep` | PASS | 0 | 0 | run, sleep |
| `power_wakeup_releases_isolation_cleanly` | `sleep` | PASS | 0 | 0 | run, sleep |
| `power_transition_with_link_backpressure` | `sleep` | PASS | 0 | 0 | run, sleep |
| `power_illegal_access_error_response` | `none` | PASS | 0 | 0 | run, crypto_only |
| `power_traffic_cross_test` | `none` | PASS | 0 | 0 | run, crypto_only, sleep |
| `power_iso_before_switch_off` | `sleep` | PASS | 0 | 0 | run, sleep |
| `power_restore_before_deiso` | `sleep` | PASS | 0 | 0 | run, sleep |
| `power_domain_sequence_matrix` | `deep_sleep` | PASS | 0 | 0 | run, crypto_only, sleep, deep_sleep |
| `power_invalid_transition_clamped` | `run` | PASS | 0 | 0 | run, crypto_only, sleep, deep_sleep |
| `dma_power_sleep_resume_queue` | `sleep` | PASS | 0 | 0 | run, sleep |
| `dma_sleep_during_queued_work` | `none` | PASS | 0 | 0 | run, sleep |
| `dma_sleep_during_active_transfer` | `none` | PASS | 0 | 0 | run, sleep |
| `dma_power_state_retention_matrix` | `none` | PASS | 0 | 0 | run, sleep, deep_sleep |
| `dma_crypto_only_submit_blocked` | `none` | PASS | 0 | 0 | run, crypto_only |
| `mem_invalid_src_dma_error` | `none` | PASS | 0 | 0 | run, sleep |
| `mem_sleep_retained_bank` | `none` | PASS | 0 | 0 | run, sleep |
| `mem_sleep_nonretained_bank` | `none` | PASS | 0 | 0 | run, sleep |
| `mem_sleep_dst_nonretained_bank` | `none` | PASS | 0 | 0 | run, sleep |
| `mem_nonretained_readback_poison_clean` | `none` | PASS | 0 | 0 | run, sleep |
| `mem_invalid_clear_on_write` | `none` | PASS | 0 | 0 | run, sleep |
| `mem_deep_sleep_retention_matrix` | `none` | PASS | 0 | 0 | run, deep_sleep |
| `mem_crypto_only_cfg_access` | `none` | PASS | 0 | 0 | run, crypto_only |

## Failure Buckets

| Bucket | Count | Unexpected | Expected |
| --- | ---: | ---: | ---: |
| `crc_integrity` | 1 | 0 | 1 |
| `credit_accounting` | 1 | 0 | 1 |
| `dma_completion` | 1 | 0 | 1 |
| `memory_integrity` | 1 | 0 | 1 |
| `retry_identity` | 1 | 0 | 1 |
