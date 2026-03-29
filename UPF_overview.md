# UPF Overview for ucie_chiplet_soc

This document explains how UPF is used in this repository, where the power intent
files live, and how they connect to the RTL, verification, and intended flows.

## Scope and Key Files

Two layers of power intent exist:

- **Base SoC (single-die reference)**: `ucie_chiplet_soc/base_soc/upf/`
  - `soc.upf` defines domains, supplies, switches, isolation, and retention.
  - `pst.upf` defines the power-state table (PST) and legal state combinations.
- **Chiplet extension (dual-die scaffolding)**: `ucie_chiplet_soc/chiplet_extension/upf/`
  - `die_a.upf`, `die_b.upf` define domain boundaries per die.
  - `pst_chiplet.upf` defines cross-die states.

Supporting RTL and verification hooks that align with the UPF intent:

- Power control FSM and sequencing: `ucie_chiplet_soc/base_soc/rtl/aon/aon_power_ctrl.sv`
- Isolation usage in RTL: `ucie_chiplet_soc/base_soc/rtl/top/soc_top.sv`
- Power sequencing assertions: `ucie_chiplet_soc/base_soc/sim/pwr_assertions.sv`
- PST checks in testbench: `ucie_chiplet_soc/base_soc/sim/tb_soc_top.sv`

## Base SoC UPF (Complete Example)

### Domains and Supplies

`base_soc/upf/soc.upf` establishes three power domains and the supply topology:

- `AON`: always-on domain containing power controller and timer.
- `PD1`: switchable domain containing the RV32 core.
- `PD2`: switchable domain containing AES key/state registers.

Supplies are declared as ports (`VDD`, `VSS`), and power switches create
domain-local supply nets (`VDD_PD1`, `VDD_PD2`) driven by RTL control signals:

- `pd1_sw_en` drives power switch `PS_PD1`.
- `pd2_sw_en` drives power switch `PS_PD2`.

### Isolation Strategy

`soc.upf` sets isolation on PD1/PD2 outputs, clamped to 0, and controlled by
active-low isolation signals (`iso_pd1_n`, `iso_pd2_n`) coming from RTL:

- Isolation is expressed in UPF (`set_isolation`).
- The RTL also instantiates example `iso_cell` modules in
  `base_soc/rtl/top/soc_top.sv` to show where isolation would be inserted and
  to make isolation behavior explicit in simulation.

This dual representation (UPF intent + RTL example cells) is intentional:
UPF remains the source of truth for sign-off tools, while the RTL shows
where the boundaries are for functional simulation and clarity.

### Retention Strategy

`soc.upf` defines retention for AES key registers in `PD2`:

- Retention elements are explicitly identified in UPF.
- Save/restore controls (`save_pd2`, `restore_pd2`) come from the power controller.

### Power-State Table (PST)

`base_soc/upf/pst.upf` describes legal power states and their per-domain values:

- `RUN`: all domains on.
- `SLEEP`: `PD1` off, `PD2` on (retention intended for PD2).
- `CRYPTO_ONLY`: `PD1` off, `PD2` on.
- `DEEP_SLEEP`: `PD1` off, `PD2` off.

The PST aligns with the FSM in `aon_power_ctrl.sv`, which sequences the same
states and generates the corresponding power and isolation controls.

## RTL/UPF Integration Points (Base SoC)

### Power Controller Sequencing

`aon_power_ctrl.sv` is the behavioral source of the power control signals that
the UPF file references:

- Drives `pd1_sw_en` and `pd2_sw_en` for power switches.
- Drives `iso_pd1_n` and `iso_pd2_n` for domain isolation.
- Pulses `save_pd2` before power-down and `restore_pd2` after power-up.
- Implements a PST-style enum (`RUN`, `SLEEP`, `CRYPTO_ONLY`, `DEEP_SLEEP`).

The sequencing logic explicitly orders isolation, save/restore, and power
switching to match common low-power design practice.

