# Seeded-Random Stress Summary

This report summarizes optional bounded seeded-random collateral. These generated scenarios are not part of the default stable regression or the canonical `60 / 60` closure gate.

- Total generated scenarios: 100
- Reproduction model: every scenario row records a deterministic seed plus the randomized knob values.
- Constraint model: generated rows are schema-checked before execution; valid rows are translated into concrete runtime plusargs.
- Representative probes validate that each family is runnable without promoting all generated scenarios into default closure.
- The optional execution matrix runs a bounded 25/10/5 subset and writes `chiplet_extension/reports/random_stress_regress_summary.csv`.

## Randomized Knobs

- DMA length
- source/destination banks
- queue pressure
- backpressure duration
- CRC fault insertion point
- lane fault type
- power transition timing
- AES block count
- parity injection
- timeout profile
- retry window

## Families

| Family | Expected scenarios | Generated scenarios | Seed preview | Representative validation | Executed subset |
| --- | ---: | ---: | --- | --- | --- |
| `random_smoke_25` (Random smoke) | 25 | 25 | `217151502`, `2137757239`, `1493581428`, `1896444131`, `294960135` | 1/1 representative probe rows met expectation | 25/25 valid executed rows met expectation; 25/25 valid rows applied manifest plusargs |
| `stress_retry_50` (Retry/backpressure stress) | 50 | 50 | `1252224366`, `1418248492`, `1368639711`, `1489067733`, `1600501735` | 1/1 representative probe rows met expectation | 10/10 valid executed rows met expectation; 10/10 valid rows applied manifest plusargs |
| `power_dma_cross_25` (Power/DMA cross stress) | 25 | 25 | `1261443206`, `864048886`, `1871676756`, `598393866`, `323884011` | 1/1 representative probe rows met expectation | 5/5 valid executed rows met expectation; 5/5 valid rows applied manifest plusargs |

## Reproduce By Seed

1. Regenerate a family manifest with `make -C chiplet_extension random-smoke-25`, `make -C chiplet_extension stress-retry-50`, or `make -C chiplet_extension power-dma-cross-25`.
2. Select the desired `seed` and knob row from the corresponding manifest in `chiplet_extension/reports/`.
3. Run the representative test listed in the manifest, preserving the seed and knob metadata in the log or bug report.
4. To regenerate the bounded executed subset, run `make -C chiplet_extension random-stress-run` followed by `make -C chiplet_extension random-stress-summary`.

## Claim Boundary

- Safe claim: directed and seeded-random testing are both used.
- Stronger claim supported by this collateral: bounded seeded-random stress generation creates 100 reproducible scenarios across DMA, retry/backpressure, parity, and power-transition timing.
- This is optional stress evidence; the closure source of truth remains `coverage_summary.csv` and `coverage_closure_matrix.md`.
