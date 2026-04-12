`timescale 1ns/1ps
`include "tb_params.svh"
`include "sva_macros.svh"
`include "dv/txn_pkg.sv"
`include "dv/ucie_cov_pkg.sv"
`include "dv/stats_pkg.sv"
`include "dv/stats_monitor.sv"
`include "dv/power_state_monitor.sv"
`include "tests/prbs_tests_pkg.sv"
`include "checkers/credit_checker.sv"
`include "checkers/retry_checker.sv"
`include "checkers/ucie_link_checker.sv"
`include "scoreboard/ucie_txn.svh"
`include "scoreboard/ucie_txn_monitor.sv"
`include "scoreboard/ucie_scoreboard.sv"

module tb_ucie_prbs;

    import txn_pkg::*;
    import prbs_tests_pkg::*;

    localparam int LANES = `TB_LANES;
    localparam int DATA_WIDTH = `TB_DATA_WIDTH;
    localparam int FLIT_WIDTH = `TB_FLIT_WIDTH;
    localparam int POST_TARGET_DRAIN_CYCLES = 256;

    logic clk;
    logic rst_n;
    logic cfg_ready;

    ucie_test_cfg cfg;
    bit found_cfg;
    string test_name;
    string scenario_kind;
    string bug_mode;
    int unsigned target_tx_count_cfg;
    int unsigned max_cycles_cfg;
    int unsigned gap_ceiling_cfg;
    int unsigned backpressure_modulus_cfg;
    int unsigned backpressure_hold_cfg;
    int unsigned error_inject_modulus_cfg;
    int unsigned credit_block_start_cfg;
    int unsigned credit_block_cycles_cfg;
    int unsigned midflight_reset_cycle_cfg;
    int unsigned crc_window_start_cfg;
    int unsigned crc_window_count_cfg;
    int unsigned crc_window_spacing_cfg;
    int unsigned lane_fault_start_cfg;
    int unsigned lane_fault_cycles_cfg;
    int unsigned training_hold_start_cfg;
    int unsigned training_hold_cycles_cfg;
    int unsigned credit_init_cfg;
    int unsigned channel_delay_cycles_cfg;
    logic allow_crc_error_cfg;
    logic randomized_cfg;
    logic enable_midflight_reset_cfg;
    logic enable_credit_starve_cfg;
    logic enable_retry_burst_cfg;
    logic enable_backpressure_cfg;
    logic enable_fault_echo_cfg;
    logic enable_crc_window_cfg;
    logic enable_lane_fault_window_cfg;
    int unsigned backpressure_hold_q;
    bit debug_progress;
    logic last_link_ready_q;
    logic last_resend_request_q;
    logic reset_observed_q;
    logic [3:0] reset_proxy_window_q;
    int unsigned error_cycle_q;
    int unsigned cycle_count_q;
    int unsigned crc_window_hits_q;
    int unsigned crc_window_ready_cycle_q;
    logic crc_window_armed_q;
    logic training_hold_active;
    logic degraded_mode;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz fabric clock
    end

    int unsigned seed;
    string cov_path;
    string score_path;
    initial begin
        cfg_ready = 1'b0;
        if (!$value$plusargs("TEST=%s", test_name)) begin
            test_name = "prbs_smoke";
        end
        apply_prbs_named_test(test_name, found_cfg, cfg);
        if (!found_cfg) begin
            $fatal(1, "Unknown PRBS test '%s'", test_name);
        end
        cfg.apply_runtime_plusargs();
        cfg.apply_seed(cfg.seed);
        seed = cfg.seed;
        scenario_kind = cfg.scenario_kind;
        bug_mode = cfg.bug_mode;
        target_tx_count_cfg = cfg.target_tx_count;
        max_cycles_cfg = cfg.max_cycles;
        gap_ceiling_cfg = cfg.link.gap_ceiling;
        backpressure_modulus_cfg = cfg.link.backpressure_modulus;
        backpressure_hold_cfg = cfg.link.backpressure_hold_cycles;
        error_inject_modulus_cfg = cfg.link.error_inject_modulus;
        credit_block_start_cfg = cfg.link.credit_block_start;
        credit_block_cycles_cfg = cfg.link.credit_block_cycles;
        midflight_reset_cycle_cfg = cfg.link.midflight_reset_cycle;
        crc_window_start_cfg = cfg.link.crc_window_start;
        crc_window_count_cfg = cfg.link.crc_window_count;
        crc_window_spacing_cfg = cfg.link.crc_window_spacing;
        lane_fault_start_cfg = cfg.link.lane_fault_start;
        lane_fault_cycles_cfg = cfg.link.lane_fault_cycles;
        training_hold_start_cfg = cfg.link.training_hold_start;
        training_hold_cycles_cfg = cfg.link.training_hold_cycles;
        credit_init_cfg = cfg.link.enable_credit_init_override ? cfg.link.credit_init_override : 128;
        channel_delay_cycles_cfg = cfg.link.channel_delay_cycles;
        allow_crc_error_cfg = cfg.allow_crc_error;
        randomized_cfg = cfg.randomized;
        enable_midflight_reset_cfg = cfg.link.enable_midflight_reset;
        enable_credit_starve_cfg = cfg.link.enable_credit_starve;
        enable_retry_burst_cfg = cfg.link.enable_retry_burst;
        enable_backpressure_cfg = cfg.link.enable_backpressure;
        enable_fault_echo_cfg = cfg.link.enable_fault_echo;
        enable_crc_window_cfg = cfg.link.enable_crc_window;
        enable_lane_fault_window_cfg = cfg.link.enable_lane_fault_window;
        cov_path = "reports/coverage_ucie_prbs.csv";
        score_path = "reports/scoreboard_ucie_prbs.csv";
        void'($value$plusargs("COV_OUT=%s", cov_path));
        void'($value$plusargs("SCORE_OUT=%s", score_path));
        debug_progress = $test$plusargs("DEBUG_PROGRESS");
        cfg_ready = 1'b1;
    end

    initial begin
        wait (cfg_ready);
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        if (enable_midflight_reset_cfg) begin
            repeat (midflight_reset_cycle_cfg) @(posedge clk);
            rst_n = 0;
            repeat (5) @(posedge clk);
            rst_n = 1;
        end
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
    logic [FLIT_WIDTH-1:0] flit_rx_payload_injected;
    logic                  depacketizer_crc_error;
    logic                  debug_send_fire;
    logic [FLIT_WIDTH-1:0] debug_send_flit;

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
    logic             lane_channel_rx_valid_raw;
    logic             lane_channel_lane_fault_raw;
    logic             lane_channel_lane_fault_unused;

    // Optional error injection between channel and RX PHY.
    logic [LANES-1:0] lane_channel_rx_data_delayed;
    logic             lane_channel_rx_valid_delayed;
    logic             lane_channel_lane_fault_delayed;
    logic [LANES-1:0] lane_channel_rx_data;
    logic             lane_channel_rx_valid;
    logic             lane_channel_lane_fault;
    logic             inject_lane_fault_q;
    logic             inject_crc_error_now;
    logic             lane_fault_drop_pending_q;
    logic             drop_rx_txn_now;
    logic             random_inject_error_q;
    localparam int unsigned MAX_CHANNEL_DELAY_CYCLES = 48;
    logic [LANES-1:0] delayed_lane_data_q  [0:MAX_CHANNEL_DELAY_CYCLES];
    logic             delayed_lane_valid_q [0:MAX_CHANNEL_DELAY_CYCLES];
    logic             delayed_lane_fault_q [0:MAX_CHANNEL_DELAY_CYCLES];

    // PRBS generator and gap control.
    int unsigned prbs_state;
    int unsigned gap_count;
    logic [5:0] training_counter_q;
    logic traffic_pause_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prbs_state <= 16'h1ACE;
            gap_count  <= 0;
        end else begin
            prbs_state <= {prbs_state[14:0], prbs_state[15] ^ prbs_state[13]};
            if (gap_count != 0) begin
                gap_count <= gap_count - 1;
            end else if (tx_stream_valid && tx_stream_ready) begin
                gap_count <= randomized_cfg ?
                    ($urandom(seed) % ((gap_ceiling_cfg == 0) ? 1 : (gap_ceiling_cfg + 1))) :
                    (prbs_state % ((gap_ceiling_cfg == 0) ? 1 : (gap_ceiling_cfg + 1)));
            end
        end
    end

    assign traffic_pause_active = enable_lane_fault_window_cfg &&
                                  (cycle_count_q >= ((lane_fault_start_cfg > 8) ? (lane_fault_start_cfg - 8) : 0)) &&
                                  (cycle_count_q < (training_hold_start_cfg + training_hold_cycles_cfg + 16));
    assign tx_stream_data  = {DATA_WIDTH/16{prbs_state[15:0]}};
    assign tx_stream_valid = (gap_count == 0) && !traffic_pause_active;

    // Random backpressure on the receive stream.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_stream_ready <= 1'b1;
            backpressure_hold_q <= 0;
        end else if (!enable_backpressure_cfg) begin
            rx_stream_ready <= 1'b1;
            backpressure_hold_q <= 0;
        end else if (backpressure_hold_q != 0) begin
            backpressure_hold_q <= backpressure_hold_q - 1;
        end else if ((randomized_cfg &&
                      ($urandom(seed) % ((backpressure_modulus_cfg == 0) ? 1 : backpressure_modulus_cfg) == 0)) ||
                     (!randomized_cfg &&
                      ((cycle_count_q % ((backpressure_modulus_cfg == 0) ? 1 : backpressure_modulus_cfg)) == 0))) begin
            rx_stream_ready <= ~rx_stream_ready;
            backpressure_hold_q <= backpressure_hold_cfg;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count_q <= 0;
        end else begin
            cycle_count_q <= cycle_count_q + 1'b1;
        end
    end

    // Targeted credit starvation scenario.
    logic credit_block;
    initial begin
        wait (cfg_ready);
        credit_block = 1'b0;
        if (enable_credit_starve_cfg) begin
            repeat (credit_block_start_cfg) @(posedge clk);
            credit_block = 1'b1;
            repeat (credit_block_cycles_cfg) @(posedge clk);
            credit_block = 1'b0;
        end
    end

    assign training_hold_active = (training_hold_cycles_cfg != 0) &&
                                  (cycle_count_q >= training_hold_start_cfg) &&
                                  (cycle_count_q < (training_hold_start_cfg + training_hold_cycles_cfg));
    assign inject_lane_fault_q = enable_lane_fault_window_cfg &&
                                 (cycle_count_q >= lane_fault_start_cfg) &&
                                 (cycle_count_q < (lane_fault_start_cfg + lane_fault_cycles_cfg));

    // Targeted CRC and retry scenarios.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            random_inject_error_q <= 1'b0;
            error_cycle_q <= 0;
            crc_window_hits_q <= 0;
            crc_window_ready_cycle_q <= 0;
            crc_window_armed_q <= 1'b0;
            lane_fault_drop_pending_q <= 1'b0;
        end else begin
            int unsigned spacing;
            random_inject_error_q <= 1'b0;

            spacing = (crc_window_spacing_cfg == 0) ? 1 : crc_window_spacing_cfg;
            if (enable_crc_window_cfg && !crc_window_armed_q) begin
                crc_window_ready_cycle_q <= crc_window_start_cfg;
                crc_window_armed_q <= 1'b1;
            end
            if (inject_crc_error_now) begin
                crc_window_hits_q <= crc_window_hits_q + 1'b1;
                crc_window_ready_cycle_q <= cycle_count_q + spacing;
            end
            if (inject_lane_fault_q) begin
                lane_fault_drop_pending_q <= 1'b1;
            end
            if (drop_rx_txn_now) begin
                lane_fault_drop_pending_q <= 1'b0;
            end

            if (enable_retry_burst_cfg || enable_fault_echo_cfg) begin
                error_cycle_q <= error_cycle_q + 1'b1;
                if (error_inject_modulus_cfg != 0) begin
                    random_inject_error_q <= lane_channel_rx_valid &&
                                             !resend_request &&
                                             ((error_cycle_q % error_inject_modulus_cfg) == 0);
                end
            end else begin
                error_cycle_q <= 0;
            end
        end
    end

    assign inject_crc_error_now = enable_crc_window_cfg &&
                                  crc_window_armed_q &&
                                  flit_rx_valid &&
                                  flit_rx_ready &&
                                  !resend_request &&
                                  (crc_window_hits_q < crc_window_count_cfg) &&
                                  (cycle_count_q >= crc_window_ready_cycle_q);
    assign drop_rx_txn_now = lane_fault_drop_pending_q &&
                             flit_rx_valid &&
                             flit_rx_ready &&
                             !resend_request;

    assign lane_channel_rx_data = lane_channel_rx_data_delayed ^
                                  (random_inject_error_q ?
                                   {{(LANES-1){1'b0}}, 1'b1} : '0);
    assign lane_channel_rx_valid = lane_channel_rx_valid_delayed;
    assign lane_channel_lane_fault = lane_channel_lane_fault_delayed |
                                     inject_lane_fault_q |
                                     (enable_fault_echo_cfg && random_inject_error_q);
    assign flit_rx_payload_injected = flit_rx_payload ^
                                      (inject_crc_error_now ?
                                       {{(FLIT_WIDTH-1){1'b0}}, 1'b1} : '0);

    assign credit_return = credit_block ? 16'd0 : credit_return_raw;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_link_ready_q <= 1'b0;
            last_resend_request_q <= 1'b0;
        end else begin
            if (debug_progress) begin
                if (flit_tx_valid && flit_tx_ready) begin
                    $display("[PRBS DBG] cycle=%0t tx_fire credits=%0d resend=%0b link_ready=%0b",
                             $time, credit_available, resend_request, link_ready);
                end
                if (flit_rx_valid && flit_rx_ready) begin
                    $display("[PRBS DBG] cycle=%0t rx_flit crc_err=%0b credit_return=%0d",
                             $time, depacketizer_crc_error, credit_return_raw);
                end
                if (inject_crc_error_now) begin
                    $display("[PRBS DBG] cycle=%0t inject_crc_window hit=%0d/%0d",
                             $time, crc_window_hits_q + 1'b1, crc_window_count_cfg);
                end
                if (inject_lane_fault_q) begin
                    $display("[PRBS DBG] cycle=%0t inject_lane_fault", $time);
                end
                if (resend_request && !last_resend_request_q) begin
                    $display("[PRBS DBG] cycle=%0t resend_request lane_fault=%0b crc_error=%0b",
                             $time, lane_adapter_lane_fault, depacketizer_crc_error);
                end
                if (link_ready != last_link_ready_q) begin
                    $display("[PRBS DBG] cycle=%0t link_ready=%0b state=%0d",
                             $time, link_ready, u_link_fsm.state_q);
                end
            end
            last_link_ready_q <= link_ready;
            last_resend_request_q <= resend_request;
        end
    end

    credit_mgr u_credit_mgr (
        .clk              (clk),
        .rst_n            (rst_n),
        .credit_init      (credit_init_cfg[15:0]),
        .credit_debit     (credit_consumed),
        .credit_return    (credit_return),
        .credit_available (credit_available),
        .underflow        (),
        .overflow         ()
    );

    // Simplified training completion for testbench purposes.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            training_counter_q <= '0;
        end else if (training_counter_q < 20) begin
            training_counter_q <= training_counter_q + 1'b1;
        end
    end
    assign training_done = (training_counter_q >= 20) && !training_hold_active;

    link_fsm u_link_fsm (
        .clk              (clk),
        .rst_n            (rst_n),
        .start_training   (1'b1),
        .training_done    (training_done),
        .fault_detected   (lane_adapter_lane_fault),
        .retry_in_progress(resend_request),
        .link_ready       (link_ready),
        .link_up          (link_up),
        .degraded_mode    (degraded_mode)
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
        .lane_link_training (lane_adapter_link_training),
        .debug_send_fire    (debug_send_fire),
        .debug_send_flit    (debug_send_flit),
        .debug_resend_fire  ()
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
        .lane_a_lane_fault(lane_channel_lane_fault_unused),
        .lane_b_tx_data   ('0),
        .lane_b_tx_valid  (1'b0),
        .lane_b_rx_data   (lane_channel_rx_data_raw),
        .lane_b_rx_valid  (lane_channel_rx_valid_raw),
        .lane_b_lane_fault(lane_channel_lane_fault_raw)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        int delay_idx;
        if (!rst_n) begin
            for (int idx = 0; idx <= MAX_CHANNEL_DELAY_CYCLES; idx++) begin
                delayed_lane_data_q[idx] <= '0;
                delayed_lane_valid_q[idx] <= 1'b0;
                delayed_lane_fault_q[idx] <= 1'b0;
            end
        end else begin
            delayed_lane_data_q[0] <= lane_channel_rx_data_raw;
            delayed_lane_valid_q[0] <= lane_channel_rx_valid_raw;
            delayed_lane_fault_q[0] <= lane_channel_lane_fault_raw;
            for (delay_idx = 1; delay_idx <= MAX_CHANNEL_DELAY_CYCLES; delay_idx++) begin
                delayed_lane_data_q[delay_idx] <= delayed_lane_data_q[delay_idx-1];
                delayed_lane_valid_q[delay_idx] <= delayed_lane_valid_q[delay_idx-1];
                delayed_lane_fault_q[delay_idx] <= delayed_lane_fault_q[delay_idx-1];
            end
        end
    end

    assign lane_channel_rx_data_delayed = delayed_lane_data_q[
        (channel_delay_cycles_cfg > MAX_CHANNEL_DELAY_CYCLES) ? MAX_CHANNEL_DELAY_CYCLES : channel_delay_cycles_cfg
    ];
    assign lane_channel_rx_valid_delayed = delayed_lane_valid_q[
        (channel_delay_cycles_cfg > MAX_CHANNEL_DELAY_CYCLES) ? MAX_CHANNEL_DELAY_CYCLES : channel_delay_cycles_cfg
    ];
    assign lane_channel_lane_fault_delayed = delayed_lane_fault_q[
        (channel_delay_cycles_cfg > MAX_CHANNEL_DELAY_CYCLES) ? MAX_CHANNEL_DELAY_CYCLES : channel_delay_cycles_cfg
    ];

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
        .flit_in    (flit_rx_payload_injected),
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
        .flit_valid    (debug_send_fire),
        .flit_ready    (1'b1),
        .flit_data     (debug_send_flit),
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
        .crc_error  (depacketizer_crc_error || drop_rx_txn_now),
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

    logic power_idle_proxy;
    assign power_idle_proxy = rst_n && !flit_tx_valid && !flit_rx_valid && !tx_stream_valid && !rx_stream_valid;

    stats_monitor u_stats (
        .clk               (clk),
        .rst_n             (rst_n),
        .link_state_a      (u_link_fsm.state_q),
        .link_state_b      (3'd0),
        .credit_available_a(credit_available),
        .credit_available_b(16'd0),
        .backpressure_a    (flit_tx_valid && !flit_tx_ready),
        .backpressure_b    (1'b0),
        .crc_error_a       (depacketizer_crc_error),
        .crc_error_b       (1'b0),
        .resend_request_a  (resend_request),
        .resend_request_b  (1'b0),
        .lane_fault_a      (lane_adapter_lane_fault),
        .lane_fault_b      (1'b0),
        .latency_valid     (latency_valid),
        .latency_value     (latency_value),
        .tx_fire           (flit_tx_valid && flit_tx_ready),
        .rx_fire           (flit_rx_valid && flit_rx_ready),
        .e2e_update        (rx_stream_valid && rx_stream_ready),
        .e2e_mismatch      (1'b0),
        .expected_empty    (1'b0),
        .power_reset_proxy (reset_observed_q),
        .power_idle_proxy  (power_idle_proxy),
        .dma_mode_active   (1'b0),
        .dma_active_valid  (1'b0),
        .dma_state         (3'd0),
        .dma_submit_count  (3'd0),
        .dma_comp_count    (3'd0),
        .dma_submit_head   (2'd0),
        .dma_submit_tail   (2'd0),
        .dma_comp_head     (2'd0),
        .dma_comp_tail     (2'd0),
        .dma_comp_full_stall(1'b0),
        .dma_submit_accept_event(1'b0),
        .dma_submit_reject_event(1'b0),
        .dma_submit_reject_err_code(4'd0),
        .dma_comp_push_event(1'b0),
        .dma_comp_pop_event (1'b0),
        .dma_comp_push_status(2'b00),
        .dma_comp_push_err_code(4'd0),
        .dma_reject_overflow_count(32'd0),
        .dma_retry_seen    (1'b0),
        .dma_recovery_seen (1'b0),
        .dma_sleep_resume_seen(1'b0)
    );

    // Assertion-based protocol checks.
    credit_checker u_credit_chk (
        .clk              (clk),
        .rst_n            (rst_n),
        .tx_valid         (flit_tx_valid),
        .tx_ready         (flit_tx_ready),
        .credit_init      (credit_init_cfg[15:0]),
        .credit_available (credit_available),
        .credit_consumed  (credit_consumed),
        .credit_return    (credit_return)
    );

    retry_checker #(
        .FLIT_WIDTH   (FLIT_WIDTH),
        .RESEND_WINDOW(1024)
    ) u_retry_chk (
        .clk           (clk),
        .rst_n         (rst_n),
        .crc_error     (depacketizer_crc_error),
        .resend_request(resend_request),
        .tx_fire       (debug_send_fire),
        .tx_flit       (debug_send_flit),
        .link_ready    (link_ready)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Nothing to do during reset.
        end else if (!allow_crc_error_cfg && depacketizer_crc_error) begin
            $error("CRC_INTEGRITY_UNEXPECTED: depacketizer_crc_error asserted in nominal path");
        end
    end

    ucie_link_checker #(
        .TRAIN_WINDOW(512),
        .PROGRESS_WINDOW(2048)
    ) u_link_chk (
        .clk            (clk),
        .rst_n          (rst_n),
        .link_up        (link_up),
        .link_ready     (link_ready),
        .start_training (1'b1),
        .fault_detected (lane_adapter_lane_fault),
        .tx_fire        (flit_tx_valid && flit_tx_ready),
        .traffic_present(flit_tx_valid)
    );

    initial begin
        int unsigned drain_cycle;
        wait (cfg_ready);
        `TB_TIMEOUT(clk, max_cycles_cfg)
        wait (tx_count >= target_tx_count_cfg);
        for (drain_cycle = 0; drain_cycle < POST_TARGET_DRAIN_CYCLES; drain_cycle++) begin
            @(posedge clk);
            if ((rx_count >= tx_count) &&
                !flit_tx_valid &&
                !flit_rx_valid &&
                !resend_request) begin
                break;
            end
        end
        u_scoreboard.write_report(score_path);
        u_stats.write_coverage(cov_path);
        u_stats.emit_result(
            "tb_ucie_prbs",
            test_name,
            scenario_kind,
            seed,
            bug_mode,
            (mismatch_count == 0 && drop_count == 0 && latency_violation_count == 0),
            (mismatch_count == 0 && drop_count == 0 && latency_violation_count == 0) ? "clean" : "scoreboard_violation",
            tx_count,
            rx_count,
            retry_count,
            mismatch_count,
            drop_count,
            latency_violation_count,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            score_path,
            cov_path,
            ""
        );
        $display("[UCIe PRBS] test=%s tx=%0d rx=%0d retries=%0d crc_err=%0d", test_name, tx_count, rx_count, retry_count, depacketizer_crc_error);
        if (mismatch_count != 0 || drop_count != 0 || latency_violation_count != 0) begin
            $error("Scoreboard violations: mismatch=%0d drop=%0d latency=%0d", mismatch_count, drop_count, latency_violation_count);
        end
        $finish;
    end

endmodule : tb_ucie_prbs
