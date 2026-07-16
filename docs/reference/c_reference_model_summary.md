# C Reference Model Summary

The chiplet verification flow keeps the Python DMA/AES golden model for full transaction checking and adds a standalone C reference model for the FLIT CRC datapath.

| Model | Language | Status | Checks | Notes |
| --- | --- | --- | ---: | --- |
| `flit_crc_ref` | C | PASS | 3 | C_REF_RESULT|status=PASS|checks=3|model=flit_crc8 |

This is portable regression collateral, not a DPI dependency.
