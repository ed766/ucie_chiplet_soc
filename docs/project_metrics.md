# Project Metrics

This is the single resume-facing metrics snapshot for the chiplet project. It is generated from the canonical CSV reports by `make -C chiplet_extension project-metrics`.

| Metric | Value | Note |
| --- | --- | --- |
| `stable_runs` | `70 / 70` | Default stable/closure regression rows meeting expectation. |
| `nominal_pass_rate` | `65 / 65` | Expected-pass rows with PASS status. |
| `randomized_stable_runs` | `1 / 1` | Randomized rows inside the stable gate. |
| `expected_bug_failures` | `5 / 5` | Expected-fail bug-validation rows that failed as intended. |
| `dma_nominal_runs` | `19 / 19` | Expected-pass DMA rows. |
| `memory_nominal_runs` | `15 / 15` | Expected-pass memory rows. |
| `functional_coverage` | `60 / 60` | Flat closure bins, 100.0% covered. |
| `low_power_proxy_targets` | `26 / 26` | Low-power proxy rows; aggregate targets: 4/4, 6/6, 4/4, 4/4, 4/4, 5/5, 12/12, 12/12, 4/4. |
| `cross_coverage_groups` | `8 / 8` | Grouped cross-evidence derived from flat coverage metrics. |
| `true_cross_groups` | `10 / 10` | Interaction-level cross evidence when generated. |
| `bounded_property_checks` | `9 / 9` | Nominal and expected-fail bounded assertion harnesses. |
| `negative_tests` | `9 / 9` | Illegal-operation tests with explicit expected response. |
| `optional_random_stress_subset` | `30 / 30 valid; 10 schema-rejected` | Optional seeded-random execution subset; not part of default closure. |
| `assertion_inventory` | `52` | Inventoried protocol/control invariants. |
| `axi_lite_protocol_coverage` | `18 / 18` | Optional AXI-Lite CSR wrapper directed protocol coverage. |
| `axi_lite_optional_bench` | `PASS` | AXI-Lite optional bench status. |
| `firmware_soc_scenarios` | `12 / 12` | ROM-backed RV32 programs controlling DMA through APB MMIO. |
| `firmware_mmio_coverage` | `30 / 30` | Firmware/MMIO protocol and scenario coverage points. |
| `firmware_outcome_crosses` | `7 / 7` | Firmware outcome, power-state, and wait-state interaction crosses. |
| `firmware_focused_code_coverage` | `86.62%` | Focused Verilator line coverage for RV32/APB/ROM integration RTL. |
| `optional_collateral_code_coverage` | `100.00%` | Verilator line coverage for optional AXI/CDC collateral RTL. |

## Claim Boundary

- `stable_runs`, `functional_coverage`, `low_power_proxy_targets`, `bounded_property_checks`, `firmware_soc_scenarios`, and `expected_bug_failures` are the core evidence set.
- `optional_random_stress_subset`, UVM artifacts, and characterization reports are useful supporting evidence, but they are not the default closure gate.
- Raw per-test CSVs are generated artifacts; the checked-in project should keep summaries and curated documentation instead.
