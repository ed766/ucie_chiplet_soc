# Performance Characterization

These measurements come from behavioral Verilator simulation and are intended
for architecture/DV discussion. They are not silicon timing, power, or
implementation signoff numbers.

| Scenario | Source test | Avg latency | Max latency | Retry count | Throughput | Notes |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| No fault | `prbs_latency_low` | 41 | 41 | 0 | 0.0289 | Baseline PRBS link path with no injected retry/fault window. |
| Backpressure | `prbs_backpressure_wave` | 41 | 41 | 0 | 0.0292 | Heavy deterministic backpressure point; throughput remains scoreboard-clean. |
| CRC retry | `prbs_crc_burst_recover` | 41 | 41 | 2 | 0.0119 | CRC retry recovery with retry rate 0.0250. |
| Lane fault | `prbs_lane_fault_recover` | 41 | 41 | 1 | 96/41 flits/latency-window | Lane fault recovery completed without scoreboard mismatch. |
| Sleep/resume during queued DMA | `dma_sleep_during_queued_work` | 41 | 41 | 0 | 1/41 flits/latency-window | DMA descriptors completed=1, errors=0. |
| Crypto-only mode | `dma_crypto_only_submit_blocked` | NA | NA | 0 | NA | Mode blocks new DMA submission; error/reject count=1. |

## Observations

- The no-fault baseline reports 41 cycles average latency and 0.0289 flits/cycle throughput in the PRBS characterization path.
- The selected backpressure point keeps average latency at 41 cycles while preserving a clean scoreboard result; the stress is visible in backpressure coverage rather than failures.
- CRC retry recovery records 2 retries at the selected point, showing retry overhead without packet-order corruption.
- Lane-fault recovery completes through `prbs_lane_fault_recover` with 1 retry event and no mismatch in the regression row.
- Sleep/resume and crypto-only rows are control-behavior characterizations: `dma_sleep_during_queued_work` proves queued DMA recovery, while `dma_crypto_only_submit_blocked` proves mode-dependent submission blocking.

## Source Artifacts

- `chiplet_extension/reports/perf_characterization.csv`
- `chiplet_extension/reports/regress_summary.csv`
- per-test `*_scoreboard.csv` files referenced by the regression summary
