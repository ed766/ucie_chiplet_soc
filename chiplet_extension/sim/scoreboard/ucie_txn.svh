`ifndef UCIE_TXN_SVH
`define UCIE_TXN_SVH

`include "tb_params.svh"

`ifndef UCIE_TXN_FLIT_WIDTH
`define UCIE_TXN_FLIT_WIDTH `TB_FLIT_WIDTH
`endif

`ifndef UCIE_TXN_CRC_WIDTH
`define UCIE_TXN_CRC_WIDTH 8
`endif

typedef struct packed {
    logic [15:0] seq_id;
    logic [7:0]  retry_count;
    logic [31:0] timestamp;
    logic [`UCIE_TXN_FLIT_WIDTH-`UCIE_TXN_CRC_WIDTH-1:0] payload;
    logic [`UCIE_TXN_CRC_WIDTH-1:0] crc;
} ucie_txn_t;

`endif // UCIE_TXN_SVH
