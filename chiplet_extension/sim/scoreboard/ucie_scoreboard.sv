`timescale 1ns/1ps
`include "scoreboard/ucie_txn.svh"

module ucie_scoreboard #(
    parameter int DEPTH       = 128,
    parameter int LATENCY_MAX = 128
) (
    input  logic      clk,
    input  logic      rst_n,
    input  logic      tx_valid,
    input  ucie_txn_t tx_txn,
    input  logic      rx_valid,
    input  ucie_txn_t rx_txn,
    output logic      latency_valid,
    output logic [15:0] latency_value,
    output int unsigned tx_count,
    output int unsigned rx_count,
    output int unsigned mismatch_count,
    output int unsigned drop_count,
    output int unsigned retry_count,
    output int unsigned latency_violation_count
);

    ucie_txn_t fifo_payload [0:DEPTH-1];
    int unsigned head_q, tail_q, count_q;
    ucie_txn_t last_txn_q;
    logic have_last_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head_q <= 0;
            tail_q <= 0;
            count_q <= 0;
            last_txn_q <= '0;
            have_last_q <= 1'b0;
            tx_count <= 0;
            rx_count <= 0;
            mismatch_count <= 0;
            drop_count <= 0;
            retry_count <= 0;
            latency_violation_count <= 0;
            latency_valid <= 1'b0;
            latency_value <= '0;
        end else begin
            latency_valid <= 1'b0;

            if (tx_valid) begin
                tx_count <= tx_count + 1;
                if (tx_txn.retry_count != 0) begin
                    retry_count <= retry_count + 1;
                    if (!have_last_q ||
                        tx_txn.seq_id != last_txn_q.seq_id ||
                        tx_txn.payload !== last_txn_q.payload ||
                        tx_txn.crc !== last_txn_q.crc) begin
                        mismatch_count <= mismatch_count + 1;
                    end
                end else begin
                    last_txn_q <= tx_txn;
                    have_last_q <= 1'b1;
                    if (count_q < DEPTH) begin
                        fifo_payload[tail_q] <= tx_txn;
                        tail_q <= (tail_q + 1) % DEPTH;
                        count_q <= count_q + 1;
                    end else begin
                        drop_count <= drop_count + 1;
                    end
                end
            end

            if (rx_valid) begin
                rx_count <= rx_count + 1;
                if (count_q == 0) begin
                    drop_count <= drop_count + 1;
                end else begin
                    logic [31:0] latency_calc;
                    if (rx_txn.payload !== fifo_payload[head_q].payload ||
                        rx_txn.crc !== fifo_payload[head_q].crc) begin
                        mismatch_count <= mismatch_count + 1;
                    end
                    latency_calc = rx_txn.timestamp - fifo_payload[head_q].timestamp;
                    latency_value <= latency_calc[15:0];
                    latency_valid <= 1'b1;
                    if (latency_calc > LATENCY_MAX) begin
                        latency_violation_count <= latency_violation_count + 1;
                    end
                    head_q <= (head_q + 1) % DEPTH;
                    count_q <= count_q - 1;
                end
            end
        end
    end

    task automatic write_report(input string path);
        int fd;
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $display("Failed to open scoreboard report file: %s", path);
            return;
        end
        $fdisplay(fd, "metric,value");
        $fdisplay(fd, "tx_count,%0d", tx_count);
        $fdisplay(fd, "rx_count,%0d", rx_count);
        $fdisplay(fd, "mismatch_count,%0d", mismatch_count);
        $fdisplay(fd, "drop_count,%0d", drop_count);
        $fdisplay(fd, "retry_count,%0d", retry_count);
        $fdisplay(fd, "latency_violation_count,%0d", latency_violation_count);
        $fclose(fd);
    endtask

endmodule : ucie_scoreboard
