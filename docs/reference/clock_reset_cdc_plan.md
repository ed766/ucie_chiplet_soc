# Clock, Reset, CDC, and RDC Plan

The default closure top remains a single-clock behavioral proxy. An optional
`soc_chiplet_async_top` adds genuine two-clock integration evidence with
Gray-pointer asynchronous FIFOs on both serialized die-to-die paths.

## Clock and Reset Domains

| Domain | Clock | Reset | Role | Current implementation |
| --- | --- | --- | --- | --- |
| Chiplet top / Die A / Die B / link proxy | `clk` | `rst_n` | Main behavioral SoC and UCIe-style datapath | Single-clock Verilator model |
| AXI-Lite CSR wrapper | `aclk` | `aresetn` | Optional control-bus integration wrapper | Independent wrapper testbench |
| CDC source example | `clk_src` | `rst_src_n` | Reusable event/source-side CDC collateral | Exercised by `tb_cdc_reset` |
| CDC destination example | `clk_dst` | `rst_dst_n` | Reusable synchronized destination domain | Exercised by `tb_cdc_reset` |
| Die A async integration | `clk_a` | `rst_a_n` | Compute/DMA and A-to-B FIFO writer | `async-cdc-check` |
| Die B async integration | `clk_b` | `rst_b_n` | AES service and B-to-A FIFO writer | `async-cdc-check` |

## Crossing Strategy

| Crossing type | Strategy | RTL collateral | Validation |
| --- | --- | --- | --- |
| Single-bit level control | Two-flop synchronizer | `chiplet_extension/rtl/cdc/cdc_sync_2ff.sv` | `make -C chiplet_extension cdc-rdc-check` |
| Source-domain event pulse | Toggle-based pulse synchronizer | `chiplet_extension/rtl/cdc/cdc_pulse_sync.sv` | `make -C chiplet_extension cdc-rdc-check` |
| Main chiplet datapath | Single-clock proxy model | `soc_chiplet_top.sv` | Existing Verilator closure |
| Optional cross-die payload and return | Gray-pointer asynchronous FIFO in each direction | `async_fifo_gray.sv`, `soc_chiplet_async_top.sv` | four-ratio matrix plus solver property lane |
| Reset release | Per-domain active-low reset sequencing | CDC/RDC testbench and structural report | `frontend-quality` plus `cdc-rdc-check` |

## Crossing Inventory

| Crossing / reset case | Source domain | Destination domain | Expected handling | Evidence |
| --- | --- | --- | --- | --- |
| Single-bit control example | `clk_src` / `rst_src_n` | `clk_dst` / `rst_dst_n` | two-flop level synchronizer | `cdc_sync_2ff`, `tb_cdc_reset` |
| Event pulse example | `clk_src` / `rst_src_n` | `clk_dst` / `rst_dst_n` | toggle-based pulse synchronizer; one destination pulse per source event | `cdc_pulse_sync`, `tb_cdc_reset` |
| Reset-domain release | source and destination reset domains | synchronized outputs | outputs clear during reset and resume without duplicate events | `tb_cdc_reset` |
| Chiplet datapath | top-level behavioral clock | same top-level behavioral clock | no CDC crossing in the default proxy; documented waiver | `soc_chiplet_top`, `cdc_rdc_summary.csv` |

## Reset Assertion / Deassertion Policy

- Resets are active-low and may assert asynchronously in the small CDC/RDC collateral.
- Reset deassertion is verified in the directed CDC/RDC bench under a non-identical source/destination clock ratio.
- Synchronized level and pulse outputs must clear during destination reset.
- A source pulse must not duplicate across destination reset release.
- The main chiplet simulation uses one behavioral clock/reset pair; that is a deliberate proxy-model boundary, not a CDC signoff claim.

## Structural Check

`make -C chiplet_extension frontend-quality` runs `chiplet_extension/scripts/run_frontend_quality.py`, which emits:

- `chiplet_extension/reports/frontend_quality_summary.csv`
- `chiplet_extension/reports/frontend_quality_summary.md`
- `chiplet_extension/reports/cdc_rdc_summary.csv`

The structural checker verifies that the reusable synchronizer modules exist, records reset/clock naming evidence, and documents the valid crossing strategy. It is intentionally pattern-based and is not commercial CDC/RDC signoff.

The generated CDC/RDC CSV includes rows for level synchronization, pulse
synchronization, reset release, a direct async-collateral scan, the single-clock
chiplet datapath, and the documented datapath waiver.

## Directed CDC/RDC Test

`make -C chiplet_extension cdc-rdc-check` compiles `tb_cdc_reset.sv` and checks:

- a two-flop synchronizer propagates asserted and deasserted levels across a destination clock;
- a source pulse produces exactly one destination-domain pulse under the tested clock ratio;
- destination reset clears synchronized outputs.
- reset release does not create a duplicate synchronized event.

## Integrated Multi-Clock Matrix

`make -C chiplet_extension async-cdc-check` runs independent Die A/Die B clock
ratios `1:1`, `5:7`, `3:5`, and `5:2` with staggered reset release. It requires
traffic in both directions, no FIFO overflow, no read-side duplication, and
clean recovery. Results are written to `reports/async_cdc_summary.csv`.

## Design Intent

The asynchronous top is optional collateral and does not replace the canonical
single-clock architecture. This is open-source CDC evidence, not commercial
CDC/RDC signoff.
