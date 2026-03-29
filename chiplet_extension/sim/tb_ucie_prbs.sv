`timescale 1ns/1ps
`include "tb_params.svh"
`include "sva_macros.svh"
`include "checkers/credit_checker.sv"
`include "checkers/retry_checker.sv"
`include "checkers/ucie_link_checker.sv"
`include "scoreboard/ucie_txn.svh"
`include "scoreboard/ucie_txn_monitor.sv"
`include "scoreboard/ucie_scoreboard.sv"
`include "coverage/ucie_coverage.sv"

module tb_ucie_prbs;

    localparam int LANES = `TB_LANES;
    localparam int DATA_WIDTH = `TB_DATA_WIDTH;
    localparam int FLIT_WIDTH = `TB_FLIT_WIDTH;

    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz fabric clock
    end

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        if ($test$plusargs("RESET_MIDFLIGHT")) begin
            repeat (300) @(posedge clk);
            rst_n = 0;
            repeat (5) @(posedge clk);
            rst_n = 1;
        end
    end

    int unsigned seed;
    string cov_path;
    string score_path;
    initial begin
        if (!$value$plusargs("SEED=%d", seed)) begin
            seed = `TB_SEED_DEFAULT;
        end
        cov_path = "reports/coverage_ucie_prbs.csv";
        score_path = "reports/scoreboard_ucie_prbs.csv";
        void'($value$plusargs("COV_OUT=%s", cov_path));
        void'($value$plusargs("SCORE_OUT=%s", score_path));
    end

    // Streaming data into the packetizer.
    logic [DATA_WIDTH-1:0] tx_stream_data;
    logic                  tx_stream_valid;
    logic                  tx_stream_ready;
    logic [DATA_WIDTH-1:0] rx_stream_data;
    logic                  rx_stream_valid;
    logic                  rx_stream_ready;

    // FLIT-level signals.
    logic [FLIT_WIDTH-1:0] flit_tx_payload;
    logic                  flit_tx_valid;
    logic                  flit_tx_ready;
    logic [FLIT_WIDTH-1:0] flit_rx_payload;
    logic                  flit_rx_valid;
    logic                  flit_rx_ready;
    logic                  depacketizer_crc_error;

    // Credit and link management.
    logic [15:0] credit_available;
    logic [15:0] credit_consumed;
    logic [15:0] credit_return_raw;
    logic [15:0] credit_return;

    logic resend_request;
    logic link_ready;
    logic link_up;
    logic training_done;

    // Adapter-side lanes.
    logic [LANES-1:0] lane_adapter_tx_data;
    logic             lane_adapter_tx_valid;
    logic             lane_adapter_link_enable;
    logic             lane_adapter_link_training;
    logic             lane_adapter_lane_clk;
    logic [LANES-1:0] lane_adapter_rx_data;
    logic             lane_adapter_rx_valid;
    logic             lane_adapter_lane_fault;

    // Channel-side lanes (after PHY).
    logic [LANES-1:0] lane_channel_tx_data;
    logic             lane_channel_tx_valid;
    logic             lane_channel_link_enable;
    logic             lane_channel_link_training;
    logic             lane_channel_lane_clk;
    logic [LANES-1:0] lane_channel_rx_data_raw;
    logic             lane_channel_rx_valid;
    logic             lane_channel_lane_fault_raw;

    // Optional error injection between channel and RX PHY.
    logic [LANES-1:0] lane_channel_rx_data;
    logic             lane_channel_lane_fault;
    logic             inject_error;

    // PRBS generator and gap control.
    int unsigned prbs_state;
    int unsigned gap_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prbs_state <= 16'h1ACE;
            gap_count  <= 0;
        end else begin
            prbs_state <= {prbs_state[14:0], prbs_state[15] ^ prbs_state[13]};
            if (gap_count != 0) begin
                gap_count <= gap_count - 1;
            end else if (tx_stream_valid && tx_stream_ready) begin
                gap_count <= ($urandom(seed) % 4);
            end
        end
    end

    assign tx_stream_data  = {DATA_WIDTH/16{prbs_state[15:0]}};
    assign tx_stream_valid = (gap_count == 0);
    assign rx_stream_ready = 1'b1;

    // Random backpressure on the receive stream.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flit_rx_ready <= 1'b1;
        end else if ($urandom(seed) % 8 == 0) begin
            flit_rx_ready <= ~flit_rx_ready;
        end
    end

    // Targeted credit starvation scenario.
    logic credit_block;
    initial begin
        credit_block = 1'b0;
        if ($test$plusargs("CREDIT_STARVE")) begin
            repeat (200) @(posedge clk);
            credit_block = 1'b1;
            repeat (100) @(posedge clk);
            credit_block = 1'b0;
        end
    end

    // Targeted retry burst scenario.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inject_error <= 1'b0;
        end else if ($test$plusargs("RETRY_BURST")) begin
            inject_error <= ($urandom(seed) % 12 == 0);
        end else begin
            inject_error <= 1'b0;
        end
    end

    assign lane_channel_rx_data  = lane_channel_rx_data_raw ^ (inject_error ? {{(LANES-1){1'b0}}, 1'b1} : '0);
    assign lane_channel_lane_fault = lane_channel_lane_fault_raw | inject_error;

    assign credit_return = credit_block ? 16'd0 : credit_return_raw;

    credit_mgr u_credit_mgr (
        .clk              (clk),
        .rst_n            (rst_n),
        .credit_init      (16'd128),
        .credit_debit     (credit_consumed),
        .credit_return    (credit_return),
        .credit_available (credit_available),
        .underflow        (),
        .overflow         ()
    );

    // Simplified training completion for testbench purposes.
    initial begin
        training_done = 1'b0;
        repeat (20) @(posedge clk);
        training_done = 1'b1;
    end

    link_fsm u_link_fsm (
        .clk              (clk),
        .rst_n            (rst_n),
        .start_training   (1'b1),
        .training_done    (training_done),
        .fault_detected   (lane_adapter_lane_fault),
        .retry_in_progress(resend_request),
        .link_ready       (link_ready),
        .link_up          (link_up),
        .degraded_mode    ()
    );

    retry_ctrl u_retry_ctrl (
        .clk               (clk),
        .rst_n             (rst_n),
        .crc_error_detected(depacketizer_crc_error),
        .nack_received     (lane_adapter_lane_fault),
        .resend_request    (resend_request),
        .link_degraded     ()
    );

    flit_packetizer #(
        .FLIT_WIDTH(FLIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_packetizer (
        .clk        (clk),
        .rst_n      (rst_n),
        .data_in    (tx_stream_data),
        .data_valid (tx_stream_valid),
        .data_ready (tx_stream_ready),
        .flit_out   (flit_tx_payload),
        .flit_valid (flit_tx_valid),
        .flit_ready (flit_tx_ready)
    );

    ucie_tx #(
        .LANES(LANES),
        .FLIT_WIDTH(FLIT_WIDTH)
    ) u_tx (
        .clk               (clk),
        .rst_n             (rst_n),
        .flit_in           (flit_tx_payload),
        .flit_valid        (flit_tx_valid),
        .flit_ready        (flit_tx_ready),
        .link_ready        (link_ready),
        .resend_request    (resend_request),
        .crc_error         (),
        .available_credits (credit_available),
        .credit_consumed   (credit_consumed),
        .lane_tx_valid      (lane_adapter_tx_valid),
        .lane_tx_data       (lane_adapter_tx_data),
        .lane_link_enable   (lane_adapter_link_enable),
        .lane_link_training (lane_adapter_link_training)
    );

    phy_behavioral #(
        .LANES           (LANES),
        .PIPELINE_STAGES (`TB_PIPELINE_STAGES),
        .JITTER_CYCLES   (`TB_JITTER_CYCLES),
        .ERROR_PROB_NUM  (`TB_ERROR_PROB_NUM),
        .ERROR_PROB_DEN  (`TB_ERROR_PROB_DEN)
    ) u_phy_tx (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .adapter_tx_data       (lane_adapter_tx_data),
        .adapter_tx_valid      (lane_adapter_tx_valid),
        .adapter_link_enable   (lane_adapter_link_enable),
        .adapter_link_training (lane_adapter_link_training),
        .adapter_lane_clk      (lane_adapter_lane_clk),
        .adapter_rx_data       (),
        .adapter_rx_valid      (),
        .adapter_lane_fault    (),
        .channel_tx_data       (lane_channel_tx_data),
        .channel_tx_valid      (lane_channel_tx_valid),
        .channel_link_enable   (lane_channel_link_enable),
        .channel_link_training (lane_channel_link_training),
        .channel_lane_clk      (lane_channel_lane_clk),
        .channel_rx_data       ('0),
        .channel_rx_valid      (1'b0),
        .channel_lane_fault    (1'b0)
    );

    channel_model #(
        .LANES                 (LANES),
        .REACH_MM              (`TB_REACH_MM),
        .SKEW_STAGES           (`TB_SKEW_STAGES),
        .CROSSTALK_SENSITIVITY (`TB_CROSSTALK_SENSITIVITY)
    ) u_channel (
        .clk              (clk),
        .rst_n            (rst_n),
        .lane_a_tx_data   (lane_channel_tx_data),
        .lane_a_tx_valid  (lane_channel_tx_valid),
        .lane_a_rx_data   (),
        .lane_a_rx_valid  (),
        .lane_a_lane_fault(1'b0),
        .lane_b_tx_data   ('0),
        .lane_b_tx_valid  (1'b0),
        .lane_b_rx_data   (lane_channel_rx_data_raw),
        .lane_b_rx_valid  (lane_channel_rx_valid),
        .lane_b_lane_fault(lane_channel_lane_fault_raw)
    );

    phy_behavioral #(
        .LANES           (LANES),
        .PIPELINE_STAGES (`TB_PIPELINE_STAGES),
        .JITTER_CYCLES   (`TB_JITTER_CYCLES),
        .ERROR_PROB_NUM  (`TB_ERROR_PROB_NUM),
        .ERROR_PROB_DEN  (`TB_ERROR_PROB_DEN)
    ) u_phy_rx (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .adapter_tx_data       ('0),
        .adapter_tx_valid      (1'b0),
        .adapter_link_enable   (1'b0),
        .adapter_link_training (1'b0),
        .adapter_lane_clk      (lane_adapter_lane_clk),
        .adapter_rx_data       (lane_adapter_rx_data),
        .adapter_rx_valid      (lane_adapter_rx_valid),
        .adapter_lane_fault    (lane_adapter_lane_fault),
        .channel_tx_data       (),
        .channel_tx_valid      (),
        .channel_link_enable   (),
        .channel_link_training (),
        .channel_lane_clk      (),
        .channel_rx_data       (lane_channel_rx_data),
        .channel_rx_valid      (lane_channel_rx_valid),
        .channel_lane_fault    (lane_channel_lane_fault)
    );

    assign lane_adapter_lane_clk = clk;

    ucie_rx #(
        .LANES(LANES),
        .FLIT_WIDTH(FLIT_WIDTH)
    ) u_rx (
        .clk            (clk),
        .rst_n          (rst_n),
        .flit_out       (flit_rx_payload),
        .flit_valid     (flit_rx_valid),
        .flit_ready     (flit_rx_ready),
        .crc_error      (),
        .credit_return  (credit_return_raw),
        .link_up        (link_up),
        .lane_rx_valid  (lane_adapter_rx_valid),
        .lane_rx_data   (lane_adapter_rx_data),
        .lane_lane_fault(lane_adapter_lane_fault)
    );

    flit_depacketizer #(
        .FLIT_WIDTH(FLIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_depacketizer (
        .clk        (clk),
        .rst_n      (rst_n),
        .flit_in    (flit_rx_payload),
        .flit_valid (flit_rx_valid),
        .flit_ready (flit_rx_ready),
        .data_out   (rx_stream_data),
        .data_valid (rx_stream_valid),
        .data_ready (rx_stream_ready),
        .crc_error  (depacketizer_crc_error)
    );

    // Scoreboard and coverage.
    logic latency_valid;
    logic [15:0] latency_value;
    int unsigned tx_count;
    int unsigned rx_count;
    int unsigned mismatch_count;
    int unsigned drop_count;
    int unsigned retry_count;
    int unsigned latency_violation_count;
    ucie_txn_t tx_txn;
    ucie_txn_t rx_txn;
    logic tx_txn_valid;
    logic rx_txn_valid;

    ucie_txn_monitor_tx u_txn_mon_tx (
        .clk           (clk),
        .rst_n         (rst_n),
        .flit_valid    (flit_tx_valid),
        .flit_ready    (flit_tx_ready),
        .flit_data     (flit_tx_payload),
        .resend_request(resend_request),
        .txn_valid     (tx_txn_valid),
        .txn           (tx_txn)
    );

    ucie_txn_monitor_rx u_txn_mon_rx (
        .clk        (clk),
        .rst_n      (rst_n),
        .flit_valid (flit_rx_valid),
        .flit_ready (flit_rx_ready),
        .flit_data  (flit_rx_payload),
        .txn_valid  (rx_txn_valid),
        .txn        (rx_txn)
    );

    ucie_scoreboard #(
        .LATENCY_MAX(`TB_MAX_LATENCY)
    ) u_scoreboard (
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
        .mismatch_count          (mismatch_count),
        .drop_count              (drop_count),
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
        .link_state              (u_link_fsm.state_q),
        .credit_available        (credit_available),
        .backpressure            (flit_tx_valid && !flit_tx_ready),
        .crc_error               (depacketizer_crc_error),
        .resend_request          (resend_request),
        .lane_fault              (lane_adapter_lane_fault),
        .error_during_backpressure(depacketizer_crc_error && (flit_tx_valid && !flit_tx_ready)),
        .latency_valid           (latency_valid),
        .latency_value           (latency_value),
        .jitter_setting          (`TB_JITTER_CYCLES),
        .error_setting           (`TB_ERROR_PROB_NUM)
    );

    // Assertion-based protocol checks.
    credit_checker u_credit_chk (
        .clk              (clk),
        .rst_n            (rst_n),
        .tx_valid         (flit_tx_valid),
        .tx_ready         (flit_tx_ready),
        .credit_available (credit_available),
        .credit_consumed  (credit_consumed),
        .credit_return    (credit_return)
    );

    retry_checker #(
        .FLIT_WIDTH   (FLIT_WIDTH),
        .RESEND_WINDOW(16)
    ) u_retry_chk (
        .clk           (clk),
        .rst_n         (rst_n),
        .crc_error     (depacketizer_crc_error),
        .resend_request(resend_request),
        .tx_fire       (flit_tx_valid && flit_tx_ready),
        .tx_flit       (flit_tx_payload),
        .link_ready    (link_ready)
    );

    ucie_link_checker #(
        .TRAIN_WINDOW(512)
    ) u_link_chk (
        .clk            (clk),
        .rst_n          (rst_n),
        .link_up        (link_up),
        .link_ready     (link_ready),
        .start_training (1'b1),
        .fault_detected (lane_adapter_lane_fault),
        .tx_fire        (flit_tx_valid && flit_tx_ready),
        .traffic_present(tx_stream_valid)
    );

    initial begin
        `TB_TIMEOUT(clk, 5000)
        wait (tx_count > 100);
        $display("[UCIe PRBS] tx=%0d rx=%0d retries=%0d crc_err=%0d", tx_count, rx_count, retry_count, depacketizer_crc_error);
        u_scoreboard.write_report(score_path);
        u_cov.write_report(cov_path);
        if (mismatch_count != 0 || drop_count != 0 || latency_violation_count != 0) begin
            $error("Scoreboard violations: mismatch=%0d drop=%0d latency=%0d", mismatch_count, drop_count, latency_violation_count);
        end
        $finish;
    end

endmodule : tb_ucie_prbs
