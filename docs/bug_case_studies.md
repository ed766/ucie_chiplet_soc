# Bug Case Studies - UCIe Chiplet DV

The project uses injected failures to prove that the checkers are real. These
case studies are the easiest way to explain the value of the DV environment in
an interview or on a project page.

```mermaid
flowchart LR
    A["Named test or bug mode"] --> B["DUT behavior"]
    B --> C["Passive monitor / scoreboard / assertion"]
    C --> D["Machine-readable result line"]
    D --> E["Failure bucket + dashboard"]
```

## 1. Credit Accounting Bug Injection

### Bug mode

- `UCIE_BUG_CREDIT_OFF_BY_ONE`

### What the DV flow proves

- `bug_credit_off_by_one` compiles with `-DUCIE_BUG_CREDIT_OFF_BY_ONE`
- `credit_checker.sv` fires
- the parser classifies the failure as `credit_assertion`
- the failure-summary script buckets it as `credit_accounting`

### Why this matters

This is direct evidence that the project is doing protocol checking rather than
only reporting clean nominal smoke tests.

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
- the run fails with a retry identity mismatch
- the failure bucket is `retry_identity`

### Why this matters

This is the strongest protocol-oriented bug case in the project because it
shows replay checking is not based on a superficial transmit handshake. The
checker watches the actual resend path.

## 4. Negative End-to-End Datapath Checks

### Tests involved

- `soc_wrong_key`
- `soc_misalign`
- `soc_expected_empty`

### What the DV flow proves

- the tests are expected to pass the regression because the checkers detect the
  bad scenario correctly
- `soc_wrong_key` and `soc_misalign` hit the end-to-end mismatch coverage
- `soc_expected_empty` proves the bench can detect a deliberate
  reference-underflow condition

### Why this matters

The SoC bench is not only a happy-path demo. It also proves the end-to-end
checker can catch intentionally bad reference conditions.

## 5. DMA Offload Bug Injection

### Bug mode

- `UCIE_BUG_DMA_DONE_EARLY`

### What the DV flow proves

- `dma_bug_done_early` compiles with `-DUCIE_BUG_DMA_DONE_EARLY`
- the DMA controller reports completion before the last destination write
- the destination scratchpad compare detects the stale ciphertext image
- the failure bucket is `dma_completion`

### Why this matters

This case study is the clearest proof that the new CSR-programmable DMA
offload path is being checked independently, not just exercised nominally.

## 6. What The Case Studies Say About The Project

The bug cases show that the environment has real verification depth:

- credit accounting is checked
- CRC corruption is observable
- retry identity is preserved
- SoC-level reference checks are file-backed and independent
- DMA completion is validated against a golden destination image and an IRQ
  completion path

That combination is much more persuasive on a resume than a bench that only
prints `PASS` on nominal smoke.
