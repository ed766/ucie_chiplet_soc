`ifndef UCIE_COV_PKG_SV
`define UCIE_COV_PKG_SV

package ucie_cov_pkg;

    localparam int unsigned UCIE_COV_TOTAL_BINS = 60;

    function automatic int unsigned coverage_total_bins();
        return UCIE_COV_TOTAL_BINS;
    endfunction

    function automatic int unsigned coverage_hit_count(
        input int unsigned link_reset,
        input int unsigned link_train,
        input int unsigned link_active,
        input int unsigned link_retrain,
        input int unsigned link_degraded,
        input int unsigned link_recoveries,
        input int unsigned credit_zero,
        input int unsigned credit_low,
        input int unsigned credit_mid,
        input int unsigned credit_high,
        input int unsigned backpressure,
        input int unsigned crc_error,
        input int unsigned resend_request,
        input int unsigned lane_fault,
        input int unsigned retry_backpressure_cross,
        input int unsigned latency_low,
        input int unsigned latency_nominal,
        input int unsigned latency_high,
        input int unsigned e2e_updates,
        input int unsigned e2e_mismatch,
        input int unsigned expected_empty,
        input int unsigned power_reset_proxy,
        input int unsigned power_idle_proxy,
        input int unsigned dma_submit_occ_0,
        input int unsigned dma_submit_occ_1,
        input int unsigned dma_submit_occ_23,
        input int unsigned dma_submit_occ_4,
        input int unsigned dma_comp_occ_0,
        input int unsigned dma_comp_occ_1,
        input int unsigned dma_comp_occ_23,
        input int unsigned dma_comp_occ_4,
        input int unsigned dma_submit_accept,
        input int unsigned dma_reject_odd,
        input int unsigned dma_reject_range,
        input int unsigned dma_reject_qfull,
        input int unsigned dma_reject_blocked,
        input int unsigned dma_reject_overflow,
        input int unsigned dma_submit_head_wrap,
        input int unsigned dma_submit_tail_wrap,
        input int unsigned dma_comp_head_wrap,
        input int unsigned dma_comp_tail_wrap,
        input int unsigned dma_active_present,
        input int unsigned dma_multi_queued,
        input int unsigned dma_comp_success,
        input int unsigned dma_comp_runtime_error,
        input int unsigned dma_comp_submit_reject,
        input int unsigned dma_retire_stall,
        input int unsigned dma_queue_drain_full_to_empty,
        input int unsigned dma_completion_under_retry,
        input int unsigned dma_completion_after_recovery,
        input int unsigned dma_completion_after_sleep_resume,
        input int unsigned mem_src_conflict,
        input int unsigned mem_dst_conflict,
        input int unsigned mem_wait,
        input int unsigned mem_parity_maint,
        input int unsigned mem_parity_dma,
        input int unsigned mem_invalid_read,
        input int unsigned mem_write_reject,
        input int unsigned mem_invalid_bank_present,
        input int unsigned mem_wake_apply
    );
        int unsigned hits;
        hits = 0;
        if (link_reset != 0) begin hits = hits + 1; end
        if (link_train != 0) begin hits = hits + 1; end
        if (link_active != 0) begin hits = hits + 1; end
        if (link_retrain != 0) begin hits = hits + 1; end
        if (link_degraded != 0) begin hits = hits + 1; end
        if (link_recoveries != 0) begin hits = hits + 1; end
        if (credit_zero != 0) begin hits = hits + 1; end
        if (credit_low != 0) begin hits = hits + 1; end
        if (credit_mid != 0) begin hits = hits + 1; end
        if (credit_high != 0) begin hits = hits + 1; end
        if (backpressure != 0) begin hits = hits + 1; end
        if (crc_error != 0) begin hits = hits + 1; end
        if (resend_request != 0) begin hits = hits + 1; end
        if (lane_fault != 0) begin hits = hits + 1; end
        if (retry_backpressure_cross != 0) begin hits = hits + 1; end
        if (latency_low != 0) begin hits = hits + 1; end
        if (latency_nominal != 0) begin hits = hits + 1; end
        if (latency_high != 0) begin hits = hits + 1; end
        if (e2e_updates != 0) begin hits = hits + 1; end
        if (e2e_mismatch != 0) begin hits = hits + 1; end
        if (expected_empty != 0) begin hits = hits + 1; end
        if (power_reset_proxy != 0) begin hits = hits + 1; end
        if (power_idle_proxy != 0) begin hits = hits + 1; end
        if (dma_submit_occ_0 != 0) begin hits = hits + 1; end
        if (dma_submit_occ_1 != 0) begin hits = hits + 1; end
        if (dma_submit_occ_23 != 0) begin hits = hits + 1; end
        if (dma_submit_occ_4 != 0) begin hits = hits + 1; end
        if (dma_comp_occ_0 != 0) begin hits = hits + 1; end
        if (dma_comp_occ_1 != 0) begin hits = hits + 1; end
        if (dma_comp_occ_23 != 0) begin hits = hits + 1; end
        if (dma_comp_occ_4 != 0) begin hits = hits + 1; end
        if (dma_submit_accept != 0) begin hits = hits + 1; end
        if (dma_reject_odd != 0) begin hits = hits + 1; end
        if (dma_reject_range != 0) begin hits = hits + 1; end
        if (dma_reject_qfull != 0) begin hits = hits + 1; end
        if (dma_reject_blocked != 0) begin hits = hits + 1; end
        if (dma_reject_overflow != 0) begin hits = hits + 1; end
        if (dma_submit_head_wrap != 0) begin hits = hits + 1; end
        if (dma_submit_tail_wrap != 0) begin hits = hits + 1; end
        if (dma_comp_head_wrap != 0) begin hits = hits + 1; end
        if (dma_comp_tail_wrap != 0) begin hits = hits + 1; end
        if (dma_active_present != 0) begin hits = hits + 1; end
        if (dma_multi_queued != 0) begin hits = hits + 1; end
        if (dma_comp_success != 0) begin hits = hits + 1; end
        if (dma_comp_runtime_error != 0) begin hits = hits + 1; end
        if (dma_comp_submit_reject != 0) begin hits = hits + 1; end
        if (dma_retire_stall != 0) begin hits = hits + 1; end
        if (dma_queue_drain_full_to_empty != 0) begin hits = hits + 1; end
        if (dma_completion_under_retry != 0) begin hits = hits + 1; end
        if (dma_completion_after_recovery != 0) begin hits = hits + 1; end
        if (dma_completion_after_sleep_resume != 0) begin hits = hits + 1; end
        if (mem_src_conflict != 0) begin hits = hits + 1; end
        if (mem_dst_conflict != 0) begin hits = hits + 1; end
        if (mem_wait != 0) begin hits = hits + 1; end
        if (mem_parity_maint != 0) begin hits = hits + 1; end
        if (mem_parity_dma != 0) begin hits = hits + 1; end
        if (mem_invalid_read != 0) begin hits = hits + 1; end
        if (mem_write_reject != 0) begin hits = hits + 1; end
        if (mem_invalid_bank_present != 0) begin hits = hits + 1; end
        if (mem_wake_apply != 0) begin hits = hits + 1; end
        return hits;
    endfunction

    task automatic write_cov_csv(
        input string path,
        input int unsigned sample_cycles,
        input int unsigned link_reset,
        input int unsigned link_train,
        input int unsigned link_active,
        input int unsigned link_retrain,
        input int unsigned link_degraded,
        input int unsigned link_transitions,
        input int unsigned link_recoveries,
        input int unsigned credit_zero,
        input int unsigned credit_low,
        input int unsigned credit_mid,
        input int unsigned credit_high,
        input int unsigned backpressure,
        input int unsigned crc_error,
        input int unsigned resend_request,
        input int unsigned lane_fault,
        input int unsigned retry_backpressure_cross,
        input int unsigned latency_low,
        input int unsigned latency_nominal,
        input int unsigned latency_high,
        input int unsigned e2e_updates,
        input int unsigned e2e_mismatch,
        input int unsigned expected_empty,
        input int unsigned power_reset_proxy,
        input int unsigned power_idle_proxy,
        input int unsigned dma_submit_occ_0,
        input int unsigned dma_submit_occ_1,
        input int unsigned dma_submit_occ_23,
        input int unsigned dma_submit_occ_4,
        input int unsigned dma_comp_occ_0,
        input int unsigned dma_comp_occ_1,
        input int unsigned dma_comp_occ_23,
        input int unsigned dma_comp_occ_4,
        input int unsigned dma_submit_accept,
        input int unsigned dma_reject_odd,
        input int unsigned dma_reject_range,
        input int unsigned dma_reject_qfull,
        input int unsigned dma_reject_blocked,
        input int unsigned dma_reject_overflow,
        input int unsigned dma_submit_head_wrap,
        input int unsigned dma_submit_tail_wrap,
        input int unsigned dma_comp_head_wrap,
        input int unsigned dma_comp_tail_wrap,
        input int unsigned dma_active_present,
        input int unsigned dma_multi_queued,
        input int unsigned dma_comp_success,
        input int unsigned dma_comp_runtime_error,
        input int unsigned dma_comp_submit_reject,
        input int unsigned dma_retire_stall,
        input int unsigned dma_queue_drain_full_to_empty,
        input int unsigned dma_completion_under_retry,
        input int unsigned dma_completion_after_recovery,
        input int unsigned dma_completion_after_sleep_resume,
        input int unsigned mem_src_conflict,
        input int unsigned mem_dst_conflict,
        input int unsigned mem_wait,
        input int unsigned mem_parity_maint,
        input int unsigned mem_parity_dma,
        input int unsigned mem_invalid_read,
        input int unsigned mem_write_reject,
        input int unsigned mem_invalid_bank_present,
        input int unsigned mem_wake_apply
    );
        int fd;
        int unsigned covered_bins;

        fd = $fopen(path, "w");
        if (fd == 0) begin
            $display("Failed to open coverage report file: %s", path);
        end else begin
            covered_bins = coverage_hit_count(
                link_reset,
                link_train,
                link_active,
                link_retrain,
                link_degraded,
                link_recoveries,
                credit_zero,
                credit_low,
                credit_mid,
                credit_high,
                backpressure,
                crc_error,
                resend_request,
                lane_fault,
                retry_backpressure_cross,
                latency_low,
                latency_nominal,
                latency_high,
                e2e_updates,
                e2e_mismatch,
                expected_empty,
                power_reset_proxy,
                power_idle_proxy,
                dma_submit_occ_0,
                dma_submit_occ_1,
                dma_submit_occ_23,
                dma_submit_occ_4,
                dma_comp_occ_0,
                dma_comp_occ_1,
                dma_comp_occ_23,
                dma_comp_occ_4,
                dma_submit_accept,
                dma_reject_odd,
                dma_reject_range,
                dma_reject_qfull,
                dma_reject_blocked,
                dma_reject_overflow,
                dma_submit_head_wrap,
                dma_submit_tail_wrap,
                dma_comp_head_wrap,
                dma_comp_tail_wrap,
                dma_active_present,
                dma_multi_queued,
                dma_comp_success,
                dma_comp_runtime_error,
                dma_comp_submit_reject,
                dma_retire_stall,
                dma_queue_drain_full_to_empty,
                dma_completion_under_retry,
                dma_completion_after_recovery,
                dma_completion_after_sleep_resume,
                mem_src_conflict,
                mem_dst_conflict,
                mem_wait,
                mem_parity_maint,
                mem_parity_dma,
                mem_invalid_read,
                mem_write_reject,
                mem_invalid_bank_present,
                mem_wake_apply
            );

            $fdisplay(fd, "metric,value");
            $fdisplay(fd, "sample_cycles,%0d", sample_cycles);
            $fdisplay(fd, "link_reset,%0d", link_reset);
            $fdisplay(fd, "link_train,%0d", link_train);
            $fdisplay(fd, "link_active,%0d", link_active);
            $fdisplay(fd, "link_retrain,%0d", link_retrain);
            $fdisplay(fd, "link_degraded,%0d", link_degraded);
            $fdisplay(fd, "link_transitions,%0d", link_transitions);
            $fdisplay(fd, "link_recoveries,%0d", link_recoveries);
            $fdisplay(fd, "credit_zero,%0d", credit_zero);
            $fdisplay(fd, "credit_low,%0d", credit_low);
            $fdisplay(fd, "credit_mid,%0d", credit_mid);
            $fdisplay(fd, "credit_high,%0d", credit_high);
            $fdisplay(fd, "backpressure,%0d", backpressure);
            $fdisplay(fd, "crc_error,%0d", crc_error);
            $fdisplay(fd, "resend_request,%0d", resend_request);
            $fdisplay(fd, "lane_fault,%0d", lane_fault);
            $fdisplay(fd, "retry_backpressure_cross,%0d", retry_backpressure_cross);
            $fdisplay(fd, "latency_low,%0d", latency_low);
            $fdisplay(fd, "latency_nominal,%0d", latency_nominal);
            $fdisplay(fd, "latency_high,%0d", latency_high);
            $fdisplay(fd, "e2e_updates,%0d", e2e_updates);
            $fdisplay(fd, "e2e_mismatch,%0d", e2e_mismatch);
            $fdisplay(fd, "expected_empty,%0d", expected_empty);
            $fdisplay(fd, "power_reset_proxy,%0d", power_reset_proxy);
            $fdisplay(fd, "power_idle_proxy,%0d", power_idle_proxy);
            $fdisplay(fd, "dma_submit_occ_0,%0d", dma_submit_occ_0);
            $fdisplay(fd, "dma_submit_occ_1,%0d", dma_submit_occ_1);
            $fdisplay(fd, "dma_submit_occ_23,%0d", dma_submit_occ_23);
            $fdisplay(fd, "dma_submit_occ_4,%0d", dma_submit_occ_4);
            $fdisplay(fd, "dma_comp_occ_0,%0d", dma_comp_occ_0);
            $fdisplay(fd, "dma_comp_occ_1,%0d", dma_comp_occ_1);
            $fdisplay(fd, "dma_comp_occ_23,%0d", dma_comp_occ_23);
            $fdisplay(fd, "dma_comp_occ_4,%0d", dma_comp_occ_4);
            $fdisplay(fd, "dma_submit_accept,%0d", dma_submit_accept);
            $fdisplay(fd, "dma_reject_odd,%0d", dma_reject_odd);
            $fdisplay(fd, "dma_reject_range,%0d", dma_reject_range);
            $fdisplay(fd, "dma_reject_qfull,%0d", dma_reject_qfull);
            $fdisplay(fd, "dma_reject_blocked,%0d", dma_reject_blocked);
            $fdisplay(fd, "dma_reject_overflow,%0d", dma_reject_overflow);
            $fdisplay(fd, "dma_submit_head_wrap,%0d", dma_submit_head_wrap);
            $fdisplay(fd, "dma_submit_tail_wrap,%0d", dma_submit_tail_wrap);
            $fdisplay(fd, "dma_comp_head_wrap,%0d", dma_comp_head_wrap);
            $fdisplay(fd, "dma_comp_tail_wrap,%0d", dma_comp_tail_wrap);
            $fdisplay(fd, "dma_active_present,%0d", dma_active_present);
            $fdisplay(fd, "dma_multi_queued,%0d", dma_multi_queued);
            $fdisplay(fd, "dma_comp_success,%0d", dma_comp_success);
            $fdisplay(fd, "dma_comp_runtime_error,%0d", dma_comp_runtime_error);
            $fdisplay(fd, "dma_comp_submit_reject,%0d", dma_comp_submit_reject);
            $fdisplay(fd, "dma_retire_stall,%0d", dma_retire_stall);
            $fdisplay(fd, "dma_queue_drain_full_to_empty,%0d", dma_queue_drain_full_to_empty);
            $fdisplay(fd, "dma_completion_under_retry,%0d", dma_completion_under_retry);
            $fdisplay(fd, "dma_completion_after_recovery,%0d", dma_completion_after_recovery);
            $fdisplay(fd, "dma_completion_after_sleep_resume,%0d", dma_completion_after_sleep_resume);
            $fdisplay(fd, "mem_src_conflict,%0d", mem_src_conflict);
            $fdisplay(fd, "mem_dst_conflict,%0d", mem_dst_conflict);
            $fdisplay(fd, "mem_wait,%0d", mem_wait);
            $fdisplay(fd, "mem_parity_maint,%0d", mem_parity_maint);
            $fdisplay(fd, "mem_parity_dma,%0d", mem_parity_dma);
            $fdisplay(fd, "mem_invalid_read,%0d", mem_invalid_read);
            $fdisplay(fd, "mem_write_reject,%0d", mem_write_reject);
            $fdisplay(fd, "mem_invalid_bank_present,%0d", mem_invalid_bank_present);
            $fdisplay(fd, "mem_wake_apply,%0d", mem_wake_apply);
            $fdisplay(fd, "covered_bins,%0d", covered_bins);
            $fdisplay(fd, "total_bins,%0d", coverage_total_bins());
            $fclose(fd);
        end
    endtask

endpackage : ucie_cov_pkg

`endif
