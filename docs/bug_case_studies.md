# Bug Case Studies — UCIe Chiplet DV

## 1. Credit Accounting Bug Injection

### Bug mode

- `UCIE_BUG_CREDIT_OFF_BY_ONE`

### What the DV flow proves

- `bug_credit_off_by_one` compiles with `-DUCIE_BUG_CREDIT_OFF_BY_ONE`
- `credit_checker.sv` fires
- the parser classifies the failure as `credit_assertion`
- the failure-summary script buckets it as `credit_accounting`

### Why this matters

This is direct evidence that the project is doing real protocol checking rather
than only reporting clean nominal smoke tests.

## 2. CRC Polynomial Bug Injection

### Bug mode

- `UCIE_BUG_CRC_POLY`

### What the DV flow proves

- `bug_crc_poly` compiles with `-DUCIE_BUG_CRC_POLY`
- the receive-side CRC path flags the corrupted polynomial behavior
- the parser classifies the issue as `crc_integrity`
- the failure bucket is `crc_integrity`

### Why this matters

This shows the environment is sensitive to link-data integrity problems, not
just credit flow or simple control assertions.

## 3. Retry Identity Bug Injection

### Bug mode

- `UCIE_BUG_RETRY_SEQ`

### What the DV flow proves

- `bug_retry_seq` compiles with `-DUCIE_BUG_RETRY_SEQ`
- the retry checker compares the replayed FLIT against the actual adapter send
  trace
- the run fails with `Retry payload mismatch`
- the failure bucket is `retry_identity`

### Why this matters

This is the strongest protocol-oriented bug case in the project because it
shows replay checking is not based on a superficial transmit handshake. The
checker watches the actual resend path.

## 4. Negative End-to-End Datapath Checks

### Tests involved

- `soc_wrong_key`
- `soc_misalign`

### What the DV flow proves

- both tests are expected to pass the regression
- their `detail` field is `negative_check_caught`
- `e2e_mismatch` coverage is hit by those negative scenarios

### Why this matters

The SoC bench is not only a happy-path demo. It also proves the end-to-end
checker can catch intentionally bad reference conditions.

## 5. Stress-Suite Closure Work

### Tests involved

- `prbs_retry_backpressure`
- `prbs_crc_burst_recover`
- `prbs_retry_burst`
- `prbs_crc_storm`
- `prbs_fault_retrain`
- `soc_fault_echo`
- `soc_retry_e2e`
- `soc_rand_mix`

### What the DV flow proves

- these scenarios remain named and runnable
- they are intentionally separated from the default stable gate
- they still generate reproducible logs, CSVs, coverage, and failure buckets

### Why this matters

The project does not hide unfinished closure work. It keeps those tests visible
as explicit next-step verification targets.

