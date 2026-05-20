# Project Metrics

This is the single resume-facing metrics snapshot for the chiplet project. It is generated from the canonical CSV reports by `make -C chiplet_extension project-metrics`.

| Metric | Value | Note |
| --- | --- | --- |
| `stable_runs` | `64 / 64` | Default stable/closure regression rows meeting expectation. |
| `nominal_pass_rate` | `59 / 59` | Expected-pass rows with PASS status. |
| `randomized_stable_runs` | `1 / 1` | Randomized rows inside the stable gate. |
| `expected_bug_failures` | `5 / 5` | Expected-fail bug-validation rows that failed as intended. |
| `dma_nominal_runs` | `19 / 19` | Expected-pass DMA rows. |
| `memory_nominal_runs` | `13 / 13` | Expected-pass memory rows. |
| `functional_coverage` | `60 / 60` | Flat closure bins, 100.0% covered. |
| `low_power_proxy_targets` | `20 / 20` | Low-power proxy rows; aggregate targets: 4/4, 6/6, 4/4, 4/4, 4/4, 5/5. |
| `cross_coverage_groups` | `8 / 8` | Grouped cross-evidence derived from flat coverage metrics. |
| `true_cross_groups` | `NA` | Interaction-level cross evidence when generated. |
| `bounded_property_checks` | `9 / 9` | Nominal and expected-fail bounded assertion harnesses. |
| `negative_tests` | `9 / 9` | Illegal-operation tests with explicit expected response. |
| `optional_random_stress_subset` | `30 / 40` | Optional seeded-random execution subset; not part of default closure. |
| `assertion_inventory` | `31` | Inventoried protocol/control invariants. |

## Claim Boundary

- `stable_runs`, `functional_coverage`, `low_power_proxy_targets`, `bounded_property_checks`, and `expected_bug_failures` are the core evidence set.
- `optional_random_stress_subset`, UVM artifacts, and characterization reports are useful supporting evidence, but they are not the default closure gate.
- Raw per-test CSVs are generated artifacts; the checked-in project should keep summaries and curated documentation instead.
