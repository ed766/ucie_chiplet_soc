`timescale 1ns/1ps
`include "tb_params.svh"
`include "sva_macros.svh"
`include "dv/txn_pkg.sv"
`include "dv/ucie_cov_pkg.sv"
`include "dv/stats_pkg.sv"
`include "dv/stats_monitor.sv"
`include "tests/soc_tests_pkg.sv"
`include "models/aes_ref_pkg.sv"
`include "checkers/credit_checker.sv"
`include "checkers/retry_checker.sv"
`include "checkers/ucie_link_checker.sv"
`include "scoreboard/ucie_txn.svh"
`include "scoreboard/ucie_txn_monitor.sv"
`include "scoreboard/ucie_scoreboard.sv"

module tb_soc_chiplets;

    import txn_pkg::*;
    import soc_tests_pkg::*;

    localparam int DATA_WIDTH = `TB_DATA_WIDTH;
    localparam int FLIT_WIDTH = `TB_FLIT_WIDTH;
    localparam int LANES = `TB_LANES;
    localparam int BLOCK_WIDTH = 128;
    localparam int WORDS_PER_BLOCK = BLOCK_WIDTH / DATA_WIDTH;
    localparam logic [127:0] AES_KEY = 128'h00112233445566778899aabbccddeeff;
    localparam int EXPECT_FIFO_DEPTH = 64;
    localparam int POST_TARGET_DRAIN_CYCLES = 256;

    logic clk;
    logic rst_n;
    logic cfg_ready;

    ucie_test_cfg cfg;
    bit found_cfg;
    string test_name;
    string scenario_kind;
    string bug_mode;
    int unsigned seed;
    int unsigned target_cipher_updates_cfg;
    int unsigned max_cycles_cfg;
    logic enable_backpressure_cfg;
    int unsigned backpressure_modulus_cfg;
    int unsigned backpressure_hold_cfg;
    logic wrong_key_mode;
    logic misalign_mode;
    string cov_path;
    string score_path;
    logic forced_rx_ready;
    int unsigned return_bp_hold_q;
    logic e2e_mismatch_event_q;
    logic expected_empty_event_q;
    logic reset_observed_q;
    logic [3:0] reset_proxy_window_q;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        wait (cfg_ready);
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_observed_q <= 1'b1;
            reset_proxy_window_q <= 4'd8;
        end else if (reset_proxy_window_q != 0) begin
            reset_observed_q <= 1'b1;
            reset_proxy_window_q <= reset_proxy_window_q - 1'b1;
        end else begin
            reset_observed_q <= 1'b0;
        end
    end

    logic [DATA_WIDTH-1:0] plaintext_monitor;
    logic [DATA_WIDTH-1:0] ciphertext_monitor;
    logic [DATA_WIDTH-1:0] die_b_ciphertext_monitor;
    logic                   crypto_error_flag;

    soc_chiplet_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FLIT_WIDTH(FLIT_WIDTH),
        .LANES     (LANES)
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

    initial begin
        cfg_ready = 1'b0;
        if (!$value$plusargs("TEST=%s", test_name)) begin
            test_name = "soc_smoke";
        end
        apply_soc_named_test(test_name, found_cfg, cfg);
        if (!found_cfg) begin
            $fatal(1, "Unknown SoC test '%s'", test_name);
        end
        cfg.apply_runtime_plusargs();
        cfg.apply_seed(cfg.seed);
        seed = cfg.seed;
        scenario_kind = cfg.scenario_kind;
        bug_mode = cfg.bug_mode;
        target_cipher_updates_cfg = cfg.target_cipher_updates;
        max_cycles_cfg = cfg.max_cycles;
        enable_backpressure_cfg = cfg.link.enable_backpressure;
        backpressure_modulus_cfg = cfg.link.backpressure_modulus;
        backpressure_hold_cfg = cfg.link.backpressure_hold_cycles;
        wrong_key_mode = cfg.neg_wrong_key;
        misalign_mode  = cfg.neg_misalign;
        cov_path = "reports/coverage_soc_chiplets.csv";
        score_path = "reports/scoreboard_soc_chiplets.csv";
        void'($value$plusargs("COV_OUT=%s", cov_path));
        void'($value$plusargs("SCORE_OUT=%s", score_path));
        cfg_ready = 1'b1;
    end

    initial begin
        forced_rx_ready = 1'b1;
        wait (cfg_ready);
        if (enable_backpressure_cfg) begin
            force u_chiplet.u_die_a.rx_stream_ready = forced_rx_ready;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            forced_rx_ready <= 1'b1;
            return_bp_hold_q <= 0;
        end else if (!enable_backpressure_cfg) begin
            forced_rx_ready <= 1'b1;
            return_bp_hold_q <= 0;
        end else if (return_bp_hold_q != 0) begin
            return_bp_hold_q <= return_bp_hold_q - 1;
        end else if ($urandom(seed) % ((backpressure_modulus_cfg == 0) ? 1 : backpressure_modulus_cfg) == 0) begin
            forced_rx_ready <= ~forced_rx_ready;
            return_bp_hold_q <= backpressure_hold_cfg;
        end
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
            e2e_mismatch_event_q <= 1'b0;
            expected_empty_event_q <= 1'b0;
            for (int idx = 0; idx < EXPECT_FIFO_DEPTH; idx++) begin
                expected_fifo[idx] <= '0;
            end
        end else begin
            e2e_mismatch_event_q <= 1'b0;
            expected_empty_event_q <= 1'b0;
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
                    expected_empty_event_q <= 1'b1;
                end else begin
                    logic [DATA_WIDTH-1:0] expected_word;
                    expected_word = expected_fifo[exp_head_q];
                    if (u_chiplet.u_die_a.rx_stream_data !== expected_word) begin
                        mismatch_count <= mismatch_count + 1;
                        e2e_mismatch_event_q <= 1'b1;
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
        .crc_error  (u_chiplet.u_die_b.depacketizer_crc_error),
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

    logic power_idle_proxy;
    assign power_idle_proxy = rst_n &&
                              !u_chiplet.u_die_a.flit_tx_valid &&
                              !u_chiplet.u_die_b.flit_tx_valid &&
                              !u_chiplet.u_die_a.rx_stream_valid;

    stats_monitor u_stats (
        .clk               (clk),
        .rst_n             (rst_n),
        .link_state_a      (u_chiplet.u_die_a.u_link_fsm.state_q),
        .link_state_b      (u_chiplet.u_die_b.u_link_fsm.state_q),
        .credit_available_a(u_chiplet.u_die_a.credit_available),
        .credit_available_b(u_chiplet.u_die_b.credit_available),
        .backpressure_a    (u_chiplet.u_die_a.flit_tx_valid && !u_chiplet.u_die_a.flit_tx_ready),
        .backpressure_b    (u_chiplet.u_die_b.flit_tx_valid && !u_chiplet.u_die_b.flit_tx_ready),
        .crc_error_a       (u_chiplet.u_die_a.depacketizer_crc_error),
        .crc_error_b       (u_chiplet.u_die_b.depacketizer_crc_error),
        .resend_request_a  (u_chiplet.u_die_a.resend_request),
        .resend_request_b  (u_chiplet.u_die_b.resend_request),
        .lane_fault_a      (u_chiplet.u_die_a.lane_adapter_lane_fault),
        .lane_fault_b      (u_chiplet.u_die_b.lane_adapter_lane_fault),
        .latency_valid     (latency_valid),
        .latency_value     (latency_value),
        .tx_fire           (tx_fire),
        .rx_fire           (rx_fire),
        .e2e_update        (rx_fire),
        .e2e_mismatch      (e2e_mismatch_event_q),
        .expected_empty    (expected_empty_event_q),
        .power_reset_proxy (reset_observed_q),
        .power_idle_proxy  (power_idle_proxy)
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
        .TRAIN_WINDOW(512),
        .PROGRESS_WINDOW(256)
    ) u_link_chk_a (
        .clk            (clk),
        .rst_n          (rst_n),
        .link_up        (u_chiplet.u_die_a.link_up),
        .link_ready     (u_chiplet.u_die_a.link_ready),
        .start_training (1'b1),
        .fault_detected (u_chiplet.u_die_a.lane_adapter_lane_fault),
        .tx_fire        (u_chiplet.u_die_a.flit_tx_valid && u_chiplet.u_die_a.flit_tx_ready),
        .traffic_present(u_chiplet.u_die_a.flit_tx_valid)
    );

    initial begin
        int unsigned drain_cycle;
        wait (cfg_ready);
        `TB_TIMEOUT(clk, max_cycles_cfg)
        wait (cipher_updates >= target_cipher_updates_cfg);
        for (drain_cycle = 0; drain_cycle < POST_TARGET_DRAIN_CYCLES; drain_cycle++) begin
            @(posedge clk);
            if ((rx_count >= tx_count) &&
                !u_chiplet.u_die_a.flit_tx_valid &&
                !u_chiplet.u_die_b.flit_tx_valid &&
                !u_chiplet.u_die_a.resend_request &&
                !u_chiplet.u_die_b.resend_request) begin
                break;
            end
        end

        u_flit_scoreboard.write_report(score_path);
        u_stats.write_coverage(cov_path);
        u_stats.emit_result(
            "tb_soc_chiplets",
            test_name,
            scenario_kind,
            seed,
            bug_mode,
            (wrong_key_mode || misalign_mode) ? (mismatch_count != 0 && expected_empty_count == 0) :
                (mismatch_count == 0 && expected_empty_count == 0 && !crypto_error_flag &&
                 flit_mismatch_count == 0 && flit_drop_count == 0 && latency_violation_count == 0),
            (wrong_key_mode || misalign_mode) ? ((mismatch_count != 0 && expected_empty_count == 0) ? "negative_check_caught" : "negative_check_missed") :
                ((mismatch_count == 0 && expected_empty_count == 0 && !crypto_error_flag &&
                  flit_mismatch_count == 0 && flit_drop_count == 0 && latency_violation_count == 0) ? "clean" : "soc_scoreboard_violation"),
            tx_count,
            rx_count,
            retry_count,
            flit_mismatch_count,
            flit_drop_count,
            latency_violation_count,
            mismatch_count,
            expected_empty_count,
            score_path,
            cov_path
        );

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

        $display("[SOC CHIPLETS] test=%s plaintext=%h ciphertext_dieA=%h ciphertext_dieB=%h",
                 test_name, plaintext_monitor, ciphertext_monitor, die_b_ciphertext_monitor);
        $finish;
    end

endmodule : tb_soc_chiplets
