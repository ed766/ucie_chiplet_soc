# Front-End Quality Summary

This report is an open-source front-end quality proxy. It is not commercial lint, CDC, STA, or signoff evidence.

| Check | Status | Details |
| --- | --- | --- |
| verilator_lint | PASS | chiplet RTL lint |
| yosys_synthesis | PASS | control/link synthesizable-subset proxy stat |
| opensta_timing | SKIP | opensta_not_found |
| cdc_rdc_structural | PASS | sync_2ff_defs=1; pulse_sync_defs=1; async_fifo_defs=1; clocks=clk,clk_dst,clk_src,lane_clk; resets=aresetn,rst_dst_n,rst_n,rst_src_n |

## CDC/RDC Structural Summary

| Crossing | Strategy | Evidence | Status |
| --- | --- | --- | --- |
| single_bit_control | cdc_sync_2ff | rtl/cdc/cdc_sync_2ff.sv | PASS |
| event_pulse | cdc_pulse_sync | rtl/cdc/cdc_pulse_sync.sv | PASS |
| reset_release | per-domain active-low reset release tested under clock-ratio variation | sim/tb_cdc_reset.sv | PASS |
| direct_async_scan | pattern scan for known CDC collateral and clock/reset naming | frontend_quality_summary.md plus cdc_rdc_summary.csv | PASS |
| chiplet_datapath | single_clock_proxy_model | soc_chiplet_top uses one behavioral clock in default simulation | PASS |
| chiplet_datapath_waiver | documented waiver: no asynchronous die-to-die clock crossing in this behavioral proxy | docs/reference/clock_reset_cdc_plan.md | WAIVED |

## Interpretation

- Verilator lint is the required local front-end syntax/lint gate.
- Yosys and OpenSTA are reported as available/skipped depending on the local open-source installation.
- CDC/RDC checking is structural and pattern-based; it documents synchronizer strategy and obvious missing collateral, not metastability signoff.
