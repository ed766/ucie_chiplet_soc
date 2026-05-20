# Protocol Characterization

These measurements come from the behavioral Verilator benches and a lightweight synthesis-based parity proxy.
They are architecture and verification characterizations, not silicon signoff numbers.

## Behavioral Performance Characterization

### Link / PRBS Sweeps

| Label | Sweep | Knob | Avg latency | Throughput | Status |
| --- | --- | ---: | ---: | ---: | --- |
| `delay_0` | `latency_vs_channel_delay` | 0 | 41 | 0.0289 | PASS |
| `delay_10` | `latency_vs_channel_delay` | 10 | 51 | 0.0285 | PASS |
| `delay_20` | `latency_vs_channel_delay` | 20 | 61 | 0.0285 | PASS |
| `bp_mod_16` | `throughput_vs_backpressure` | 16 | 41 | 0.0292 | PASS |
| `bp_mod_8` | `throughput_vs_backpressure` | 8 | 41 | 0.0292 | PASS |
| `bp_mod_4` | `throughput_vs_backpressure` | 4 | 41 | 0.0292 | PASS |
| `bp_mod_2` | `throughput_vs_backpressure` | 2 | 41 | 0.0292 | PASS |
| `crc_spacing_24` | `retry_rate_vs_fault_density` | 24 | 41 | 0.0119 | PASS |
| `crc_spacing_16` | `retry_rate_vs_fault_density` | 16 | 41 | 0.0119 | PASS |
| `crc_spacing_8` | `retry_rate_vs_fault_density` | 8 | 41 | 0.0119 | PASS |

- Link characterization stays in `perf_characterization.csv`; the DMA/memory tradeoff data is kept separate in `dma_mem_characterization.csv`.
- The existing PRBS sweeps remain the behavioral baseline for latency, backpressure, and retry-density trends.

## DMA/Memory Architectural Tradeoff Characterization

### Phase A Visual Summary

| Study | Best point | Why it wins |
| --- | --- | --- |
| Queue depth | `dma_back_to_back q1 b2 p1` | With one active descriptor, shallower queues minimize average completion latency under fixed immediate-drain traffic. |
| Bank mode | `mem_conflict_light q4 b2 p1` | Two-bank mode reduces maintenance conflict and wait pressure without changing the software-visible memory model. |
| Parity cost | `n/a` | Parity-enabled vs disabled cost is captured when the local synthesis proxy can elaborate the DMA slice. |
| Invalid recovery | `invalid_memory_recovery q4 b2 p1` | Recovery cost is reported in explicit writes and cycles until required banks become valid. |

### Queue Depth Sweep

| queue depth | descriptor throughput | average completion latency cycles | max completion latency cycles | submit reject count | completion occupancy mean |
| --- | --- | --- | --- | --- | --- |
| 1 | 0.0082 | 219 | 231 | 0 | 0.1286 |
| 2 | 0.0082 | 333 | 352 | 0 | 0.1286 |
| 4 | 0.0082 | 546 | 594 | 0 | 0.1234 |
| 4 | 0.0070 | 121 | 121 | 0 | 0.0775 |

- Queue depth is measured under fixed 32-descriptor back-to-back submission pressure.
- The queue study uses immediate completion draining so the sensitivity reflects submit-side elasticity, not delayed software service.

### Bank Mode Sweep

| bank mode | workload | source conflict count | destination conflict count | maint wait mean | maint wait p95 | maintenance starvation incidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | mem_conflict_light | 8 | 5 | 0.0649 | 1 | 0.0000 |
| 1 | mem_conflict_heavy | 8 | 5 | 0.0649 | 1 | 0.0000 |
| 2 | mem_conflict_light | 0 | 1 | 0.0000 | 0 | 0.0000 |
| 2 | mem_conflict_heavy | 3 | 2 | 0.0128 | 0 | 0.0000 |

- The 1-bank vs 2-bank comparison is a structural compile-time sweep, not a runtime mode bit.
- Conflict-light and conflict-heavy workloads alternate source and destination maintenance reads 50/50.

### Maintenance Starvation Sweep

| bank mode | maint wait mean | maint wait p95 | maint wait max | maintenance starvation incidence |
| --- | --- | --- | --- | --- |
| 1 | 0.0649 | 1 | 2 | 0.0000 |
| 2 | 0.0128 | 0 | 1 | 0.0000 |

- Starvation incidence is the fraction of maintenance reads with wait time greater than 32 cycles.
- The starvation view reuses the conflict-heavy measurements instead of inventing a second traffic generator.

### Invalid-Memory Recovery Sweep

| invalid abort count | recovery writes | recovery cycles | throughput penalty vs baseline |
| --- | --- | --- | --- |
| 1 | 4 | 52 | 0.7429 |

- Recovery rewrites one required word per invalid bank in ascending bank/address order.
- The reported recovery cost is behavioral and directly tied to the architectural invalid-bit clearing rule.

## Synthesis-Proxy Cost Estimation

| Parity | Throughput | Cell count | Area estimate | Worst-path delay | Cell delta | Area delta | Delay delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `0` | 0.0070 | NA | NA | NA | NA | NA | NA |
| `1` | 0.0070 | NA | NA | NA | NA | NA | NA |

- The parity proxy attempts to synthesize the `dma_offload_ctrl` slice with identical settings and only toggles `PARITY_ENABLE`.
- The local Yosys proxy could not elaborate the current SystemVerilog slice, so cost fields are marked `NA`; behavioral parity-on/off results are still reported.
- Worst-path delay is a lightweight synthesis proxy when available and should not be read as signoff timing.

## Notes

- Phase A is intentionally limited to queue depth, bank mode, parity cost, maintenance starvation, and invalid-memory recovery.
- Completion-depth, timeout-threshold, retention-policy, and retry/fault sensitivity sweeps remain deferred to Phase B.
