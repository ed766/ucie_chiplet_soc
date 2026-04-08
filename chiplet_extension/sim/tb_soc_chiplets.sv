`timescale 1ns/1ps
`include "tb_params.svh"
`include "sva_macros.svh"
`include "dv/txn_pkg.sv"
`include "dv/ucie_cov_pkg.sv"
`include "dv/stats_pkg.sv"
`include "dv/stats_monitor.sv"
`include "tests/soc_tests_pkg.sv"
`include "checkers/credit_checker.sv"
`include "checkers/retry_checker.sv"
`include "checkers/ucie_link_checker.sv"
`include "scoreboard/ucie_txn.svh"
`include "scoreboard/e2e_ref_scoreboard.sv"
`include "scoreboard/ucie_txn_monitor.sv"
`include "scoreboard/ucie_scoreboard.sv"

module tb_soc_chiplets;

    import txn_pkg::*;
    import soc_tests_pkg::*;

    localparam int DATA_WIDTH = `TB_DATA_WIDTH;
    localparam int FLIT_WIDTH = `TB_FLIT_WIDTH;
    localparam int LANES = `TB_LANES;
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
    logic enable_fault_echo_cfg;
    logic enable_lane_fault_window_cfg;
    int unsigned lane_fault_start_cfg;
    int unsigned lane_fault_cycles_cfg;
    int unsigned training_hold_start_cfg;
    int unsigned training_hold_cycles_cfg;
    logic wrong_key_mode;
    logic misalign_mode;
    string cov_path;
    string score_path;
    string ref_path;
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
        enable_fault_echo_cfg = cfg.link.enable_fault_echo;
        enable_lane_fault_window_cfg = cfg.link.enable_lane_fault_window;
        lane_fault_start_cfg = cfg.link.lane_fault_start;
        lane_fault_cycles_cfg = cfg.link.lane_fault_cycles;
        training_hold_start_cfg = cfg.link.training_hold_start;
        training_hold_cycles_cfg = cfg.link.training_hold_cycles;
        wrong_key_mode = cfg.neg_wrong_key;
        misalign_mode  = cfg.neg_misalign;
        cov_path = "reports/coverage_soc_chiplets.csv";
        score_path = "reports/scoreboard_soc_chiplets.csv";
        ref_path = "";
        void'($value$plusargs("COV_OUT=%s", cov_path));
        void'($value$plusargs("SCORE_OUT=%s", score_path));
        if (!$value$plusargs("REF_CSV=%s", ref_path)) begin
            $fatal(1, "tb_soc_chiplets requires +REF_CSV=<path>");
        end
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

    initial begin
        wait (cfg_ready);
        wait (rst_n);
        if (enable_fault_echo_cfg || enable_lane_fault_window_cfg) begin
            repeat (lane_fault_start_cfg) @(posedge clk);
            force u_chiplet.u_die_a.lane_adapter_lane_fault = 1'b1;
            repeat ((lane_fault_cycles_cfg == 0) ? 1 : lane_fault_cycles_cfg) @(posedge clk);
            release u_chiplet.u_die_a.lane_adapter_lane_fault;
        end
    end

    initial begin
        wait (cfg_ready);
        wait (rst_n);
        if (training_hold_cycles_cfg != 0) begin
            repeat (training_hold_start_cfg) @(posedge clk);
            force u_chiplet.u_die_a.training_done = 1'b0;
            repeat (training_hold_cycles_cfg) @(posedge clk);
            release u_chiplet.u_die_a.training_done;
        end
    end

    // Internal handshake signals from Die A stream interface.
    wire tx_fire = u_chiplet.u_die_a.tx_stream_valid && u_chiplet.u_die_a.tx_stream_ready;
    wire rx_fire = u_chiplet.u_die_a.rx_stream_valid && u_chiplet.u_die_a.rx_stream_ready;

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
        .flit_valid    (u_chiplet.u_die_a.u_tx.debug_send_fire),
        .flit_ready    (1'b1),
        .flit_data     (u_chiplet.u_die_a.u_tx.debug_send_flit),
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

    e2e_ref_scoreboard #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(1024)
    ) u_e2e_scoreboard (
        .clk                 (clk),
        .rst_n               (rst_n),
        .rx_valid            (u_chiplet.u_die_a.rx_stream_valid),
        .rx_ready            (u_chiplet.u_die_a.rx_stream_ready),
        .rx_data             (u_chiplet.u_die_a.rx_stream_data),
        .observed_count      (cipher_updates),
        .mismatch_count      (mismatch_count),
        .expected_empty_count(expected_empty_count),
        .update_event        (),
        .mismatch_event      (e2e_mismatch_event_q),
        .expected_empty_event(expected_empty_event_q)
    );

    initial begin
        wait (cfg_ready);
        u_e2e_scoreboard.load_reference(ref_path);
    end

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
        .RESEND_WINDOW(256)
    ) u_retry_chk_a (
        .clk           (clk),
        .rst_n         (rst_n),
        .crc_error     (u_chiplet.u_die_a.depacketizer_crc_error),
        .resend_request(u_chiplet.u_die_a.resend_request),
        .tx_fire       (u_chiplet.u_die_a.u_tx.debug_send_fire),
        .tx_flit       (u_chiplet.u_die_a.u_tx.debug_send_flit),
        .link_ready    (u_chiplet.u_die_a.link_ready)
    );

    retry_checker #(
        .FLIT_WIDTH   (`TB_FLIT_WIDTH),
        .RESEND_WINDOW(256)
    ) u_retry_chk_b (
        .clk           (clk),
        .rst_n         (rst_n),
        .crc_error     (u_chiplet.u_die_b.depacketizer_crc_error),
        .resend_request(u_chiplet.u_die_b.resend_request),
        .tx_fire       (u_chiplet.u_die_b.u_tx.debug_send_fire),
        .tx_flit       (u_chiplet.u_die_b.u_tx.debug_send_flit),
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
