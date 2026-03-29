# Verification Plan — UCIe Chiplet SoC

## Scope

This plan targets the chiplet extension under `chiplet_extension/` and focuses on
the UCIe-style link, die-to-die protocol behavior, and the AES traffic loop.
The intent is to demonstrate verification discipline for an exploratory design,
not full sign-off closure.

## Features and Plan Items

| Feature | Stimulus | Checkers/Assertions | Coverage | Pass Criteria |
| --- | --- | --- | --- | --- |
| Link bring-up | `tb_ucie_prbs.sv` nominal training; link FSM enabled | `ucie_link_checker.sv`: training completes within `TRAIN_WINDOW` | `link_state_*` bins | Link reaches ACTIVE within window without faults |
| Credit init | `tb_ucie_prbs.sv` startup | `credit_checker.sv`: expected vs. actual credits | `credit_zero/low/mid/high` bins | Credits match model, no underflow |
| Normal traffic | Continuous PRBS and plaintext traffic | `ucie_scoreboard.sv` ordering/loss checks | `latency_*` bins | No mismatches, bounded latency |
| Reordering | N/A (link is in-order; no reorder buffers) | `ucie_scoreboard.sv` FIFO match | N/A | RX flits match TX order |
| Backpressure | Random `flit_rx_ready` toggles | `credit_checker.sv`, link liveness | `backpressure` bin | No send without credit; progress resumes |
| Retry | CRC errors injected, `retry_ctrl` active | `retry_checker.sv`: resend within N cycles | `resend_request` bin | Resend requested and payload matches |
| CRC errors | PHY/channel injection + optional CRC bug | `retry_checker.sv`, depacketizer flags | `crc_error` bin | CRC errors detected; no silent corruption |
| Lane faults | Channel/PHY injects faults | `ucie_link_checker.sv` tolerates faults | `lane_fault` bin | Faults observable, link recovers when possible |
| Reset behavior | `+RESET_MIDFLIGHT` scenario | `ucie_link_checker.sv` (no tx before ready) | link reset bin | Reset drains pipeline and retrains |
| AES correctness | `tb_soc_chiplets.sv` plaintext loop | Independent `aes_ref_pkg` model | `scoreboard_soc_chiplets.csv` | Ciphertext matches reference |
| Negative tests | `+NEG_WRONG_KEY`, `+NEG_MISALIGN` | Reference mismatch detection | mismatch counters | Errors are detected as expected |

## Traceability Table

| Plan Item | Test(s) | Assertions/Checkers | Coverage |
| --- | --- | --- | --- |
| Link bring-up | `tb_ucie_prbs.sv` | `ucie_link_checker.sv` | `coverage_ucie_prbs.csv` (`link_*`) |
| Credit init/backpressure | `tb_ucie_prbs.sv` | `credit_checker.sv` | `coverage_ucie_prbs.csv` (`credit_*`, `backpressure`) |
| Retry/CRC | `tb_ucie_prbs.sv` | `retry_checker.sv` | `coverage_ucie_prbs.csv` (`crc_error`, `resend_request`) |
| Reordering | `tb_ucie_prbs.sv` | `ucie_scoreboard.sv` | N/A |
| AES correctness | `tb_soc_chiplets.sv` | `aes_ref_pkg` scoreboard | `scoreboard_soc_chiplets.csv` |
| Negative tests | `tb_soc_chiplets.sv` with `+NEG_*` | AES mismatch counts | `scoreboard_soc_chiplets.csv` |
| Reset mid-flight | `tb_ucie_prbs.sv +RESET_MIDFLIGHT` | `ucie_link_checker.sv` | `coverage_ucie_prbs.csv` |

## Notes

- Coverage is implemented as counters in `sim/coverage/ucie_coverage.sv` and
  dumped to CSV. This is simulator-agnostic and works with Icarus Verilog.
- Seeded regressions are automated via `make regress`, which emits
  `reports/regress_summary.csv` plus per-run logs and coverage artifacts.
- Bug injection toggles (`UCIE_BUG_*`) intentionally break the RTL to prove
  the checkers and scoreboards catch issues (see `Goal.txt` item 7).
  Example: `make chiplet-sim SIM_TOOL=iverilog SIM_DEFINES='-DUCIE_BUG_CREDIT_OFF_BY_ONE'`.
