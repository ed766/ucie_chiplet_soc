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

## DMA/Memory Architecture Points

| Scenario | Avg latency | Max latency | Throughput | Conflicts/wait | Recovery | Notes |
| --- | ---: | ---: | ---: | --- | --- | --- |
| DMA nominal stream | 121 | 121 | 0.0070 | 0 src / 0 dst / 0 wait | NA | Optional nominal-stream baseline row for queue-depth interpretation. |
| Queue depth 1 | 219 | 231 | 0.0082 | 0 src / 0 dst / 0 wait | NA | Back-to-back enqueue attempts every cycle across a fixed 32-descriptor workload. |
| Queue depth 2 | 333 | 352 | 0.0082 | 0 src / 0 dst / 0 wait | NA | Back-to-back enqueue attempts every cycle across a fixed 32-descriptor workload. |
| Queue depth 4 | 546 | 594 | 0.0082 | 0 src / 0 dst / 0 wait | NA | Back-to-back enqueue attempts every cycle across a fixed 32-descriptor workload. |
| 1-bank conflict heavy | 492 | 594 | 0.0081 | 8 src / 5 dst / 13 wait | NA | Maintenance reads are issued every 16 cycles with fixed 50/50 source/destination alternation. |
| 2-bank conflict heavy | 494 | 594 | 0.0081 | 3 src / 2 dst / 5 wait | NA | Maintenance reads are issued every 16 cycles with fixed 50/50 source/destination alternation. |
| Invalid-memory recovery | 514 | 1026 | 0.0018 | 0 src / 0 dst / 0 wait | 4 writes, 52 cycles, 0.7429 penalty | Deterministic recovery rewrites one required word per invalid bank in ascending bank/address order. |

## Tradeoff Snapshot

| Study | Low/base point | Stress point | Delta | Interpretation |
| --- | --- | --- | ---: | --- |
| Channel delay | delay_0: 41 avg cycles | delay_20: 61 avg cycles | 20 cycles | The latency shim is directly visible in end-to-end receive latency. |
| CRC retry overhead | no fault: 0.0289 flits/cycle | CRC retry: 0.0119 flits/cycle, 2 retries | -58.8% | Retry/recovery lowers effective throughput while preserving ordering. |
| DMA queue depth | depth 1: 219 avg cycles | depth 4: 546 avg cycles | 327 cycles | Back-to-back submission increases latency because execution remains strictly in-order. |
| Bank conflict pressure | 2 banks: 5 wait, 3/2 src/dst conflicts | 1 bank: 13 wait, 8/5 src/dst conflicts | 8 fewer wait cycles/events | Banking reduces maintenance conflict pressure under the heavy-contention workload. |
| Invalid-memory recovery | valid banks: no recovery sequence required | 4 recovery writes, 52 cycles | 0.7429 throughput penalty | Post-wake invalid banks create a measurable software recovery cost. |

## Observations

- The no-fault baseline reports 41 cycles average latency and 0.0289 flits/cycle throughput in the PRBS characterization path.
- The selected backpressure point keeps average latency at 41 cycles while preserving a clean scoreboard result; the stress is visible in backpressure coverage rather than failures.
- CRC retry recovery records 2 retries at the selected point, showing retry overhead without packet-order corruption.
- Back-to-back DMA queueing is visible in behavioral latency: queue depth 1 reports 219 average cycles, while queue depth 4 reports 546 average cycles because descriptors wait behind older accepted work.
- The banked scratchpad study shows lower conflict/wait pressure in 2-bank heavy contention (3 src / 2 dst / 5 wait) than the 1-bank structural variant (8 src / 5 dst / 13 wait).
- Invalid-memory recovery is measurable rather than just functional: the deterministic recovery row reports 4 writes, 52 cycles, 0.7429 penalty.
- Lane-fault recovery completes through `prbs_lane_fault_recover` with 1 retry event and no mismatch in the regression row.
- Sleep/resume and crypto-only rows are control-behavior characterizations: `dma_sleep_during_queued_work` proves queued DMA recovery, while `dma_crypto_only_submit_blocked` proves mode-dependent submission blocking.

## Source Artifacts

- `chiplet_extension/reports/perf_characterization.csv`
- `chiplet_extension/reports/dma_mem_characterization.csv`
- `chiplet_extension/reports/regress_summary.csv`
- per-test `*_scoreboard.csv` files referenced by the regression summary
