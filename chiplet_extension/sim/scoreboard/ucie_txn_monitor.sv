`timescale 1ns/1ps
`include "scoreboard/ucie_txn.svh"

module ucie_txn_monitor_tx (
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          flit_valid,
    input  logic                          flit_ready,
    input  logic [`UCIE_TXN_FLIT_WIDTH-1:0] flit_data,
    input  logic                          resend_request,
    output logic                          txn_valid,
    output ucie_txn_t                     txn
);

    localparam int PAYLOAD_WIDTH = `UCIE_TXN_FLIT_WIDTH - `UCIE_TXN_CRC_WIDTH;

    logic [31:0] cycle_q;
    logic [15:0] seq_id_q;
    logic [15:0] last_seq_q;
    logic [7:0]  retry_count_q;
    logic        expect_resend_q;

    logic [15:0] seq_id_d;
    logic [15:0] last_seq_d;
    logic [7:0]  retry_count_d;
    logic        expect_resend_d;

    logic [PAYLOAD_WIDTH-1:0]          payload;
    logic [`UCIE_TXN_CRC_WIDTH-1:0]    crc;
    logic                             flit_fire;
    logic                             expect_resend_now;

    assign payload = flit_data[PAYLOAD_WIDTH-1:0];
    assign crc     = flit_data[`UCIE_TXN_FLIT_WIDTH-1 -: `UCIE_TXN_CRC_WIDTH];
    assign flit_fire = flit_valid && flit_ready;
    assign expect_resend_now = expect_resend_q || resend_request;

    always_comb begin
        txn = '0;
        txn_valid = flit_fire;
        if (flit_fire) begin
            txn.payload   = payload;
            txn.crc       = crc;
            txn.timestamp = cycle_q;
            if (expect_resend_now) begin
                txn.seq_id      = last_seq_q;
                txn.retry_count = retry_count_q + 1'b1;
            end else begin
                txn.seq_id      = seq_id_q;
                txn.retry_count = 0;
            end
        end
    end

    always_comb begin
        seq_id_d = seq_id_q;
        last_seq_d = last_seq_q;
        retry_count_d = retry_count_q;
        expect_resend_d = expect_resend_q;

        if (resend_request) begin
            expect_resend_d = 1'b1;
        end

        if (flit_fire) begin
            if (expect_resend_d) begin
                retry_count_d = retry_count_q + 1'b1;
                expect_resend_d = 1'b0;
            end else begin
                last_seq_d = seq_id_q;
                seq_id_d = seq_id_q + 1'b1;
                retry_count_d = 0;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_q <= 0;
            seq_id_q <= 0;
            last_seq_q <= 0;
            retry_count_q <= 0;
            expect_resend_q <= 1'b0;
        end else begin
            cycle_q <= cycle_q + 1'b1;
            seq_id_q <= seq_id_d;
            last_seq_q <= last_seq_d;
            retry_count_q <= retry_count_d;
            expect_resend_q <= expect_resend_d;
        end
    end

endmodule : ucie_txn_monitor_tx

module ucie_txn_monitor_rx (
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          flit_valid,
    input  logic                          flit_ready,
    input  logic [`UCIE_TXN_FLIT_WIDTH-1:0] flit_data,
    output logic                          txn_valid,
    output ucie_txn_t                     txn
);

    localparam int PAYLOAD_WIDTH = `UCIE_TXN_FLIT_WIDTH - `UCIE_TXN_CRC_WIDTH;

    logic [31:0] cycle_q;
    logic [15:0] seq_id_q;
    logic [PAYLOAD_WIDTH-1:0]          payload;
    logic [`UCIE_TXN_CRC_WIDTH-1:0]    crc;
    logic                             flit_fire;

    assign payload = flit_data[PAYLOAD_WIDTH-1:0];
    assign crc     = flit_data[`UCIE_TXN_FLIT_WIDTH-1 -: `UCIE_TXN_CRC_WIDTH];
    assign flit_fire = flit_valid && flit_ready;

    always_comb begin
        txn = '0;
        txn_valid = flit_fire;
        if (flit_fire) begin
            txn.seq_id      = seq_id_q;
            txn.retry_count = 0;
            txn.payload     = payload;
            txn.crc         = crc;
            txn.timestamp   = cycle_q;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_q <= 0;
            seq_id_q <= 0;
        end else begin
            cycle_q <= cycle_q + 1'b1;
            if (flit_fire) begin
                seq_id_q <= seq_id_q + 1'b1;
            end
        end
    end

endmodule : ucie_txn_monitor_rx