### Isolation in RTL

`soc_top.sv` includes example `iso_cell` instances:

- PD2 APB response signals are isolated before they cross into AON.
- A PD1-to-AON signal (`retire`) is isolated as a demonstration.

These cells are illustrative for functional simulation; in real flows the UPF
is used to insert library-specific isolation cells.

### Power-Aware Verification Hooks

Two levels of verification align with UPF intent:

- `base_soc/sim/pwr_assertions.sv` binds assertions to `aon_power_ctrl` to check
  isolation-before-power-off, save/restore ordering, and isolation hold while
  a domain is off.
- `base_soc/sim/tb_soc_top.sv` uses APB writes to move through power states and
  checks that the status reflects the expected PST state transitions.

## Chiplet Extension UPF (Scaffolding)

The chiplet extension mirrors the base SoC structure but intentionally omits
tool-specific details so the dual-die system can be elaborated later:

### Per-Die Domains

- `chiplet_extension/upf/die_a.upf`:
  - `AON_A` (always-on control) and `PD1_RV32` (compute).
  - Minimal supplies (`AON_A_VDD`, `AON_A_VSS`) shared by both domains for now.
- `chiplet_extension/upf/die_b.upf`:
  - `AON_B` (always-on control) and `PD2_AES` (crypto).
  - Minimal supplies (`AON_B_VDD`, `AON_B_VSS`) shared by both domains for now.

These files define the domain boundaries (`die_a_system`, `die_b_system`) and
introduce basic per-domain power states (on/off) without switches, isolation,
or retention.

### Cross-Die PST

`chiplet_extension/upf/pst_chiplet.upf` defines a PST across both dice:

- `RUN`: all domains on.
- `SLEEP`: compute/crypto domains off, always-on domains on.
- `CRYPTO_ONLY`: only crypto die on.
- `DEEP_SLEEP`: all domains off.

This PST describes the intended joint operating modes and provides the entry
point for tool-based power intent checks once real supplies and switches are
added.

## Techniques and Methods Used

- **Domain partitioning**: Always-on control logic is separated from compute
  and crypto blocks so low-power states can gate large blocks safely.
- **Power switching**: UPF `create_power_switch` is used in the base SoC to
  define explicit switch control points driven by RTL.
- **Isolation**: UPF `set_isolation` describes clamping behavior; RTL instantiates
  example `iso_cell` modules to make the boundaries visible in simulation.
- **Retention**: UPF `set_retention` captures which flops should preserve state
  and how save/restore is controlled.
- **PST-driven intent**: Both base SoC and chiplet extension use PST files to
  formalize legal operating modes and to align RTL sequencing with UPF intent.

## How to Extend the Chiplet UPF

If you want the chiplet extension to be power-aware in the same way as the
base SoC, these are the typical next steps:

1. **Define real supplies and power switches per die**
   - Add `create_supply_net` and `connect_supply_net`.
   - Use `create_power_switch` with die-local control signals.
2. **Add isolation for cross-die and cross-domain signals**
   - Specify `set_isolation` in UPF.
   - Map isolation controls to die-local AON logic.
3. **Add retention for crypto keys or state that must survive sleep**
   - Use `set_retention` for key flops and AES state.
4. **Align RTL sequencing with PST**
   - Implement or mirror the base SoC `aon_power_ctrl` style sequencing per die.
5. **Power-aware verification**
   - Bind assertions (similar to `pwr_assertions.sv`) to ensure ordering.
   - Add tests that toggle PST states and verify isolation/retention behavior.

## Practical Notes

- The base SoC UPF is the canonical example for real sign-off intent.
- The chiplet UPF is intentionally minimal; it documents intent but does not
  yet drive tool-specific insertion or verification.
- When moving to sign-off, keep UPF as the single source of truth and avoid
  hard-coding power behavior in RTL (beyond example cells for simulation).
