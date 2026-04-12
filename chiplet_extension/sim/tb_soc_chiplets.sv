`timescale 1ns/1ps
`include "tb_params.svh"
`include "sva_macros.svh"
`include "dv/txn_pkg.sv"
`include "dv/ucie_cov_pkg.sv"
`include "dv/stats_pkg.sv"
`include "dv/stats_monitor.sv"
`include "dv/dma_completion_monitor.sv"
`include "dv/power_state_monitor.sv"
`include "tests/soc_tests_pkg.sv"
`include "checkers/credit_checker.sv"
`include "checkers/dma_csr_irq_checker.sv"
`include "checkers/retry_checker.sv"
`include "checkers/ucie_link_checker.sv"
`include "scoreboard/ucie_txn.svh"
`include "scoreboard/dma_mem_ref_scoreboard.sv"
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
    localparam logic [1:0] PWR_RUN = 2'd0;
    localparam logic [1:0] PWR_CRYPTO_ONLY = 2'd1;
    localparam logic [1:0] PWR_SLEEP = 2'd2;
    localparam logic [1:0] PWR_DEEP_SLEEP = 2'd3;
    localparam logic [7:0] DMA_CTRL_ADDR = 8'h00;
    localparam logic [7:0] DMA_STATUS_ADDR = 8'h04;
    localparam logic [7:0] DMA_SRC_BASE_ADDR = 8'h08;
    localparam logic [7:0] DMA_DST_BASE_ADDR = 8'h0c;
    localparam logic [7:0] DMA_LEN_ADDR = 8'h10;
    localparam logic [7:0] DMA_TAG_ADDR = 8'h14;
    localparam logic [7:0] DMA_IRQ_EN_ADDR = 8'h18;
    localparam logic [7:0] DMA_IRQ_STATUS_ADDR = 8'h1c;
    localparam logic [7:0] DMA_SCRATCH_IDX_ADDR = 8'h20;
    localparam logic [7:0] DMA_SCRATCH_SEL_ADDR = 8'h24;
    localparam logic [7:0] DMA_SCRATCH_LO_ADDR = 8'h28;
    localparam logic [7:0] DMA_SCRATCH_HI_ADDR = 8'h2c;
    localparam logic [7:0] DMA_SUBMIT_Q_STATUS_ADDR = 8'h30;
    localparam logic [7:0] DMA_COMP_Q_STATUS_ADDR = 8'h34;
    localparam logic [7:0] DMA_COMP_TAG_ADDR = 8'h38;
    localparam logic [7:0] DMA_COMP_STATUS_ADDR = 8'h3c;
    localparam logic [7:0] DMA_COMP_WORDS_ADDR = 8'h40;
    localparam logic [7:0] DMA_COMP_POP_ADDR = 8'h44;
    localparam logic [7:0] DMA_ACTIVE_TAG_ADDR = 8'h48;
    localparam logic [7:0] DMA_ACTIVE_STATUS_ADDR = 8'h4c;
    localparam logic [7:0] DMA_SUBMIT_RESULT_ADDR = 8'h50;
    localparam logic [7:0] DMA_REJECT_OVF_ADDR = 8'h54;
    localparam logic [7:0] DMA_MEM_OP_CTRL_ADDR = 8'h58;
    localparam logic [7:0] DMA_MEM_OP_STATUS_ADDR = 8'h5c;
    localparam logic [7:0] DMA_MEM_ERR_STATUS_ADDR = 8'h60;
    localparam logic [7:0] DMA_MEM_ERR_COUNT_ADDR = 8'h64;
    localparam logic [7:0] DMA_RET_CFG_ADDR = 8'h68;
    localparam logic [7:0] DMA_RET_STATUS_ADDR = 8'h6c;
    localparam logic [7:0] DMA_RET_VALID_STATUS_ADDR = 8'h70;
    localparam logic [7:0] DMA_MEM_CONFLICT_COUNT_ADDR = 8'h74;
    localparam logic [7:0] DMA_MEM_WAIT_COUNT_ADDR = 8'h78;
    localparam logic [7:0] DMA_MEM_INJECT_ADDR_ADDR = 8'h7c;
    localparam logic [7:0] DMA_MEM_INJECT_CTRL_ADDR = 8'h80;
    localparam logic [7:0] DMA_MEM_INJECT_STATUS_ADDR = 8'h84;
    localparam logic [1:0] DMA_COMP_SUCCESS = 2'b01;
    localparam logic [1:0] DMA_COMP_RUNTIME_ERROR = 2'b10;
    localparam logic [1:0] DMA_COMP_SUBMIT_REJECT = 2'b11;
    localparam logic [3:0] DMA_ERR_ODD_LEN = 4'd1;
    localparam logic [3:0] DMA_ERR_RANGE = 4'd2;
    localparam logic [3:0] DMA_ERR_QUEUE_FULL = 4'd3;
    localparam logic [3:0] DMA_ERR_TIMEOUT = 4'd4;
    localparam logic [3:0] DMA_ERR_SUBMIT_BLOCKED = 4'd5;
    localparam logic [3:0] DMA_ERR_MEM_PARITY = 4'd6;
    localparam logic [3:0] DMA_ERR_MEM_INVALID = 4'd7;

    logic clk;
    logic rst_n;
    logic tb_cfg_ready;
    logic cfg_valid;
    logic cfg_write;
    logic [7:0] cfg_addr;
    logic [31:0] cfg_wdata;
    logic [31:0] cfg_rdata;
    logic cfg_ready;
    logic irq_done;

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
    int unsigned power_event_start_cfg;
    int unsigned power_event_cycles_cfg;
    int unsigned power_recovery_cycles_cfg;
    logic wrong_key_mode;
    logic misalign_mode;
    logic expect_expected_empty_mode;
    logic use_dma_cfg;
    logic randomized_cfg;
    string power_mode_cfg;
    string cov_path;
    string score_path;
    string ref_path;
    string power_path;
    logic forced_rx_ready;
    int unsigned return_bp_hold_q;
    logic e2e_mismatch_event_q;
    logic expected_empty_event_q;
    logic reset_observed_q;
    logic [3:0] reset_proxy_window_q;
    logic mon_rst_n;
    logic [1:0] power_state_q;
    logic [31:0] cfg_rdata_capture_q;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        mon_rst_n = 1'b0;
        power_state_q = PWR_RUN;
        wait (tb_cfg_ready);
        repeat (12) @(posedge clk);
        mon_rst_n = 1'b1;
    end

    initial begin
        wait (tb_cfg_ready);
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
    logic                   dma_busy_monitor;
    logic                   dma_done_monitor;
    logic                   dma_error_monitor;
    logic                   irq_done_monitor;
    logic [15:0]            dma_tag_monitor;

    soc_chiplet_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FLIT_WIDTH(FLIT_WIDTH),
        .LANES     (LANES)
    ) u_chiplet (
        .clk                       (clk),
        .rst_n                     (rst_n),
        .power_state               (power_state_q),
        .dma_mode_force            (use_dma_cfg),
        .cfg_valid                 (cfg_valid),
        .cfg_write                 (cfg_write),
        .cfg_addr                  (cfg_addr),
        .cfg_wdata                 (cfg_wdata),
        .cfg_rdata                 (cfg_rdata),
        .cfg_ready                 (cfg_ready),
        .irq_done                  (irq_done),
        .plaintext_monitor         (plaintext_monitor),
        .ciphertext_monitor        (ciphertext_monitor),
        .die_b_ciphertext_monitor  (die_b_ciphertext_monitor),
        .crypto_error_flag         (crypto_error_flag),
        .dma_busy_monitor          (dma_busy_monitor),
        .dma_done_monitor          (dma_done_monitor),
        .dma_error_monitor         (dma_error_monitor),
        .irq_done_monitor          (irq_done_monitor),
        .dma_tag_monitor           (dma_tag_monitor)
    );

    int unsigned cipher_updates;
    int unsigned mismatch_count;
    int unsigned expected_empty_count;
    int unsigned dma_mem_observed_count;
    int unsigned dma_mem_mismatch_count;
    int unsigned dma_desc_completed_count;
    int unsigned dma_submit_accepted_count;
    int unsigned dma_submit_rejected_count;
    int unsigned dma_completion_push_count;
    int unsigned dma_completion_pop_count;
    int unsigned dma_irq_count;
    int unsigned dma_error_count;
    logic dma_mem_update_event_q;
    logic dma_mem_mismatch_event_q;
    logic dma_start_event_q;
    logic dma_done_event_q;
    logic dma_error_event_q;
    logic dma_pop_event_q;
    logic [15:0] dma_last_tag_q;
    logic [2:0] dma_last_state_q;
    logic [8:0] dma_last_words_launched_q;
    logic [8:0] dma_last_words_retired_q;
    logic [3:0] dma_last_err_code_q;
    logic [1:0] dma_last_completion_status_q;
    logic dma_retry_seen_q;
    logic dma_recovery_seen_q;
    logic dma_sleep_resume_seen_q;
    logic [2:0] dma_prev_link_state_a_q;
    logic [2:0] dma_prev_link_state_b_q;
    logic [1:0] dma_prev_power_state_q;
    logic dma_cov_reset_q;
    logic [31:0] dma_submit_result_word_q;
    logic [31:0] dma_front_comp_status_word_q;

    assign dma_submit_result_word_q = {10'd0,
                                       u_chiplet.u_die_a.u_dma.submit_reject_tag_q,
                                       u_chiplet.u_die_a.u_dma.submit_reject_err_code_q,
                                       u_chiplet.u_die_a.u_dma.submit_rejected_q,
                                       u_chiplet.u_die_a.u_dma.submit_accepted_q};
    assign dma_front_comp_status_word_q = u_chiplet.u_die_a.u_dma.comp_empty ? 32'd0 :
                                          {26'd0,
                                           u_chiplet.u_die_a.u_dma.comp_status_q[u_chiplet.u_die_a.u_dma.comp_head_q],
                                           u_chiplet.u_die_a.u_dma.comp_err_code_q[u_chiplet.u_die_a.u_dma.comp_head_q]};

    initial begin
        tb_cfg_ready = 1'b0;
        cfg_valid = 1'b0;
        cfg_write = 1'b0;
        cfg_addr = '0;
        cfg_wdata = '0;
        cfg_rdata_capture_q = '0;
        dma_cov_reset_q = 1'b0;
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
        power_event_start_cfg = cfg.power_event_start;
        power_event_cycles_cfg = cfg.power_event_cycles;
        power_recovery_cycles_cfg = cfg.power_recovery_cycles;
        wrong_key_mode = cfg.neg_wrong_key;
        misalign_mode  = cfg.neg_misalign;
        expect_expected_empty_mode = cfg.expect_expected_empty;
        use_dma_cfg = cfg.use_dma;
        randomized_cfg = cfg.randomized;
        power_mode_cfg = cfg.power_mode;
        cov_path = "reports/coverage_soc_chiplets.csv";
        score_path = "reports/scoreboard_soc_chiplets.csv";
        ref_path = "";
        power_path = "reports/power_soc_chiplets.csv";
        void'($value$plusargs("COV_OUT=%s", cov_path));
        void'($value$plusargs("SCORE_OUT=%s", score_path));
        void'($value$plusargs("POWER_OUT=%s", power_path));
        if (!$value$plusargs("REF_CSV=%s", ref_path)) begin
            $fatal(1, "tb_soc_chiplets requires +REF_CSV=<path>");
        end
        tb_cfg_ready = 1'b1;
    end

    initial begin
        forced_rx_ready = 1'b1;
        wait (tb_cfg_ready);
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
        end else if ((randomized_cfg &&
                      ($urandom(seed) % ((backpressure_modulus_cfg == 0) ? 1 : backpressure_modulus_cfg) == 0)) ||
                     (!randomized_cfg &&
                      ((cipher_updates % ((backpressure_modulus_cfg == 0) ? 1 : backpressure_modulus_cfg)) == 0))) begin
            forced_rx_ready <= ~forced_rx_ready;
            return_bp_hold_q <= backpressure_hold_cfg;
        end
    end

    initial begin
        wait (tb_cfg_ready);
        wait (rst_n);
        if (enable_fault_echo_cfg || enable_lane_fault_window_cfg) begin
            repeat (lane_fault_start_cfg) @(posedge clk);
            force u_chiplet.u_die_a.lane_adapter_lane_fault = 1'b1;
            repeat ((lane_fault_cycles_cfg == 0) ? 1 : lane_fault_cycles_cfg) @(posedge clk);
            release u_chiplet.u_die_a.lane_adapter_lane_fault;
        end
    end

    initial begin
        wait (tb_cfg_ready);
        wait (rst_n);
        if (training_hold_cycles_cfg != 0) begin
            repeat (training_hold_start_cfg) @(posedge clk);
            force u_chiplet.u_die_a.training_done = 1'b0;
            repeat (training_hold_cycles_cfg) @(posedge clk);
            release u_chiplet.u_die_a.training_done;
        end
    end

    initial begin
        wait (tb_cfg_ready);
        wait (rst_n);
        case (power_mode_cfg)
            "crypto_only": begin
                repeat (power_event_start_cfg) @(posedge clk);
                power_state_q = PWR_CRYPTO_ONLY;
                if (!use_dma_cfg) begin
                    force u_chiplet.u_die_a.tx_stream_valid = 1'b0;
                    force u_chiplet.u_die_a.legacy_tx_stream_ready = 1'b0;
                end
                repeat (power_event_cycles_cfg) @(posedge clk);
                if (!use_dma_cfg) begin
                    release u_chiplet.u_die_a.tx_stream_valid;
                    release u_chiplet.u_die_a.legacy_tx_stream_ready;
                end
                power_state_q = PWR_RUN;
            end
            "sleep": begin
                repeat (power_event_start_cfg) @(posedge clk);
                power_state_q = PWR_SLEEP;
                if (!use_dma_cfg) begin
                    force u_chiplet.u_die_a.tx_stream_valid = 1'b0;
                    force u_chiplet.u_die_a.legacy_tx_stream_ready = 1'b0;
                end
                force u_chiplet.u_die_a.rx_stream_ready = 1'b0;
                force u_chiplet.u_die_a.training_done = 1'b0;
                force u_chiplet.u_die_b.training_done = 1'b0;
                force u_chiplet.u_die_b.plaintext_ready = 1'b0;
                repeat (power_event_cycles_cfg) @(posedge clk);
                if (!use_dma_cfg) begin
                    release u_chiplet.u_die_a.tx_stream_valid;
                    release u_chiplet.u_die_a.legacy_tx_stream_ready;
                end
                release u_chiplet.u_die_a.rx_stream_ready;
                release u_chiplet.u_die_a.training_done;
                release u_chiplet.u_die_b.training_done;
                release u_chiplet.u_die_b.plaintext_ready;
                power_state_q = PWR_RUN;
            end
            "deep_sleep": begin
                repeat (power_event_start_cfg) @(posedge clk);
                power_state_q = PWR_DEEP_SLEEP;
                if (!use_dma_cfg) begin
                    force u_chiplet.u_die_a.tx_stream_valid = 1'b0;
                    force u_chiplet.u_die_a.legacy_tx_stream_ready = 1'b0;
                end
                force u_chiplet.u_die_a.rx_stream_ready = 1'b0;
                force u_chiplet.u_die_a.training_done = 1'b0;
                force u_chiplet.u_die_b.training_done = 1'b0;
                force u_chiplet.u_die_b.plaintext_ready = 1'b0;
                repeat (power_event_cycles_cfg) @(posedge clk);
                if (!use_dma_cfg) begin
                    release u_chiplet.u_die_a.tx_stream_valid;
                    release u_chiplet.u_die_a.legacy_tx_stream_ready;
                end
                release u_chiplet.u_die_a.rx_stream_ready;
                release u_chiplet.u_die_b.plaintext_ready;
                power_state_q = PWR_RUN;
                force u_chiplet.u_die_a.lane_adapter_lane_fault = 1'b1;
                force u_chiplet.u_die_b.lane_adapter_lane_fault = 1'b1;
                repeat (power_recovery_cycles_cfg) @(posedge clk);
                release u_chiplet.u_die_a.training_done;
                release u_chiplet.u_die_b.training_done;
                release u_chiplet.u_die_a.lane_adapter_lane_fault;
                release u_chiplet.u_die_b.lane_adapter_lane_fault;
            end
            default: begin
                power_state_q = PWR_RUN;
            end
        endcase
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
    int unsigned power_run_cycles;
    int unsigned power_crypto_only_cycles;
    int unsigned power_sleep_cycles;
    int unsigned power_deep_sleep_cycles;
    int unsigned trans_run_to_crypto_only;
    int unsigned trans_crypto_only_to_run;
    int unsigned trans_run_to_sleep;
    int unsigned trans_sleep_to_run;
    int unsigned trans_run_to_deep_sleep;
    int unsigned trans_deep_sleep_to_run;
    int unsigned power_illegal_activity_violations;
    int unsigned power_resume_events;
    int unsigned power_resume_violations;
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
        .rx_valid            (use_dma_cfg ? 1'b0 : u_chiplet.u_die_a.rx_stream_valid),
        .rx_ready            (use_dma_cfg ? 1'b0 : u_chiplet.u_die_a.rx_stream_ready),
        .rx_data             (use_dma_cfg ? '0 : u_chiplet.u_die_a.rx_stream_data),
        .observed_count      (cipher_updates),
        .mismatch_count      (mismatch_count),
        .expected_empty_count(expected_empty_count),
        .update_event        (),
        .mismatch_event      (e2e_mismatch_event_q),
        .expected_empty_event(expected_empty_event_q)
    );

    dma_mem_ref_scoreboard #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(256)
    ) u_dma_ref_scoreboard (
        .observed_count(dma_mem_observed_count),
        .mismatch_count(dma_mem_mismatch_count),
        .update_event(dma_mem_update_event_q),
        .mismatch_event(dma_mem_mismatch_event_q)
    );

    dma_completion_monitor u_dma_mon (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .submit_accept_event   (u_chiplet.u_die_a.u_dma.submit_accept_event_q),
        .submit_reject_event   (u_chiplet.u_die_a.u_dma.submit_reject_event_q),
        .comp_push_event       (u_chiplet.u_die_a.u_dma.comp_push_event_q),
        .comp_pop_event        (u_chiplet.u_die_a.u_dma.comp_pop_event_q),
        .irq_done              (irq_done_monitor),
        .active_valid          (u_chiplet.u_die_a.u_dma.active_valid_q),
        .active_tag            (u_chiplet.u_die_a.u_dma.active_tag_q),
        .active_state          (u_chiplet.u_die_a.u_dma.state_q),
        .words_launched        (u_chiplet.u_die_a.u_dma.send_count_q),
        .words_retired         (u_chiplet.u_die_a.u_dma.recv_count_q),
        .comp_push_status      (u_chiplet.u_die_a.u_dma.comp_push_status_q),
        .comp_push_err_code    (u_chiplet.u_die_a.u_dma.comp_push_err_code_q),
        .comp_push_tag         (u_chiplet.u_die_a.u_dma.comp_push_tag_q),
        .comp_push_words       (u_chiplet.u_die_a.u_dma.comp_push_words_q),
        .submit_accepted_count (dma_submit_accepted_count),
        .submit_rejected_count (dma_submit_rejected_count),
        .completion_push_count (dma_completion_push_count),
        .completion_pop_count  (dma_completion_pop_count),
        .desc_completed_count  (dma_desc_completed_count),
        .irq_count             (dma_irq_count),
        .error_count           (dma_error_count),
        .start_event           (dma_start_event_q),
        .done_event            (dma_done_event_q),
        .error_event           (dma_error_event_q),
        .pop_event             (dma_pop_event_q),
        .last_tag              (dma_last_tag_q),
        .last_state            (dma_last_state_q),
        .last_words_launched   (dma_last_words_launched_q),
        .last_words_retired    (dma_last_words_retired_q),
        .last_err_code         (dma_last_err_code_q),
        .last_completion_status(dma_last_completion_status_q)
    );

    initial begin
        wait (tb_cfg_ready);
        if (use_dma_cfg) begin
            u_dma_ref_scoreboard.load_reference(ref_path);
        end else begin
            u_e2e_scoreboard.load_reference(ref_path);
        end
    end

    power_state_monitor u_power_mon (
        .clk                        (clk),
        .mon_rst_n                  (mon_rst_n),
        .power_state                (power_state_q),
        .producer_valid             (u_chiplet.u_die_a.tx_stream_valid),
        .tx_fire                    (tx_fire),
        .rx_fire                    (rx_fire),
        .e2e_update                 (rx_fire),
        .run_cycles                 (power_run_cycles),
        .crypto_only_cycles         (power_crypto_only_cycles),
        .sleep_cycles               (power_sleep_cycles),
        .deep_sleep_cycles          (power_deep_sleep_cycles),
        .trans_run_to_crypto_only   (trans_run_to_crypto_only),
        .trans_crypto_only_to_run   (trans_crypto_only_to_run),
        .trans_run_to_sleep         (trans_run_to_sleep),
        .trans_sleep_to_run         (trans_sleep_to_run),
        .trans_run_to_deep_sleep    (trans_run_to_deep_sleep),
        .trans_deep_sleep_to_run    (trans_deep_sleep_to_run),
        .illegal_activity_violations(power_illegal_activity_violations),
        .resume_events              (power_resume_events),
        .resume_violations          (power_resume_violations)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_retry_seen_q <= 1'b0;
            dma_recovery_seen_q <= 1'b0;
            dma_sleep_resume_seen_q <= 1'b0;
            dma_prev_link_state_a_q <= 3'd0;
            dma_prev_link_state_b_q <= 3'd0;
            dma_prev_power_state_q <= PWR_RUN;
        end else begin
            dma_prev_link_state_a_q <= u_chiplet.u_die_a.u_link_fsm.state_q;
            dma_prev_link_state_b_q <= u_chiplet.u_die_b.u_link_fsm.state_q;
            dma_prev_power_state_q <= power_state_q;

            if (dma_cov_reset_q) begin
                dma_retry_seen_q <= 1'b0;
                dma_recovery_seen_q <= 1'b0;
                dma_sleep_resume_seen_q <= 1'b0;
            end else begin
                if ((retry_count != 0) ||
                    u_chiplet.u_die_a.resend_request ||
                    u_chiplet.u_die_b.resend_request ||
                    u_chiplet.u_die_a.depacketizer_crc_error ||
                    u_chiplet.u_die_b.depacketizer_crc_error ||
                    u_chiplet.u_die_a.lane_adapter_lane_fault ||
                    u_chiplet.u_die_b.lane_adapter_lane_fault) begin
                    dma_retry_seen_q <= 1'b1;
                end
                if ((((dma_prev_link_state_a_q == 3'd3) || (dma_prev_link_state_a_q == 3'd4)) &&
                     (u_chiplet.u_die_a.u_link_fsm.state_q == 3'd2)) ||
                    (((dma_prev_link_state_b_q == 3'd3) || (dma_prev_link_state_b_q == 3'd4)) &&
                     (u_chiplet.u_die_b.u_link_fsm.state_q == 3'd2))) begin
                    dma_recovery_seen_q <= 1'b1;
                end
                if ((power_resume_events != 0) ||
                    ((dma_prev_power_state_q != PWR_RUN) && (power_state_q == PWR_RUN))) begin
                    dma_sleep_resume_seen_q <= 1'b1;
                end
            end
        end
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
        .power_idle_proxy  (power_idle_proxy),
        .dma_mode_active   (use_dma_cfg),
        .dma_active_valid  (u_chiplet.u_die_a.u_dma.active_valid_q),
        .dma_state         (u_chiplet.u_die_a.u_dma.state_q),
        .dma_submit_count  (u_chiplet.u_die_a.u_dma.submit_count_q),
        .dma_comp_count    (u_chiplet.u_die_a.u_dma.comp_count_q),
        .dma_submit_head   (u_chiplet.u_die_a.u_dma.submit_head_q),
        .dma_submit_tail   (u_chiplet.u_die_a.u_dma.submit_tail_q),
        .dma_comp_head     (u_chiplet.u_die_a.u_dma.comp_head_q),
        .dma_comp_tail     (u_chiplet.u_die_a.u_dma.comp_tail_q),
        .dma_comp_full_stall(u_chiplet.u_die_a.u_dma.comp_full_stall_q),
        .dma_submit_accept_event(u_chiplet.u_die_a.u_dma.submit_accept_event_q),
        .dma_submit_reject_event(u_chiplet.u_die_a.u_dma.submit_reject_event_q),
        .dma_submit_reject_err_code(u_chiplet.u_die_a.u_dma.submit_reject_err_code_q),
        .dma_comp_push_event(u_chiplet.u_die_a.u_dma.comp_push_event_q),
        .dma_comp_pop_event (u_chiplet.u_die_a.u_dma.comp_pop_event_q),
        .dma_comp_push_status(u_chiplet.u_die_a.u_dma.comp_push_status_q),
        .dma_comp_push_err_code(u_chiplet.u_die_a.u_dma.comp_push_err_code_q),
        .dma_reject_overflow_count(u_chiplet.u_die_a.u_dma.reject_overflow_count_q),
        .dma_retry_seen    (dma_retry_seen_q),
        .dma_recovery_seen (dma_recovery_seen_q),
        .dma_sleep_resume_seen(dma_sleep_resume_seen_q),
        .mem_src_conflicts (u_chiplet.u_die_a.u_dma.src_conflicts_q),
        .mem_dst_conflicts (u_chiplet.u_die_a.u_dma.dst_conflicts_q),
        .mem_src_wait_cycles(u_chiplet.u_die_a.u_dma.src_wait_cycles_q),
        .mem_dst_wait_cycles(u_chiplet.u_die_a.u_dma.dst_wait_cycles_q),
        .mem_op_parity_error(u_chiplet.u_die_a.u_dma.mem_op_parity_error_q),
        .mem_op_invalid_read_seen(u_chiplet.u_die_a.u_dma.mem_op_invalid_read_seen_q),
        .mem_write_reject_dma_active(u_chiplet.u_die_a.u_dma.mem_op_write_reject_dma_active_q),
        .mem_src_invalid_bank_mask(u_chiplet.u_die_a.u_dma.src_invalid_bank_mask_q),
        .mem_dst_invalid_bank_mask(u_chiplet.u_die_a.u_dma.dst_invalid_bank_mask_q),
        .mem_wake_apply_seen(u_chiplet.u_die_a.u_dma.wake_apply_seen_q)
    );

    credit_checker u_credit_chk_a (
        .clk              (clk),
        .rst_n            (rst_n),
        .tx_valid         (u_chiplet.u_die_a.flit_tx_valid),
        .tx_ready         (u_chiplet.u_die_a.flit_tx_ready),
        .credit_init      (16'd128),
        .credit_available (u_chiplet.u_die_a.credit_available),
        .credit_consumed  (u_chiplet.u_die_a.credit_consumed),
        .credit_return    (u_chiplet.u_die_a.credit_return)
    );

    credit_checker u_credit_chk_b (
        .clk              (clk),
        .rst_n            (rst_n),
        .tx_valid         (u_chiplet.u_die_b.flit_tx_valid),
        .tx_ready         (u_chiplet.u_die_b.flit_tx_ready),
        .credit_init      (16'd128),
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

    dma_csr_irq_checker u_dma_irq_chk (
        .clk                  (clk),
        .rst_n                (rst_n),
        .cfg_valid            (cfg_valid),
        .cfg_write            (cfg_write),
        .cfg_addr             (cfg_addr),
        .cfg_wdata            (cfg_wdata),
        .irq_done             (irq_done_monitor),
        .irq_en               (u_chiplet.u_die_a.u_dma.irq_en_q),
        .irq_status           (u_chiplet.u_die_a.u_dma.irq_status_q),
        .active_valid         (u_chiplet.u_die_a.u_dma.active_valid_q),
        .comp_empty           (u_chiplet.u_die_a.u_dma.comp_empty),
        .comp_tag             (u_chiplet.u_die_a.u_dma.comp_tag_q[u_chiplet.u_die_a.u_dma.comp_head_q]),
        .comp_status_word     (dma_front_comp_status_word_q[7:0]),
        .comp_words           (u_chiplet.u_die_a.u_dma.comp_words_q[u_chiplet.u_die_a.u_dma.comp_head_q]),
        .comp_pop_event       (u_chiplet.u_die_a.u_dma.comp_pop_event_q),
        .comp_push_event      (u_chiplet.u_die_a.u_dma.comp_push_event_q),
        .comp_push_status     (u_chiplet.u_die_a.u_dma.comp_push_status_q),
        .comp_push_err_code   (u_chiplet.u_die_a.u_dma.comp_push_err_code_q),
        .active_tag           (u_chiplet.u_die_a.u_dma.active_tag_q),
        .active_state         (u_chiplet.u_die_a.u_dma.state_q),
        .submit_result        (dma_submit_result_word_q),
        .reject_overflow_count(u_chiplet.u_die_a.u_dma.reject_overflow_count_q),
        .power_state          (power_state_q)
    );

    function automatic logic [DATA_WIDTH-1:0] dma_source_word(input int unsigned index);
        dma_source_word = 64'h1000_0000_0000_0000 | DATA_WIDTH'(index);
    endfunction

    task automatic cfg_write32(
        input logic [7:0] addr,
        input logic [31:0] data
    );
        begin
            @(posedge clk);
            cfg_valid = 1'b1;
            cfg_write = 1'b1;
            cfg_addr = addr;
            cfg_wdata = data;
            @(posedge clk);
            while (!cfg_ready) begin
                @(posedge clk);
            end
            cfg_valid = 1'b0;
            cfg_write = 1'b0;
            cfg_addr = '0;
            cfg_wdata = '0;
        end
    endtask

    task automatic cfg_read32(
        input logic [7:0] addr,
        output logic [31:0] data
    );
        begin
            @(posedge clk);
            cfg_valid = 1'b1;
            cfg_write = 1'b0;
            cfg_addr = addr;
            cfg_wdata = '0;
            @(posedge clk);
            while (!cfg_ready) begin
                @(posedge clk);
            end
            data = cfg_rdata;
            cfg_rdata_capture_q = data;
            cfg_valid = 1'b0;
            cfg_addr = '0;
        end
    endtask

    task automatic dma_soft_reset();
        begin
            cfg_write32(DMA_CTRL_ADDR, 32'h0000_0002);
            cfg_write32(DMA_IRQ_STATUS_ADDR, 32'h0000_0003);
        end
    endtask

    task automatic dma_hard_reset();
        begin
            rst_n = 1'b0;
            repeat (6) @(posedge clk);
            rst_n = 1'b1;
            repeat (8) @(posedge clk);
        end
    endtask

    task automatic dma_clear_irq(input logic [1:0] mask);
        begin
            cfg_write32(DMA_IRQ_STATUS_ADDR, {30'd0, mask});
        end
    endtask

    task automatic dma_set_irq_en(input logic [1:0] mask);
        begin
            cfg_write32(DMA_IRQ_EN_ADDR, {30'd0, mask});
        end
    endtask

    task automatic dma_program_desc(
        input int unsigned src_base,
        input int unsigned dst_base,
        input int unsigned len_words,
        input int unsigned tag
    );
        begin
            cfg_write32(DMA_SRC_BASE_ADDR, src_base[31:0]);
            cfg_write32(DMA_DST_BASE_ADDR, dst_base[31:0]);
            cfg_write32(DMA_LEN_ADDR, len_words[31:0]);
            cfg_write32(DMA_TAG_ADDR, tag[31:0]);
        end
    endtask

    task automatic dma_start();
        begin
            cfg_write32(DMA_CTRL_ADDR, 32'h0000_0001);
        end
    endtask

    task automatic dma_enqueue_desc(
        input int unsigned src_base,
        input int unsigned dst_base,
        input int unsigned len_words,
        input int unsigned tag
    );
        begin
            dma_program_desc(src_base, dst_base, len_words, tag);
            dma_start();
        end
    endtask

    function automatic logic [DATA_WIDTH-1:0] mem_poison_word(input int unsigned index);
        mem_poison_word = 64'hDEAD_0000_0000_0000 ^ DATA_WIDTH'(index[7:0]);
    endfunction

    task automatic dma_mem_read_status(
        output bit busy,
        output bit done,
        output bit wait_conflict,
        output bit parity_error,
        output bit invalid_read_seen,
        output bit op_reject_busy,
        output bit write_reject_dma_active
    );
        logic [31:0] word;
        begin
            cfg_read32(DMA_MEM_OP_STATUS_ADDR, word);
            busy = word[0];
            done = word[1];
            wait_conflict = word[2];
            parity_error = word[3];
            invalid_read_seen = word[4];
            op_reject_busy = word[5];
            write_reject_dma_active = word[6];
        end
    endtask

    task automatic dma_mem_wait_done(
        input int unsigned wait_cycles,
        output bit hit_target
    );
        bit busy;
        bit done;
        bit wait_conflict_unused;
        bit parity_error_unused;
        bit invalid_read_seen_unused;
        bit op_reject_busy_unused;
        bit write_reject_dma_active_unused;
        begin
            hit_target = 1'b0;
            for (int unsigned cycle = 0; cycle < wait_cycles; cycle++) begin
                dma_mem_read_status(busy,
                                    done,
                                    wait_conflict_unused,
                                    parity_error_unused,
                                    invalid_read_seen_unused,
                                    op_reject_busy_unused,
                                    write_reject_dma_active_unused);
                if (!busy && done) begin
                    hit_target = 1'b1;
                    break;
                end
                @(posedge clk);
            end
        end
    endtask

    task automatic dma_mem_start(
        input bit is_dst,
        input int unsigned index,
        input bit is_write,
        input logic [DATA_WIDTH-1:0] value
    );
        begin
            cfg_write32(DMA_SCRATCH_SEL_ADDR, {31'd0, is_dst});
            cfg_write32(DMA_SCRATCH_IDX_ADDR, index[31:0]);
            cfg_write32(DMA_SCRATCH_LO_ADDR, value[31:0]);
            cfg_write32(DMA_SCRATCH_HI_ADDR, value[63:32]);
            cfg_write32(DMA_MEM_OP_CTRL_ADDR, {30'd0, is_write, 1'b1});
        end
    endtask

    task automatic dma_mem_start_read(
        input bit is_dst,
        input int unsigned index
    );
        begin
            dma_mem_start(is_dst, index, 1'b0, '0);
        end
    endtask

    task automatic dma_mem_start_write(
        input bit is_dst,
        input int unsigned index,
        input logic [DATA_WIDTH-1:0] value
    );
        begin
            dma_mem_start(is_dst, index, 1'b1, value);
        end
    endtask

    task automatic dma_mem_read64(
        input bit is_dst,
        input int unsigned index,
        output logic [DATA_WIDTH-1:0] value
    );
        logic [31:0] lo_word;
        logic [31:0] hi_word;
        bit hit_target;
        begin
            dma_mem_start_read(is_dst, index);
            dma_mem_wait_done(2048, hit_target);
            if (!hit_target) begin
                $fatal(1, "MEM_OP read timed out is_dst=%0d index=%0d", is_dst, index);
            end
            cfg_read32(DMA_SCRATCH_LO_ADDR, lo_word);
            cfg_read32(DMA_SCRATCH_HI_ADDR, hi_word);
            value = {hi_word, lo_word};
        end
    endtask

    task automatic dma_mem_write64(
        input bit is_dst,
        input int unsigned index,
        input logic [DATA_WIDTH-1:0] value
    );
        bit hit_target;
        begin
            dma_mem_start_write(is_dst, index, value);
            dma_mem_wait_done(2048, hit_target);
            if (!hit_target) begin
                $fatal(1, "MEM_OP write timed out is_dst=%0d index=%0d", is_dst, index);
            end
        end
    endtask

    task automatic dma_mem_read_err_status(
        output logic [7:0] last_addr,
        output bit last_is_dst,
        output bit last_on_dma,
        output bit last_bank_id,
        output logic [2:0] last_err_kind
    );
        logic [31:0] word;
        begin
            cfg_read32(DMA_MEM_ERR_STATUS_ADDR, word);
            last_addr = word[7:0];
            last_is_dst = word[8];
            last_on_dma = word[9];
            last_bank_id = word[10];
            last_err_kind = word[13:11];
        end
    endtask

    task automatic dma_mem_read_counters(
        output int unsigned src_conflicts,
        output int unsigned dst_conflicts,
        output int unsigned src_wait_cycles,
        output int unsigned dst_wait_cycles,
        output int unsigned src_parity_errors,
        output int unsigned dst_parity_errors
    );
        logic [31:0] word;
        begin
            cfg_read32(DMA_MEM_CONFLICT_COUNT_ADDR, word);
            src_conflicts = word[15:0];
            dst_conflicts = word[31:16];
            cfg_read32(DMA_MEM_WAIT_COUNT_ADDR, word);
            src_wait_cycles = word[15:0];
            dst_wait_cycles = word[31:16];
            cfg_read32(DMA_MEM_ERR_COUNT_ADDR, word);
            src_parity_errors = word[15:0];
            dst_parity_errors = word[31:16];
        end
    endtask

    task automatic dma_mem_set_ret_cfg(
        input logic [1:0] src_sleep_mask,
        input logic [1:0] dst_sleep_mask,
        input logic [1:0] src_deep_mask,
        input logic [1:0] dst_deep_mask
    );
        begin
            cfg_write32(DMA_RET_CFG_ADDR,
                        {24'd0, dst_deep_mask, src_deep_mask, dst_sleep_mask, src_sleep_mask});
        end
    endtask

    task automatic dma_mem_read_ret_status(
        output bit lp_entry_seen,
        output bit wake_apply_seen,
        output bit src_corruption_seen,
        output bit dst_corruption_seen,
        output logic [1:0] last_low_power_state
    );
        logic [31:0] word;
        begin
            cfg_read32(DMA_RET_STATUS_ADDR, word);
            lp_entry_seen = word[0];
            wake_apply_seen = word[1];
            src_corruption_seen = word[2];
            dst_corruption_seen = word[3];
            last_low_power_state = word[5:4];
        end
    endtask

    task automatic dma_mem_read_valid_masks(
        output logic [1:0] src_invalid_bank_mask,
        output logic [1:0] dst_invalid_bank_mask
    );
        logic [31:0] word;
        begin
            cfg_read32(DMA_RET_VALID_STATUS_ADDR, word);
            src_invalid_bank_mask = word[1:0];
            dst_invalid_bank_mask = word[3:2];
        end
    endtask

    task automatic dma_mem_invert_parity(
        input bit target_dst,
        input int unsigned index
    );
        logic [31:0] status_word;
        begin
            cfg_write32(DMA_MEM_INJECT_ADDR_ADDR, index[31:0]);
            cfg_write32(DMA_MEM_INJECT_CTRL_ADDR, {29'd0, 1'b1, target_dst, 1'b1});
            for (int unsigned cycle = 0; cycle < 256; cycle++) begin
                cfg_read32(DMA_MEM_INJECT_STATUS_ADDR, status_word);
                if (!status_word[0] && status_word[1]) begin
                    break;
                end
                @(posedge clk);
            end
        end
    endtask

    task automatic dma_scratch_write64(
        input bit is_dst,
        input int unsigned index,
        input logic [DATA_WIDTH-1:0] value
    );
        begin
            dma_mem_write64(is_dst, index, value);
        end
    endtask

    task automatic dma_scratch_read64(
        input bit is_dst,
        input int unsigned index,
        output logic [DATA_WIDTH-1:0] value
    );
        logic [31:0] lo_word;
        logic [31:0] hi_word;
        begin
            dma_mem_read64(is_dst, index, value);
        end
    endtask

    task automatic dma_preload_source_range(
        input int unsigned base_index,
        input int unsigned len_words
    );
        for (int unsigned word_idx = 0; word_idx < len_words; word_idx++) begin
            dma_scratch_write64(1'b0, base_index + word_idx, dma_source_word(base_index + word_idx));
        end
    endtask

    task automatic dma_clear_dest_range(
        input int unsigned base_index,
        input int unsigned len_words
    );
        for (int unsigned word_idx = 0; word_idx < len_words; word_idx++) begin
            dma_scratch_write64(1'b1, base_index + word_idx, '0);
        end
    endtask

    task automatic dma_compare_dest_range(
        input int unsigned base_index,
        input int unsigned len_words
    );
        logic [DATA_WIDTH-1:0] observed_word;
        for (int unsigned word_idx = 0; word_idx < len_words; word_idx++) begin
            dma_scratch_read64(1'b1, base_index + word_idx, observed_word);
            u_dma_ref_scoreboard.compare_word(base_index + word_idx, observed_word);
        end
    endtask

    task automatic dma_read_submit_result(
        output bit accepted,
        output bit rejected,
        output logic [3:0] err_code,
        output logic [15:0] tag
    );
        logic [31:0] word;
        begin
            cfg_read32(DMA_SUBMIT_RESULT_ADDR, word);
            accepted = word[0];
            rejected = word[1];
            err_code = word[5:2];
            tag = word[21:6];
        end
    endtask

    task automatic dma_read_queue_status(
        input logic [7:0] addr,
        output bit empty,
        output bit full,
        output int unsigned count,
        output int unsigned head,
        output int unsigned tail
    );
        logic [31:0] word;
        begin
            cfg_read32(addr, word);
            empty = word[0];
            full = word[1];
            head = word[3:2];
            tail = word[5:4];
            count = word[8:6];
        end
    endtask

    task automatic dma_read_active_status(
        output bit active_valid,
        output bit comp_full_stall,
        output int unsigned state,
        output int unsigned submit_count,
        output int unsigned comp_count
    );
        logic [31:0] word;
        begin
            cfg_read32(DMA_ACTIVE_STATUS_ADDR, word);
            state = word[2:0];
            active_valid = word[3];
            comp_full_stall = word[4];
            submit_count = word[7:5];
            comp_count = word[10:8];
        end
    endtask

    task automatic dma_read_front_completion(
        output bit empty,
        output logic [15:0] tag,
        output logic [1:0] status,
        output logic [3:0] err_code,
        output logic [8:0] words_retired
    );
        logic [31:0] status_word;
        logic [31:0] tag_word;
        logic [31:0] words_word;
        bit full_unused;
        int unsigned count_unused;
        int unsigned head_unused;
        int unsigned tail_unused;
        begin
            dma_read_queue_status(DMA_COMP_Q_STATUS_ADDR, empty, full_unused, count_unused, head_unused, tail_unused);
            if (empty) begin
                tag = '0;
                status = 2'b00;
                err_code = '0;
                words_retired = '0;
            end else begin
                cfg_read32(DMA_COMP_TAG_ADDR, tag_word);
                cfg_read32(DMA_COMP_STATUS_ADDR, status_word);
                cfg_read32(DMA_COMP_WORDS_ADDR, words_word);
                tag = tag_word[15:0];
                err_code = status_word[3:0];
                status = status_word[5:4];
                words_retired = words_word[8:0];
            end
        end
    endtask

    task automatic dma_pop_completion();
        begin
            cfg_write32(DMA_COMP_POP_ADDR, 32'h0000_0001);
        end
    endtask

    task automatic dma_wait_for_completion_pushes(
        input int unsigned target_pushes,
        input int unsigned wait_cycles,
        output bit hit_target
    );
        begin
            hit_target = 1'b0;
            for (int unsigned cycle = 0; cycle < wait_cycles; cycle++) begin
                @(posedge clk);
                if (dma_completion_push_count >= target_pushes) begin
                    hit_target = 1'b1;
                    break;
                end
            end
        end
    endtask

    task automatic dma_wait_for_submit_count(
        input int unsigned target_count,
        input int unsigned wait_cycles,
        output bit hit_target
    );
        bit empty_local;
        bit full_local;
        int unsigned count_local;
        int unsigned head_local;
        int unsigned tail_local;
        begin
            hit_target = 1'b0;
            for (int unsigned cycle = 0; cycle < wait_cycles; cycle++) begin
                dma_read_queue_status(DMA_SUBMIT_Q_STATUS_ADDR,
                                      empty_local, full_local, count_local, head_local, tail_local);
                if (count_local == target_count) begin
                    hit_target = 1'b1;
                    break;
                end
                @(posedge clk);
            end
        end
    endtask

    task automatic dma_wait_for_comp_count(
        input int unsigned target_count,
        input int unsigned wait_cycles,
        output bit hit_target
    );
        bit empty_local;
        bit full_local;
        int unsigned count_local;
        int unsigned head_local;
        int unsigned tail_local;
        begin
            hit_target = 1'b0;
            for (int unsigned cycle = 0; cycle < wait_cycles; cycle++) begin
                dma_read_queue_status(DMA_COMP_Q_STATUS_ADDR,
                                      empty_local, full_local, count_local, head_local, tail_local);
                if (count_local == target_count) begin
                    hit_target = 1'b1;
                    break;
                end
                @(posedge clk);
            end
        end
    endtask

    task automatic dma_wait_for_idle(
        input int unsigned wait_cycles,
        output bit went_idle
    );
        bit active_valid_local;
        bit stall_local;
        int unsigned state_local;
        int unsigned submit_count_local;
        int unsigned comp_count_local;
        begin
            went_idle = 1'b0;
            for (int unsigned cycle = 0; cycle < wait_cycles; cycle++) begin
                dma_read_active_status(active_valid_local, stall_local, state_local, submit_count_local, comp_count_local);
                if (!active_valid_local && (submit_count_local == 0)) begin
                    went_idle = 1'b1;
                    break;
                end
                @(posedge clk);
            end
        end
    endtask

    task automatic dma_wait_for_state(
        input int unsigned target_state,
        input int unsigned wait_cycles,
        output bit hit_target
    );
        bit active_valid_local;
        bit stall_local;
        int unsigned state_local;
        int unsigned submit_count_local;
        int unsigned comp_count_local;
        begin
            hit_target = 1'b0;
            for (int unsigned cycle = 0; cycle < wait_cycles; cycle++) begin
                dma_read_active_status(active_valid_local,
                                       stall_local,
                                       state_local,
                                       submit_count_local,
                                       comp_count_local);
                if (active_valid_local && (state_local == target_state)) begin
                    hit_target = 1'b1;
                    break;
                end
                @(posedge clk);
            end
        end
    endtask

    task automatic wait_for_link_drain();
        for (int unsigned drain_cycle = 0; drain_cycle < POST_TARGET_DRAIN_CYCLES; drain_cycle++) begin
            @(posedge clk);
            if ((rx_count >= tx_count) &&
                !u_chiplet.u_die_a.flit_tx_valid &&
                !u_chiplet.u_die_b.flit_tx_valid &&
                !u_chiplet.u_die_a.resend_request &&
                !u_chiplet.u_die_b.resend_request) begin
                break;
            end
        end
    endtask

    task automatic run_dma_named_test(
        output bit pass_q,
        output string detail_q
    );
        bit local_ok;
        bit accepted;
        bit rejected;
        bit empty;
        bit full;
        bit hit_target;
        bit active_valid_local;
        bit stall_local;
        logic [3:0] err_code;
        logic [15:0] tag;
        logic [1:0] status;
        logic [8:0] words_retired;
        logic [31:0] status_word;
        logic [31:0] irq_word;
        logic [31:0] inject_status_word;
        logic [DATA_WIDTH-1:0] observed_word;
        logic [DATA_WIDTH-1:0] observed_word_b;
        logic [DATA_WIDTH-1:0] programmed_word;
        logic [7:0] last_mem_addr;
        logic [2:0] last_mem_err_kind;
        logic [1:0] src_invalid_bank_mask;
        logic [1:0] dst_invalid_bank_mask;
        logic [1:0] last_low_power_state;
        bit mem_busy;
        bit mem_done;
        bit mem_wait_conflict;
        bit mem_parity_error;
        bit mem_invalid_read_seen;
        bit mem_op_reject_busy;
        bit mem_write_reject_dma_active;
        bit mem_last_is_dst;
        bit mem_last_on_dma;
        bit mem_last_bank_id;
        bit lp_entry_seen;
        bit wake_apply_seen;
        bit src_corruption_seen;
        bit dst_corruption_seen;
        int unsigned src_conflicts;
        int unsigned dst_conflicts;
        int unsigned src_wait_cycles;
        int unsigned dst_wait_cycles;
        int unsigned src_parity_errors;
        int unsigned dst_parity_errors;
        int unsigned count_local;
        int unsigned head_local;
        int unsigned tail_local;
        int unsigned state_local;
        int unsigned submit_count_local;
        int unsigned comp_count_local;
        int unsigned push_before;

        pass_q = 1'b0;
        detail_q = "dma_unhandled_test";
        local_ok = 1'b1;

        wait (rst_n);
        dma_cov_reset_q = 1'b1;
        @(posedge clk);
        dma_cov_reset_q = 1'b0;
        power_state_q = PWR_RUN;
        dma_soft_reset();
        dma_set_irq_en(2'b00);
        dma_mem_set_ret_cfg(2'b11, 2'b11, 2'b00, 2'b00);

        case (test_name)
            "dma_queue_smoke": begin
                dma_preload_source_range(cfg.dma_src_base, cfg.dma_len_words);
                dma_clear_dest_range(cfg.dma_dst_base, cfg.dma_len_words);
                push_before = dma_completion_push_count;
                dma_set_irq_en(2'b01);
                dma_enqueue_desc(cfg.dma_src_base, cfg.dma_dst_base, cfg.dma_len_words, cfg.dma_tag);
                dma_wait_for_completion_pushes(push_before + 1, max_cycles_cfg, hit_target);
                local_ok = local_ok && hit_target;
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                local_ok = local_ok && !empty &&
                           (tag == cfg.dma_tag[15:0]) &&
                           (status == DMA_COMP_SUCCESS) &&
                           (words_retired == cfg.dma_len_words[8:0]);
                dma_compare_dest_range(cfg.dma_dst_base, cfg.dma_len_words);
                dma_pop_completion();
                dma_wait_for_idle(512, hit_target);
                pass_q = local_ok && hit_target && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_queue_smoke_clean" : "dma_completion_violation";
            end
            "dma_queue_back_to_back": begin
                dma_preload_source_range(cfg.dma_src_base, cfg.dma_len_words);
                dma_preload_source_range(cfg.dma_second_src_base, cfg.dma_second_len_words);
                dma_clear_dest_range(cfg.dma_dst_base, cfg.dma_len_words);
                dma_clear_dest_range(cfg.dma_second_dst_base, cfg.dma_second_len_words);
                push_before = dma_completion_push_count;
                dma_set_irq_en(2'b01);
                dma_enqueue_desc(cfg.dma_src_base, cfg.dma_dst_base, cfg.dma_len_words, cfg.dma_tag);
                dma_enqueue_desc(cfg.dma_second_src_base, cfg.dma_second_dst_base, cfg.dma_second_len_words, cfg.dma_second_tag);
                dma_wait_for_completion_pushes(push_before + 2, max_cycles_cfg, hit_target);
                local_ok = local_ok && hit_target;
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                local_ok = local_ok && !empty && (tag == cfg.dma_tag[15:0]) &&
                           (status == DMA_COMP_SUCCESS) && (words_retired == cfg.dma_len_words[8:0]);
                dma_pop_completion();
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                local_ok = local_ok && !empty && (tag == cfg.dma_second_tag[15:0]) &&
                           (status == DMA_COMP_SUCCESS) && (words_retired == cfg.dma_second_len_words[8:0]);
                dma_pop_completion();
                dma_compare_dest_range(cfg.dma_dst_base, cfg.dma_len_words);
                dma_compare_dest_range(cfg.dma_second_dst_base, cfg.dma_second_len_words);
                pass_q = local_ok && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_queue_back_to_back_clean" : "dma_completion_violation";
            end
            "dma_queue_full_reject": begin
                logic [31:0] overflow_word;
                dma_set_irq_en(2'b10);
                dma_preload_source_range(8, 20);
                power_state_q = PWR_SLEEP;
                for (int qidx = 0; qidx < 4; qidx++) begin
                    dma_enqueue_desc(8 + (qidx * 4), 64 + (qidx * 4), 4, 16'h2100 + qidx);
                end
                dma_wait_for_submit_count(4, 256, hit_target);
                local_ok = local_ok && hit_target;
                dma_enqueue_desc(40, 120, 4, 16'h2104);
                dma_read_submit_result(accepted, rejected, err_code, tag);
                local_ok = local_ok && !accepted && rejected && (err_code == DMA_ERR_QUEUE_FULL) && (tag == 16'h2104);
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                local_ok = local_ok && !empty && (status == DMA_COMP_SUBMIT_REJECT) &&
                           (err_code == DMA_ERR_QUEUE_FULL) && (tag == 16'h2104) && (words_retired == 0);
                dma_enqueue_desc(44, 124, 4, 16'h2105);
                dma_enqueue_desc(48, 128, 4, 16'h2106);
                dma_enqueue_desc(52, 132, 4, 16'h2107);
                dma_wait_for_comp_count(4, 256, hit_target);
                local_ok = local_ok && hit_target;
                dma_enqueue_desc(56, 136, 4, 16'h2108);
                cfg_read32(DMA_REJECT_OVF_ADDR, overflow_word);
                local_ok = local_ok && (overflow_word != 0);
                for (int reject_idx = 0; reject_idx < 4; reject_idx++) begin
                    dma_read_front_completion(empty, tag, status, err_code, words_retired);
                    local_ok = local_ok && !empty && (status == DMA_COMP_SUBMIT_REJECT);
                    dma_pop_completion();
                end
                power_state_q = PWR_RUN;
                dma_wait_for_completion_pushes(dma_completion_push_count + 4, max_cycles_cfg, hit_target);
                for (int success_idx = 0; success_idx < 4; success_idx++) begin
                    dma_read_front_completion(empty, tag, status, err_code, words_retired);
                    local_ok = local_ok && !empty && (status == DMA_COMP_SUCCESS);
                    dma_pop_completion();
                end
                dma_compare_dest_range(64, 4);
                dma_compare_dest_range(68, 4);
                dma_compare_dest_range(72, 4);
                dma_compare_dest_range(76, 4);
                repeat (16) @(posedge clk);
                pass_q = local_ok && hit_target && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_queue_full_reject_clean" : "dma_config_violation";
            end
            "dma_completion_fifo_drain": begin
                dma_set_irq_en(2'b01);
                dma_preload_source_range(96, 12);
                dma_clear_dest_range(144, 12);
                dma_enqueue_desc(96, 144, 4, 16'h2200);
                dma_enqueue_desc(100, 148, 4, 16'h2201);
                dma_enqueue_desc(104, 152, 4, 16'h2202);
                dma_wait_for_completion_pushes(dma_completion_push_count + 3, max_cycles_cfg, hit_target);
                local_ok = local_ok && hit_target;
                for (int pop_idx = 0; pop_idx < 3; pop_idx++) begin
                    dma_read_front_completion(empty, tag, status, err_code, words_retired);
                    local_ok = local_ok && !empty && (status == DMA_COMP_SUCCESS) &&
                               (tag == (16'h2200 + pop_idx)) && (words_retired == 4);
                    dma_pop_completion();
                end
                dma_read_queue_status(DMA_COMP_Q_STATUS_ADDR, empty, full, count_local, head_local, tail_local);
                dma_compare_dest_range(144, 12);
                pass_q = local_ok && empty && (count_local == 0) && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_completion_fifo_drain_clean" : "dma_completion_violation";
            end
            "dma_irq_masking": begin
                dma_preload_source_range(cfg.dma_src_base, cfg.dma_len_words);
                dma_clear_dest_range(cfg.dma_dst_base, cfg.dma_len_words);
                dma_set_irq_en(2'b00);
                dma_enqueue_desc(cfg.dma_src_base, cfg.dma_dst_base, cfg.dma_len_words, cfg.dma_tag);
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                cfg_read32(DMA_IRQ_STATUS_ADDR, irq_word);
                local_ok = local_ok && hit_target && (irq_word[0] == 1'b1) && !irq_done_monitor;
                dma_set_irq_en(2'b01);
                @(posedge clk);
                local_ok = local_ok && irq_done_monitor;
                dma_clear_irq(2'b01);
                @(posedge clk);
                local_ok = local_ok && !irq_done_monitor;
                dma_pop_completion();

                dma_set_irq_en(2'b00);
                dma_enqueue_desc(250, cfg.dma_dst_base, 3, 16'h2300);
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                local_ok = local_ok && !empty && (status == DMA_COMP_SUBMIT_REJECT) &&
                           (err_code == DMA_ERR_ODD_LEN) && !irq_done_monitor;
                cfg_read32(DMA_IRQ_STATUS_ADDR, irq_word);
                local_ok = local_ok && (irq_word[1] == 1'b1);
                dma_set_irq_en(2'b10);
                @(posedge clk);
                local_ok = local_ok && irq_done_monitor;
                dma_clear_irq(2'b10);
                dma_pop_completion();
                pass_q = local_ok;
                detail_q = pass_q ? "dma_irq_masking_clean" : "dma_irq_mask_violation";
            end
            "dma_odd_len_reject": begin
                dma_clear_dest_range(cfg.dma_dst_base, 4);
                dma_enqueue_desc(cfg.dma_src_base, cfg.dma_dst_base, 3, cfg.dma_tag);
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                dma_compare_dest_range(cfg.dma_dst_base, 4);
                pass_q = !empty && (status == DMA_COMP_SUBMIT_REJECT) &&
                         (err_code == DMA_ERR_ODD_LEN) && (words_retired == 0) &&
                         (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_odd_len_reject_clean" : "dma_config_violation";
            end
            "dma_range_reject": begin
                dma_clear_dest_range(cfg.dma_dst_base, 8);
                dma_enqueue_desc(cfg.dma_src_base, cfg.dma_dst_base, cfg.dma_len_words, cfg.dma_tag);
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                dma_compare_dest_range(cfg.dma_dst_base, 8);
                pass_q = !empty && (status == DMA_COMP_SUBMIT_REJECT) &&
                         (err_code == DMA_ERR_RANGE) && (words_retired == 0) &&
                         (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_range_reject_clean" : "dma_config_violation";
            end
            "dma_timeout_error": begin
                dma_preload_source_range(cfg.dma_src_base, cfg.dma_len_words);
                dma_clear_dest_range(cfg.dma_dst_base, cfg.dma_len_words);
                push_before = dma_completion_push_count;
                force u_chiplet.u_die_a.dma_rx_stream_valid = 1'b0;
                dma_enqueue_desc(cfg.dma_src_base, cfg.dma_dst_base, cfg.dma_len_words, cfg.dma_tag);
                dma_wait_for_completion_pushes(push_before + 1, max_cycles_cfg, hit_target);
                release u_chiplet.u_die_a.dma_rx_stream_valid;
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                pass_q = hit_target && !empty && (status == DMA_COMP_RUNTIME_ERROR) &&
                         (err_code == DMA_ERR_TIMEOUT) && (words_retired == 0);
                detail_q = pass_q ? "dma_timeout_error_clean" : "dma_config_violation";
            end
            "dma_retry_recover_queue": begin
                dma_preload_source_range(64, 4);
                dma_preload_source_range(80, 4);
                dma_clear_dest_range(96, 4);
                dma_clear_dest_range(112, 4);
                dma_set_irq_en(2'b01);
                dma_enqueue_desc(64, 96, 4, 16'h2400);
                dma_enqueue_desc(80, 112, 4, 16'h2401);
                dma_wait_for_completion_pushes(dma_completion_push_count + 2, max_cycles_cfg, hit_target);
                dma_compare_dest_range(96, 4);
                dma_compare_dest_range(112, 4);
                pass_q = hit_target && dma_retry_seen_q && dma_recovery_seen_q && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_retry_recover_queue_clean" : "dma_completion_violation";
            end
            "dma_power_sleep_resume_queue": begin
                dma_preload_source_range(72, 8);
                dma_clear_dest_range(112, 8);
                repeat ((power_event_start_cfg > 20) ? (power_event_start_cfg - 20) : 1) @(posedge clk);
                dma_set_irq_en(2'b01);
                dma_enqueue_desc(72, 112, 8, 16'h2500);
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                dma_compare_dest_range(112, 8);
                pass_q = hit_target && dma_sleep_resume_seen_q && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_power_sleep_resume_queue_clean" : "dma_completion_violation";
            end
            "dma_comp_fifo_full_stall": begin
                dma_set_irq_en(2'b00);
                dma_preload_source_range(120, 20);
                dma_clear_dest_range(160, 20);
                for (int didx = 0; didx < 5; didx++) begin
                    dma_enqueue_desc(120 + (didx * 4), 160 + (didx * 4), 4, 16'h2600 + didx);
                end
                dma_wait_for_comp_count(4, max_cycles_cfg, hit_target);
                local_ok = local_ok && hit_target;
                dma_read_active_status(active_valid_local, stall_local, state_local, submit_count_local, comp_count_local);
                local_ok = local_ok && (comp_count_local == 4);
                repeat (256) @(posedge clk);
                dma_pop_completion();
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, 2048, hit_target);
                local_ok = local_ok && hit_target;
                dma_read_active_status(active_valid_local, stall_local, state_local, submit_count_local, comp_count_local);
                pass_q = local_ok && (dma_desc_completed_count == 5) &&
                         (dma_completion_push_count == 5) && (dma_completion_pop_count >= 1);
                detail_q = pass_q ? "dma_comp_fifo_full_stall_clean" : "dma_completion_violation";
            end
            "dma_irq_pending_then_enable": begin
                dma_set_irq_en(2'b00);
                dma_preload_source_range(140, 4);
                dma_clear_dest_range(196, 4);
                dma_enqueue_desc(140, 196, 4, 16'h2700);
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                cfg_read32(DMA_IRQ_STATUS_ADDR, irq_word);
                local_ok = local_ok && hit_target && !irq_done_monitor && irq_word[0];
                dma_set_irq_en(2'b01);
                @(posedge clk);
                pass_q = local_ok && irq_done_monitor;
                detail_q = pass_q ? "dma_irq_pending_then_enable_clean" : "dma_irq_mask_violation";
            end
            "dma_comp_pop_empty": begin
                dma_read_queue_status(DMA_COMP_Q_STATUS_ADDR, empty, full, count_local, head_local, tail_local);
                local_ok = local_ok && empty && (count_local == 0);
                dma_pop_completion();
                dma_read_queue_status(DMA_COMP_Q_STATUS_ADDR, empty, full, count_local, head_local, tail_local);
                pass_q = local_ok && empty && (count_local == 0);
                detail_q = pass_q ? "dma_comp_pop_empty_clean" : "dma_completion_violation";
            end
            "dma_reset_mid_queue": begin
                power_state_q = PWR_SLEEP;
                dma_enqueue_desc(8, 40, 4, 16'h2800);
                dma_enqueue_desc(12, 44, 4, 16'h2801);
                dma_wait_for_submit_count(2, 256, hit_target);
                local_ok = local_ok && hit_target;
                dma_hard_reset();
                dma_read_queue_status(DMA_SUBMIT_Q_STATUS_ADDR, empty, full, count_local, head_local, tail_local);
                local_ok = local_ok && empty && (count_local == 0);
                dma_read_queue_status(DMA_COMP_Q_STATUS_ADDR, empty, full, count_local, head_local, tail_local);
                power_state_q = PWR_RUN;
                pass_q = local_ok && empty && (count_local == 0) && !u_chiplet.u_die_a.u_dma.active_valid_q;
                detail_q = pass_q ? "dma_reset_mid_queue_clean" : "dma_config_violation";
            end
            "dma_tag_reuse": begin
                dma_preload_source_range(20, 8);
                dma_clear_dest_range(80, 8);
                dma_enqueue_desc(20, 80, 4, 16'h2900);
                dma_enqueue_desc(24, 84, 4, 16'h2900);
                dma_wait_for_completion_pushes(dma_completion_push_count + 2, max_cycles_cfg, hit_target);
                dma_compare_dest_range(80, 8);
                pass_q = hit_target && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_tag_reuse_clean" : "dma_completion_violation";
            end
            "dma_power_state_retention_matrix": begin
                power_state_q = PWR_SLEEP;
                dma_enqueue_desc(32, 88, 4, 16'h2a00);
                dma_wait_for_submit_count(1, 256, hit_target);
                local_ok = local_ok && hit_target;
                power_state_q = PWR_RUN;
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                local_ok = local_ok && hit_target;
                power_state_q = PWR_SLEEP;
                dma_enqueue_desc(40, 96, 4, 16'h2a01);
                dma_wait_for_submit_count(1, 256, hit_target);
                local_ok = local_ok && hit_target;
                power_state_q = PWR_DEEP_SLEEP;
                repeat (8) @(posedge clk);
                power_state_q = PWR_RUN;
                cfg_read32(DMA_SRC_BASE_ADDR, status_word);
                local_ok = local_ok && (status_word == 0);
                dma_read_queue_status(DMA_SUBMIT_Q_STATUS_ADDR, empty, full, count_local, head_local, tail_local);
                local_ok = local_ok && empty && (count_local == 0);
                dma_read_queue_status(DMA_COMP_Q_STATUS_ADDR, empty, full, count_local, head_local, tail_local);
                pass_q = local_ok && empty && (count_local == 0) && !u_chiplet.u_die_a.u_dma.active_valid_q;
                detail_q = pass_q ? "dma_power_state_retention_matrix_clean" : "dma_config_violation";
            end
            "dma_crypto_only_submit_blocked": begin
                power_state_q = PWR_CRYPTO_ONLY;
                dma_enqueue_desc(8, 40, 4, 16'h2b00);
                dma_read_submit_result(accepted, rejected, err_code, tag);
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                local_ok = local_ok && !accepted && rejected &&
                           (status == DMA_COMP_SUBMIT_REJECT) &&
                           (err_code == DMA_ERR_SUBMIT_BLOCKED);
                dma_pop_completion();
                power_state_q = PWR_RUN;
                pass_q = local_ok;
                detail_q = pass_q ? "dma_crypto_only_submit_blocked_clean" : "dma_config_violation";
            end
            "mem_bank_parallel_service": begin
                dma_preload_source_range(32, 8);
                dma_clear_dest_range(96, 8);
                dma_enqueue_desc(32, 96, 8, 16'h3000);
                dma_wait_for_state(2, 512, hit_target);
                local_ok = local_ok && hit_target;
                dma_scratch_read64(1'b0, 33, observed_word);
                dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                    mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                dma_mem_read_counters(src_conflicts, dst_conflicts, src_wait_cycles, dst_wait_cycles,
                                      src_parity_errors, dst_parity_errors);
                local_ok = local_ok && !mem_busy && mem_done && !mem_wait_conflict &&
                           !mem_parity_error && !mem_invalid_read_seen &&
                           (observed_word == dma_source_word(33)) &&
                           (src_conflicts == 0) && (src_wait_cycles == 0);
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                dma_compare_dest_range(96, 8);
                pass_q = local_ok && hit_target && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "mem_bank_parallel_service_clean" : "memory_bank_conflict_violation";
            end
            "mem_src_bank_conflict": begin
                dma_preload_source_range(40, 8);
                dma_clear_dest_range(104, 8);
                dma_mem_read_counters(src_conflicts, dst_conflicts, src_wait_cycles, dst_wait_cycles,
                                      src_parity_errors, dst_parity_errors);
                dma_enqueue_desc(40, 104, 8, 16'h3001);
                dma_wait_for_state(2, 512, hit_target);
                local_ok = local_ok && hit_target;
                force u_chiplet.u_die_a.tx_stream_ready = 1'b0;
                repeat (4) @(posedge clk);
                count_local = u_chiplet.u_die_a.u_dma.tx_src_bank ? 41 : 40;
                dma_mem_start_read(1'b0, count_local);
                repeat (4) @(posedge clk);
                release u_chiplet.u_die_a.tx_stream_ready;
                dma_mem_wait_done(2048, hit_target);
                local_ok = local_ok && hit_target;
                cfg_read32(DMA_SCRATCH_LO_ADDR, status_word);
                cfg_read32(DMA_SCRATCH_HI_ADDR, irq_word);
                observed_word = {irq_word, status_word};
                dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                    mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                dma_mem_read_counters(src_conflicts, dst_conflicts, src_wait_cycles, dst_wait_cycles,
                                      src_parity_errors, dst_parity_errors);
                local_ok = local_ok && mem_done && mem_wait_conflict && !mem_parity_error &&
                           !mem_invalid_read_seen &&
                           (observed_word == dma_source_word(count_local)) &&
                           (src_conflicts != 0) && (src_wait_cycles != 0);
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                dma_compare_dest_range(104, 8);
                pass_q = local_ok && hit_target && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "mem_src_bank_conflict_clean" : "memory_bank_conflict_violation";
            end
            "mem_dst_bank_conflict": begin
                dma_preload_source_range(48, 8);
                dma_clear_dest_range(112, 8);
                dma_enqueue_desc(48, 112, 8, 16'h3002);
                dma_wait_for_state(3, 1024, hit_target);
                local_ok = local_ok && hit_target;
                dst_conflicts = 0;
                dst_wait_cycles = 0;
                for (int attempt = 0; attempt < 8; attempt++) begin
                    dma_scratch_read64(1'b1, 112, observed_word);
                    dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                        mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                    dma_mem_read_counters(src_conflicts, dst_conflicts, src_wait_cycles, dst_wait_cycles,
                                          src_parity_errors, dst_parity_errors);
                    if (dst_conflicts != 0) begin
                        break;
                    end
                end
                local_ok = local_ok && mem_done && !mem_parity_error &&
                           (dst_conflicts != 0) && (dst_wait_cycles != 0);
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                dma_compare_dest_range(112, 8);
                pass_q = local_ok && hit_target && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "mem_dst_bank_conflict_clean" : "memory_bank_conflict_violation";
            end
            "mem_read_while_dma": begin
                dma_preload_source_range(56, 8);
                dma_clear_dest_range(120, 8);
                dma_enqueue_desc(56, 120, 8, 16'h3003);
                dma_wait_for_state(2, 512, hit_target);
                local_ok = local_ok && hit_target && u_chiplet.u_die_a.u_dma.active_valid_q;
                dma_scratch_read64(1'b0, 57, observed_word);
                dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                    mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                local_ok = local_ok && mem_done && !mem_parity_error && !mem_invalid_read_seen &&
                           !mem_op_reject_busy && !mem_write_reject_dma_active &&
                           (observed_word == dma_source_word(57));
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                dma_compare_dest_range(120, 8);
                pass_q = local_ok && hit_target && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "mem_read_while_dma_clean" : "memory_read_visibility_violation";
            end
            "mem_write_while_dma_reject": begin
                dma_preload_source_range(64, 8);
                dma_clear_dest_range(128, 8);
                dma_enqueue_desc(64, 128, 8, 16'h3004);
                dma_wait_for_state(2, 512, hit_target);
                local_ok = local_ok && hit_target;
                dma_mem_start_write(1'b0, 64, 64'hFACE_CAFE_1234_5678);
                dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                    mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                local_ok = local_ok && !mem_busy && mem_write_reject_dma_active;
                dma_scratch_read64(1'b0, 64, observed_word);
                local_ok = local_ok && (observed_word == dma_source_word(64));
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                dma_compare_dest_range(128, 8);
                pass_q = local_ok && hit_target && (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "mem_write_while_dma_reject_clean" : "memory_write_reject_violation";
            end
            "mem_parity_src_detect": begin
                dma_preload_source_range(72, 4);
                dma_clear_dest_range(136, 4);
                dma_mem_invert_parity(1'b0, 72);
                dma_enqueue_desc(72, 136, 4, 16'h3005);
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                dma_mem_read_counters(src_conflicts, dst_conflicts, src_wait_cycles, dst_wait_cycles,
                                      src_parity_errors, dst_parity_errors);
                dma_mem_read_err_status(last_mem_addr, mem_last_is_dst, mem_last_on_dma,
                                        mem_last_bank_id, last_mem_err_kind);
                pass_q = hit_target && !empty && (status == DMA_COMP_RUNTIME_ERROR) &&
                         (err_code == DMA_ERR_MEM_PARITY) && (words_retired == 0) &&
                         (src_parity_errors != 0) && !mem_last_is_dst && mem_last_on_dma &&
                         (last_mem_err_kind == 3'd2) && (last_mem_addr == 8'd72);
                detail_q = pass_q ? "mem_parity_src_detect_clean" : "memory_integrity_violation";
            end
            "mem_parity_dst_maint_detect": begin
                programmed_word = 64'h1234_5678_9ABC_DEF0;
                dma_scratch_write64(1'b1, 90, programmed_word);
                dma_mem_invert_parity(1'b1, 90);
                dma_scratch_read64(1'b1, 90, observed_word);
                dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                    mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                dma_mem_read_counters(src_conflicts, dst_conflicts, src_wait_cycles, dst_wait_cycles,
                                      src_parity_errors, dst_parity_errors);
                dma_mem_read_err_status(last_mem_addr, mem_last_is_dst, mem_last_on_dma,
                                        mem_last_bank_id, last_mem_err_kind);
                pass_q = mem_done && mem_parity_error && !mem_invalid_read_seen &&
                         (observed_word == programmed_word) &&
                         (dst_parity_errors != 0) && mem_last_is_dst && !mem_last_on_dma &&
                         (last_mem_err_kind == 3'd1) && (last_mem_addr == 8'd90);
                detail_q = pass_q ? "mem_parity_dst_maint_detect_clean" : "memory_integrity_violation";
            end
            "mem_sleep_retained_bank": begin
                programmed_word = 64'h0101_0101_0101_0101;
                observed_word_b = 64'h0202_0202_0202_0202;
                dma_mem_set_ret_cfg(2'b11, 2'b11, 2'b00, 2'b00);
                dma_scratch_write64(1'b0, 0, programmed_word);
                dma_scratch_write64(1'b0, 1, observed_word_b);
                power_state_q = PWR_SLEEP;
                repeat (8) @(posedge clk);
                power_state_q = PWR_RUN;
                repeat (4) @(posedge clk);
                dma_mem_read_valid_masks(src_invalid_bank_mask, dst_invalid_bank_mask);
                dma_scratch_read64(1'b0, 0, observed_word);
                dma_scratch_read64(1'b0, 1, observed_word_b);
                dma_mem_read_ret_status(lp_entry_seen, wake_apply_seen, src_corruption_seen,
                                        dst_corruption_seen, last_low_power_state);
                pass_q = (src_invalid_bank_mask == 2'b00) && (dst_invalid_bank_mask == 2'b00) &&
                         (observed_word == programmed_word) && (observed_word_b == 64'h0202_0202_0202_0202) &&
                         lp_entry_seen && wake_apply_seen && !src_corruption_seen && !dst_corruption_seen &&
                         (last_low_power_state == PWR_SLEEP);
                detail_q = pass_q ? "mem_sleep_retained_bank_clean" : "memory_retention_violation";
            end
            "mem_sleep_nonretained_bank": begin
                dma_mem_set_ret_cfg(2'b01, 2'b11, 2'b00, 2'b00);
                dma_scratch_write64(1'b0, 0, 64'hAAAA_BBBB_CCCC_DDDD);
                dma_scratch_write64(1'b0, 1, 64'h1111_2222_3333_4444);
                power_state_q = PWR_SLEEP;
                repeat (8) @(posedge clk);
                power_state_q = PWR_RUN;
                repeat (4) @(posedge clk);
                dma_mem_read_valid_masks(src_invalid_bank_mask, dst_invalid_bank_mask);
                dma_scratch_read64(1'b0, 0, observed_word);
                dma_scratch_read64(1'b0, 1, observed_word_b);
                dma_mem_read_ret_status(lp_entry_seen, wake_apply_seen, src_corruption_seen,
                                        dst_corruption_seen, last_low_power_state);
                pass_q = (src_invalid_bank_mask == 2'b10) && (dst_invalid_bank_mask == 2'b00) &&
                         (observed_word == 64'hAAAA_BBBB_CCCC_DDDD) &&
                         (observed_word_b == mem_poison_word(1)) &&
                         src_corruption_seen && lp_entry_seen && wake_apply_seen &&
                         (last_low_power_state == PWR_SLEEP);
                detail_q = pass_q ? "mem_sleep_nonretained_bank_clean" : "memory_retention_violation";
            end
            "mem_nonretained_readback_poison_clean": begin
                dma_mem_set_ret_cfg(2'b01, 2'b11, 2'b00, 2'b00);
                dma_scratch_write64(1'b0, 1, 64'h5555_6666_7777_8888);
                power_state_q = PWR_SLEEP;
                repeat (8) @(posedge clk);
                power_state_q = PWR_RUN;
                repeat (4) @(posedge clk);
                dma_scratch_read64(1'b0, 1, observed_word);
                dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                    mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                dma_mem_read_err_status(last_mem_addr, mem_last_is_dst, mem_last_on_dma,
                                        mem_last_bank_id, last_mem_err_kind);
                pass_q = mem_done && !mem_parity_error && mem_invalid_read_seen &&
                         (observed_word == mem_poison_word(1)) &&
                         !mem_last_is_dst && !mem_last_on_dma &&
                         (last_mem_err_kind == 3'd3) && (last_mem_addr == 8'd1);
                detail_q = pass_q ? "mem_nonretained_readback_poison_clean_clean" : "memory_retention_violation";
            end
            "mem_invalid_clear_on_write": begin
                programmed_word = 64'hA5A5_5A5A_F0F0_0F0F;
                dma_mem_set_ret_cfg(2'b01, 2'b11, 2'b00, 2'b00);
                dma_scratch_write64(1'b0, 1, 64'h9999_AAAA_BBBB_CCCC);
                power_state_q = PWR_SLEEP;
                repeat (8) @(posedge clk);
                power_state_q = PWR_RUN;
                repeat (4) @(posedge clk);
                dma_mem_read_valid_masks(src_invalid_bank_mask, dst_invalid_bank_mask);
                local_ok = local_ok && (src_invalid_bank_mask == 2'b10);
                dma_scratch_write64(1'b0, 1, programmed_word);
                dma_mem_read_valid_masks(src_invalid_bank_mask, dst_invalid_bank_mask);
                local_ok = local_ok && (src_invalid_bank_mask == 2'b00);
                dma_scratch_read64(1'b0, 1, observed_word);
                dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                    mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                pass_q = local_ok && mem_done && !mem_parity_error && !mem_invalid_read_seen &&
                         (observed_word == programmed_word);
                detail_q = pass_q ? "mem_invalid_clear_on_write_clean" : "memory_retention_violation";
            end
            "mem_deep_sleep_retention_matrix": begin
                dma_mem_set_ret_cfg(2'b11, 2'b11, 2'b01, 2'b10);
                dma_scratch_write64(1'b0, 0, 64'h1010_1010_1010_1010);
                dma_scratch_write64(1'b0, 1, 64'h2020_2020_2020_2020);
                dma_scratch_write64(1'b1, 0, 64'h3030_3030_3030_3030);
                dma_scratch_write64(1'b1, 1, 64'h4040_4040_4040_4040);
                power_state_q = PWR_DEEP_SLEEP;
                repeat (8) @(posedge clk);
                power_state_q = PWR_RUN;
                repeat (4) @(posedge clk);
                dma_mem_read_valid_masks(src_invalid_bank_mask, dst_invalid_bank_mask);
                dma_scratch_read64(1'b0, 0, observed_word);
                dma_scratch_read64(1'b0, 1, observed_word_b);
                local_ok = local_ok && (observed_word == 64'h1010_1010_1010_1010) &&
                           (observed_word_b == mem_poison_word(1));
                dma_scratch_read64(1'b1, 0, observed_word);
                dma_scratch_read64(1'b1, 1, observed_word_b);
                dma_mem_read_ret_status(lp_entry_seen, wake_apply_seen, src_corruption_seen,
                                        dst_corruption_seen, last_low_power_state);
                pass_q = local_ok && (src_invalid_bank_mask == 2'b10) && (dst_invalid_bank_mask == 2'b01) &&
                         (observed_word == mem_poison_word(0)) &&
                         (observed_word_b == 64'h4040_4040_4040_4040) &&
                         src_corruption_seen && dst_corruption_seen &&
                         lp_entry_seen && wake_apply_seen && (last_low_power_state == PWR_DEEP_SLEEP);
                detail_q = pass_q ? "mem_deep_sleep_retention_matrix_clean" : "memory_retention_violation";
            end
            "mem_crypto_only_cfg_access": begin
                programmed_word = 64'hCAFE_BABE_0000_0012;
                dma_scratch_write64(1'b0, 18, programmed_word);
                power_state_q = PWR_CRYPTO_ONLY;
                dma_scratch_read64(1'b0, 18, observed_word);
                dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                    mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                local_ok = local_ok && mem_done && !mem_parity_error && !mem_invalid_read_seen &&
                           (observed_word == programmed_word);
                dma_scratch_write64(1'b0, 19, 64'hABCD_EF01_2345_6789);
                dma_scratch_read64(1'b0, 19, observed_word_b);
                local_ok = local_ok && (observed_word_b == 64'hABCD_EF01_2345_6789);
                dma_enqueue_desc(8, 40, 4, 16'h3006);
                dma_read_submit_result(accepted, rejected, err_code, tag);
                dma_read_front_completion(empty, tag, status, err_code, words_retired);
                local_ok = local_ok && !accepted && rejected && !empty &&
                           (status == DMA_COMP_SUBMIT_REJECT) &&
                           (err_code == DMA_ERR_SUBMIT_BLOCKED);
                dma_pop_completion();
                power_state_q = PWR_RUN;
                pass_q = local_ok;
                detail_q = pass_q ? "mem_crypto_only_cfg_access_clean" : "memory_power_mode_violation";
            end
            "mem_bug_parity_skip": begin
                programmed_word = 64'h0BAD_F00D_1111_2222;
                dma_scratch_write64(1'b1, 94, programmed_word);
                dma_mem_invert_parity(1'b1, 94);
                dma_scratch_read64(1'b1, 94, observed_word);
                dma_mem_read_status(mem_busy, mem_done, mem_wait_conflict, mem_parity_error,
                                    mem_invalid_read_seen, mem_op_reject_busy, mem_write_reject_dma_active);
                dma_mem_read_counters(src_conflicts, dst_conflicts, src_wait_cycles, dst_wait_cycles,
                                      src_parity_errors, dst_parity_errors);
                dma_mem_read_err_status(last_mem_addr, mem_last_is_dst, mem_last_on_dma,
                                        mem_last_bank_id, last_mem_err_kind);
                pass_q = mem_done && mem_parity_error && !mem_invalid_read_seen &&
                         (observed_word == programmed_word) &&
                         (dst_parity_errors != 0) && mem_last_is_dst && !mem_last_on_dma &&
                         (last_mem_err_kind == 3'd1) && (last_mem_addr == 8'd94);
                detail_q = pass_q ? "memory_bug_missed" : "memory_integrity_violation";
            end
            "dma_bug_done_early": begin
                dma_preload_source_range(cfg.dma_src_base, cfg.dma_len_words);
                dma_clear_dest_range(cfg.dma_dst_base, cfg.dma_len_words);
                dma_enqueue_desc(cfg.dma_src_base, cfg.dma_dst_base, cfg.dma_len_words, cfg.dma_tag);
                dma_wait_for_completion_pushes(dma_completion_push_count + 1, max_cycles_cfg, hit_target);
                dma_compare_dest_range(cfg.dma_dst_base, cfg.dma_len_words);
                pass_q = hit_target &&
                         (dma_last_completion_status_q == DMA_COMP_SUCCESS) &&
                         (dma_last_words_retired_q == cfg.dma_len_words) &&
                         (dma_mem_mismatch_count == 0);
                detail_q = pass_q ? "dma_bug_missed" : "dma_completion_violation";
            end
            default: begin
                pass_q = 1'b0;
                detail_q = "dma_unhandled_test";
            end
        endcase

        cfg_read32(DMA_STATUS_ADDR, status_word);
        if (pass_q && status_word[0]) begin
            pass_q = 1'b0;
            detail_q = "dma_status_busy_stuck";
        end
    endtask

    initial begin
        bit pass_q;
        string detail_q;
        wait (tb_cfg_ready);
        `TB_TIMEOUT(clk, max_cycles_cfg)
        if (use_dma_cfg) begin
            run_dma_named_test(pass_q, detail_q);
            wait_for_link_drain();
            if (pass_q) begin
                if ((test_name == "dma_retry_recover_queue") ||
                    (test_name == "dma_power_sleep_resume_queue")) begin
                    pass_q = (latency_violation_count == 0 &&
                              power_illegal_activity_violations == 0);
                end else begin
                    pass_q = (flit_mismatch_count == 0 && flit_drop_count == 0 && latency_violation_count == 0 &&
                              power_illegal_activity_violations == 0 && power_resume_violations == 0);
                end
                if (!pass_q) begin
                    detail_q = "dma_link_side_violation";
                end
            end
        end else begin
            wait (cipher_updates >= target_cipher_updates_cfg);
            wait_for_link_drain();

            if (wrong_key_mode || misalign_mode) begin
                pass_q = (mismatch_count != 0 && expected_empty_count == 0);
                detail_q = pass_q ? "negative_check_caught" : "negative_check_missed";
            end else if (expect_expected_empty_mode) begin
                pass_q = (mismatch_count == 0 && expected_empty_count != 0 &&
                          power_illegal_activity_violations == 0 && power_resume_violations == 0);
                detail_q = pass_q ? "expected_empty_detected" : "expected_empty_missed";
            end else if (scenario_kind == "power_proxy") begin
                pass_q = (mismatch_count == 0 && expected_empty_count == 0 && !crypto_error_flag &&
                          flit_mismatch_count == 0 && flit_drop_count == 0 && latency_violation_count == 0 &&
                          power_illegal_activity_violations == 0 && power_resume_violations == 0);
                detail_q = pass_q ? "power_proxy_clean" : "power_proxy_violation";
            end else begin
                pass_q = (mismatch_count == 0 && expected_empty_count == 0 && !crypto_error_flag &&
                          flit_mismatch_count == 0 && flit_drop_count == 0 && latency_violation_count == 0);
                detail_q = pass_q ? "clean" : "soc_scoreboard_violation";
            end
        end

        u_flit_scoreboard.write_report(score_path);
        u_stats.write_coverage(cov_path);
        u_power_mon.write_report(power_path, power_mode_cfg);
        u_stats.emit_result(
            "tb_soc_chiplets",
            test_name,
            scenario_kind,
            seed,
            bug_mode,
            pass_q,
            detail_q,
            tx_count,
            rx_count,
            retry_count,
            flit_mismatch_count,
            flit_drop_count,
            latency_violation_count,
            mismatch_count,
            expected_empty_count,
            dma_desc_completed_count,
            dma_submit_accepted_count,
            dma_submit_rejected_count,
            dma_completion_push_count,
            dma_completion_pop_count,
            dma_irq_count,
            dma_error_count,
            dma_mem_mismatch_count,
            score_path,
            cov_path,
            power_path
        );

        if (use_dma_cfg) begin
            if (!pass_q) begin
                $error("DMA test failed: detail=%s dma_mismatch=%0d desc=%0d submit_ok=%0d submit_reject=%0d comp_push=%0d comp_pop=%0d irq=%0d err=%0d flit_mismatch=%0d drop=%0d latency=%0d",
                       detail_q, dma_mem_mismatch_count, dma_desc_completed_count, dma_submit_accepted_count,
                       dma_submit_rejected_count, dma_completion_push_count, dma_completion_pop_count, dma_irq_count, dma_error_count,
                       flit_mismatch_count, flit_drop_count, latency_violation_count);
            end
        end else if (wrong_key_mode || misalign_mode) begin
            if (mismatch_count == 0) begin
                $error("Negative test did not flag mismatches as expected");
            end
        end else if (expect_expected_empty_mode) begin
            if (expected_empty_count == 0 || mismatch_count != 0) begin
                $error("Expected-empty negative test missed: mismatch=%0d empty=%0d",
                       mismatch_count, expected_empty_count);
            end
        end else if (scenario_kind == "power_proxy") begin
            if (!pass_q) begin
                $error("Power proxy violation: mismatch=%0d empty=%0d flit_mismatch=%0d drop=%0d power_illegal=%0d resume=%0d",
                       mismatch_count, expected_empty_count, flit_mismatch_count, flit_drop_count,
                       power_illegal_activity_violations, power_resume_violations);
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
