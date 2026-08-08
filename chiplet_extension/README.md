# Chiplet Extension Developer Guide

This directory contains the flagship dual-die subsystem, its verification environments, firmware, power intent, models, and report generators. The portfolio-level architecture and measured results are summarized in the [top-level README](../README.md); this page is the concise build and contributor guide.

## Architecture Boundary

- RV32I/Zicsr firmware controls the DMA through APB MMIO.
- A four-entry submit queue and four-entry completion FIFO manage software-visible work.
- Banked, parity-protected scratchpads feed a behavioral UCIe-style retry link and Die B AES service.
- UPF 4.0 intent describes isolation, retention, switchable domains, and four operating states.
- AXI-Lite is optional CSR-integration collateral; it is not the firmware or payload path.

The implementation is intentionally a verification-focused subsystem. It does not claim UCIe or AXI certification, complete RISC-V privileged compliance, or commercial power, CDC, timing, or formal signoff.

## Quick Start

```bash
# Default non-UVM closure and core documentation
make project-check

# Static UPF intent validation
make upf-check

# Full GCC/ISS and external architectural evidence
make firmware-c-release-check
make firmware-c-coverage

# Supporting methodology lanes
make formal-prove
make async-cdc-check
make uvm-ci
```

Run these commands from `chiplet_extension/`, or prefix them with `make -C chiplet_extension` from the repository root.

## Verification Lanes

| Lane | Primary target | Evidence boundary |
| --- | --- | --- |
| `closure` | Stable procedural SystemVerilog regression, functional coverage, power proxy, and expected bug failures | Default functional gate |
| `firmware-soc-check` | Twelve ROM-backed APB/MMIO programs | Lightweight firmware integration |
| `firmware-c-release-check` | GCC C, repository-local ISS, seeded workloads, ABI/compiler matrix, privileged traps, mutations, Spike, ACT4/Sail, and RVFI formal | Required external tools; separate from chiplet closure |
| `firmware-c-coverage` | Focused RV32/APB/timer/ROM execution coverage | Verilator code-coverage proxy |
| `formal-prove` | Solver-backed safety, covers, and mutation counterexamples | Open-source property evidence |
| `uvm-ci` | Four real UVM phase/TLM/coverage/RAL tests | Supporting methodology evidence, not the default gate |
| `async-cdc-check` | Integrated two-clock ratios and reset skew | Behavioral CDC evidence |
| `upf-check` | UPF structure, supply, isolation, retention, and PST rules | Static intent validation only |

The GCC release target uses `--require` for pinned external tools. Missing or revision-mismatched Spike, ACT4/Sail, or formal dependencies fail the release rather than being counted as a pass.

## Key Targets

```text
chiplet-sim                  fast procedural smoke
regress                      stable non-UVM regression
closure                      stable functional/power/bug gate
power-regress                low-power proxy scenarios
negative-regress             explicit illegal-operation tests
random-stress-run            optional executed seeded stress subset
coverage-edges-check         code-coverage-focused edge scenarios
code-coverage                full chiplet Verilator coverage report
firmware-soc-check           lightweight RV32/APB firmware matrix
firmware-c-check             named GCC/ISS scenarios
firmware-c-closure           directed plus seeded GCC closure
firmware-c-release-check     complete compiled-firmware release gate
privileged-arch-check        misa/mtval/mtvec/MRET scenarios
timer-wfi-check              timer, WFI, priority, and counter checks
rv32-external-tools-install  restore checksum-pinned external tools
rv32-external-iss-check      Spike architectural comparison
rv32-act-check               ACT4/Sail architectural tests
rv32-formal-check            standard and custom RVFI properties
firmware-c-rtl-mutation-check true RTL mutation sensitivity
axi-lite-check               optional AXI-Lite CSR wrapper
cdc-rdc-check                structural and directed CDC/RDC collateral
frontend-quality             lint, synthesis/timing proxies, CDC/RDC summary
project-metrics              regenerate canonical metrics
readme-metrics               refresh the top-level generated snapshot
docs-check                   links, stale claims, and path hygiene
```

## Repository Layout

```text
rtl/             chiplet, DMA, memory, link, power proxy, CDC, and integration RTL
sim/             procedural/UVM benches, agents, monitors, scoreboards, assertions
formal/          bounded and solver-backed harnesses
firmware/        lightweight encoded firmware collateral
firmware_c/      GCC C/assembly, startup code, linker script, and toolchain lock
models/          independent protocol and transaction reference models
scripts/         runners, generators, checkers, and report automation
upf/             tool-neutral IEEE 1801 / UPF 4.0 intent
reports/         curated normalized CSV/Markdown evidence
build/           ignored generated binaries, traces, logs, and coverage databases
```

## Evidence and Documentation

Canonical summaries live under `reports/`; raw logs, ELF files, wave databases, and per-seed traces remain ignored under `build/`. Run `make project-metrics readme-metrics normalize-report-paths docs-check` after refreshing evidence.

Start a review with:

1. [Project metrics](../docs/project_metrics.md)
2. [Verification traceability](../docs/verification_traceability_matrix.md)
3. [Compiled-C and ISS evidence](../docs/reference/compiled_firmware_verification.md)
4. [External RV32 validation](../docs/reference/rv32_external_validation.md)
5. [Power verification](../docs/power_verification_plan.md)
6. [Coverage closure](../docs/coverage_closure_case_study.md)
7. [Formal evidence](../docs/formal_appendix.md)
8. [Documentation index](../docs/README.md)

## Report Hygiene

- Curated reports use repository-relative paths.
- Smoke outputs use smoke-specific filenames and never overwrite closure summaries.
- Functional, interaction, code, power, UVM, formal, and mutation metrics remain separate.
- Raw and reviewed code coverage are both reported; exclusions retain a documented denominator.
- Expected-fail bug rows pass only when the intended checker observes the intended failure.
- Release regeneration must leave documentation and canonical reports reproducible.

## Tooling

The default flow uses Python 3, Verilator, GCC/binutils for `rv32i_zicsr`, and standard Unix build tools. Optional lanes use pinned Verilator/UVM, OSS CAD Suite, Spike, ACT4/Sail, `riscv-formal`, Yosys, and LibreLane. Use the provided install/check targets rather than substituting unreported tool revisions.

For the complete scenario inventory and acceptance policy, use the [verification plan](../docs/verification_plan.md) instead of expanding this developer guide.
