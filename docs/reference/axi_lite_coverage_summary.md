# AXI-Lite Coverage Summary

This is directed protocol coverage for the optional AXI-Lite CSR bridge. It is separate from chiplet functional closure and is not commercial AXI VIP signoff.

| Metric | Value |
| --- | ---: |
| Bench status | PASS |
| Coverage points hit | 18 / 18 |
| Protocol assertions | 6 |
| Assertion failures | 0 |

| Coverage point | Hit |
| --- | ---: |
| `basic_rw` | yes |
| `doorbell` | yes |
| `write_simultaneous` | yes |
| `write_aw_first` | yes |
| `write_w_first` | yes |
| `back_to_back` | yes |
| `b_backpressure` | yes |
| `r_backpressure` | yes |
| `write_wait_state` | yes |
| `read_wait_state` | yes |
| `partial_wstrb_slverr` | yes |
| `out_of_range_slverr` | yes |
| `unaligned_slverr` | yes |
| `read_while_write_pending` | yes |
| `reset_pending_write` | yes |
| `reset_pending_read` | yes |
| `resp_okay` | yes |
| `resp_slverr` | yes |

- Run log: `chiplet_extension/build/optional_benches/axi_lite/run.log`
