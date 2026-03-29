`timescale 1ns/1ps
`include "tb_params.svh"
`include "sva_macros.svh"
`include "models/aes_ref_pkg.sv"
`include "checkers/credit_checker.sv"
`include "checkers/retry_checker.sv"
`include "checkers/ucie_link_checker.sv"
`include "scoreboard/ucie_txn.svh"
`include "scoreboard/ucie_txn_monitor.sv"
`include "scoreboard/ucie_scoreboard.sv"
`include "coverage/ucie_coverage.sv"

module tb_soc_chiplets;

    localparam int DATA_WIDTH = `TB_DATA_WIDTH;
    localparam int BLOCK_WIDTH = 128;
    localparam int WORDS_PER_BLOCK = BLOCK_WIDTH / DATA_WIDTH;
    localparam logic [127:0] AES_KEY = 128'h00112233445566778899aabbccddeeff;
    localparam int EXPECT_FIFO_DEPTH = 64;

    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
    end

    logic [DATA_WIDTH-1:0] plaintext_monitor;
    logic [DATA_WIDTH-1:0] ciphertext_monitor;
    logic [DATA_WIDTH-1:0] die_b_ciphertext_monitor;
    logic                   crypto_error_flag;

    soc_chiplet_top #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_chiplet (
        .clk                       (clk),
        .rst_n                     (rst_n),
        .plaintext_monitor         (plaintext_monitor),
        .ciphertext_monitor        (ciphertext_monitor),
        .die_b_ciphertext_monitor  (die_b_ciphertext_monitor),
        .crypto_error_flag         (crypto_error_flag)
    );

    // Independent AES reference scoreboard (not shared with DUT).
    logic [BLOCK_WIDTH-1:0] plain_block_q;
    int unsigned            plain_word_count_q;
    logic [DATA_WIDTH-1:0] expected_fifo [0:EXPECT_FIFO_DEPTH-1];
    int unsigned            exp_head_q;
    int unsigned            exp_tail_q;
    int unsigned            exp_count_q;

    int unsigned cipher_updates;
    int unsigned mismatch_count;
    int unsigned expected_empty_count;

    logic wrong_key_mode;
    logic misalign_mode;
    string cov_path;
    string score_path;

    initial begin
        wrong_key_mode = $test$plusargs("NEG_WRONG_KEY");
        misalign_mode  = $test$plusargs("NEG_MISALIGN");
        cov_path = "reports/coverage_soc_chiplets.csv";
        score_path = "reports/scoreboard_soc_chiplets.csv";
        void'($value$plusargs("COV_OUT=%s", cov_path));
        void'($value$plusargs("SCORE_OUT=%s", score_path));
    end

    // Internal handshake signals from Die A stream interface.
    wire tx_fire = u_chiplet.u_die_a.tx_stream_valid && u_chiplet.u_die_a.tx_stream_ready;
    wire rx_fire = u_chiplet.u_die_a.rx_stream_valid && u_chiplet.u_die_a.rx_stream_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            plain_block_q       <= '0;
            plain_word_count_q  <= 0;
            exp_head_q          <= 0;
            exp_tail_q          <= 0;
            exp_count_q         <= 0;
            cipher_updates      <= 0;
            mismatch_count      <= 0;
            expected_empty_count<= 0;
            for (int idx = 0; idx < EXPECT_FIFO_DEPTH; idx++) begin
                expected_fifo[idx] <= '0;
            end
        end else begin
            if (tx_fire) begin
                int insert_idx;
                logic [BLOCK_WIDTH-1:0] block_next;
                insert_idx = misalign_mode ? ((plain_word_count_q + 1) % WORDS_PER_BLOCK) : plain_word_count_q;
                block_next = plain_block_q;
                block_next[DATA_WIDTH*insert_idx +: DATA_WIDTH] = u_chiplet.u_die_a.tx_stream_data;
                plain_block_q <= block_next;
                if (plain_word_count_q == WORDS_PER_BLOCK-1) begin
                    logic [127:0] ref_key;
                    logic [127:0] cipher_block;
                    ref_key = wrong_key_mode ? 128'h0 : AES_KEY;
                    cipher_block = aes_ref_pkg::aes_encrypt(ref_key, block_next);
                    for (int i = 0; i < WORDS_PER_BLOCK; i++) begin
                        expected_fifo[(exp_tail_q + i) % EXPECT_FIFO_DEPTH] <= cipher_block[DATA_WIDTH*i +: DATA_WIDTH];
                    end
                    exp_tail_q <= (exp_tail_q + WORDS_PER_BLOCK) % EXPECT_FIFO_DEPTH;
                    exp_count_q <= exp_count_q + WORDS_PER_BLOCK;
                    plain_word_count_q <= 0;
                end else begin
                    plain_word_count_q <= plain_word_count_q + 1;
                end
            end

            if (rx_fire) begin
                cipher_updates <= cipher_updates + 1;
                if (exp_count_q == 0) begin
                    expected_empty_count <= expected_empty_count + 1;
                end else begin
                    logic [DATA_WIDTH-1:0] expected_word;
                    expected_word = expected_fifo[exp_head_q];
                    if (u_chiplet.u_die_a.rx_stream_data !== expected_word) begin
                        mismatch_count <= mismatch_count + 1;
                    end
                    exp_head_q <= (exp_head_q + 1) % EXPECT_FIFO_DEPTH;
                    exp_count_q <= exp_count_q - 1;
                end
            end
        end
    end

    // Link-level scoreboard using FLIT handshakes between Die A and Die B.
    logic latency_valid;
    logic [15:0] latency_value;
    int unsigned tx_count;
    int unsigned rx_count;
    int unsigned flit_mismatch_count;
    int unsigned flit_drop_count;
    int unsigned retry_count;
    int unsigned latency_violation_count;
    ucie_txn_t tx_txn;
    ucie_txn_t rx_txn;
    logic tx_txn_valid;
    logic rx_txn_valid;

    ucie_txn_monitor_tx u_txn_mon_tx (
        .clk           (clk),
        .rst_n         (rst_n),
        .flit_valid    (u_chiplet.u_die_a.flit_tx_valid),
        .flit_ready    (u_chiplet.u_die_a.flit_tx_ready),
        .flit_data     (u_chiplet.u_die_a.flit_tx_payload),
        .resend_request(u_chiplet.u_die_a.resend_request),
        .txn_valid     (tx_txn_valid),
        .txn           (tx_txn)
    );

    ucie_txn_monitor_rx u_txn_mon_rx (
        .clk        (clk),
        .rst_n      (rst_n),
        .flit_valid (u_chiplet.u_die_b.flit_rx_valid),
        .flit_ready (u_chiplet.u_die_b.flit_rx_ready),
        .flit_data  (u_chiplet.u_die_b.flit_rx_payload),
        .txn_valid  (rx_txn_valid),
        .txn        (rx_txn)
    );

    ucie_scoreboard #(
        .LATENCY_MAX (`TB_MAX_LATENCY)
    ) u_flit_scoreboard (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .tx_valid                (tx_txn_valid),
        .tx_txn                  (tx_txn),
        .rx_valid                (rx_txn_valid),
        .rx_txn                  (rx_txn),
        .latency_valid           (latency_valid),
        .latency_value           (latency_value),
        .tx_count                (tx_count),
        .rx_count                (rx_count),
        .mismatch_count          (flit_mismatch_count),
        .drop_count              (flit_drop_count),
        .retry_count             (retry_count),
        .latency_violation_count (latency_violation_count)
    );

    ucie_coverage #(
        .CREDIT_MAX  (256),
        .LATENCY_LOW (4),
        .LATENCY_HIGH(16)
    ) u_cov (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .link_state              (u_chiplet.u_die_a.u_link_fsm.state_q),
        .credit_available        (u_chiplet.u_die_a.credit_available),
        .backpressure            (u_chiplet.u_die_a.flit_tx_valid && !u_chiplet.u_die_a.flit_tx_ready),
        .crc_error               (u_chiplet.u_die_a.depacketizer_crc_error),
        .resend_request          (u_chiplet.u_die_a.resend_request),
        .lane_fault              (u_chiplet.u_die_a.lane_adapter_lane_fault),
        .error_during_backpressure(u_chiplet.u_die_a.depacketizer_crc_error && (u_chiplet.u_die_a.flit_tx_valid && !u_chiplet.u_die_a.flit_tx_ready)),
        .latency_valid           (latency_valid),
        .latency_value           (latency_value),
        .jitter_setting          (`TB_JITTER_CYCLES),
        .error_setting           (`TB_ERROR_PROB_NUM)
    );

    credit_checker u_credit_chk_a (
        .clk              (clk),
        .rst_n            (rst_n),
        .tx_valid         (u_chiplet.u_die_a.flit_tx_valid),
        .tx_ready         (u_chiplet.u_die_a.flit_tx_ready),
        .credit_available (u_chiplet.u_die_a.credit_available),
        .credit_consumed  (u_chiplet.u_die_a.credit_consumed),
        .credit_return    (u_chiplet.u_die_a.credit_return)
    );

    credit_checker u_credit_chk_b (
        .clk              (clk),
        .rst_n            (rst_n),
        .tx_valid         (u_chiplet.u_die_b.flit_tx_valid),
        .tx_ready         (u_chiplet.u_die_b.flit_tx_ready),
        .credit_available (u_chiplet.u_die_b.credit_available),
        .credit_consumed  (u_chiplet.u_die_b.credit_consumed),
        .credit_return    (u_chiplet.u_die_b.credit_return)
    );

    retry_checker #(
        .FLIT_WIDTH   (`TB_FLIT_WIDTH),
        .RESEND_WINDOW(32)
    ) u_retry_chk_a (
        .clk           (clk),
        .rst_n         (rst_n),
        .crc_error     (u_chiplet.u_die_a.depacketizer_crc_error),
        .resend_request(u_chiplet.u_die_a.resend_request),
        .tx_fire       (u_chiplet.u_die_a.flit_tx_valid && u_chiplet.u_die_a.flit_tx_ready),
        .tx_flit       (u_chiplet.u_die_a.flit_tx_payload),
        .link_ready    (u_chiplet.u_die_a.link_ready)
    );

    retry_checker #(
        .FLIT_WIDTH   (`TB_FLIT_WIDTH),
        .RESEND_WINDOW(32)
    ) u_retry_chk_b (
        .clk           (clk),
        .rst_n         (rst_n),
        .crc_error     (u_chiplet.u_die_b.depacketizer_crc_error),
        .resend_request(u_chiplet.u_die_b.resend_request),
        .tx_fire       (u_chiplet.u_die_b.flit_tx_valid && u_chiplet.u_die_b.flit_tx_ready),
        .tx_flit       (u_chiplet.u_die_b.flit_tx_payload),
        .link_ready    (u_chiplet.u_die_b.link_ready)
    );

    ucie_link_checker #(
        .TRAIN_WINDOW(512)
    ) u_link_chk_a (
        .clk            (clk),
        .rst_n          (rst_n),
        .link_up        (u_chiplet.u_die_a.link_up),
        .link_ready     (u_chiplet.u_die_a.link_ready),
        .start_training (1'b1),
        .fault_detected (u_chiplet.u_die_a.lane_adapter_lane_fault),
        .tx_fire        (u_chiplet.u_die_a.flit_tx_valid && u_chiplet.u_die_a.flit_tx_ready),
        .traffic_present(u_chiplet.u_die_a.tx_stream_valid)
    );

    initial begin
        `TB_TIMEOUT(clk, 5000)
        wait (cipher_updates >= 8);

        u_flit_scoreboard.write_report(score_path);
        u_cov.write_report(cov_path);

        if (wrong_key_mode || misalign_mode) begin
            if (mismatch_count == 0) begin
                $error("Negative test did not flag mismatches as expected");
            end
        end else begin
            if (mismatch_count != 0 || expected_empty_count != 0) begin
                $error("Ciphertext mismatches: mismatch=%0d empty=%0d", mismatch_count, expected_empty_count);
            end
            if (crypto_error_flag) begin
                $error("Crypto error flag asserted at end of test");
            end
        end

        $display("[SOC CHIPLETS] plaintext=%h ciphertext_dieA=%h ciphertext_dieB=%h", 
                 plaintext_monitor, ciphertext_monitor, die_b_ciphertext_monitor);
        $finish;
    end

endmodule : tb_soc_chiplets
