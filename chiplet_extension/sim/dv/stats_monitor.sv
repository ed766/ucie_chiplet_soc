`ifndef UCIE_STATS_MONITOR_SV
`define UCIE_STATS_MONITOR_SV

module stats_monitor (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [2:0]  link_state_a,
    input  logic [2:0]  link_state_b,
    input  logic [15:0] credit_available_a,
    input  logic [15:0] credit_available_b,
    input  logic        backpressure_a,
    input  logic        backpressure_b,
    input  logic        crc_error_a,
    input  logic        crc_error_b,
    input  logic        resend_request_a,
    input  logic        resend_request_b,
    input  logic        lane_fault_a,
    input  logic        lane_fault_b,
    input  logic        latency_valid,
    input  logic [15:0] latency_value,
    input  logic        tx_fire,
    input  logic        rx_fire,
    input  logic        e2e_update,
    input  logic        e2e_mismatch,
    input  logic        expected_empty,
    input  logic        power_reset_proxy,
    input  logic        power_idle_proxy
);

    import ucie_cov_pkg::*;
    import stats_pkg::*;

    localparam int unsigned CREDIT_LOW  = 16;
    localparam int unsigned CREDIT_HIGH = 96;
    localparam int unsigned LAT_LOW     = 16;
    localparam int unsigned LAT_HIGH    = 64;

    int unsigned sample_cycles_q;
    int unsigned link_reset_q;
    int unsigned link_train_q;
    int unsigned link_active_q;
    int unsigned link_retrain_q;
    int unsigned link_degraded_q;
    int unsigned link_transitions_q;
    int unsigned link_recoveries_q;
    int unsigned credit_zero_q;
    int unsigned credit_low_q;
    int unsigned credit_mid_q;
    int unsigned credit_high_q;
    int unsigned backpressure_q;
    int unsigned crc_error_q;
    int unsigned resend_request_q;
    int unsigned lane_fault_q;
    int unsigned retry_backpressure_cross_q;
    int unsigned latency_low_q;
    int unsigned latency_nominal_q;
    int unsigned latency_high_q;
    int unsigned e2e_updates_q;
    int unsigned e2e_mismatch_q;
    int unsigned expected_empty_q;
    int unsigned power_reset_proxy_q;
    int unsigned power_idle_proxy_q;

    logic [2:0] last_link_state_a_q;
    logic [2:0] last_link_state_b_q;

    always_ff @(posedge clk or negedge rst_n) begin : sample_cov
        if (!rst_n) begin
            sample_cycles_q <= 0;
            link_reset_q <= 0;
            link_train_q <= 0;
            link_active_q <= 0;
            link_retrain_q <= 0;
            link_degraded_q <= 0;
            link_transitions_q <= 0;
            link_recoveries_q <= 0;
            credit_zero_q <= 0;
            credit_low_q <= 0;
            credit_mid_q <= 0;
            credit_high_q <= 0;
            backpressure_q <= 0;
            crc_error_q <= 0;
            resend_request_q <= 0;
            lane_fault_q <= 0;
            retry_backpressure_cross_q <= 0;
            latency_low_q <= 0;
            latency_nominal_q <= 0;
            latency_high_q <= 0;
            e2e_updates_q <= 0;
            e2e_mismatch_q <= 0;
            expected_empty_q <= 0;
            power_reset_proxy_q <= 0;
            power_idle_proxy_q <= 0;
            last_link_state_a_q <= 3'd0;
            last_link_state_b_q <= 3'd0;
        end else begin
            int unsigned sample_cycles_n;
            int unsigned link_reset_n;
            int unsigned link_train_n;
            int unsigned link_active_n;
            int unsigned link_retrain_n;
            int unsigned link_degraded_n;
            int unsigned link_transitions_n;
            int unsigned link_recoveries_n;
            int unsigned credit_zero_n;
            int unsigned credit_low_n;
            int unsigned credit_mid_n;
            int unsigned credit_high_n;
            int unsigned backpressure_n;
            int unsigned crc_error_n;
            int unsigned resend_request_n;
            int unsigned lane_fault_n;
            int unsigned retry_backpressure_cross_n;
            int unsigned latency_low_n;
            int unsigned latency_nominal_n;
            int unsigned latency_high_n;
            int unsigned e2e_updates_n;
            int unsigned e2e_mismatch_n;
            int unsigned expected_empty_n;
            int unsigned power_reset_proxy_n;
            int unsigned power_idle_proxy_n;

            sample_cycles_n = sample_cycles_q + 1;
            link_reset_n = link_reset_q;
            link_train_n = link_train_q;
            link_active_n = link_active_q;
            link_retrain_n = link_retrain_q;
            link_degraded_n = link_degraded_q;
            link_transitions_n = link_transitions_q;
            link_recoveries_n = link_recoveries_q;
            credit_zero_n = credit_zero_q;
            credit_low_n = credit_low_q;
            credit_mid_n = credit_mid_q;
            credit_high_n = credit_high_q;
            backpressure_n = backpressure_q;
            crc_error_n = crc_error_q;
            resend_request_n = resend_request_q;
            lane_fault_n = lane_fault_q;
            retry_backpressure_cross_n = retry_backpressure_cross_q;
            latency_low_n = latency_low_q;
            latency_nominal_n = latency_nominal_q;
            latency_high_n = latency_high_q;
            e2e_updates_n = e2e_updates_q;
            e2e_mismatch_n = e2e_mismatch_q;
            expected_empty_n = expected_empty_q;
            power_reset_proxy_n = power_reset_proxy_q;
            power_idle_proxy_n = power_idle_proxy_q;

            case (link_state_a)
                3'd0: link_reset_n = link_reset_n + 1;
                3'd1: link_train_n = link_train_n + 1;
                3'd2: link_active_n = link_active_n + 1;
                3'd3: link_retrain_n = link_retrain_n + 1;
                default: link_degraded_n = link_degraded_n + 1;
            endcase
            case (link_state_b)
                3'd0: link_reset_n = link_reset_n + 1;
                3'd1: link_train_n = link_train_n + 1;
                3'd2: link_active_n = link_active_n + 1;
                3'd3: link_retrain_n = link_retrain_n + 1;
                default: link_degraded_n = link_degraded_n + 1;
            endcase

            if (link_state_a != last_link_state_a_q) begin
                link_transitions_n = link_transitions_n + 1;
            end
            if (link_state_b != last_link_state_b_q) begin
                link_transitions_n = link_transitions_n + 1;
            end
            if ((last_link_state_a_q == 3'd3 || last_link_state_a_q == 3'd4) && link_state_a == 3'd2) begin
                link_recoveries_n = link_recoveries_n + 1;
            end
            if ((last_link_state_b_q == 3'd3 || last_link_state_b_q == 3'd4) && link_state_b == 3'd2) begin
                link_recoveries_n = link_recoveries_n + 1;
            end

            if (credit_available_a == 0) begin
                credit_zero_n = credit_zero_n + 1;
            end else if (credit_available_a <= CREDIT_LOW) begin
                credit_low_n = credit_low_n + 1;
            end else if (credit_available_a >= CREDIT_HIGH) begin
                credit_high_n = credit_high_n + 1;
            end else begin
                credit_mid_n = credit_mid_n + 1;
            end
            if (credit_available_b == 0) begin
                credit_zero_n = credit_zero_n + 1;
            end else if (credit_available_b <= CREDIT_LOW) begin
                credit_low_n = credit_low_n + 1;
            end else if (credit_available_b >= CREDIT_HIGH) begin
                credit_high_n = credit_high_n + 1;
            end else begin
                credit_mid_n = credit_mid_n + 1;
            end

            if (backpressure_a || backpressure_b) begin
                backpressure_n = backpressure_n + 1;
            end
            if (crc_error_a || crc_error_b) begin
                crc_error_n = crc_error_n + 1;
            end
            if (resend_request_a || resend_request_b) begin
                resend_request_n = resend_request_n + 1;
            end
            if (lane_fault_a || lane_fault_b) begin
                lane_fault_n = lane_fault_n + 1;
            end
            if ((backpressure_a || backpressure_b) &&
                (resend_request_a || resend_request_b || crc_error_a || crc_error_b)) begin
                retry_backpressure_cross_n = retry_backpressure_cross_n + 1;
            end

            if (latency_valid) begin
                if (latency_value <= LAT_LOW) begin
                    latency_low_n = latency_low_n + 1;
                end else if (latency_value >= LAT_HIGH) begin
                    latency_high_n = latency_high_n + 1;
                end else begin
                    latency_nominal_n = latency_nominal_n + 1;
                end
            end

            if (e2e_update || tx_fire || rx_fire) begin
                e2e_updates_n = e2e_updates_n + 1;
            end
            if (e2e_mismatch) begin
                e2e_mismatch_n = e2e_mismatch_n + 1;
            end
            if (expected_empty) begin
                expected_empty_n = expected_empty_n + 1;
            end
            if (power_reset_proxy) begin
                power_reset_proxy_n = power_reset_proxy_n + 1;
            end
            if (power_idle_proxy) begin
                power_idle_proxy_n = power_idle_proxy_n + 1;
            end

            sample_cycles_q <= sample_cycles_n;
            link_reset_q <= link_reset_n;
            link_train_q <= link_train_n;
            link_active_q <= link_active_n;
            link_retrain_q <= link_retrain_n;
            link_degraded_q <= link_degraded_n;
            link_transitions_q <= link_transitions_n;
            link_recoveries_q <= link_recoveries_n;
            credit_zero_q <= credit_zero_n;
            credit_low_q <= credit_low_n;
            credit_mid_q <= credit_mid_n;
            credit_high_q <= credit_high_n;
            backpressure_q <= backpressure_n;
            crc_error_q <= crc_error_n;
            resend_request_q <= resend_request_n;
            lane_fault_q <= lane_fault_n;
            retry_backpressure_cross_q <= retry_backpressure_cross_n;
            latency_low_q <= latency_low_n;
            latency_nominal_q <= latency_nominal_n;
            latency_high_q <= latency_high_n;
            e2e_updates_q <= e2e_updates_n;
            e2e_mismatch_q <= e2e_mismatch_n;
            expected_empty_q <= expected_empty_n;
            power_reset_proxy_q <= power_reset_proxy_n;
            power_idle_proxy_q <= power_idle_proxy_n;
            last_link_state_a_q <= link_state_a;
            last_link_state_b_q <= link_state_b;
        end
    end

    function automatic int unsigned coverage_hits();
        return coverage_hit_count(
            link_reset_q,
            link_train_q,
            link_active_q,
            link_retrain_q,
            link_degraded_q,
            link_recoveries_q,
            credit_zero_q,
            credit_low_q,
            credit_mid_q,
            credit_high_q,
            backpressure_q,
            crc_error_q,
            resend_request_q,
            lane_fault_q,
            retry_backpressure_cross_q,
            latency_low_q,
            latency_nominal_q,
            latency_high_q,
            e2e_updates_q,
            e2e_mismatch_q,
            expected_empty_q,
            power_reset_proxy_q,
            power_idle_proxy_q
        );
    endfunction

    function automatic int unsigned coverage_total();
        return coverage_total_bins();
    endfunction

    task automatic write_coverage(input string path);
        write_cov_csv(
            path,
            sample_cycles_q,
            link_reset_q,
            link_train_q,
            link_active_q,
            link_retrain_q,
            link_degraded_q,
            link_transitions_q,
            link_recoveries_q,
            credit_zero_q,
            credit_low_q,
            credit_mid_q,
            credit_high_q,
            backpressure_q,
            crc_error_q,
            resend_request_q,
            lane_fault_q,
            retry_backpressure_cross_q,
            latency_low_q,
            latency_nominal_q,
            latency_high_q,
            e2e_updates_q,
            e2e_mismatch_q,
            expected_empty_q,
            power_reset_proxy_q,
            power_idle_proxy_q
        );
    endtask

    task automatic emit_result(
        input string bench_name,
        input string test_name,
        input string scenario_kind,
        input int unsigned seed,
        input string bug_mode,
        input bit pass,
        input string detail,
        input int unsigned tx_count,
        input int unsigned rx_count,
        input int unsigned retry_count,
        input int unsigned mismatch_count,
        input int unsigned drop_count,
        input int unsigned latency_violation_count,
        input int unsigned e2e_mismatch_count,
        input int unsigned expected_empty_count,
        input string score_path,
        input string cov_path
    );
        emit_result_line(
            bench_name,
            test_name,
            scenario_kind,
            seed,
            bug_mode,
            pass,
            detail,
            tx_count,
            rx_count,
            retry_count,
            mismatch_count,
            drop_count,
            latency_violation_count,
            e2e_mismatch_count,
            expected_empty_count,
            coverage_hits(),
            coverage_total(),
            score_path,
            cov_path
        );
    endtask

endmodule : stats_monitor

`endif
