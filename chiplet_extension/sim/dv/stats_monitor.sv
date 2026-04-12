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
    input  logic        power_idle_proxy,
    input  logic        dma_mode_active,
    input  logic        dma_active_valid,
    input  logic [2:0]  dma_state,
    input  logic [2:0]  dma_submit_count,
    input  logic [2:0]  dma_comp_count,
    input  logic [1:0]  dma_submit_head,
    input  logic [1:0]  dma_submit_tail,
    input  logic [1:0]  dma_comp_head,
    input  logic [1:0]  dma_comp_tail,
    input  logic        dma_comp_full_stall,
    input  logic        dma_submit_accept_event,
    input  logic        dma_submit_reject_event,
    input  logic [3:0]  dma_submit_reject_err_code,
    input  logic        dma_comp_push_event,
    input  logic        dma_comp_pop_event,
    input  logic [1:0]  dma_comp_push_status,
    input  logic [3:0]  dma_comp_push_err_code,
    input  logic [31:0] dma_reject_overflow_count,
    input  logic        dma_retry_seen,
    input  logic        dma_recovery_seen,
    input  logic        dma_sleep_resume_seen,
    input  logic [15:0] mem_src_conflicts,
    input  logic [15:0] mem_dst_conflicts,
    input  logic [15:0] mem_src_wait_cycles,
    input  logic [15:0] mem_dst_wait_cycles,
    input  logic        mem_op_parity_error,
    input  logic        mem_op_invalid_read_seen,
    input  logic        mem_write_reject_dma_active,
    input  logic [1:0]  mem_src_invalid_bank_mask,
    input  logic [1:0]  mem_dst_invalid_bank_mask,
    input  logic        mem_wake_apply_seen
);

    import ucie_cov_pkg::*;
    import stats_pkg::*;

    localparam int unsigned CREDIT_LOW  = 16;
    localparam int unsigned CREDIT_HIGH = 96;
    localparam int unsigned LAT_LOW     = 41;
    localparam int unsigned LAT_HIGH    = 61;
    localparam logic [1:0] COMP_STATUS_SUCCESS       = 2'b01;
    localparam logic [1:0] COMP_STATUS_RUNTIME_ERROR = 2'b10;
    localparam logic [1:0] COMP_STATUS_SUBMIT_REJECT = 2'b11;

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
    int unsigned dma_submit_occ_0_q;
    int unsigned dma_submit_occ_1_q;
    int unsigned dma_submit_occ_23_q;
    int unsigned dma_submit_occ_4_q;
    int unsigned dma_comp_occ_0_q;
    int unsigned dma_comp_occ_1_q;
    int unsigned dma_comp_occ_23_q;
    int unsigned dma_comp_occ_4_q;
    int unsigned dma_submit_accept_q;
    int unsigned dma_reject_odd_q;
    int unsigned dma_reject_range_q;
    int unsigned dma_reject_qfull_q;
    int unsigned dma_reject_blocked_q;
    int unsigned dma_reject_overflow_q;
    int unsigned dma_submit_head_wrap_q;
    int unsigned dma_submit_tail_wrap_q;
    int unsigned dma_comp_head_wrap_q;
    int unsigned dma_comp_tail_wrap_q;
    int unsigned dma_active_present_q;
    int unsigned dma_multi_queued_q;
    int unsigned dma_comp_success_q;
    int unsigned dma_comp_runtime_error_q;
    int unsigned dma_comp_submit_reject_q;
    int unsigned dma_retire_stall_q;
    int unsigned dma_queue_drain_full_to_empty_q;
    int unsigned dma_completion_under_retry_q;
    int unsigned dma_completion_after_recovery_q;
    int unsigned dma_completion_after_sleep_resume_q;
    int unsigned mem_src_conflict_q;
    int unsigned mem_dst_conflict_q;
    int unsigned mem_wait_q;
    int unsigned mem_parity_maint_q;
    int unsigned mem_parity_dma_q;
    int unsigned mem_invalid_read_q;
    int unsigned mem_write_reject_q;
    int unsigned mem_invalid_bank_present_q;
    int unsigned mem_wake_apply_q;

    logic [2:0] last_link_state_a_q;
    logic [2:0] last_link_state_b_q;
    logic [1:0] last_submit_head_q;
    logic [1:0] last_submit_tail_q;
    logic [1:0] last_comp_head_q;
    logic [1:0] last_comp_tail_q;
    logic queue_seen_full_q;

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
            dma_submit_occ_0_q <= 0;
            dma_submit_occ_1_q <= 0;
            dma_submit_occ_23_q <= 0;
            dma_submit_occ_4_q <= 0;
            dma_comp_occ_0_q <= 0;
            dma_comp_occ_1_q <= 0;
            dma_comp_occ_23_q <= 0;
            dma_comp_occ_4_q <= 0;
            dma_submit_accept_q <= 0;
            dma_reject_odd_q <= 0;
            dma_reject_range_q <= 0;
            dma_reject_qfull_q <= 0;
            dma_reject_blocked_q <= 0;
            dma_reject_overflow_q <= 0;
            dma_submit_head_wrap_q <= 0;
            dma_submit_tail_wrap_q <= 0;
            dma_comp_head_wrap_q <= 0;
            dma_comp_tail_wrap_q <= 0;
            dma_active_present_q <= 0;
            dma_multi_queued_q <= 0;
            dma_comp_success_q <= 0;
            dma_comp_runtime_error_q <= 0;
            dma_comp_submit_reject_q <= 0;
            dma_retire_stall_q <= 0;
            dma_queue_drain_full_to_empty_q <= 0;
            dma_completion_under_retry_q <= 0;
            dma_completion_after_recovery_q <= 0;
            dma_completion_after_sleep_resume_q <= 0;
            mem_src_conflict_q <= 0;
            mem_dst_conflict_q <= 0;
            mem_wait_q <= 0;
            mem_parity_maint_q <= 0;
            mem_parity_dma_q <= 0;
            mem_invalid_read_q <= 0;
            mem_write_reject_q <= 0;
            mem_invalid_bank_present_q <= 0;
            mem_wake_apply_q <= 0;
            last_link_state_a_q <= 3'd0;
            last_link_state_b_q <= 3'd0;
            last_submit_head_q <= 2'd0;
            last_submit_tail_q <= 2'd0;
            last_comp_head_q <= 2'd0;
            last_comp_tail_q <= 2'd0;
            queue_seen_full_q <= 1'b0;
        end else begin
            sample_cycles_q <= sample_cycles_q + 1;

            case (link_state_a)
                3'd0: link_reset_q <= link_reset_q + 1;
                3'd1: link_train_q <= link_train_q + 1;
                3'd2: link_active_q <= link_active_q + 1;
                3'd3: link_retrain_q <= link_retrain_q + 1;
                default: link_degraded_q <= link_degraded_q + 1;
            endcase
            case (link_state_b)
                3'd0: link_reset_q <= link_reset_q + 1;
                3'd1: link_train_q <= link_train_q + 1;
                3'd2: link_active_q <= link_active_q + 1;
                3'd3: link_retrain_q <= link_retrain_q + 1;
                default: link_degraded_q <= link_degraded_q + 1;
            endcase

            if (link_state_a != last_link_state_a_q) begin
                link_transitions_q <= link_transitions_q + 1;
            end
            if (link_state_b != last_link_state_b_q) begin
                link_transitions_q <= link_transitions_q + 1;
            end
            if ((last_link_state_a_q == 3'd3 || last_link_state_a_q == 3'd4) && link_state_a == 3'd2) begin
                link_recoveries_q <= link_recoveries_q + 1;
            end
            if ((last_link_state_b_q == 3'd3 || last_link_state_b_q == 3'd4) && link_state_b == 3'd2) begin
                link_recoveries_q <= link_recoveries_q + 1;
            end

            if (credit_available_a == 0) begin
                credit_zero_q <= credit_zero_q + 1;
            end else if (credit_available_a <= CREDIT_LOW) begin
                credit_low_q <= credit_low_q + 1;
            end else if (credit_available_a >= CREDIT_HIGH) begin
                credit_high_q <= credit_high_q + 1;
            end else begin
                credit_mid_q <= credit_mid_q + 1;
            end
            if (credit_available_b == 0) begin
                credit_zero_q <= credit_zero_q + 1;
            end else if (credit_available_b <= CREDIT_LOW) begin
                credit_low_q <= credit_low_q + 1;
            end else if (credit_available_b >= CREDIT_HIGH) begin
                credit_high_q <= credit_high_q + 1;
            end else begin
                credit_mid_q <= credit_mid_q + 1;
            end

            if (backpressure_a || backpressure_b) begin
                backpressure_q <= backpressure_q + 1;
            end
            if (crc_error_a || crc_error_b) begin
                crc_error_q <= crc_error_q + 1;
            end
            if (resend_request_a || resend_request_b) begin
                resend_request_q <= resend_request_q + 1;
            end
            if (lane_fault_a || lane_fault_b) begin
                lane_fault_q <= lane_fault_q + 1;
            end
            if ((backpressure_a || backpressure_b) &&
                (resend_request_a || resend_request_b || crc_error_a || crc_error_b)) begin
                retry_backpressure_cross_q <= retry_backpressure_cross_q + 1;
            end

            if (latency_valid) begin
                if (latency_value <= LAT_LOW) begin
                    latency_low_q <= latency_low_q + 1;
                end else if (latency_value >= LAT_HIGH) begin
                    latency_high_q <= latency_high_q + 1;
                end else begin
                    latency_nominal_q <= latency_nominal_q + 1;
                end
            end

            if (e2e_update || tx_fire || rx_fire) begin
                e2e_updates_q <= e2e_updates_q + 1;
            end
            if (e2e_mismatch) begin
                e2e_mismatch_q <= e2e_mismatch_q + 1;
            end
            if (expected_empty) begin
                expected_empty_q <= expected_empty_q + 1;
            end
            if (power_reset_proxy) begin
                power_reset_proxy_q <= power_reset_proxy_q + 1;
            end
            if (power_idle_proxy) begin
                power_idle_proxy_q <= power_idle_proxy_q + 1;
            end

            if (dma_mode_active) begin
                case (dma_submit_count)
                    3'd0: dma_submit_occ_0_q <= dma_submit_occ_0_q + 1;
                    3'd1: dma_submit_occ_1_q <= dma_submit_occ_1_q + 1;
                    3'd4: dma_submit_occ_4_q <= dma_submit_occ_4_q + 1;
                    default: dma_submit_occ_23_q <= dma_submit_occ_23_q + 1;
                endcase

                case (dma_comp_count)
                    3'd0: dma_comp_occ_0_q <= dma_comp_occ_0_q + 1;
                    3'd1: dma_comp_occ_1_q <= dma_comp_occ_1_q + 1;
                    3'd4: dma_comp_occ_4_q <= dma_comp_occ_4_q + 1;
                    default: dma_comp_occ_23_q <= dma_comp_occ_23_q + 1;
                endcase

                if (dma_active_valid) begin
                    dma_active_present_q <= dma_active_present_q + 1;
                end
                if (dma_submit_count >= 2) begin
                    dma_multi_queued_q <= dma_multi_queued_q + 1;
                end
                if (dma_comp_full_stall || (dma_state == 3'd4)) begin
                    dma_retire_stall_q <= dma_retire_stall_q + 1;
                end
                if ((dma_submit_head < last_submit_head_q) && (dma_submit_count != 0)) begin
                    dma_submit_head_wrap_q <= dma_submit_head_wrap_q + 1;
                end
                if ((dma_submit_tail < last_submit_tail_q) &&
                    (dma_submit_accept_event || dma_submit_reject_event)) begin
                    dma_submit_tail_wrap_q <= dma_submit_tail_wrap_q + 1;
                end
                if ((dma_comp_head < last_comp_head_q) && dma_comp_pop_event) begin
                    dma_comp_head_wrap_q <= dma_comp_head_wrap_q + 1;
                end
                if ((dma_comp_tail < last_comp_tail_q) && dma_comp_push_event) begin
                    dma_comp_tail_wrap_q <= dma_comp_tail_wrap_q + 1;
                end
            end

            if (dma_submit_accept_event) begin
                dma_submit_accept_q <= dma_submit_accept_q + 1;
            end
            if (dma_submit_reject_event) begin
                case (dma_submit_reject_err_code)
                    4'd1: dma_reject_odd_q <= dma_reject_odd_q + 1;
                    4'd2: dma_reject_range_q <= dma_reject_range_q + 1;
                    4'd3: dma_reject_qfull_q <= dma_reject_qfull_q + 1;
                    4'd5: dma_reject_blocked_q <= dma_reject_blocked_q + 1;
                    default: begin
                    end
                endcase
            end
            if (dma_reject_overflow_count != 0) begin
                dma_reject_overflow_q <= dma_reject_overflow_q + 1;
            end

            if (dma_comp_push_event) begin
                case (dma_comp_push_status)
                    COMP_STATUS_SUCCESS: begin
                        dma_comp_success_q <= dma_comp_success_q + 1;
                    end
                    COMP_STATUS_RUNTIME_ERROR: begin
                        dma_comp_runtime_error_q <= dma_comp_runtime_error_q + 1;
                    end
                    COMP_STATUS_SUBMIT_REJECT: begin
                        dma_comp_submit_reject_q <= dma_comp_submit_reject_q + 1;
                    end
                    default: begin
                    end
                endcase

                if (dma_retry_seen) begin
                    dma_completion_under_retry_q <= dma_completion_under_retry_q + 1;
                end
                if (dma_recovery_seen) begin
                    dma_completion_after_recovery_q <= dma_completion_after_recovery_q + 1;
                end
                if (dma_sleep_resume_seen) begin
                    dma_completion_after_sleep_resume_q <= dma_completion_after_sleep_resume_q + 1;
                end
            end

            if ((dma_submit_count == 4) || (dma_comp_count == 4)) begin
                queue_seen_full_q <= 1'b1;
            end else if (queue_seen_full_q && !dma_active_valid &&
                         (dma_submit_count == 0) && (dma_comp_count == 0)) begin
                dma_queue_drain_full_to_empty_q <= dma_queue_drain_full_to_empty_q + 1;
                queue_seen_full_q <= 1'b0;
            end

            if (mem_src_conflicts != 0) begin
                mem_src_conflict_q <= mem_src_conflict_q + 1;
            end
            if (mem_dst_conflicts != 0) begin
                mem_dst_conflict_q <= mem_dst_conflict_q + 1;
            end
            if ((mem_src_wait_cycles != 0) || (mem_dst_wait_cycles != 0)) begin
                mem_wait_q <= mem_wait_q + 1;
            end
            if (mem_op_parity_error) begin
                mem_parity_maint_q <= mem_parity_maint_q + 1;
            end
            if (dma_comp_push_event &&
                (dma_comp_push_status == COMP_STATUS_RUNTIME_ERROR) &&
                (dma_comp_push_err_code == 4'd6)) begin
                mem_parity_dma_q <= mem_parity_dma_q + 1;
            end
            if (mem_op_invalid_read_seen) begin
                mem_invalid_read_q <= mem_invalid_read_q + 1;
            end
            if (mem_write_reject_dma_active) begin
                mem_write_reject_q <= mem_write_reject_q + 1;
            end
            if ((mem_src_invalid_bank_mask != 2'b00) || (mem_dst_invalid_bank_mask != 2'b00)) begin
                mem_invalid_bank_present_q <= mem_invalid_bank_present_q + 1;
            end
            if (mem_wake_apply_seen) begin
                mem_wake_apply_q <= mem_wake_apply_q + 1;
            end

            last_link_state_a_q <= link_state_a;
            last_link_state_b_q <= link_state_b;
            last_submit_head_q <= dma_submit_head;
            last_submit_tail_q <= dma_submit_tail;
            last_comp_head_q <= dma_comp_head;
            last_comp_tail_q <= dma_comp_tail;
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
            power_idle_proxy_q,
            dma_submit_occ_0_q,
            dma_submit_occ_1_q,
            dma_submit_occ_23_q,
            dma_submit_occ_4_q,
            dma_comp_occ_0_q,
            dma_comp_occ_1_q,
            dma_comp_occ_23_q,
            dma_comp_occ_4_q,
            dma_submit_accept_q,
            dma_reject_odd_q,
            dma_reject_range_q,
            dma_reject_qfull_q,
            dma_reject_blocked_q,
            dma_reject_overflow_q,
            dma_submit_head_wrap_q,
            dma_submit_tail_wrap_q,
            dma_comp_head_wrap_q,
            dma_comp_tail_wrap_q,
            dma_active_present_q,
            dma_multi_queued_q,
            dma_comp_success_q,
            dma_comp_runtime_error_q,
            dma_comp_submit_reject_q,
            dma_retire_stall_q,
            dma_queue_drain_full_to_empty_q,
            dma_completion_under_retry_q,
            dma_completion_after_recovery_q,
            dma_completion_after_sleep_resume_q,
            mem_src_conflict_q,
            mem_dst_conflict_q,
            mem_wait_q,
            mem_parity_maint_q,
            mem_parity_dma_q,
            mem_invalid_read_q,
            mem_write_reject_q,
            mem_invalid_bank_present_q,
            mem_wake_apply_q
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
            power_idle_proxy_q,
            dma_submit_occ_0_q,
            dma_submit_occ_1_q,
            dma_submit_occ_23_q,
            dma_submit_occ_4_q,
            dma_comp_occ_0_q,
            dma_comp_occ_1_q,
            dma_comp_occ_23_q,
            dma_comp_occ_4_q,
            dma_submit_accept_q,
            dma_reject_odd_q,
            dma_reject_range_q,
            dma_reject_qfull_q,
            dma_reject_blocked_q,
            dma_reject_overflow_q,
            dma_submit_head_wrap_q,
            dma_submit_tail_wrap_q,
            dma_comp_head_wrap_q,
            dma_comp_tail_wrap_q,
            dma_active_present_q,
            dma_multi_queued_q,
            dma_comp_success_q,
            dma_comp_runtime_error_q,
            dma_comp_submit_reject_q,
            dma_retire_stall_q,
            dma_queue_drain_full_to_empty_q,
            dma_completion_under_retry_q,
            dma_completion_after_recovery_q,
            dma_completion_after_sleep_resume_q,
            mem_src_conflict_q,
            mem_dst_conflict_q,
            mem_wait_q,
            mem_parity_maint_q,
            mem_parity_dma_q,
            mem_invalid_read_q,
            mem_write_reject_q,
            mem_invalid_bank_present_q,
            mem_wake_apply_q
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
        input int unsigned dma_desc_completed_count,
        input int unsigned dma_submit_accepted_count,
        input int unsigned dma_submit_rejected_count,
        input int unsigned dma_completion_push_count,
        input int unsigned dma_completion_pop_count,
        input int unsigned dma_irq_count,
        input int unsigned dma_error_count,
        input int unsigned dma_mem_mismatch_count,
        input string score_path,
        input string cov_path,
        input string power_path
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
            dma_desc_completed_count,
            dma_submit_accepted_count,
            dma_submit_rejected_count,
            dma_completion_push_count,
            dma_completion_pop_count,
            dma_irq_count,
            dma_error_count,
            dma_mem_mismatch_count,
            coverage_hits(),
            coverage_total(),
            score_path,
            cov_path,
            power_path
        );
    endtask

endmodule : stats_monitor

`endif
