# Verification Dashboard

## Regression Snapshot

| Metric | Value |
| --- | ---: |
| Total runs | 14 |
| Runs meeting expectation | 14 |
| Nominal pass rate | 13/13 |
| Randomized runs meeting expectation | 4/4 |
| Unexpected failures | 0 |
| Expected bug-validation failures | 1 |

## Coverage Snapshot

| Metric | Value |
| --- | ---: |
| Covered functional bins | 11/23 |
| Functional coverage percent | 47.8% |

## Bug Validation

| Test | Bug mode | Observed status | Meets expectation | Detail |
| --- | --- | --- | --- | --- |
| `bug_credit_off_by_one` | `UCIE_BUG_CREDIT_OFF_BY_ONE` | FAIL | 1 | credit_assertion |

## Failure Buckets

| Bucket | Count | Unexpected | Expected |
| --- | ---: | ---: | ---: |
| `credit_accounting` | 1 | 0 | 1 |
