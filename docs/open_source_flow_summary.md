# Open-Source Verification and Quality Flow Summary

This project is intentionally built around open-source-accessible tools. The reports below are strong project evidence, but they are not a substitute for commercial simulation, CDC, STA, or UPF signoff.

| Evidence layer | Command | Primary artifact | What it shows | Limitation |
| --- | --- | --- | --- | --- |
| Stable functional verification | `make -C chiplet_extension closure` | `chiplet_extension/reports/regress_summary.csv` | Directed/regression scenarios meet expected pass/fail behavior | Verilator behavioral simulation only |
| Functional coverage | `make -C chiplet_extension closure` | `chiplet_extension/reports/coverage_summary.csv` | Canonical 60-bin feature closure | Project-defined functional model, not commercial coverage DB |
| Low-power proxy coverage | `make -C chiplet_extension power-regress` | `chiplet_extension/reports/power_state_summary.csv` | RUN/SLEEP/DEEP_SLEEP/CRYPTO_ONLY proxy behavior, per-domain switch/isolation coverage, retention, and sequencing coverage | Verilator does not simulate UPF semantics directly |
| Assertions / bounded checks | `make -C chiplet_extension formal-check` | `chiplet_extension/reports/formal_summary.csv` | Bounded property evidence for selected protocol/control invariants | Bounded Verilator harnesses, not full formal proof |
| Solver-backed formal | `make -C chiplet_extension formal-prove` | `chiplet_extension/reports/formal_proof_summary.csv` | Seven unbounded safety proofs, paired covers, and mutation sensitivity using pinned OSS CAD Suite | Focused leaf/contract proofs, not full-chip formal signoff |
| UPF static intent | `make -C chiplet_extension upf-check` | Console output, `chiplet_extension/upf/chiplet_full.upf`, and `chiplet_extension/reports/upf_intent_summary.md` | Tool-neutral UPF 4.0 domains, switches, isolation, retention, PST structure, entrypoints, and sequencing-control binding | Not run through commercial UPF-aware implementation |
| Front-end quality proxy | `make -C chiplet_extension frontend-quality` | `chiplet_extension/reports/frontend_quality_summary.md` | Verilator chiplet lint, bounded Yosys control/link synthesis proxy, and structural CDC/RDC summary; OpenSTA is explicitly skipped when unavailable | Open-source structural proxy, not full-chip synthesis, STA, or CDC signoff |
| Code coverage | `make -C chiplet_extension code-coverage` | `chiplet_extension/reports/code_coverage_summary.md` | Line, branch, raw/reviewed toggle, uncovered-point inventory, and test-contribution evidence | Separate from functional coverage; the reviewed release gate is met at `90.26%` |
| AXI-Lite CSR wrapper | `make -C chiplet_extension axi-lite-check` | `docs/reference/axi_lite_coverage_summary.md` | Directed AXI-Lite protocol/control-bus scenarios, response checks, wait states, reset recovery, and assertions | Optional integration wrapper collateral, not commercial AXI VIP signoff |
| UVM RAL CSR model | `make -C chiplet_extension uvm-ral-smoke` | `docs/uvm_status.md` and optional `uvm_ral_smoke_*` reports | Optional UVM register-model frontdoor access through the AXI-Lite CSR bridge | Requires external UVM-capable Verilator/UVM setup; not default closure |
| Real UVM CI smoke | `make -C chiplet_extension uvm-ci` | `chiplet_extension/reports/uvm_ci_regress_summary.csv` | Four phase/TLM/scoreboard/subscriber/RAL tests pass with zero errors/fatals | Supporting methodology evidence, not the default 60-bin gate |
| Integrated asynchronous CDC | `make -C chiplet_extension async-cdc-check` | `chiplet_extension/reports/async_cdc_summary.csv` | Two Gray-pointer FIFOs across four independent clock-ratio/reset-skew scenarios | Open-source behavioral and focused property evidence, not CDC signoff |
| C reference model | `make -C chiplet_extension c-reference-check` | `chiplet_extension/reports/c_reference_summary.csv` | Independent C CRC model self-test collateral | CRC datapath only; full DMA/AES golden model remains Python |
| RV32 firmware integration | `make -C chiplet_extension firmware-soc-check` | `docs/firmware_soc_verification.md` | Twelve ROM-backed programs cover DMA queueing, IRQ, timeout, parity, retention, APB reset/waits, and completion stalls | Lightweight RV32 subset and behavioral simulation, not production firmware signoff |
| GCC C / RV32 architectural differential | `make -C chiplet_extension firmware-c-closure firmware-c-coverage` | `docs/reference/compiled_firmware_verification.md` | 35 named programs plus 50 deterministic seeded executions, `178 / 178` points, `94 / 94` event-correlated crosses, split code/data images, precise traps/interrupts, APB/DMA checking, independent instruction/memory/CSR state including `mscratch`, `10 / 10` true RTL mutations, `10 / 10` trace-checker self-tests, and native code coverage | Repository-local ISS plus Spike `12 / 12`, ACT4/Sail `45 / 45`, formal `3 / 3`, and external mutation matrix `4 / 4`; not RISC-V certification |
| Firmware integration code coverage | `make -C chiplet_extension firmware-code-coverage` | `chiplet_extension/reports/firmware_code_coverage_summary.md` | Focused RV32/APB/ROM integration line coverage and per-component breakdown | Verilator execution proxy with documented scope, not commercial coverage closure |

## Recommended Review Path

1. Run `make -C chiplet_extension project-check` for core functional, power, assertion, and documentation evidence.
2. Run `make -C chiplet_extension frontend-quality` for lint/CDC/RDC/open-source quality evidence.
3. Run `make -C chiplet_extension code-coverage` when RTL execution coverage is desired.
4. Run `make -C chiplet_extension axi-lite-check` for optional AXI-Lite CSR wrapper protocol evidence.
5. Run `make -C chiplet_extension formal-prove` when the pinned OSS CAD Suite is installed.
6. Run `make -C chiplet_extension uvm-check-env` and `make -C chiplet_extension uvm-ci` only when external UVM tooling is configured.
7. Run `make -C chiplet_extension c-reference-check` for the standalone C reference-model check.
8. Read `docs/verification_traceability_matrix.md` to map features to stimulus, checkers, assertions, and reports.
9. Read `docs/firmware_soc_verification.md` for the CPU-driven end-to-end path.

## Non-Signoff Statement

The flow is designed to be reproducible without proprietary tools. Yosys/OpenSTA results, when available, are quality proxies. UPF is complete declarative intent, but commercial UPF-aware simulation/synthesis/implementation remains out of scope.
