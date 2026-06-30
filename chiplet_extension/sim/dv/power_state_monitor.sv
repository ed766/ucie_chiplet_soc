`ifndef UCIE_POWER_STATE_MONITOR_SV
`define UCIE_POWER_STATE_MONITOR_SV

module power_state_monitor #(
    parameter int CRYPTO_DRAIN_GRACE = 12,
    parameter int RESUME_WINDOW = 256
) (
    input  logic        clk,
    input  logic        mon_rst_n,
    input  logic [1:0]  power_state,
    input  logic        producer_valid,
    input  logic        tx_fire,
    input  logic        rx_fire,
    input  logic        e2e_update,
    input  logic        sw_pd_a_traffic,
    input  logic        sw_pd_a_dma,
    input  logic        sw_pd_a_link,
    input  logic        sw_pd_b_crypto,
    input  logic        sw_pd_b_link,
    input  logic        sw_pd_channel,
    input  logic        iso_pd_a_traffic_n,
    input  logic        iso_pd_a_dma_n,
    input  logic        iso_pd_a_link_n,
    input  logic        iso_pd_b_crypto_n,
    input  logic        iso_pd_b_link_n,
    input  logic        iso_pd_channel_n,
    input  logic        save_dma_sleep,
    input  logic        restore_dma_sleep,
    input  logic        save_dma_mem,
    input  logic        restore_dma_mem,
    input  logic        dma_active_valid,
    input  logic [3:0]  dma_submit_count,
    input  logic [3:0]  dma_comp_count,
    input  logic        irq_pending,
    output int unsigned run_cycles,
    output int unsigned crypto_only_cycles,
    output int unsigned sleep_cycles,
    output int unsigned deep_sleep_cycles,
    output int unsigned trans_run_to_crypto_only,
    output int unsigned trans_crypto_only_to_run,
    output int unsigned trans_run_to_sleep,
    output int unsigned trans_sleep_to_run,
    output int unsigned trans_run_to_deep_sleep,
    output int unsigned trans_deep_sleep_to_run,
    output int unsigned illegal_activity_violations,
    output int unsigned resume_events,
    output int unsigned resume_violations,
    output int unsigned domain_combo_run,
    output int unsigned domain_combo_crypto_only,
    output int unsigned domain_combo_sleep,
    output int unsigned domain_combo_deep_sleep,
    output int unsigned isolation_assert_cycles,
    output int unsigned isolation_deassert_cycles,
    output int unsigned isolation_blocked_cycles,
    output int unsigned isolation_release_traffic_seen,
    output int unsigned dma_sleep_save_seen,
    output int unsigned dma_sleep_restore_seen,
    output int unsigned dma_mem_save_seen,
    output int unsigned dma_mem_restore_seen,
    output int unsigned activity_cross_no_traffic,
    output int unsigned activity_cross_link_traffic,
    output int unsigned activity_cross_dma_queued,
    output int unsigned activity_cross_dma_active,
    output int unsigned activity_cross_completion_pending
);

    localparam logic [1:0] PWR_RUN         = 2'd0;
    localparam logic [1:0] PWR_CRYPTO_ONLY = 2'd1;
    localparam logic [1:0] PWR_SLEEP       = 2'd2;
    localparam logic [1:0] PWR_DEEP_SLEEP  = 2'd3;

    logic [1:0]  last_state_q;
    logic        waiting_resume_q;
    logic        waiting_deisol_traffic_q;
    logic [5:0]  switch_vec_q;
    logic [5:0]  iso_n_vec_q;
    logic [5:0]  last_switch_vec_q;
    logic [5:0]  last_iso_n_vec_q;
    logic        last_save_dma_sleep_q;
    logic        last_restore_dma_sleep_q;
    logic        last_save_dma_mem_q;
    logic        last_restore_dma_mem_q;
    logic        restore_seen_since_lp_q;
    int unsigned crypto_drain_q;
    int unsigned resume_window_q;

    int unsigned switch_pd_a_traffic_on_seen;
    int unsigned switch_pd_a_traffic_off_seen;
    int unsigned switch_pd_a_dma_on_seen;
    int unsigned switch_pd_a_dma_off_seen;
    int unsigned switch_pd_a_link_on_seen;
    int unsigned switch_pd_a_link_off_seen;
    int unsigned switch_pd_b_crypto_on_seen;
    int unsigned switch_pd_b_crypto_off_seen;
    int unsigned switch_pd_b_link_on_seen;
    int unsigned switch_pd_b_link_off_seen;
    int unsigned switch_pd_channel_on_seen;
    int unsigned switch_pd_channel_off_seen;
    int unsigned iso_pd_a_traffic_assert_seen;
    int unsigned iso_pd_a_traffic_deassert_seen;
    int unsigned iso_pd_a_dma_assert_seen;
    int unsigned iso_pd_a_dma_deassert_seen;
    int unsigned iso_pd_a_link_assert_seen;
    int unsigned iso_pd_a_link_deassert_seen;
    int unsigned iso_pd_b_crypto_assert_seen;
    int unsigned iso_pd_b_crypto_deassert_seen;
    int unsigned iso_pd_b_link_assert_seen;
    int unsigned iso_pd_b_link_deassert_seen;
    int unsigned iso_pd_channel_assert_seen;
    int unsigned iso_pd_channel_deassert_seen;
    int unsigned seq_iso_before_switch_off_seen;
    int unsigned seq_iso_before_switch_off_violations;
    int unsigned seq_switch_on_before_restore_seen;
    int unsigned seq_switch_on_before_restore_violations;
    int unsigned seq_restore_before_deiso_seen;
    int unsigned seq_restore_before_deiso_violations;
    int unsigned retention_pulse_width_ok_seen;
    int unsigned retention_pulse_width_violations;
    int unsigned unsupported_transition_seen;

    wire all_domains_on = sw_pd_a_traffic && sw_pd_a_dma && sw_pd_a_link &&
                          sw_pd_b_crypto && sw_pd_b_link && sw_pd_channel;
    wire all_iso_deasserted = iso_pd_a_traffic_n && iso_pd_a_dma_n && iso_pd_a_link_n &&
                              iso_pd_b_crypto_n && iso_pd_b_link_n && iso_pd_channel_n;
    wire any_iso_asserted = !all_iso_deasserted;
    wire link_activity = producer_valid || tx_fire || rx_fire || e2e_update;
    wire completion_pending = (dma_comp_count != 4'd0) || irq_pending;
    wire no_activity = !link_activity && !dma_active_valid &&
                       (dma_submit_count == 4'd0) && !completion_pending;
    wire [5:0] switch_vec = {sw_pd_a_traffic, sw_pd_a_dma, sw_pd_a_link,
                             sw_pd_b_crypto, sw_pd_b_link, sw_pd_channel};
    wire [5:0] iso_n_vec = {iso_pd_a_traffic_n, iso_pd_a_dma_n, iso_pd_a_link_n,
                            iso_pd_b_crypto_n, iso_pd_b_link_n, iso_pd_channel_n};
    wire [5:0] switch_rise = switch_vec & ~last_switch_vec_q;
    wire [5:0] switch_fall = ~switch_vec & last_switch_vec_q;
    wire [5:0] iso_deassert = iso_n_vec & ~last_iso_n_vec_q;
    wire [5:0] iso_assert = ~iso_n_vec & last_iso_n_vec_q;

    wire combo_run = all_domains_on && all_iso_deasserted;
    wire combo_crypto_only = !sw_pd_a_traffic && sw_pd_a_dma && sw_pd_a_link &&
                             sw_pd_b_crypto && sw_pd_b_link && sw_pd_channel &&
                             !iso_pd_a_traffic_n && iso_pd_a_dma_n && iso_pd_a_link_n &&
                             iso_pd_b_crypto_n && iso_pd_b_link_n && iso_pd_channel_n;
    wire combo_sleep = !sw_pd_a_traffic && !sw_pd_a_dma && !sw_pd_a_link &&
                       !sw_pd_b_crypto && !sw_pd_b_link && !sw_pd_channel &&
                       !iso_pd_a_traffic_n && !iso_pd_a_dma_n && !iso_pd_a_link_n &&
                       !iso_pd_b_crypto_n && !iso_pd_b_link_n && !iso_pd_channel_n;

    logic [2:0] domain_combo_id;
    logic [2:0] transition_id;
    logic [2:0] activity_id;
    logic [2:0] retention_event_id;

    always_comb begin
        if (combo_run) begin
            domain_combo_id = 3'd1;
        end else if (combo_crypto_only) begin
            domain_combo_id = 3'd2;
        end else if (combo_sleep && (power_state == PWR_SLEEP)) begin
            domain_combo_id = 3'd3;
        end else if (combo_sleep && (power_state == PWR_DEEP_SLEEP)) begin
            domain_combo_id = 3'd4;
        end else begin
            domain_combo_id = 3'd0;
        end

        transition_id = 3'd0;
        if (power_state != last_state_q) begin
            if ((last_state_q == PWR_RUN) && (power_state == PWR_CRYPTO_ONLY)) begin
                transition_id = 3'd1;
            end else if ((last_state_q == PWR_CRYPTO_ONLY) && (power_state == PWR_RUN)) begin
                transition_id = 3'd2;
            end else if ((last_state_q == PWR_RUN) && (power_state == PWR_SLEEP)) begin
                transition_id = 3'd3;
            end else if ((last_state_q == PWR_SLEEP) && (power_state == PWR_RUN)) begin
                transition_id = 3'd4;
            end else if ((last_state_q == PWR_RUN) && (power_state == PWR_DEEP_SLEEP)) begin
                transition_id = 3'd5;
            end else if ((last_state_q == PWR_DEEP_SLEEP) && (power_state == PWR_RUN)) begin
                transition_id = 3'd6;
            end
        end

        if (dma_active_valid) begin
            activity_id = 3'd3;
        end else if (dma_submit_count != 4'd0) begin
            activity_id = 3'd2;
        end else if (completion_pending) begin
            activity_id = 3'd4;
        end else if (link_activity) begin
            activity_id = 3'd1;
        end else begin
            activity_id = 3'd0;
        end

        if (save_dma_sleep) begin
            retention_event_id = 3'd1;
        end else if (restore_dma_sleep) begin
            retention_event_id = 3'd2;
        end else if (save_dma_mem) begin
            retention_event_id = 3'd3;
        end else if (restore_dma_mem) begin
            retention_event_id = 3'd4;
        end else begin
            retention_event_id = 3'd0;
        end
    end

`ifndef VERILATOR
    // Simulator-native coverage for UVM-style environments. Verilator uses the
    // mirrored integer counters below to keep the repo runnable without a
    // commercial coverage engine.
    covergroup low_power_cg @(posedge clk iff mon_rst_n);
        option.per_instance = 1;

        cp_power_state: coverpoint power_state {
            bins run = {PWR_RUN};
            bins crypto_only = {PWR_CRYPTO_ONLY};
            bins sleep = {PWR_SLEEP};
            bins deep_sleep = {PWR_DEEP_SLEEP};
        }

        cp_transition: coverpoint transition_id {
            bins run_to_crypto_only = {3'd1};
            bins crypto_only_to_run = {3'd2};
            bins run_to_sleep = {3'd3};
            bins sleep_to_run = {3'd4};
            bins run_to_deep_sleep = {3'd5};
            bins deep_sleep_to_run = {3'd6};
            ignore_bins no_transition = {3'd0};
        }

        cp_domain_combo: coverpoint domain_combo_id {
            bins pst_run = {3'd1};
            bins pst_crypto_only = {3'd2};
            bins pst_sleep = {3'd3};
            bins pst_deep_sleep = {3'd4};
            illegal_bins non_pst_combo = {3'd0};
        }

        cp_isolation: coverpoint any_iso_asserted {
            bins deasserted = {1'b0};
            bins asserted = {1'b1};
        }

        cp_retention_event: coverpoint retention_event_id {
            bins dma_sleep_save = {3'd1};
            bins dma_sleep_restore = {3'd2};
            bins dma_mem_save = {3'd3};
            bins dma_mem_restore = {3'd4};
            ignore_bins no_retention_event = {3'd0};
        }

        cp_activity: coverpoint activity_id {
            bins no_traffic = {3'd0};
            bins link_traffic = {3'd1};
            bins dma_queued = {3'd2};
            bins dma_active = {3'd3};
            bins completion_pending = {3'd4};
        }

        x_state_domain: cross cp_power_state, cp_domain_combo;
        x_transition_activity: cross cp_transition, cp_activity;
        x_isolation_activity: cross cp_isolation, cp_activity;
    endgroup

    low_power_cg low_power_cov = new();
`endif

    always_ff @(posedge clk or negedge mon_rst_n) begin
        if (!mon_rst_n) begin
            run_cycles <= 0;
            crypto_only_cycles <= 0;
            sleep_cycles <= 0;
            deep_sleep_cycles <= 0;
            trans_run_to_crypto_only <= 0;
            trans_crypto_only_to_run <= 0;
            trans_run_to_sleep <= 0;
            trans_sleep_to_run <= 0;
            trans_run_to_deep_sleep <= 0;
            trans_deep_sleep_to_run <= 0;
            illegal_activity_violations <= 0;
            resume_events <= 0;
            resume_violations <= 0;
            domain_combo_run <= 0;
            domain_combo_crypto_only <= 0;
            domain_combo_sleep <= 0;
            domain_combo_deep_sleep <= 0;
            isolation_assert_cycles <= 0;
            isolation_deassert_cycles <= 0;
            isolation_blocked_cycles <= 0;
            isolation_release_traffic_seen <= 0;
            dma_sleep_save_seen <= 0;
            dma_sleep_restore_seen <= 0;
            dma_mem_save_seen <= 0;
            dma_mem_restore_seen <= 0;
            activity_cross_no_traffic <= 0;
            activity_cross_link_traffic <= 0;
            activity_cross_dma_queued <= 0;
            activity_cross_dma_active <= 0;
            activity_cross_completion_pending <= 0;
            last_state_q <= PWR_RUN;
            waiting_resume_q <= 1'b0;
            waiting_deisol_traffic_q <= 1'b0;
            switch_vec_q <= 6'b111111;
            iso_n_vec_q <= 6'b111111;
            last_switch_vec_q <= 6'b111111;
            last_iso_n_vec_q <= 6'b111111;
            last_save_dma_sleep_q <= 1'b0;
            last_restore_dma_sleep_q <= 1'b0;
            last_save_dma_mem_q <= 1'b0;
            last_restore_dma_mem_q <= 1'b0;
            restore_seen_since_lp_q <= 1'b0;
            crypto_drain_q <= 0;
            resume_window_q <= 0;
            switch_pd_a_traffic_on_seen <= 0;
            switch_pd_a_traffic_off_seen <= 0;
            switch_pd_a_dma_on_seen <= 0;
            switch_pd_a_dma_off_seen <= 0;
            switch_pd_a_link_on_seen <= 0;
            switch_pd_a_link_off_seen <= 0;
            switch_pd_b_crypto_on_seen <= 0;
            switch_pd_b_crypto_off_seen <= 0;
            switch_pd_b_link_on_seen <= 0;
            switch_pd_b_link_off_seen <= 0;
            switch_pd_channel_on_seen <= 0;
            switch_pd_channel_off_seen <= 0;
            iso_pd_a_traffic_assert_seen <= 0;
            iso_pd_a_traffic_deassert_seen <= 0;
            iso_pd_a_dma_assert_seen <= 0;
            iso_pd_a_dma_deassert_seen <= 0;
            iso_pd_a_link_assert_seen <= 0;
            iso_pd_a_link_deassert_seen <= 0;
            iso_pd_b_crypto_assert_seen <= 0;
            iso_pd_b_crypto_deassert_seen <= 0;
            iso_pd_b_link_assert_seen <= 0;
            iso_pd_b_link_deassert_seen <= 0;
            iso_pd_channel_assert_seen <= 0;
            iso_pd_channel_deassert_seen <= 0;
            seq_iso_before_switch_off_seen <= 0;
            seq_iso_before_switch_off_violations <= 0;
            seq_switch_on_before_restore_seen <= 0;
            seq_switch_on_before_restore_violations <= 0;
            seq_restore_before_deiso_seen <= 0;
            seq_restore_before_deiso_violations <= 0;
            retention_pulse_width_ok_seen <= 0;
            retention_pulse_width_violations <= 0;
            unsupported_transition_seen <= 0;
        end else begin
            case (power_state)
                PWR_RUN: run_cycles <= run_cycles + 1;
                PWR_CRYPTO_ONLY: crypto_only_cycles <= crypto_only_cycles + 1;
                PWR_SLEEP: sleep_cycles <= sleep_cycles + 1;
                default: deep_sleep_cycles <= deep_sleep_cycles + 1;
            endcase

            if (switch_rise[5]) switch_pd_a_traffic_on_seen <= switch_pd_a_traffic_on_seen + 1;
            if (switch_fall[5]) switch_pd_a_traffic_off_seen <= switch_pd_a_traffic_off_seen + 1;
            if (switch_rise[4]) switch_pd_a_dma_on_seen <= switch_pd_a_dma_on_seen + 1;
            if (switch_fall[4]) switch_pd_a_dma_off_seen <= switch_pd_a_dma_off_seen + 1;
            if (switch_rise[3]) switch_pd_a_link_on_seen <= switch_pd_a_link_on_seen + 1;
            if (switch_fall[3]) switch_pd_a_link_off_seen <= switch_pd_a_link_off_seen + 1;
            if (switch_rise[2]) switch_pd_b_crypto_on_seen <= switch_pd_b_crypto_on_seen + 1;
            if (switch_fall[2]) switch_pd_b_crypto_off_seen <= switch_pd_b_crypto_off_seen + 1;
            if (switch_rise[1]) switch_pd_b_link_on_seen <= switch_pd_b_link_on_seen + 1;
            if (switch_fall[1]) switch_pd_b_link_off_seen <= switch_pd_b_link_off_seen + 1;
            if (switch_rise[0]) switch_pd_channel_on_seen <= switch_pd_channel_on_seen + 1;
            if (switch_fall[0]) switch_pd_channel_off_seen <= switch_pd_channel_off_seen + 1;

            if (iso_assert[5]) iso_pd_a_traffic_assert_seen <= iso_pd_a_traffic_assert_seen + 1;
            if (iso_deassert[5]) iso_pd_a_traffic_deassert_seen <= iso_pd_a_traffic_deassert_seen + 1;
            if (iso_assert[4]) iso_pd_a_dma_assert_seen <= iso_pd_a_dma_assert_seen + 1;
            if (iso_deassert[4]) iso_pd_a_dma_deassert_seen <= iso_pd_a_dma_deassert_seen + 1;
            if (iso_assert[3]) iso_pd_a_link_assert_seen <= iso_pd_a_link_assert_seen + 1;
            if (iso_deassert[3]) iso_pd_a_link_deassert_seen <= iso_pd_a_link_deassert_seen + 1;
            if (iso_assert[2]) iso_pd_b_crypto_assert_seen <= iso_pd_b_crypto_assert_seen + 1;
            if (iso_deassert[2]) iso_pd_b_crypto_deassert_seen <= iso_pd_b_crypto_deassert_seen + 1;
            if (iso_assert[1]) iso_pd_b_link_assert_seen <= iso_pd_b_link_assert_seen + 1;
            if (iso_deassert[1]) iso_pd_b_link_deassert_seen <= iso_pd_b_link_deassert_seen + 1;
            if (iso_assert[0]) iso_pd_channel_assert_seen <= iso_pd_channel_assert_seen + 1;
            if (iso_deassert[0]) iso_pd_channel_deassert_seen <= iso_pd_channel_deassert_seen + 1;

            if (|switch_fall) begin
                if ((switch_fall & iso_n_vec) == 6'b0) begin
                    seq_iso_before_switch_off_seen <= seq_iso_before_switch_off_seen + 1;
                end else begin
                    seq_iso_before_switch_off_violations <= seq_iso_before_switch_off_violations + 1;
                end
            end

            if (restore_dma_sleep || restore_dma_mem) begin
                restore_seen_since_lp_q <= 1'b1;
                if (sw_pd_a_dma) begin
                    seq_switch_on_before_restore_seen <= seq_switch_on_before_restore_seen + 1;
                end else begin
                    seq_switch_on_before_restore_violations <= seq_switch_on_before_restore_violations + 1;
                end
            end

            if ((waiting_deisol_traffic_q || restore_seen_since_lp_q) && (|iso_deassert)) begin
                if (restore_seen_since_lp_q) begin
                    seq_restore_before_deiso_seen <= seq_restore_before_deiso_seen + 1;
                end else begin
                    seq_restore_before_deiso_violations <= seq_restore_before_deiso_violations + 1;
                end
            end

            if ((save_dma_sleep && last_save_dma_sleep_q) ||
                (restore_dma_sleep && last_restore_dma_sleep_q) ||
                (save_dma_mem && last_save_dma_mem_q) ||
                (restore_dma_mem && last_restore_dma_mem_q)) begin
                retention_pulse_width_violations <= retention_pulse_width_violations + 1;
            end else if (save_dma_sleep || restore_dma_sleep ||
                         save_dma_mem || restore_dma_mem) begin
                retention_pulse_width_ok_seen <= retention_pulse_width_ok_seen + 1;
            end

            if ((power_state == PWR_RUN) && combo_run) begin
                domain_combo_run <= domain_combo_run + 1;
            end
            if ((power_state == PWR_CRYPTO_ONLY) && combo_crypto_only) begin
                domain_combo_crypto_only <= domain_combo_crypto_only + 1;
            end
            if ((power_state == PWR_SLEEP) && combo_sleep) begin
                domain_combo_sleep <= domain_combo_sleep + 1;
            end
            if ((power_state == PWR_DEEP_SLEEP) && combo_sleep) begin
                domain_combo_deep_sleep <= domain_combo_deep_sleep + 1;
            end

            if (any_iso_asserted) begin
                isolation_assert_cycles <= isolation_assert_cycles + 1;
                if (!tx_fire && !rx_fire && !e2e_update) begin
                    isolation_blocked_cycles <= isolation_blocked_cycles + 1;
                end
            end else begin
                isolation_deassert_cycles <= isolation_deassert_cycles + 1;
            end

            if (save_dma_sleep) begin
                dma_sleep_save_seen <= dma_sleep_save_seen + 1;
            end
            if (restore_dma_sleep) begin
                dma_sleep_restore_seen <= dma_sleep_restore_seen + 1;
            end
            if (save_dma_mem) begin
                dma_mem_save_seen <= dma_mem_save_seen + 1;
            end
            if (restore_dma_mem) begin
                dma_mem_restore_seen <= dma_mem_restore_seen + 1;
            end

            if (power_state != last_state_q) begin
                if (no_activity) begin
                    activity_cross_no_traffic <= activity_cross_no_traffic + 1;
                end
                if (link_activity) begin
                    activity_cross_link_traffic <= activity_cross_link_traffic + 1;
                end
                if (dma_submit_count != 4'd0) begin
                    activity_cross_dma_queued <= activity_cross_dma_queued + 1;
                end
                if (dma_active_valid) begin
                    activity_cross_dma_active <= activity_cross_dma_active + 1;
                end
                if (completion_pending) begin
                    activity_cross_completion_pending <= activity_cross_completion_pending + 1;
                end
                if (last_state_q == PWR_RUN && power_state == PWR_CRYPTO_ONLY) begin
                    trans_run_to_crypto_only <= trans_run_to_crypto_only + 1;
                    crypto_drain_q <= CRYPTO_DRAIN_GRACE;
                end else if (last_state_q == PWR_CRYPTO_ONLY && power_state == PWR_RUN) begin
                    trans_crypto_only_to_run <= trans_crypto_only_to_run + 1;
                end else if (last_state_q == PWR_RUN && power_state == PWR_SLEEP) begin
                    trans_run_to_sleep <= trans_run_to_sleep + 1;
                    restore_seen_since_lp_q <= 1'b0;
                end else if (last_state_q == PWR_SLEEP && power_state == PWR_RUN) begin
                    trans_sleep_to_run <= trans_sleep_to_run + 1;
                    waiting_resume_q <= 1'b1;
                    waiting_deisol_traffic_q <= 1'b1;
                    resume_window_q <= RESUME_WINDOW;
                end else if (last_state_q == PWR_RUN && power_state == PWR_DEEP_SLEEP) begin
                    trans_run_to_deep_sleep <= trans_run_to_deep_sleep + 1;
                    restore_seen_since_lp_q <= 1'b0;
                end else if (last_state_q == PWR_DEEP_SLEEP && power_state == PWR_RUN) begin
                    trans_deep_sleep_to_run <= trans_deep_sleep_to_run + 1;
                    waiting_resume_q <= 1'b1;
                    waiting_deisol_traffic_q <= 1'b1;
                    resume_window_q <= RESUME_WINDOW;
                end else begin
                    unsupported_transition_seen <= unsupported_transition_seen + 1;
                end
                last_state_q <= power_state;
            end

            if (crypto_drain_q != 0) begin
                crypto_drain_q <= crypto_drain_q - 1;
            end

            if (power_state == PWR_CRYPTO_ONLY) begin
                if ((crypto_drain_q == 0) && (producer_valid || tx_fire)) begin
                    illegal_activity_violations <= illegal_activity_violations + 1;
                end
            end else if ((power_state == PWR_SLEEP) || (power_state == PWR_DEEP_SLEEP)) begin
                if (producer_valid || tx_fire || rx_fire || e2e_update) begin
                    illegal_activity_violations <= illegal_activity_violations + 1;
                end
            end

            if (waiting_resume_q) begin
                if (e2e_update || dma_active_valid ||
                    (dma_submit_count != 4'd0) || completion_pending) begin
                    resume_events <= resume_events + 1;
                    waiting_resume_q <= 1'b0;
                    resume_window_q <= 0;
                end else if (resume_window_q != 0) begin
                    resume_window_q <= resume_window_q - 1;
                    if (resume_window_q == 1) begin
                        resume_violations <= resume_violations + 1;
                        waiting_resume_q <= 1'b0;
                    end
                end
            end

            if (waiting_deisol_traffic_q && all_iso_deasserted && link_activity) begin
                isolation_release_traffic_seen <= isolation_release_traffic_seen + 1;
                waiting_deisol_traffic_q <= 1'b0;
            end
            last_switch_vec_q <= switch_vec;
            last_iso_n_vec_q <= iso_n_vec;
            switch_vec_q <= switch_vec;
            iso_n_vec_q <= iso_n_vec;
            last_save_dma_sleep_q <= save_dma_sleep;
            last_restore_dma_sleep_q <= restore_dma_sleep;
            last_save_dma_mem_q <= save_dma_mem;
            last_restore_dma_mem_q <= restore_dma_mem;
        end
    end

    task automatic write_report(input string path, input string mode_name);
        int fd;
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $display("Failed to open power report file: %s", path);
        end else begin
            $fdisplay(fd, "metric,value");
            $fdisplay(fd, "power_mode,%s", mode_name);
            $fdisplay(fd, "run_cycles,%0d", run_cycles);
            $fdisplay(fd, "crypto_only_cycles,%0d", crypto_only_cycles);
            $fdisplay(fd, "sleep_cycles,%0d", sleep_cycles);
            $fdisplay(fd, "deep_sleep_cycles,%0d", deep_sleep_cycles);
            $fdisplay(fd, "trans_run_to_crypto_only,%0d", trans_run_to_crypto_only);
            $fdisplay(fd, "trans_crypto_only_to_run,%0d", trans_crypto_only_to_run);
            $fdisplay(fd, "trans_run_to_sleep,%0d", trans_run_to_sleep);
            $fdisplay(fd, "trans_sleep_to_run,%0d", trans_sleep_to_run);
            $fdisplay(fd, "trans_run_to_deep_sleep,%0d", trans_run_to_deep_sleep);
            $fdisplay(fd, "trans_deep_sleep_to_run,%0d", trans_deep_sleep_to_run);
            $fdisplay(fd, "domain_combo_run,%0d", domain_combo_run);
            $fdisplay(fd, "domain_combo_crypto_only,%0d", domain_combo_crypto_only);
            $fdisplay(fd, "domain_combo_sleep,%0d", domain_combo_sleep);
            $fdisplay(fd, "domain_combo_deep_sleep,%0d", domain_combo_deep_sleep);
            $fdisplay(fd, "isolation_assert_cycles,%0d", isolation_assert_cycles);
            $fdisplay(fd, "isolation_deassert_cycles,%0d", isolation_deassert_cycles);
            $fdisplay(fd, "isolation_blocked_cycles,%0d", isolation_blocked_cycles);
            $fdisplay(fd, "isolation_release_traffic_seen,%0d", isolation_release_traffic_seen);
            $fdisplay(fd, "dma_sleep_save_seen,%0d", dma_sleep_save_seen);
            $fdisplay(fd, "dma_sleep_restore_seen,%0d", dma_sleep_restore_seen);
            $fdisplay(fd, "dma_mem_save_seen,%0d", dma_mem_save_seen);
            $fdisplay(fd, "dma_mem_restore_seen,%0d", dma_mem_restore_seen);
            $fdisplay(fd, "switch_pd_a_traffic_on_seen,%0d", switch_pd_a_traffic_on_seen);
            $fdisplay(fd, "switch_pd_a_traffic_off_seen,%0d", switch_pd_a_traffic_off_seen);
            $fdisplay(fd, "switch_pd_a_dma_on_seen,%0d", switch_pd_a_dma_on_seen);
            $fdisplay(fd, "switch_pd_a_dma_off_seen,%0d", switch_pd_a_dma_off_seen);
            $fdisplay(fd, "switch_pd_a_link_on_seen,%0d", switch_pd_a_link_on_seen);
            $fdisplay(fd, "switch_pd_a_link_off_seen,%0d", switch_pd_a_link_off_seen);
            $fdisplay(fd, "switch_pd_b_crypto_on_seen,%0d", switch_pd_b_crypto_on_seen);
            $fdisplay(fd, "switch_pd_b_crypto_off_seen,%0d", switch_pd_b_crypto_off_seen);
            $fdisplay(fd, "switch_pd_b_link_on_seen,%0d", switch_pd_b_link_on_seen);
            $fdisplay(fd, "switch_pd_b_link_off_seen,%0d", switch_pd_b_link_off_seen);
            $fdisplay(fd, "switch_pd_channel_on_seen,%0d", switch_pd_channel_on_seen);
            $fdisplay(fd, "switch_pd_channel_off_seen,%0d", switch_pd_channel_off_seen);
            $fdisplay(fd, "iso_pd_a_traffic_assert_seen,%0d", iso_pd_a_traffic_assert_seen);
            $fdisplay(fd, "iso_pd_a_traffic_deassert_seen,%0d", iso_pd_a_traffic_deassert_seen);
            $fdisplay(fd, "iso_pd_a_dma_assert_seen,%0d", iso_pd_a_dma_assert_seen);
            $fdisplay(fd, "iso_pd_a_dma_deassert_seen,%0d", iso_pd_a_dma_deassert_seen);
            $fdisplay(fd, "iso_pd_a_link_assert_seen,%0d", iso_pd_a_link_assert_seen);
            $fdisplay(fd, "iso_pd_a_link_deassert_seen,%0d", iso_pd_a_link_deassert_seen);
            $fdisplay(fd, "iso_pd_b_crypto_assert_seen,%0d", iso_pd_b_crypto_assert_seen);
            $fdisplay(fd, "iso_pd_b_crypto_deassert_seen,%0d", iso_pd_b_crypto_deassert_seen);
            $fdisplay(fd, "iso_pd_b_link_assert_seen,%0d", iso_pd_b_link_assert_seen);
            $fdisplay(fd, "iso_pd_b_link_deassert_seen,%0d", iso_pd_b_link_deassert_seen);
            $fdisplay(fd, "iso_pd_channel_assert_seen,%0d", iso_pd_channel_assert_seen);
            $fdisplay(fd, "iso_pd_channel_deassert_seen,%0d", iso_pd_channel_deassert_seen);
            $fdisplay(fd, "seq_iso_before_switch_off_seen,%0d", seq_iso_before_switch_off_seen);
            $fdisplay(fd, "seq_iso_before_switch_off_violations,%0d", seq_iso_before_switch_off_violations);
            $fdisplay(fd, "seq_switch_on_before_restore_seen,%0d", seq_switch_on_before_restore_seen);
            $fdisplay(fd, "seq_switch_on_before_restore_violations,%0d", seq_switch_on_before_restore_violations);
            $fdisplay(fd, "seq_restore_before_deiso_seen,%0d", seq_restore_before_deiso_seen);
            $fdisplay(fd, "seq_restore_before_deiso_violations,%0d", seq_restore_before_deiso_violations);
            $fdisplay(fd, "retention_pulse_width_ok_seen,%0d", retention_pulse_width_ok_seen);
            $fdisplay(fd, "retention_pulse_width_violations,%0d", retention_pulse_width_violations);
            $fdisplay(fd, "unsupported_transition_seen,%0d", unsupported_transition_seen);
            $fdisplay(fd, "activity_cross_no_traffic,%0d", activity_cross_no_traffic);
            $fdisplay(fd, "activity_cross_link_traffic,%0d", activity_cross_link_traffic);
            $fdisplay(fd, "activity_cross_dma_queued,%0d", activity_cross_dma_queued);
            $fdisplay(fd, "activity_cross_dma_active,%0d", activity_cross_dma_active);
            $fdisplay(fd, "activity_cross_completion_pending,%0d", activity_cross_completion_pending);
            $fdisplay(fd, "illegal_activity_violations,%0d", illegal_activity_violations);
            $fdisplay(fd, "resume_events,%0d", resume_events);
            $fdisplay(fd, "resume_violations,%0d", resume_violations);
            $fclose(fd);
        end
    endtask

endmodule : power_state_monitor

`endif
