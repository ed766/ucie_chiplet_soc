# Debug Case Study - DMA Retry Recovery

## Scenario

The debug scenario follows a DMA crypto transfer while the UCIe-style link
experiences backpressure and retry pressure. The transaction starts from a
normal DMA submission, launches FLIT traffic, stalls under backpressure,
requests retry, replays the protected FLIT, retires completions, and finally
asserts IRQ while the scoreboard observes the expected destination image.

## Expected Behavior

- DMA submission is accepted only when queue space exists.
- FLIT valid/data stay stable while the link is backpressured.
- Retry request causes replay before new packet retirement.
- Credit count remains bounded.
- Completion is generated once per accepted descriptor.
- IRQ remains asserted while completion/error state is pending.
- Scoreboard passes only after destination memory matches the golden image.

## Observed Failure Class

The representative injected failure class is retry replay identity corruption:
the replayed FLIT does not match the previously transmitted FLIT. In the closed
flow this maps to `UCIE_BUG_RETRY_SEQ`, which fails in the retry-identity
bucket.

## Waveform Evidence

The waveform below is generated deterministically by:

```bash
make -C chiplet_extension dma-retry-waveform
```

![DMA retry debug waveform](/home/esgha/ucie_chiplet_soc/docs/images/dma_retry_waveform.png)

The key debug landmarks are:

- `dma_submit_valid` / `dma_submit_ready`: two accepted descriptors.
- `flit_valid` / `flit_ready`: traffic launches, then stalls under backpressure.
- `retry_req`: retry window opens while traffic is blocked.
- `credit_count`: credits remain bounded through stall/replay.
- `completion_valid` / `completion_status`: completions appear after retry recovery.
- `irq`: remains asserted while completion state is pending.
- `scoreboard_pass`: only rises after the destination image is checked.

## Root Cause Model

The retry bug mode corrupts the replay identity path. The checker does not rely
only on `valid/ready`; it compares the replayed FLIT against the stored transmit
identity. That catches stale or mutated replay data even if the handshake looks
legal.

## Fix Or Validation Result

The nominal design keeps retry identity stable and passes the replay property.
The injected bug mode is expected to fail, proving the checker is sensitive to
the intended failure mode.

## Regression And Coverage Added

- Regression: `bug_retry_seq`
- Bounded property: `ucie_tx_retry_identity`
- Power/traffic stress scenario: `power_traffic_cross_test`
- Coverage evidence: retry, backpressure, CRC/fault, DMA completion, and low-power activity-cross bins remain reported through the generated closure matrix.
