# Protocol Characterization

These measurements come from the behavioral Verilator PRBS bench, so they are
verification-oriented characterizations rather than silicon sign-off numbers.
They complement the DMA offload verification added in `chiplet_extension/`
without trying to replace it.

## Latency vs Channel Delay

| Label | Delay cycles | Avg latency | Min | Max | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `delay_0` | 0 | 41 | 41 | 41 | PASS |
| `delay_10` | 10 | 51 | 51 | 51 | PASS |
| `delay_20` | 20 | 61 | 61 | 61 | PASS |

## Throughput vs Backpressure

| Label | Backpressure modulus | Backpressure hits | Throughput (rx/sample_cycles) | Avg latency | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `bp_mod_16` | 16 | 4131 | 0.0292 | 41 | PASS |
| `bp_mod_8` | 8 | 4131 | 0.0292 | 41 | PASS |
| `bp_mod_4` | 4 | 4131 | 0.0292 | 41 | PASS |
| `bp_mod_2` | 2 | 4131 | 0.0292 | 41 | PASS |

## Retry Rate vs Fault Density Proxy

| Label | CRC spacing | Retries | Retry rate (retry/tx) | CRC hits | Resend hits | Status |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `crc_spacing_24` | 24 | 2 | 0.0250 | 12 | 12 | PASS |
| `crc_spacing_16` | 16 | 2 | 0.0250 | 12 | 12 | PASS |
| `crc_spacing_8` | 8 | 2 | 0.0250 | 12 | 12 | PASS |

## Notes

- The latency sweep uses the receive-path channel-delay shim in `tb_ucie_prbs.sv`.
- The retry-density sweep uses CRC spacing as a deterministic fault-density proxy.
- In this behavioral model, the backpressure sweep is more visible in backpressure-hit counts and latency buckets than in raw throughput.
- These runs intentionally reuse the named tests and scoreboards already used by the regression flow.
