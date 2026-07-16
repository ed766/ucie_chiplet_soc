# Negative Test Summary

This lane covers illegal software/protocol actions separately from compile-time bug-injection modes. Each case must fail if the illegal action silently succeeds.

- Negative cases meeting expectation: 9 / 9

| Test | Illegal action | Expected response | Checker | Coverage bin | Status |
| --- | --- | --- | --- | --- | --- |
| `dma_comp_pop_empty` | Pop an empty completion FIFO. | No-op; no synthetic completion appears. | dma_csr_irq_checker | `dma_comp_occ_0` | PASS |
| `dma_queue_full_reject` | Submit while the internal submit queue is full. | Submit-reject completion with ERR_QUEUE_FULL or reject-overflow accounting. | dma_csr_irq_checker + completion scoreboard | `dma_reject_qfull` | PASS |
| `dma_crypto_only_submit_blocked` | Submit a descriptor in CRYPTO_ONLY. | Submit-reject completion with ERR_SUBMIT_BLOCKED and no accepted descriptor. | dma_csr_irq_checker | `dma_reject_blocked` | PASS |
| `mem_write_while_dma_reject` | Attempt maintenance write while DMA has active context. | Maintenance write reject; source memory remains unchanged. | memory scoreboard | `mem_write_reject` | PASS |
| `mem_op_start_busy_reject` | Start a maintenance op while another maintenance op is busy. | MEM_OP_STATUS.op_reject_busy is set and active op is undisturbed. | MEM_OP status checker | `mem_wait` | PASS |
| `mem_inject_start_busy_reject` | Start parity injection while maintenance op is busy. | MEM_INJECT_STATUS.reject_busy is set and active op is undisturbed. | MEM_INJECT status checker | `mem_wait` | PASS |
| `mem_parity_src_detect` | Consume a parity-bad source word through DMA. | Runtime-error completion with ERR_MEM_PARITY and zero retired words. | DMA/memory scoreboard | `mem_parity_dma` | PASS |
| `power_illegal_access_error_response` | Attempt unavailable-domain DMA submission in CRYPTO_ONLY. | Blocked-submission reject path; descriptor not accepted. | power proxy + DMA checker | `dma_reject_blocked` | PASS |
| `power_transition_with_link_backpressure` | Cross a power transition while link backpressure is active. | No isolation/resume violation and traffic recovers cleanly. | power_state_monitor | `retry_backpressure_cross` | PASS |
