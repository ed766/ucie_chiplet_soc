# Bug Case Studies — UCIe Chiplet DV

## 1. Credit Accounting Bug Injection

### Bug mode

- `UCIE_BUG_CREDIT_OFF_BY_ONE`

### Why this case matters

This is the clearest proof that the project is doing real checking instead of
just printing `PASS` banners. The bug perturbs credit accounting in the link
path, and the verification environment is expected to catch it immediately.

### How it is validated

Run:

```bash
python3 chiplet_extension/scripts/run_regression.py --suite bug
```

### Expected observation

- `bug_credit_off_by_one` compiles with `-DUCIE_BUG_CREDIT_OFF_BY_ONE`
- `credit_checker.sv` fires
- the regression parser classifies the result as a failure even though the bench
  aborts before emitting a `DV_RESULT` line
- the failure summary buckets the issue as `credit_accounting`

### Evidence

- Log:
  `chiplet_extension/build/verilator_regression/logs/bug_credit_off_by_one_seed6be68c02.log`
- Summary:
  `chiplet_extension/reports/regress_summary.csv`
- Failure buckets:
  `chiplet_extension/reports/failure_buckets.csv`

### Takeaway

The environment can prove checker sensitivity with a known injected bug, not
just nominal regressions.

## 2. Retry-Stress Failure Bucketing

### Tests involved

- `prbs_retry_burst`
- `prbs_crc_storm`
- `prbs_fault_retrain`

### Why this case matters

These tests are useful because they show the DV flow can also identify and
group non-closure behavior. They are not hidden or silently dropped. They are
kept as exploratory stress tests, and when run they consistently land in the
same failure bucket.

### How to reproduce

```bash
python3 chiplet_extension/scripts/run_regression.py --suite stress
```

### Observed behavior

- the stress runs currently fail with `LINK_PROGRESS_BOUNDED`
- the parser maps those failures to `link_progress`
- the failure-summary script groups them together in one bucket instead of
  leaving them as unrelated raw log files

Representative log:

- `chiplet_extension/build/verilator_regression/logs/prbs_retry_burst.log`

### Takeaway

Even before closure is complete, the project shows verification maturity:

- failures are reproducible
- failures are categorized automatically
- the stable suite stays clean while the stress suite remains available for
  debug and future closure work

## 3. Negative End-to-End Datapath Checks

### Tests involved

- `soc_wrong_key`
- `soc_misalign`

### Why these cases matter

A weak end-to-end bench often only proves that the happy path works. These
negative cases show the SoC bench also proves the checker can catch bad
conditions when it should.

### Observed behavior

- both tests are expected to pass the regression
- their `detail` field is `negative_check_caught`
- `e2e_mismatch` coverage is hit by these negative cases

Evidence:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`

### Takeaway

The full-chiplet bench is not a smoke demo only. It includes purposeful
negative checking and coverage evidence for those conditions.
