# Verification Dashboard

## Regression Snapshot

| Metric | Value |
| --- | ---: |
| Total runs | 16 |
| Runs meeting expectation | 16 |
| Nominal pass rate | 13/13 |
| Randomized runs meeting expectation | 3/3 |
| Unexpected failures | 0 |
| Expected bug-validation failures | 3 |

## Coverage Snapshot

| Metric | Value |
| --- | ---: |
| Covered functional bins | 18/23 |
| Functional coverage percent | 78.3% |

## Bug Validation

| Test | Bug mode | Observed status | Meets expectation | Detail |
| --- | --- | --- | --- | --- |
| `bug_credit_off_by_one` | `UCIE_BUG_CREDIT_OFF_BY_ONE` | FAIL | 1 | credit_assertion |
| `bug_crc_poly` | `UCIE_BUG_CRC_POLY` | FAIL | 1 | crc_integrity |
| `bug_retry_seq` | `UCIE_BUG_RETRY_SEQ` | FAIL | 1 | retry_identity |

## Failure Buckets

| Bucket | Count | Unexpected | Expected |
| --- | ---: | ---: | ---: |
| `crc_integrity` | 1 | 0 | 1 |
| `credit_accounting` | 1 | 0 | 1 |
| `retry_identity` | 1 | 0 | 1 |
